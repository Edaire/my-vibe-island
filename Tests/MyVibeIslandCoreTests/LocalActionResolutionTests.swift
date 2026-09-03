import XCTest
@testable import MyVibeIslandCore

final class LocalActionResolutionTests: XCTestCase {
    func testLocalActionResolutionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            LocalActionResolutionMatrixFixture.self,
            from: try FixtureLoader.data("runtime/local-action-resolution-matrix")
        )

        let actual = LocalActionResolutionMatrixFixture(rows: [
            LocalActionResolutionMatrixRow(
                id: "single-permission-approve",
                initialEvents: [
                    .permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"),
                ],
                resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .approve, selection: "approve-once")
            ),
            LocalActionResolutionMatrixRow(
                id: "multiple-permission-deny-one",
                initialEvents: [
                    .permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"),
                    .permissionRequested(source: "codex", sessionId: "s1", requestId: "r2", toolName: "Edit"),
                ],
                resolution: ActionResolution(requestId: "r1", sessionId: "s1", kind: .deny)
            ),
            LocalActionResolutionMatrixRow(
                id: "wrong-session-noop",
                initialEvents: [
                    .permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"),
                ],
                resolution: ActionResolution(requestId: "r1", sessionId: "other", kind: .approve)
            ),
            LocalActionResolutionMatrixRow(
                id: "unknown-request-noop",
                initialEvents: [],
                resolution: ActionResolution(requestId: "missing", sessionId: "s1", kind: .dismiss)
            ),
            LocalActionResolutionMatrixRow(
                id: "question-answer-clears-actionable",
                initialEvents: [
                    .questionAsked(source: "codex", sessionId: "s1", requestId: "q1", toolName: "Prompt"),
                ],
                resolution: ActionResolution(requestId: "q1", sessionId: "s1", kind: .answer, selection: "yes")
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testResolvingExistingRequestRemovesPendingAndClearsAttention() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))

        let resolved = state.applyResolution(ActionResolution(
            requestId: "r1",
            sessionId: "s1",
            kind: .approve,
            selection: "approve-once"
        ))

        XCTAssertTrue(resolved)
        XCTAssertEqual(state.pendingRequestIds, [])
        XCTAssertEqual(state.actionableRequests, [])
        XCTAssertFalse(state.needsAttention)
    }

    func testDismissingFinalPermissionRestoresTheReportedActiveStatus() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        state.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "s1",
            activity: SessionActivityUpdate(status: .active, summary: nil)
        ))
        state.apply(.permissionRequested(
            source: "codex",
            sessionId: "s1",
            requestId: "r1",
            toolName: "Shell"
        ))

        XCTAssertEqual(state.originalStatus, .waitingForApproval)
        XCTAssertTrue(state.applyResolution(ActionResolution(
            requestId: "r1",
            sessionId: "s1",
            kind: .dismiss
        )))

        XCTAssertEqual(state.originalStatus, .processing)
        XCTAssertTrue(state.pendingRequestIds.isEmpty)
        XCTAssertTrue(state.actionableRequests.isEmpty)
    }

    func testTerminalCompletionClearsPendingPermissionWithoutLocalResolution() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        state.apply(.permissionRequested(
            source: "codex",
            sessionId: "s1",
            requestId: "terminal-r1",
            toolName: "Bash"
        ))

        state.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "s1",
            activity: SessionActivityUpdate(status: .completed, summary: "Codex completed the turn.")
        ))

        XCTAssertTrue(state.pendingRequestIds.isEmpty)
        XCTAssertTrue(state.actionableRequests.isEmpty)
        XCTAssertFalse(state.needsAttention)
        XCTAssertEqual(state.originalStatus, .ended)
    }

    func testResolvingOneOfMultipleRequestsKeepsRemainingAttention() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r2", toolName: "Edit"))

        let resolved = state.applyResolution(ActionResolution(requestId: "r1", sessionId: "s1", kind: .deny))

        XCTAssertTrue(resolved)
        XCTAssertEqual(state.pendingRequestIds, ["r2"])
        XCTAssertEqual(state.actionableRequests.map(\.requestId), ["r2"])
        XCTAssertTrue(state.needsAttention)
    }

    func testWrongSessionResolutionIsNoOp() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))

        let resolved = state.applyResolution(ActionResolution(requestId: "r1", sessionId: "other", kind: .approve))

        XCTAssertFalse(resolved)
        XCTAssertEqual(state.pendingRequestIds, ["r1"])
        XCTAssertEqual(state.actionableRequests.map(\.requestId), ["r1"])
        XCTAssertTrue(state.needsAttention)
    }

    func testUnknownRequestResolutionIsNoOp() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")

        let resolved = state.applyResolution(ActionResolution(requestId: "missing", sessionId: "s1", kind: .dismiss))

        XCTAssertFalse(resolved)
        XCTAssertEqual(state.pendingRequestIds, [])
        XCTAssertEqual(state.actionableRequests, [])
        XCTAssertFalse(state.needsAttention)
    }

    func testRuntimeResolveActionStoresSelectionAndSavesSessionState() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        let store = InMemorySessionStore()
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator,
            sessionStore: store
        )

        let resolved = runtime.resolveAction(ActionResolution(
            requestId: "r1",
            sessionId: "s1",
            kind: .approve,
            selection: "approve-once"
        ))

        XCTAssertTrue(resolved)
        XCTAssertEqual(runtime.actionableRequests(), [])
        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "s1")?.pendingRequestIds, [])
        XCTAssertEqual(store.loadSnapshot().questionSelections, ["r1": "approve-once"])
        XCTAssertEqual(store.loadSnapshot().sessions.first?.pendingRequestIds, [])
    }

    func testRuntimeWithoutStoreResolvesLocalStateWithoutSelectionPersistence() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator
        )

        let resolved = runtime.resolveAction(ActionResolution(requestId: "r1", sessionId: "s1", kind: .dismiss))

        XCTAssertTrue(resolved)
        XCTAssertEqual(runtime.actionableRequests(), [])
        XCTAssertNil(runtime.questionSelection(forRequestId: "r1"))
    }
}

private struct LocalActionResolutionMatrixFixture: Codable, Equatable {
    let rows: [LocalActionResolutionMatrixRow]
}

private struct LocalActionResolutionMatrixRow: Codable, Equatable {
    let id: String
    let resolved: Bool
    let pendingRequestIds: [String]
    let actionableRequestIds: [String]
    let needsAttention: Bool
    let isRestored: Bool

    init(id: String, initialEvents: [AgentEvent], resolution: ActionResolution) {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        for event in initialEvents {
            state.apply(event)
        }

        let resolved = state.applyResolution(resolution)

        self.id = id
        self.resolved = resolved
        self.pendingRequestIds = state.pendingRequestIds
        self.actionableRequestIds = state.actionableRequests.map(\.requestId)
        self.needsAttention = state.needsAttention
        self.isRestored = state.isRestored
    }
}
