import XCTest
@testable import MyVibeIslandCore

final class ActionableRequestReadModelTests: XCTestCase {
    func testActionableRequestReadModelMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ActionableRequestReadModelMatrixFixture.self,
            from: try FixtureLoader.data("runtime/actionable-request-read-model-matrix")
        )

        let duplicateState = stateWithDuplicatePermissionRequest()
        let restoredState = SessionState(agentSession: AgentSession(
            id: "restored",
            source: "claude",
            cwd: "/tmp/restored",
            pendingRequestIds: ["r1", "r2"]
        ))

        let selectedCoordinator = SessionCoordinator()
        selectedCoordinator.apply(.permissionRequested(
            source: "codex",
            sessionId: "s1",
            requestId: "r1",
            toolName: "Shell"
        ))
        let selectedStore = InMemorySessionStore()
        selectedStore.setQuestionSelection("approve-once", forRequestId: "r1")
        let selectedRuntime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: selectedCoordinator,
            sessionStore: selectedStore
        )

        let noStoreCoordinator = SessionCoordinator()
        noStoreCoordinator.apply(.permissionRequested(
            source: "codex",
            sessionId: "s1",
            requestId: "r1",
            toolName: "Shell"
        ))
        let noStoreRuntime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: noStoreCoordinator
        )

        let liveCoordinator = SessionCoordinator(sessions: [
            SessionState(sessionId: "live", source: "codex", cwd: "/tmp/live"),
        ])
        let storedSessionStore = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(id: "stored", source: "claude", cwd: "/tmp/stored"),
        ]))
        let liveRuntime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: liveCoordinator,
            sessionStore: storedSessionStore
        )

        let actual = ActionableRequestReadModelMatrixFixture(cases: [
            ActionableRequestReadModelMatrixCase(
                name: "permission-request-stores-details",
                projection: projection(for: stateWithPermissionRequest())
            ),
            ActionableRequestReadModelMatrixCase(
                name: "duplicate-permission-updates-tool-name",
                projection: projection(for: duplicateState)
            ),
            ActionableRequestReadModelMatrixCase(
                name: "restored-session-drops-ephemeral-requests",
                projection: projection(for: restoredState)
            ),
            ActionableRequestReadModelMatrixCase(
                name: "runtime-merges-stored-selection",
                projection: projection(for: selectedRuntime)
            ),
            ActionableRequestReadModelMatrixCase(
                name: "runtime-without-store-has-no-selection",
                projection: projection(for: noStoreRuntime)
            ),
            ActionableRequestReadModelMatrixCase(
                name: "existing-coordinator-does-not-restore-store-session",
                projection: ActionableRequestReadModelProjection(
                    requestIds: [],
                    sessionIds: liveRuntime.runtimeSessionSnapshots().map(\.snapshot.sessionId),
                    sources: liveRuntime.runtimeSessionSnapshots().map(\.snapshot.source),
                    kinds: [],
                    toolNames: [],
                    pendingRequestIds: [],
                    storedSelections: [],
                    singleLookupSelection: nil,
                    liveSessionIds: liveRuntime.runtimeSessionSnapshots().map(\.snapshot.sessionId)
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testPermissionRequestStoresActionableRequestDetails() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")

        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))

        XCTAssertEqual(state.pendingRequestIds, ["r1"])
        XCTAssertEqual(state.actionableRequests.count, 1)
        XCTAssertEqual(state.actionableRequests.first?.requestId, "r1")
        XCTAssertEqual(state.actionableRequests.first?.toolName, "Shell")
        XCTAssertNotNil(state.actionableRequests.first?.actionableRequestLifecycleTimestamp)
    }

    func testDuplicatePermissionRequestUpdatesDetailsWithoutDuplicatingPendingId() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")

        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Edit"))

        XCTAssertEqual(state.pendingRequestIds, ["r1"])
        XCTAssertEqual(state.actionableRequests.count, 1)
        XCTAssertEqual(state.actionableRequests.first?.requestId, "r1")
        XCTAssertEqual(state.actionableRequests.first?.toolName, "Edit")
        XCTAssertNotNil(state.actionableRequests.first?.actionableRequestLifecycleTimestamp)
    }

    func testRestoredSessionDropsEphemeralActionableRequests() {
        let state = SessionState(agentSession: AgentSession(
            id: "restored",
            source: "claude",
            cwd: "/tmp/restored",
            pendingRequestIds: ["r1", "r2"]
        ))

        XCTAssertTrue(state.pendingRequestIds.isEmpty)
        XCTAssertTrue(state.actionableRequests.isEmpty)
        XCTAssertFalse(state.needsAttention)
    }

    func testRuntimeActionableRequestsMergeStoredSelections() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        let store = InMemorySessionStore()
        store.setQuestionSelection("approve-once", forRequestId: "r1")
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator,
            sessionStore: store
        )

        XCTAssertEqual(runtime.actionableRequests().count, 1)
        XCTAssertEqual(runtime.actionableRequests().first?.request.requestId, "r1")
        XCTAssertEqual(runtime.actionableRequests().first?.request.toolName, "Shell")
        XCTAssertNotNil(runtime.actionableRequests().first?.request.actionableRequestLifecycleTimestamp)
        XCTAssertEqual(runtime.actionableRequests().first?.storedSelection, "approve-once")
        XCTAssertEqual(runtime.actionableRequest(requestId: "r1")?.storedSelection, "approve-once")
    }

    func testRuntimeWithoutStoreReturnsActionableRequestsWithoutStoredSelections() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator
        )

        XCTAssertEqual(runtime.actionableRequests().map(\.storedSelection), [nil])
    }

    func testRuntimeWithExistingCoordinatorDoesNotRestoreOverLiveSessionState() {
        let coordinator = SessionCoordinator(sessions: [
            SessionState(sessionId: "live", source: "codex", cwd: "/tmp/live"),
        ])
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(id: "stored", source: "claude", cwd: "/tmp/stored"),
        ]))

        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator,
            sessionStore: store
        )

        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "live")?.cwd, "/tmp/live")
        XCTAssertNil(runtime.sessionSnapshot(sessionId: "stored"))
    }

    func testGenericQuestionRequestStoresOnlySafePromptAndNormalizedOptions() {
        let lifecycleTimestamp = Date(timeIntervalSince1970: 123)
        let coordinator = SessionCoordinator()
        let response = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            now: { lifecycleTimestamp }
        ).handle(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "generic-agent",
            requestId: "question-1",
            command: .hookEvent,
            payload: [
                "rawEventName": .string("QuestionRequest"),
                "sessionId": .string("session-1"),
                "cwd": .string("/tmp/project"),
                "toolName": .string("AskUserQuestion"),
                "message": .string("Which implementation path should be used?"),
                "multiSelect": .bool(true),
                "options": .array([
                    .string("Structured"),
                    .object([
                        "id": .string("minimal"),
                        "label": .string("Minimal"),
                        "description": .string("Use the smallest compatible change."),
                        "rawCommand": .string("must-not-be-retained"),
                    ]),
                    .object(["description": .string("missing label")]),
                ]),
            ]
        ))

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.actionableRequests(), [
            ActionableRequest(
                requestId: "question-1",
                sessionId: "session-1",
                source: "generic-agent",
                kind: .question,
                toolName: "AskUserQuestion",
                details: ActionRequestDetails(
                    prompt: "Which implementation path should be used?",
                    options: [
                        ActionRequestOption(id: "option-1", label: "Structured"),
                        ActionRequestOption(
                            id: "minimal",
                            label: "Minimal",
                            detail: "Use the smallest compatible change."
                        ),
                    ],
                    allowsMultipleSelection: true
                ),
                actionableRequestLifecycleTimestamp: lifecycleTimestamp
            ),
        ])
    }

    func testCodexPermissionPreviewUsesLocalResolutionByDefaultWhileUnknownAdapterDoesNot() {
        let unknown = ActionRequestPreview(request: ActionableRequest(
            requestId: "unknown-1",
            sessionId: "session-1",
            source: "generic-agent",
            kind: .permission,
            toolName: "Shell"
        ))
        let codex = ActionRequestPreview(request: ActionableRequest(
            requestId: "codex-1",
            sessionId: "session-1",
            source: "codex",
            kind: .permission,
            toolName: "Shell"
        ))

        XCTAssertFalse(unknown.canResolveLocally)
        XCTAssertTrue(codex.canResolveLocally)
    }

    func testRecoveredOpenCodeAskUserQuestionPayloadBuildsMultiQuestionDetails() {
        let coordinator = SessionCoordinator()

        let response = BridgeRequestHandler(sessionCoordinator: coordinator).handle(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "opencode",
            requestId: "question-1",
            command: .hookEvent,
            payload: [
                "rawEventName": .string("PermissionRequest"),
                "sessionId": .string("session-1"),
                "cwd": .string("/tmp/project"),
                "toolName": .string("AskUserQuestion"),
                "tool_input": .object([
                    "questions": .array([
                        .object([
                            "header": .string("Target"),
                            "question": .string("Choose a deployment target"),
                            "options": .array([
                                .object([
                                    "label": .string("Local"),
                                    "description": .string("Run on this Mac"),
                                ]),
                                .object(["label": .string("Remote")]),
                            ]),
                            "multiSelect": .bool(false),
                        ]),
                        .object([
                            "header": .string("Checks"),
                            "question": .string("Select verification steps"),
                            "options": .array([
                                .object(["label": .string("Tests")]),
                                .object(["label": .string("Lint")]),
                            ]),
                            "multiSelect": .bool(true),
                            "rawSecret": .string("must-not-be-retained"),
                        ]),
                    ]),
                ]),
            ]
        ))

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.actionableRequests().first?.kind, .question)
        XCTAssertEqual(coordinator.actionableRequests().first?.details?.questions, [
            ActionRequestQuestion(
                id: "Target",
                header: "Target",
                prompt: "Choose a deployment target",
                options: [
                    ActionRequestOption(id: "option-1", label: "Local", detail: "Run on this Mac"),
                    ActionRequestOption(id: "option-2", label: "Remote"),
                ]
            ),
            ActionRequestQuestion(
                id: "Checks",
                header: "Checks",
                prompt: "Select verification steps",
                options: [
                    ActionRequestOption(id: "option-1", label: "Tests"),
                    ActionRequestOption(id: "option-2", label: "Lint"),
                ],
                allowsMultipleSelection: true
            ),
        ])
    }

    private func stateWithPermissionRequest() -> SessionState {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        return state
    }

    private func stateWithDuplicatePermissionRequest() -> SessionState {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Edit"))
        return state
    }

    private func projection(for state: SessionState) -> ActionableRequestReadModelProjection {
        ActionableRequestReadModelProjection(
            requestIds: state.actionableRequests.map(\.requestId),
            sessionIds: state.actionableRequests.map(\.sessionId),
            sources: state.actionableRequests.map(\.source),
            kinds: state.actionableRequests.map(\.kind.rawValue),
            toolNames: state.actionableRequests.map(\.toolName),
            pendingRequestIds: state.pendingRequestIds,
            storedSelections: [],
            singleLookupSelection: nil,
            liveSessionIds: []
        )
    }

    private func projection(for runtime: AppRuntime) -> ActionableRequestReadModelProjection {
        let requests = runtime.actionableRequests()
        return ActionableRequestReadModelProjection(
            requestIds: requests.map(\.request.requestId),
            sessionIds: requests.map(\.request.sessionId),
            sources: requests.map(\.request.source),
            kinds: requests.map(\.request.kind.rawValue),
            toolNames: requests.map(\.request.toolName),
            pendingRequestIds: runtime.runtimeSessionSnapshots().compactMap(\.snapshot.waitingActionSummary.firstPendingRequestId),
            storedSelections: requests.map(\.storedSelection),
            singleLookupSelection: runtime.actionableRequest(requestId: "r1")?.storedSelection,
            liveSessionIds: runtime.runtimeSessionSnapshots().map(\.snapshot.sessionId)
        )
    }

    private struct ActionableRequestReadModelMatrixFixture: Codable, Equatable {
        let cases: [ActionableRequestReadModelMatrixCase]
    }

    private struct ActionableRequestReadModelMatrixCase: Codable, Equatable {
        let name: String
        let projection: ActionableRequestReadModelProjection
    }

    private struct ActionableRequestReadModelProjection: Codable, Equatable {
        let requestIds: [String]
        let sessionIds: [String]
        let sources: [String]
        let kinds: [String]
        let toolNames: [String]
        let pendingRequestIds: [String]
        let storedSelections: [String?]
        let singleLookupSelection: String?
        let liveSessionIds: [String]
    }
}
