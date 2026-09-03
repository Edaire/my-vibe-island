import XCTest
@testable import MyVibeIslandCore

final class AppRuntimeTests: XCTestCase {
    func testProductionRuntimeAdmitsClaudeSessionThroughBridgeHook() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let home = temporaryHomeDirectory()
        let runtime = AppRuntime(
            socketPath: socketPath,
            sessionStore: AppRuntimeSessionStore.defaultStore(homeDirectory: home),
            localWatcherHomeDirectory: home
        )
        try runtime.startBridge()
        defer { runtime.stop() }

        _ = try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: "claude",
                requestId: nil,
                command: .hookEvent,
                payload: [
                    "hook_event_name": .string("SessionStart"),
                    "session_id": .string("claude-live"),
                    "cwd": .string("/tmp/claude-live")
                ]
            )
        )

        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "claude-live")?.source, "claude")
        XCTAssertEqual(runtime.islandRuntimeSnapshot().sessions.map(\.id), ["claude-live"])
    }

    func testProductionRuntimeDoesNotRenderPersistedSessionUntilLiveEvidenceArrives() {
        let home = temporaryHomeDirectory()
        let store = AppRuntimeSessionStore.defaultStore(homeDirectory: home)
        store.replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "historical-claude",
                source: "claude",
                cwd: "/tmp/old-project",
                originalStatus: .processing,
                firstUserMessage: "old prompt",
                lastUserMessage: "old prompt"
            ),
        ]))

        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        XCTAssertEqual(runtime.islandRuntimeSnapshot().sessions.map(\.id), [])
    }

    func testRuntimeDismissExpiresBlockingContinuation() throws {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(
            source: "codex",
            sessionId: "expiry-session",
            requestId: "expiry-request",
            toolName: "Shell"
        ))
        let continuations = PendingActionContinuations(timeout: 1)
        let runtime = AppRuntime(
            sessionCoordinator: coordinator,
            blockingActionContinuations: continuations
        )
        let request = try XCTUnwrap(coordinator.actionableRequests().first)
        let completed = DispatchGroup()
        completed.enter()
        DispatchQueue.global().async {
            _ = continuations.wait(for: request)
            completed.leave()
        }
        let deadline = Date().addingTimeInterval(0.2)
        while Date() < deadline, continuations.pendingCount == 0 {
            Thread.sleep(forTimeInterval: 0.005)
        }

        XCTAssertTrue(runtime.resolveAction(ActionResolution(
            requestId: request.requestId,
            sessionId: request.sessionId,
            kind: .dismiss
        )))
        XCTAssertEqual(completed.wait(timeout: .now() + 0.2), .success)
        XCTAssertEqual(continuations.pendingCount, 0)
    }

    func testRuntimeTerminalHandoffReleasesOwnedPermissionHook() throws {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(
            source: "codex",
            sessionId: "terminal-handoff-session",
            requestId: "terminal-handoff-request",
            toolName: "Shell"
        ))
        let continuations = PendingActionContinuations(timeout: 10)
        let runtime = AppRuntime(
            sessionCoordinator: coordinator,
            blockingActionContinuations: continuations
        )
        let request = try XCTUnwrap(coordinator.actionableRequests().first)
        let waiter = DispatchGroup()
        waiter.enter()
        DispatchQueue.global().async {
            _ = continuations.wait(for: request)
            waiter.leave()
        }
        let deadline = Date().addingTimeInterval(0.2)
        while Date() < deadline, !continuations.owns(request) {
            Thread.sleep(forTimeInterval: 0.005)
        }

        XCTAssertTrue(runtime.handoffPendingApprovalToTerminal(sessionId: request.sessionId))
        XCTAssertEqual(waiter.wait(timeout: .now() + 0.2), .success)
        XCTAssertFalse(continuations.owns(request))
    }

    private final class ResponseBox: @unchecked Sendable {
        private let lock = NSLock()
        private var response: BridgeResponse?
        private var error: Error?

        func record(_ result: Result<BridgeResponse, Error>) {
            lock.lock()
            switch result {
            case let .success(response):
                self.response = response
            case let .failure(error):
                self.error = error
            }
            lock.unlock()
        }

        func get() throws -> BridgeResponse {
            lock.lock()
            defer {
                lock.unlock()
            }

            if let error {
                throw error
            }
            return try XCTUnwrap(response)
        }
    }

    private final class ConcurrentStartResults: @unchecked Sendable {
        private let lock = NSLock()
        private var successes = 0
        private var failures: [BridgeSocketError] = []

        func recordSuccess() {
            lock.lock()
            successes += 1
            lock.unlock()
        }

        func recordFailure(_ error: BridgeSocketError) {
            lock.lock()
            failures.append(error)
            lock.unlock()
        }

        func snapshot() -> (successes: Int, failures: [BridgeSocketError]) {
            lock.lock()
            defer {
                lock.unlock()
            }

            return (successes, failures)
        }
    }

    private final class SessionPreviewRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var publications: [[SessionCardPreview]] = []

        func record(_ previews: [SessionCardPreview]) {
            lock.lock()
            publications.append(previews)
            lock.unlock()
        }

        func snapshot() -> [[SessionCardPreview]] {
            lock.lock()
            defer { lock.unlock() }
            return publications
        }
    }

    private final class IslandRuntimeSnapshotRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var snapshots: [IslandRuntimeSnapshot] = []

        func record(_ snapshot: IslandRuntimeSnapshot) {
            lock.lock()
            snapshots.append(snapshot)
            lock.unlock()
        }

        func snapshot() -> [IslandRuntimeSnapshot] {
            lock.lock()
            defer { lock.unlock() }
            return snapshots
        }
    }

    private final class RecordingJumpRunner: TerminalJumpActionRunning, @unchecked Sendable {
        private(set) var actions: [TerminalJumpActionDescription] = []
        private let result: TerminalJumpRunnerResult

        init(result: TerminalJumpRunnerResult) {
            self.result = result
        }

        func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
            actions.append(action)
            return result
        }
    }

    private func helloResponse(socketPath: String) throws -> BridgeResponse {
        try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(schemaVersion: 1, clientRole: "diagnostic", source: "app", requestId: nil, command: .hello, payload: [:])
        )
    }

    private func temporaryHomeDirectory() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-production-runtime-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    func testAppRuntimeJumpReadModelMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppRuntimeJumpReadModelMatrixFixture.self,
            from: try FixtureLoader.data("runtime/app-runtime-jump-read-model-matrix")
        )

        let emptyRuntime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())

        let tmuxInput = JumpInput(sessionId: "tmux", source: "codex", tmuxPane: "%1")
        let tmuxRuntime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(
                    sessionId: "tmux",
                    source: "codex",
                    cwd: "/tmp/project",
                    jumpInput: tmuxInput,
                    resolvedJumpTarget: TerminalResolver().resolve(tmuxInput)
                ),
            ])
        )

        let workspaceInput = JumpInput(sessionId: "workspace", source: "codex", cwd: "/tmp/project")
        let runner = RecordingJumpRunner(result: .succeeded("opened workspace"))
        let workspaceRuntime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(
                    sessionId: "workspace",
                    source: "codex",
                    cwd: "/tmp/project",
                    jumpInput: workspaceInput,
                    resolvedJumpTarget: TerminalResolver().resolve(workspaceInput)
                ),
            ]),
            jumpRunner: runner
        )

        let actual = AppRuntimeJumpReadModelMatrixFixture(rows: [
            row(id: "empty-runtime-status", runtime: emptyRuntime, sessionId: "missing", mode: .dryRun),
            row(id: "tmux-planned-dry-run", runtime: tmuxRuntime, sessionId: "tmux", mode: .dryRun),
            row(id: "tmux-execute-blocked-without-runner", runtime: tmuxRuntime, sessionId: "tmux", mode: .execute),
            row(id: "workspace-execute-injected-runner", runtime: workspaceRuntime, sessionId: "workspace", mode: .execute),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRuntimeReportsStoppedInitialStatus() {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(socketPath: socketPath)

        XCTAssertEqual(runtime.status(), AppRuntimeStatus(socketPath: socketPath, isBridgeRunning: false, sessionCount: 0))
    }

    func testRuntimeStartsBridgeAndRespondsToHello() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(socketPath: socketPath)
        try runtime.startBridge()
        defer {
            runtime.stop()
        }

        let response = try helloResponse(socketPath: socketPath)

        XCTAssertEqual(response, .ok(message: "bridge reachable"))
        XCTAssertEqual(runtime.status().isBridgeRunning, true)
    }

    func testRuntimeStoresHookEventSessionState() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(socketPath: socketPath)
        try runtime.startBridge()
        defer {
            runtime.stop()
        }

        _ = try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: "codex",
                requestId: nil,
                command: .hookEvent,
                payload: [
                    "rawEventName": .string("SessionStart"),
                    "sessionId": .string("s1"),
                    "cwd": .string("/tmp/project")
                ]
            )
        )

        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "s1")?.cwd, "/tmp/project")
        XCTAssertEqual(runtime.status().sessionCount, 1)
    }

    func testIslandRuntimeSnapshotSurfacesSessionStartAsSpotlight() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let recorder = IslandRuntimeSnapshotRecorder()
        let runtime = AppRuntime(
            socketPath: socketPath,
            islandRuntimeDidChange: recorder.record
        )
        try runtime.startBridge()
        defer { runtime.stop() }

        _ = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("live-session"),
                "cwd": .string("/tmp/live")
            ]
        ))

        XCTAssertEqual(runtime.islandRuntimeSnapshot().sessions.map(\.id), ["live-session"])
    }

    func testRuntimeCoalescesPendingSessionPublicationsIntoOneSnapshot() {
        let queue = DispatchQueue(label: "my-vibe-island.tests.publication-gate")
        let recorder = IslandRuntimeSnapshotRecorder()
        let delivered = DispatchSemaphore(value: 0)
        queue.suspend()
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(sessionId: "session", source: "codex", cwd: "/tmp/session"),
            ]),
            publicationQueue: queue,
            islandRuntimeDidChange: { snapshot in
                recorder.record(snapshot)
                delivered.signal()
            }
        )

        runtime.publishSessionPreviews()
        runtime.publishSessionPreviews()
        XCTAssertEqual(recorder.snapshot(), [])

        queue.resume()
        XCTAssertEqual(delivered.wait(timeout: .now() + 1), .success)
        Thread.sleep(forTimeInterval: 0.03)
        XCTAssertEqual(recorder.snapshot().count, 1)
    }

    func testRuntimeDoesNotDropMutationArrivingWhilePublicationIsQueued() {
        let queue = DispatchQueue(label: "my-vibe-island.tests.publication-dirty")
        let recorder = IslandRuntimeSnapshotRecorder()
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let delivered = DispatchSemaphore(value: 0)
        let coordinator = SessionCoordinator(sessions: [
            SessionState(sessionId: "initial", source: "codex", cwd: "/tmp/initial"),
        ])
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator,
            publicationQueue: queue,
            islandRuntimeDidChange: { snapshot in
                recorder.record(snapshot)
                entered.signal()
                _ = release.wait(timeout: .now() + 1)
                delivered.signal()
            }
        )

        runtime.publishSessionPreviews()
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        coordinator.apply(.sessionStarted(source: "codex", sessionId: "arrived", cwd: "/tmp/arrived"))
        runtime.publishSessionPreviews()
        release.signal()
        XCTAssertEqual(delivered.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(delivered.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(recorder.snapshot().last?.sessions.map(\.id), ["arrived", "initial"])
    }

    func testSessionEndCleanupPublishesRemovedSessionToIslandRuntimeConsumer() {
        let scheduler = AppRuntimeManualSessionEndCleanupScheduler()
        let coordinator = SessionCoordinator(
            sessions: [],
            sessionEndCleanupScheduler: scheduler
        )
        let recorder = IslandRuntimeSnapshotRecorder()
        let delivered = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "my-vibe-island.tests.session-end-publication")
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator,
            publicationQueue: queue,
            islandRuntimeDidChange: { snapshot in
                recorder.record(snapshot)
                delivered.signal()
            }
        )

        coordinator.apply(.sessionStarted(source: "codex", sessionId: "ending", cwd: "/tmp/ending"))
        coordinator.apply(.sessionEnded(source: "codex", sessionId: "ending"))
        scheduler.runNext()

        XCTAssertEqual(delivered.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(recorder.snapshot().last?.sessions.map(\.id), [])
        XCTAssertEqual(runtime.islandRuntimeSnapshot().sessions.map(\.id), [])
    }

    func testRuntimePublishesSortedSessionPreviewsAfterStartAndHookMutation() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let recorder = SessionPreviewRecorder()
        let runtime = AppRuntime(
            socketPath: socketPath,
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(
                    sessionId: "z-session",
                    source: "codex",
                    cwd: "/tmp/z",
                    updatedAt: Date()
                ),
                SessionState(sessionId: "a-session", source: "claude", cwd: "/tmp/a", updatedAt: Date(), firstUserMessage: "Synthetic session"),
            ]),
            sessionPreviewsDidChange: recorder.record
        )
        try runtime.startBridge()
        defer { runtime.stop() }

        XCTAssertTrue(waitUntil { !recorder.snapshot().isEmpty })
        XCTAssertEqual(recorder.snapshot().first?.map(\.sessionId), ["a-session", "z-session"])

        _ = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("UserPromptSubmit"),
                "sessionId": .string("m-session"),
                "cwd": .string("/tmp/m"),
                "prompt": .string("Start the live session"),
            ]
        ))

        XCTAssertTrue(waitUntil {
            recorder.snapshot().last?.map(\.sessionId) == ["a-session", "m-session", "z-session"]
        })
        XCTAssertEqual(recorder.snapshot().last?.map(\.sessionId), ["a-session", "m-session", "z-session"])
    }

    func testRuntimePublishesAtomicIslandSnapshotAcrossRequestAndResolution() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let recorder = IslandRuntimeSnapshotRecorder()
        let runtime = AppRuntime(
            socketPath: socketPath,
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(
                    sessionId: "z-session",
                    source: "codex",
                    cwd: "/tmp/z",
                    originalStatus: .runningTool,
                    updatedAt: Date()
                ),
                SessionState(sessionId: "a-session", source: "claude", cwd: "/tmp/a", updatedAt: Date(), firstUserMessage: "Synthetic session"),
            ]),
            islandRuntimeDidChange: recorder.record
        )
        try runtime.startBridge()
        defer { runtime.stop() }

        XCTAssertTrue(waitUntil { !recorder.snapshot().isEmpty })
        XCTAssertEqual(recorder.snapshot().first?.sessionPreviews.map(\.sessionId), ["z-session", "a-session"])
        XCTAssertEqual(recorder.snapshot().first?.actionRequestPreviews, [])

        _ = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "generic-agent",
            requestId: "question-1",
            command: .hookEvent,
            payload: [
                "rawEventName": .string("QuestionRequest"),
                "sessionId": .string("m-session"),
                "cwd": .string("/tmp/m"),
                "toolName": .string("Question"),
                "message": .string("Choose a path"),
                "options": .array([.string("Minimal")]),
            ]
        ))

        XCTAssertTrue(waitUntil {
            recorder.snapshot().last?.actionRequestPreviews.map(\.requestId) == ["question-1"]
        })
        XCTAssertEqual(
            recorder.snapshot().last?.sessionPreviews.map(\.sessionId),
            ["m-session", "z-session", "a-session"]
        )
        XCTAssertEqual(
            recorder.snapshot().last?.actionRequestPreviews.map(\.requestId),
            ["question-1"]
        )
        XCTAssertTrue(runtime.resolveAction(ActionResolution(
            requestId: "question-1",
            sessionId: "m-session",
            kind: .answer,
            selection: "Minimal"
        )))
        XCTAssertTrue(waitUntil { recorder.snapshot().last?.actionRequestPreviews.isEmpty == true })
        XCTAssertEqual(recorder.snapshot().last?.actionRequestPreviews, [])
    }

    func testIslandRuntimeSnapshotPublishesFullSessionsWithoutFlatteningStructuredFields() throws {
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(
                    sessionId: "z-session",
                    source: "codex",
                    cwd: "/tmp/z",
                    originalStatus: .runningTool,
                    toolInput: [
                        "command": .string("swift test"),
                        "timeout": .integer(120),
                    ],
                    firstUserMessage: "Run the focused tests"
                ),
                SessionState(sessionId: "a-session", source: "claude", cwd: "/tmp/a", updatedAt: Date(), firstUserMessage: "Synthetic session"),
            ])
        )

        let snapshot = runtime.islandRuntimeSnapshot()

        XCTAssertEqual(snapshot.sessions.map(\.id), ["z-session", "a-session"])
        XCTAssertEqual(snapshot.sessionPreviews.map(\.sessionId), ["z-session", "a-session"])
        let session = try XCTUnwrap(snapshot.sessions.first)
        XCTAssertEqual(session.originalStatus, .runningTool)
        XCTAssertEqual(session.toolInput, [
            "command": .string("swift test"),
            "timeout": .integer(120),
        ])
        XCTAssertEqual(session.firstUserMessage, "Run the focused tests")
    }

    func testIslandRuntimeSnapshotExcludesRestoredHistoryAndEphemeralRequests() {
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(agentSession: AgentSession(
                    id: "restored-history",
                    source: "codex",
                    cwd: "/tmp/history",
                    originalStatus: .ended
                )),
                SessionState(
                    sessionId: "live-session",
                    source: "codex",
                    cwd: "/tmp/live",
                    originalStatus: .processing
                ),
                SessionState(agentSession: AgentSession(
                    id: "restored-actionable",
                    source: "codex",
                    cwd: "/tmp/actionable",
                    pendingRequestIds: ["request-1"]
                )),
            ])
        )

        let snapshot = runtime.islandRuntimeSnapshot()

        XCTAssertEqual(snapshot.sessions.map(\.id), ["live-session"])
        XCTAssertEqual(snapshot.sessionPreviews.map(\.sessionId), ["live-session"])
        XCTAssertTrue(snapshot.actionRequestPreviews.isEmpty)
    }

    func testRestoredCodexPermissionDoesNotReappearAfterProcessRestart() {
        let request = ActionableRequest(
            requestId: "codex-terminal:restored-session:turn-1",
            sessionId: "restored-session",
            source: "codex",
            kind: .permission,
            toolName: "Bash",
            details: ActionRequestDetails(command: "/usr/bin/whoami")
        )
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "restored-session",
                source: "codex",
                cwd: "/tmp/restored",
                originalStatus: .waitingForApproval,
                pendingRequestIds: [request.requestId],
                actionableRequests: [request]
            ),
        ]))
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionStore: store,
            blockingActionContinuations: PendingActionContinuations(timeout: 10)
        )

        let snapshot = runtime.islandRuntimeSnapshot()

        XCTAssertTrue(snapshot.actionRequestPreviews.isEmpty)
        XCTAssertEqual(snapshot.sessions.map(\.id), [])
    }

    func testLiveCodexPermissionUsesLocalResolutionByDefault() {
        let request = ActionableRequest(
            requestId: "live-request",
            sessionId: "live-session",
            source: "codex",
            kind: .permission,
            toolName: "Bash"
        )
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(
            source: request.source,
            sessionId: request.sessionId,
            requestId: request.requestId,
            toolName: request.toolName
        ))
        let continuations = PendingActionContinuations(timeout: 10)
        continuations.register(for: request)
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator,
            blockingActionContinuations: continuations
        )

        let preview = try! XCTUnwrap(runtime.islandRuntimeSnapshot().actionRequestPreviews.first)

        XCTAssertTrue(preview.canResolveLocally)
    }

    func testLiveCodexPermissionUsesLocalResolutionForLegacyNotchTarget() {
        let defaults = UserDefaults.standard
        let key = "codexApprovalTarget"
        let priorTarget = defaults.object(forKey: key)
        defaults.set("notch", forKey: key)
        defer {
            if let priorTarget {
                defaults.set(priorTarget, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let request = ActionableRequest(
            requestId: "notch-request",
            sessionId: "notch-session",
            source: "codex",
            kind: .permission,
            toolName: "Bash"
        )
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(
            source: request.source,
            sessionId: request.sessionId,
            requestId: request.requestId,
            toolName: request.toolName
        ))
        let continuations = PendingActionContinuations(timeout: 10)
        continuations.register(for: request)
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator,
            blockingActionContinuations: continuations
        )

        let preview = try! XCTUnwrap(runtime.islandRuntimeSnapshot().actionRequestPreviews.first)

        XCTAssertTrue(preview.canResolveLocally)
    }

    func testIslandRuntimeSnapshotKeepsHistoricalConversationContentWithoutBackfillingEmptyMetadata() {
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(
                    sessionId: "spotlight",
                    source: "codex",
                    cwd: "/tmp/spotlight",
                    originalStatus: .processing,
                    updatedAt: Date(timeIntervalSince1970: 300),
                    lastUserMessage: "Current conversation"
                ),
                SessionState(
                    sessionId: "empty-running-metadata",
                    source: "codex",
                    cwd: "/tmp/empty",
                    originalStatus: .processing,
                    updatedAt: Date(timeIntervalSince1970: 200)
                ),
                SessionState(
                    sessionId: "completed-conversation",
                    source: "codex",
                    cwd: "/tmp/history",
                    originalStatus: .ended,
                    updatedAt: Date(timeIntervalSince1970: 100),
                    lastUserMessage: "Recovered conversation"
                ),
            ])
        )

        let snapshot = runtime.islandRuntimeSnapshot()

        XCTAssertEqual(
            snapshot.sessions.map(\.id),
            ["spotlight", "empty-running-metadata", "completed-conversation"]
        )
    }

    func testIslandRuntimeSnapshotDoesNotInjectEmptyFallbackSession() {
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(
                    sessionId: "empty-fallback",
                    source: "codex",
                    cwd: "/tmp/empty-fallback",
                    originalStatus: .waitingForInput,
                    isRestored: true
                )
            ])
        )

        XCTAssertEqual(runtime.islandRuntimeSnapshot().sessions.map(\.id), [])
    }

    func testIslandRuntimeSnapshotFiltersIDARecoveredInternalConsolidationSession() {
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(
                    sessionId: "internal-session",
                    source: "codex",
                    cwd: "/tmp/memory_consolidation/",
                    originalStatus: .thinking,
                    lastUserMessage: "internal"
                ),
                SessionState(
                    sessionId: "visible-session",
                    source: "codex",
                    cwd: "/tmp/visible",
                    originalStatus: .thinking,
                    lastUserMessage: "visible"
                ),
            ])
        )

        XCTAssertEqual(runtime.islandRuntimeSnapshot().sessions.map(\.id), ["visible-session"])
    }

    func testIslandRuntimeSnapshotUsesPersistedActiveSessionAsSpotlight() {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(activeSessionId: "focused"))
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(
                    sessionId: "focused",
                    source: "codex",
                    cwd: "/tmp/focused",
                    originalStatus: .processing,
                    updatedAt: Date(timeIntervalSince1970: 100),
                    lastUserMessage: "Focused session"
                ),
                SessionState(
                    sessionId: "newer",
                    source: "codex",
                    cwd: "/tmp/newer",
                    originalStatus: .processing,
                    updatedAt: Date(timeIntervalSince1970: 200),
                    lastUserMessage: "Newer session"
                ),
            ]),
            sessionStore: store
        )

        XCTAssertEqual(runtime.islandRuntimeSnapshot().sessions.map(\.id), ["newer", "focused"])
    }

    func testIslandRuntimeSnapshotPlacesPendingApprovalBeforePersistedSpotlight() {
        let request = ActionableRequest(
            requestId: "approval-request",
            sessionId: "approval",
            source: "codex",
            kind: .permission,
            toolName: "Bash",
            details: ActionRequestDetails(command: "/usr/bin/whoami")
        )
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(
                    sessionId: "focused",
                    source: "codex",
                    cwd: "/tmp/focused",
                    originalStatus: .processing,
                    updatedAt: Date(timeIntervalSince1970: 200),
                    lastUserMessage: "Focused session"
                ),
                SessionState(
                    sessionId: "approval",
                    source: "codex",
                    cwd: "/tmp/approval",
                    originalStatus: .waitingForApproval,
                    pendingRequestIds: [request.requestId],
                    actionableRequests: [request]
                ),
            ]),
            sessionStore: InMemorySessionStore(snapshot: SessionStoreSnapshot(activeSessionId: "focused"))
        )

        XCTAssertEqual(runtime.islandRuntimeSnapshot().sessions.map(\.id), ["approval", "focused"])
    }

    func testIslandRuntimeSnapshotDoesNotUseTerminalObservationForSpotlightOrdering() {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(activeSessionId: "persisted"))
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(
                    sessionId: "persisted",
                    source: "codex",
                    cwd: "/tmp/persisted",
                    originalStatus: .processing,
                    updatedAt: Date(timeIntervalSince1970: 200),
                    lastUserMessage: "Persisted session",
                    jumpInput: JumpInput(
                        sessionId: "persisted",
                        source: "codex",
                        cwd: "/tmp/persisted",
                        tty: "/dev/ttys001"
                    )
                ),
                SessionState(
                    sessionId: "frontmost",
                    source: "codex",
                    cwd: "/tmp/frontmost",
                    originalStatus: .processing,
                    updatedAt: Date(timeIntervalSince1970: 100),
                    lastUserMessage: "Frontmost terminal session",
                    jumpInput: JumpInput(
                        sessionId: "frontmost",
                        source: "codex",
                        cwd: "/tmp/frontmost",
                        tty: "ttys002"
                    )
                ),
            ]),
            sessionStore: store,
            activeCliTTYs: { _ in ["/dev/ttys002"] }
        )

        XCTAssertEqual(runtime.islandRuntimeSnapshot().sessions.map(\.id), ["persisted", "frontmost"])
    }

    func testIslandRuntimeSnapshotKeepsAllSurfacedSessionsWithSpotlightFirst() {
        let sessions = (0..<11).map { index in
            let sessionID = String(format: "attention-%02d", index)
            return SessionState(
                sessionId: sessionID,
                source: "codex",
                cwd: "/tmp/\(sessionID)",
                updatedAt: Date(timeIntervalSince1970: Double(1_000 - index)),
                pendingRequestIds: ["request-\(index)"],
                actionableRequests: [
                    ActionableRequest(
                        requestId: "request-\(index)",
                        sessionId: sessionID,
                        source: "codex",
                        kind: .permission,
                        toolName: "Bash"
                    ),
                ]
            )
        }
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: sessions)
        )

        let snapshot = runtime.islandRuntimeSnapshot()

        let expectedIDs = (0..<11).map { String(format: "attention-%02d", $0) }
        XCTAssertEqual(snapshot.sessions.map(\.id), expectedIDs)
        XCTAssertEqual(snapshot.sessionPreviews.map(\.sessionId), expectedIDs)
        XCTAssertEqual(snapshot.actionRequestPreviews.map(\.sessionId), expectedIDs)
    }

    func testIslandRuntimeSnapshotKeepsCoordinatorCodexSessionWhenProcessObservationDiffers() {
        let staleCodex = SessionState(
            sessionId: "hook-codex",
            source: "codex",
            cwd: "/tmp/hook",
            firstUserMessage: "bridge-provided first message",
            lastUserMessage: "bridge-provided current message"
        )
        let processObservation = SessionState(
            sessionId: "process-only-codex",
            source: "codex",
            cwd: "/tmp/process",
            lastUserMessage: "derived from ps"
        )
        let claude = SessionState(
            sessionId: "claude-live",
            source: "claude",
            cwd: "/tmp/claude",
            lastUserMessage: "claude"
        )
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [staleCodex.agentSession()]))
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [staleCodex, claude]),
            sessionStore: store,
            activeCodexSessions: { _ in [processObservation] }
        )

        let snapshot = runtime.islandRuntimeSnapshot()

        XCTAssertTrue(snapshot.sessions.map(\.id).contains("hook-codex"))
        XCTAssertFalse(snapshot.sessions.map(\.id).contains("process-only-codex"))
        XCTAssertEqual(
            snapshot.sessions.first(where: { $0.id == "hook-codex" })?.firstUserMessage,
            "bridge-provided first message"
        )
    }

    func testIslandRuntimeSnapshotKeepsHookReportedCodexApprovalMissingFromProcessMap() {
        let request = ActionableRequest(
            requestId: "codex-terminal:approval-session:turn-1",
            sessionId: "approval-session",
            source: "codex",
            kind: .permission,
            toolName: "Bash",
            details: ActionRequestDetails(
                command: "/usr/bin/whoami",
                reason: "May I run the harmless command?"
            )
        )
        let approval = SessionState(
            sessionId: "approval-session",
            source: "codex",
            cwd: "/tmp/approval",
            originalStatus: .waitingForApproval,
            firstUserMessage: "Request approval before running whoami.",
            pendingRequestIds: [request.requestId],
            actionableRequests: [request]
        )
        let stale = SessionState(
            sessionId: "stale-codex",
            source: "codex",
            cwd: "/tmp/stale",
            lastUserMessage: "stale"
        )
        let live = SessionState(
            sessionId: "live-codex",
            source: "codex",
            cwd: "/tmp/live",
            lastUserMessage: "live"
        )
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [stale, approval]),
            sessionStore: InMemorySessionStore(),
            activeCodexSessions: { _ in [live] }
        )

        let snapshot = runtime.islandRuntimeSnapshot()

        XCTAssertEqual(snapshot.sessions.map { $0.id }, ["approval-session", "stale-codex"])
        XCTAssertEqual(snapshot.actionRequestPreviews.map { $0.sessionId }, ["approval-session"])
        XCTAssertEqual(snapshot.actionRequestPreviews.first?.command, "/usr/bin/whoami")
    }

    func testIslandRuntimeSnapshotPreservesHookApprovalWhenProcessMapContainsSameCodexSession() {
        let request = ActionableRequest(
            requestId: "codex-terminal:live-approval:turn-1",
            sessionId: "live-approval",
            source: "codex",
            kind: .permission,
            toolName: "Bash",
            details: ActionRequestDetails(
                command: "/usr/bin/whoami",
                reason: "May I run the harmless command?"
            )
        )
        let hookApproval = SessionState(
            sessionId: "live-approval",
            source: "codex",
            cwd: "/tmp/approval",
            originalStatus: .waitingForApproval,
            firstUserMessage: "Request approval before running whoami.",
            pendingRequestIds: [request.requestId],
            actionableRequests: [request]
        )
        let processSession = SessionState(
            sessionId: "live-approval",
            source: "codex",
            cwd: "/tmp/approval",
            activeTool: "exec",
            activitySummary: "Codex is working.",
            lastAssistantMessage: "I will request approval.",
            lastUserMessage: "Request approval before running whoami."
        )
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [hookApproval]),
            sessionStore: InMemorySessionStore(),
            activeCodexSessions: { _ in [processSession] }
        )

        let snapshot = runtime.islandRuntimeSnapshot()

        XCTAssertEqual(snapshot.sessions.map(\.id), ["live-approval"])
        XCTAssertEqual(snapshot.sessions.first?.originalStatus, .waitingForApproval)
        XCTAssertEqual(snapshot.sessions.first?.pendingRequestIds, [request.requestId])
        XCTAssertEqual(snapshot.actionRequestPreviews.map(\.requestId), [request.requestId])
        XCTAssertEqual(snapshot.actionRequestPreviews.first?.command, "/usr/bin/whoami")
    }

    func testJumpUsesLiveCodexTerminalTargetInsteadOfStaleCoordinatorTarget() {
        let sessionId = "codex-019fa691-5d17-7052-9c37-91477bdf6307"
        let stale = SessionState(
            sessionId: sessionId,
            source: "codex",
            cwd: "/repo/terminal",
            jumpInput: JumpInput(
                sessionId: sessionId,
                source: "codex",
                bundleId: "com.apple.Terminal",
                cwd: "/repo/terminal",
                pid: 99_999,
                codexThreadId: "019fa691-5d17-7052-9c37-91477bdf6307"
            )
        )
        let live = SessionState(
            sessionId: sessionId,
            source: "codex",
            cwd: "/repo/terminal",
            jumpInput: JumpInput(
                sessionId: sessionId,
                source: "codex",
                bundleId: "com.apple.Terminal",
                cwd: "/repo/terminal",
                pid: 84_887,
                tty: "ttys175",
                codexThreadId: "019fa691-5d17-7052-9c37-91477bdf6307"
            ),
            resolvedJumpTarget: TerminalResolver().resolve(JumpInput(
                sessionId: sessionId,
                source: "codex",
                bundleId: "com.apple.Terminal",
                cwd: "/repo/terminal",
                pid: 84_887,
                tty: "ttys175",
                codexThreadId: "019fa691-5d17-7052-9c37-91477bdf6307"
            ), provenance: .processObservation)
        )
        let runner = RecordingJumpRunner(result: .succeeded("selected terminal tab"))
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [stale]),
            sessionStore: InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [stale.agentSession()])),
            jumpRunner: runner,
            activeCodexSessions: { _ in [live] }
        )

        let result = runtime.executeJumpToSession(sessionId: sessionId, mode: .execute)

        XCTAssertEqual(result.status, .executed)
        XCTAssertEqual(result.handlerId, "terminal-tty")
        XCTAssertTrue(result.actionDescription?.arguments.contains("if tty of candidateTab is \"ttys175\" then") == true)
    }

    func testIslandRuntimeSnapshotKeepsContentfulDeferredCodexSessionsInRenderList() {
        let activeCodex = SessionState(
            sessionId: "active-codex",
            source: "codex",
            cwd: "/tmp/active",
            originalStatus: .processing,
            updatedAt: Date()
        )
        let completedCodex = SessionState(
            sessionId: "completed-codex",
            source: "codex",
            cwd: "/tmp/completed",
            originalStatus: .ended,
            lastAssistantMessage: "old result",
            updatedAt: Date(timeIntervalSinceReferenceDate: 1),
            firstUserMessage: "show old session too"
        )
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [activeCodex, completedCodex]),
            sessionStore: InMemorySessionStore()
        )

        let snapshot = runtime.islandRuntimeSnapshot()

        XCTAssertEqual(snapshot.sessions.map { $0.id }, ["active-codex", "completed-codex"])
        XCTAssertEqual(snapshot.sessionPreviews.map { $0.sessionId }, ["active-codex", "completed-codex"])
    }

    func testLiveCodexJumpUsesClickTimeEnrichedBrowserURL() {
        let sessionId = "codex-kanban"
        let live = SessionState(
            sessionId: sessionId,
            source: "codex",
            cwd: "/repo/kanban",
            jumpInput: JumpInput(
                sessionId: sessionId,
                source: "codex",
                tmuxPane: "%147",
                tmuxSocketPath: "/private/tmp/tmux-502/kanban-agency"
            )
        )
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(),
            sessionStore: InMemorySessionStore(),
            activeCodexSessions: { _ in [live] },
            jumpInputEnricher: { input in
                KanbanBrowserJumpTargetEnricher(tmuxSessionName: { _, _ in
                    "kanban-codex-t_4c1056f8"
                }).enrich(input)
            }
        )

        let plan = runtime.jumpToSession(sessionId: sessionId)

        XCTAssertEqual(plan.handlerId, "custom-url")
        XCTAssertEqual(plan.resolvedTarget?.input.customJumpURL, "http://127.0.0.1:8766/s/t_4c1056f8")
    }

    func testStoredCoordinatorJumpUsesClickTimeEnrichedBrowserURL() {
        let sessionId = "codex-kanban-stored"
        let stored = SessionState(
            sessionId: sessionId,
            source: "codex",
            cwd: "/repo/kanban",
            jumpInput: JumpInput(
                sessionId: sessionId,
                source: "codex",
                tmuxPane: "%177",
                tmuxSocketPath: "/private/tmp/tmux-502/kanban-agency"
            )
        )
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [stored]),
            sessionStore: nil,
            activeCodexSessions: { _ in nil },
            jumpInputEnricher: { input in
                KanbanBrowserJumpTargetEnricher(tmuxSessionName: { _, _ in
                    "kanban-codex-t_4c1056f8"
                }).enrich(input)
            }
        )

        let plan = runtime.jumpToSession(sessionId: sessionId)

        XCTAssertEqual(plan.handlerId, "custom-url")
        XCTAssertEqual(plan.resolvedTarget?.input.customJumpURL, "http://127.0.0.1:8766/s/t_4c1056f8")
    }

    func testIslandRuntimeSnapshotDoesNotRenderProcessOnlyCodexSessions() {
        let firstProcess = SessionState(
            sessionId: "process-ttys175",
            source: "codex",
            cwd: "",
            activitySummary: "Codex process is running.",
            safeTitle: "Codex process ttys175",
            originalStatus: .processing,
            currentCommandPreview: "/opt/homebrew/bin/codex",
            updatedAt: Date(timeIntervalSince1970: 2_000),
            jumpInput: JumpInput(sessionId: "process-ttys175", source: "codex", tty: "ttys175")
        )
        let secondProcess = SessionState(
            sessionId: "process-ttys176",
            source: "codex",
            cwd: "",
            activitySummary: "Codex process is running.",
            safeTitle: "Codex process ttys176",
            originalStatus: .processing,
            currentCommandPreview: "/opt/homebrew/bin/codex",
            updatedAt: Date(timeIntervalSince1970: 1_900),
            jumpInput: JumpInput(sessionId: "process-ttys176", source: "codex", tty: "ttys176")
        )
        let store = InMemorySessionStore()
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(),
            sessionStore: store,
            activeCodexSessions: { _ in [firstProcess, secondProcess] }
        )

        let snapshot = runtime.islandRuntimeSnapshot()

        XCTAssertEqual(snapshot.sessions.map { $0.id }, [])
        XCTAssertEqual(snapshot.sessionPreviews.map { $0.sessionId }, [])
    }

    func testProductionRuntimeDoesNotUseLegacyTerminalSessionMapAsRenderInput() throws {
        let home = temporaryHomeDirectory()
        let directory = home.appendingPathComponent("Library/Application Support/vibe-island")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("""
        {
          "codex-terminal": {
            "source": "codex",
            "status": "running_tool",
            "currentTool": "Bash",
            "cwd": "/repo/live",
            "lastUserMessage": "show sessions",
            "lastAssistantMessage": "loading sessions",
            "lastActivityAt": 806402514.0,
            "tty": "/dev/ttys016"
          }
        }
        """.utf8).write(to: directory.appendingPathComponent("session-terminals.json"))
        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        let snapshot = runtime.islandRuntimeSnapshot()

        XCTAssertEqual(snapshot.sessions.map(\.id), [])
    }

    func testProductionRuntimeDoesNotUseBridgeTerminalSessionMapAsRenderInput() throws {
        let home = temporaryHomeDirectory()
        let directory = home.appendingPathComponent("Library/Application Support/MyVibeIsland")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("""
        {
          "codex-live": {
            "source": "codex",
            "status": "working",
            "cwd": "/tmp/live",
            "lastUserMessage": "live hook session",
            "lastAssistantMessage": "currently working",
            "lastActivityAt": 806402514.0
          }
        }
        """.utf8).write(to: directory.appendingPathComponent("session-terminals.json"))

        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        let snapshot = runtime.islandRuntimeSnapshot()

        XCTAssertEqual(snapshot.sessions.map(\.id), [])
    }

    func testProductionRuntimeRestoresStoreSessionInsteadOfReplacingItWithTerminalMap() throws {
        let home = temporaryHomeDirectory()
        let directory = home.appendingPathComponent("Library/Application Support/MyVibeIsland")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("""
        {
          "codex-hook": {
            "source": "codex",
            "status": "working",
            "cwd": "/tmp/hook",
            "lastUserMessage": "from hook",
            "lastActivityAt": 806402514.0
          }
        }
        """.utf8).write(to: directory.appendingPathComponent("session-terminals.json"))

        let store = AppRuntimeSessionStore.defaultStore(homeDirectory: home)
        store.upsert(AgentSession(
            id: "codex-live-store",
            source: "codex",
            cwd: "/tmp/live-store",
            originalStatus: .processing,
            updatedAt: Date(timeIntervalSinceReferenceDate: 806402515.0),
            lastUserMessage: "live process-backed session"
        ))

        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        XCTAssertEqual(runtime.islandRuntimeSnapshot().sessions.map(\.id), [])
    }

    func testIslandRuntimeSnapshotDecodesLegacyPayloadWithEmptySessions() throws {
        let data = Data(#"{"sessionPreviews":[],"actionRequestPreviews":[]}"#.utf8)

        let snapshot = try JSONDecoder().decode(IslandRuntimeSnapshot.self, from: data)

        XCTAssertEqual(snapshot.sessions, [])
        XCTAssertEqual(snapshot.sessionPreviews, [])
        XCTAssertEqual(snapshot.actionRequestPreviews, [])
    }

    func testRuntimeJumpToSessionReturnsPlannedJumpAction() throws {
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1"),
                resolvedJumpTarget: TerminalResolver().resolve(JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1"))
            )
        ])
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator
        )

        let plan = runtime.jumpToSession(sessionId: "s1")

        XCTAssertEqual(plan.status, .planned)
        XCTAssertEqual(plan.handlerId, "tmux")
        XCTAssertEqual(plan.precision, .exactPane)
    }

    func testRuntimeJumpToSessionReturnsMissingSessionPlan() {
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())

        let plan = runtime.jumpToSession(sessionId: "missing")

        XCTAssertEqual(plan.status, .unavailable)
        XCTAssertEqual(plan.failureReason, .missingSession)
    }

    func testRuntimeExecuteJumpToSessionReturnsDryRunDecision() throws {
        let jumpInput = JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1")
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: jumpInput,
                resolvedJumpTarget: TerminalResolver().resolve(jumpInput)
            )
        ])
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator
        )

        let result = runtime.executeJumpToSession(sessionId: "s1")

        XCTAssertEqual(result.status, .dryRun)
        XCTAssertEqual(result.handlerId, "tmux")
        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.permissionRequirements, [.cli, .automation])
        XCTAssertEqual(result.diagnosticSummary, "dry run: tmux exactPane")
    }

    func testRuntimeExecuteJumpToSessionBlocksExecuteModeUntilHandlersExist() throws {
        let jumpInput = JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1")
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: jumpInput,
                resolvedJumpTarget: TerminalResolver().resolve(jumpInput)
            )
        ])
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator
        )

        let result = runtime.executeJumpToSession(sessionId: "s1", mode: .execute)

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.blockReason, .executionNotImplemented)
        XCTAssertEqual(result.diagnosticSummary, "execution not implemented: tmux")
    }

    func testRuntimeExecuteJumpToSessionUsesInjectedRunner() throws {
        let jumpInput = JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: jumpInput,
                resolvedJumpTarget: TerminalResolver().resolve(jumpInput)
            )
        ])
        let runner = RecordingJumpRunner(result: .succeeded("opened workspace"))
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: coordinator,
            jumpRunner: runner
        )

        let result = runtime.executeJumpToSession(sessionId: "s1", mode: .execute)

        XCTAssertEqual(result.status, .executed)
        XCTAssertEqual(result.handlerId, "workspace")
        XCTAssertEqual(result.precision, .workspace)
        XCTAssertEqual(result.actionDescription?.kind, .openWorkspace)
        XCTAssertEqual(result.actionDescription?.target, "/tmp/project")
        XCTAssertEqual(result.diagnosticSummary, "opened workspace")
        XCTAssertEqual(runner.actions.map(\.kind), [.openWorkspace])
    }

    func testProductionRuntimeUsesWorkspaceRunnerForExecuteMode() throws {
        let runtime = AppRuntime.productionRuntime()

        let result = runtime.executeJumpToSession(sessionId: "missing", mode: .execute)

        XCTAssertEqual(result.status, .unavailable)
        XCTAssertEqual(result.blockReason, .unavailablePlan)
    }

    func testProductionRuntimeUsesCLIActionRunnerForTmuxExecuteMode() {
        let home = temporaryHomeDirectory()
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "tmux",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: JumpInput(sessionId: "tmux", source: "codex", tmuxPane: "%999")
            )
        ]))
        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        let result = runtime.executeJumpToSession(sessionId: "tmux", mode: .execute)

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.handlerId, "tmux")
        XCTAssertEqual(result.blockReason, .runnerFailed)
        XCTAssertTrue([
            "missing CLI command: tmux",
            "failed to run CLI handler tmux"
        ].contains(result.diagnosticSummary))
        XCTAssertEqual(result.actionDescription?.arguments, ["select-pane", "-t", "%999"])
    }

    func testProductionRuntimeUsesSocketActionRunnerForSupacodeExecuteMode() {
        let home = temporaryHomeDirectory()
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "supacode",
                source: "supacode",
                cwd: "/tmp/project",
                jumpInput: JumpInput(
                    sessionId: "supacode",
                    source: "supacode",
                    supacodeSurfaceId: "surface-3",
                    supacodeSocketPath: "/tmp/supacode.sock"
                )
            )
        ]))
        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        let result = runtime.executeJumpToSession(sessionId: "supacode", mode: .execute)

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.handlerId, "supacode")
        XCTAssertEqual(result.blockReason, .runnerFailed)
        XCTAssertEqual(result.diagnosticSummary, "failed to send socket request for supacode")
        XCTAssertEqual(result.actionDescription?.kind, .sendSocketRequest)
        XCTAssertEqual(result.actionDescription?.arguments, [
            "--socket",
            "/tmp/supacode.sock",
            "surface.focus",
            "surface-3"
        ])
    }

    func testProductionRuntimeUsesURLActionRunnerForCustomURLExecuteMode() {
        let home = temporaryHomeDirectory()
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "url",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: JumpInput(
                    sessionId: "url",
                    source: "codex",
                    customJumpURL: "my-vibe-island://session/url"
                )
            )
        ]))
        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        let result = runtime.executeJumpToSession(sessionId: "url", mode: .execute)

        XCTAssertEqual(result.handlerId, "custom-url")
        XCTAssertEqual(result.actionDescription?.kind, .openURL)
        XCTAssertEqual(result.actionDescription?.target, "my-vibe-island://session/url")
        XCTAssertNotEqual(result.diagnosticSummary, "terminal action runner unsupported action: openURL")
    }

    func testProductionRuntimeUsesURLSchemeAvailabilityForCodexDeepLinkExecuteMode() {
        let home = temporaryHomeDirectory()
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "codex-url",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: JumpInput(
                    sessionId: "codex-url",
                    source: "codex",
                    codexThreadId: "thread-1"
                )
            )
        ]))
        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        let result = runtime.executeJumpToSession(sessionId: "codex-thread-1", mode: .execute)

        XCTAssertEqual(result.handlerId, "codex-deeplink")
        XCTAssertEqual(result.actionDescription?.kind, .openURL)
        XCTAssertEqual(result.actionDescription?.target, "codex://threads/thread-1")
        XCTAssertNotEqual(result.diagnosticSummary, "terminal action runner unsupported action: openURL")
    }

    func testProductionRuntimeUsesApplicationActionRunnerForApplicationExecuteMode() {
        let home = temporaryHomeDirectory()
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "application",
                source: "claude",
                cwd: "/tmp/project",
                jumpInput: JumpInput(
                    sessionId: "application",
                    source: "claude",
                    bundleId: "com.my-vibe-island.missing-application"
                )
            )
        ]))
        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        let result = runtime.executeJumpToSession(sessionId: "application", mode: .execute)

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.handlerId, "application")
        XCTAssertEqual(result.blockReason, .runnerFailed)
        XCTAssertEqual(result.actionDescription?.kind, .activateApplication)
        XCTAssertEqual(result.actionDescription?.target, "com.my-vibe-island.missing-application")
        XCTAssertEqual(result.diagnosticSummary, "failed to activate application: com.my-vibe-island.missing-application")
    }

    func testProductionRuntimeDescribesAutomationPayloadForItermDryRun() {
        let home = temporaryHomeDirectory()
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "iterm",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: JumpInput(
                    sessionId: "iterm",
                    source: "codex",
                    bundleId: "com.googlecode.iterm2",
                    itermSessionId: "missing-session"
                )
            )
        ]))
        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        let result = runtime.executeJumpToSession(sessionId: "iterm")

        XCTAssertEqual(result.status, .dryRun)
        XCTAssertEqual(result.handlerId, "iterm")
        XCTAssertNil(result.blockReason)
        XCTAssertEqual(result.actionDescription?.kind, .runAutomation)
        XCTAssertEqual(result.actionDescription?.target, "com.googlecode.iterm2")
        XCTAssertNotEqual(result.actionDescription?.arguments, [])
    }

    func testProductionRuntimeUsesIDEWorkspaceOpenerForIDEWorkspaceExecuteMode() {
        let home = temporaryHomeDirectory()
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "ide",
                source: "codex",
                cwd: "/tmp/my-vibe-island-missing-ide-workspace",
                jumpInput: JumpInput(
                    sessionId: "ide",
                    source: "codex",
                    cwd: "/tmp/my-vibe-island-missing-ide-workspace",
                    isIDEHost: true
                )
            )
        ]))
        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        let result = runtime.executeJumpToSession(sessionId: "ide", mode: .execute)

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.handlerId, "ide-workspace")
        XCTAssertEqual(result.blockReason, .runnerFailed)
        XCTAssertEqual(result.diagnosticSummary, "IDE workspace missing: /tmp/my-vibe-island-missing-ide-workspace")
    }

    func testProductionRuntimeRestoresSessionsFromDefaultStore() {
        let home = temporaryHomeDirectory()
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(id: "stored", source: "codex", cwd: "/tmp/stored"),
        ]))

        let runtime = AppRuntime.productionRuntime(homeDirectory: home)

        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "stored")?.cwd, "/tmp/stored")
    }

    func testRuntimeResolveActionSignalsBlockingHookContinuation() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(
            socketPath: socketPath,
            blockingActionContinuations: PendingActionContinuations(timeout: 1.0)
        )
        try runtime.startBridge()
        defer {
            runtime.stop()
        }

        let hookCompleted = expectation(description: "blocking hook completed")
        let hookResponse = ResponseBox()
        DispatchQueue.global().async {
            do {
                let response = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
                    schemaVersion: 1,
                    clientRole: "hook",
                    source: "codex",
                    requestId: "r1",
                    command: .hookEvent,
                    payload: [
                        "rawEventName": .string("PermissionRequest"),
                        "sessionId": .string("s1"),
                        "cwd": .string("/tmp/project"),
                        "toolName": .string("Shell"),
                    ]
                ))
                hookResponse.record(.success(response))
            } catch {
                hookResponse.record(.failure(error))
            }
            hookCompleted.fulfill()
        }

        let pendingAppeared = expectation(description: "pending action appeared")
        DispatchQueue.global().async {
            let deadline = Date().addingTimeInterval(1.0)
            while Date() < deadline {
                if runtime.actionableRequest(requestId: "r1") != nil {
                    pendingAppeared.fulfill()
                    return
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        wait(for: [pendingAppeared], timeout: 1.1)

        XCTAssertTrue(runtime.resolveAction(ActionResolution(requestId: "r1", sessionId: "s1", kind: .approve)))
        wait(for: [hookCompleted], timeout: 1.1)
        XCTAssertEqual(try hookResponse.get().sourceDirective, .object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                ]),
            ]),
        ]))
    }

    func testRuntimeStopIsIdempotent() throws {
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        try runtime.startBridge()

        runtime.stop()
        runtime.stop()

        XCTAssertEqual(runtime.status().isBridgeRunning, false)
    }

    func testRepeatedRuntimeStartThrowsAndFirstBridgeStillResponds() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(socketPath: socketPath)
        try runtime.startBridge()
        defer {
            runtime.stop()
        }

        XCTAssertThrowsError(try runtime.startBridge()) { error in
            XCTAssertEqual(error as? BridgeSocketError, .alreadyRunning)
        }
        XCTAssertEqual(try helloResponse(socketPath: socketPath), .ok(message: "bridge reachable"))
    }

    func testFailedRuntimeStartLeavesBridgeStopped() {
        let overlongPath = "/tmp/" + String(repeating: "a", count: 200) + ".sock"
        let runtime = AppRuntime(socketPath: overlongPath)

        XCTAssertThrowsError(try runtime.startBridge()) { error in
            XCTAssertEqual(error as? BridgeSocketError, .pathTooLong(overlongPath))
        }
        XCTAssertEqual(runtime.status().isBridgeRunning, false)
    }

    func testRuntimeDeinitAfterStartStopsSocket() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        var runtime: AppRuntime? = AppRuntime(socketPath: socketPath)
        try runtime?.startBridge()

        runtime = nil

        XCTAssertThrowsError(try helloResponse(socketPath: socketPath)) { error in
            guard case .connectFailed = error as? BridgeSocketError else {
                return XCTFail("Expected connect failure after runtime deinit, got \(error)")
            }
        }
    }

    func testConcurrentRuntimeStartAllowsExactlyOneBridge() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntime(socketPath: socketPath)
        defer {
            runtime.stop()
        }
        let attempts = 12
        let group = DispatchGroup()
        let startGate = DispatchSemaphore(value: 0)
        let results = ConcurrentStartResults()

        for _ in 0..<attempts {
            group.enter()
            DispatchQueue.global().async {
                startGate.wait()
                do {
                    try runtime.startBridge()
                    results.recordSuccess()
                } catch let error as BridgeSocketError {
                    results.recordFailure(error)
                } catch {
                    XCTFail("Unexpected start error: \(error)")
                }
                group.leave()
            }
        }

        for _ in 0..<attempts {
            startGate.signal()
        }
        XCTAssertEqual(group.wait(timeout: .now() + 2.0), .success)

        let observedResults = results.snapshot()

        XCTAssertEqual(observedResults.successes, 1)
        XCTAssertEqual(observedResults.failures.count, attempts - 1)
        XCTAssertTrue(observedResults.failures.allSatisfy { error in
            switch error {
            case .alreadyRunning, .bindFailed, .listenFailed:
                return true
            default:
                return false
            }
        })
        XCTAssertEqual(runtime.status().isBridgeRunning, true)
        XCTAssertEqual(try helloResponse(socketPath: socketPath), .ok(message: "bridge reachable"))
    }

    func testConcurrentRuntimeStartAndStopLeavesRuntimeStoppedOrReachable() {
        for _ in 0..<20 {
            let socketPath = BridgeSocketPath.temporaryForTests()
            let runtime = AppRuntime(socketPath: socketPath)
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global().async {
                _ = try? runtime.startBridge()
                group.leave()
            }

            group.enter()
            DispatchQueue.global().async {
                runtime.stop()
                group.leave()
            }

            XCTAssertEqual(group.wait(timeout: .now() + 2.0), .success)

            if runtime.status().isBridgeRunning {
                XCTAssertEqual(try? helloResponse(socketPath: socketPath), .ok(message: "bridge reachable"))
            } else {
                XCTAssertThrowsError(try helloResponse(socketPath: socketPath))
            }

            runtime.stop()
        }
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        _ predicate: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.005)
        }
        return predicate()
    }

    private func row(
        id: String,
        runtime: AppRuntime,
        sessionId: String,
        mode: TerminalJumpExecutionMode
    ) -> AppRuntimeJumpReadModelMatrixRow {
        let status = runtime.status()
        let plan = runtime.jumpToSession(sessionId: sessionId)
        let result = runtime.executeJumpToSession(sessionId: sessionId, mode: mode)
        return AppRuntimeJumpReadModelMatrixRow(
            id: id,
            isBridgeRunning: status.isBridgeRunning,
            sessionCount: status.sessionCount,
            planStatus: plan.status.rawValue,
            planHandlerId: plan.handlerId,
            planFailureReason: plan.failureReason?.rawValue,
            executionStatus: result.status.rawValue,
            executionHandlerId: result.handlerId,
            executionBlockReason: result.blockReason?.rawValue,
            actionKind: result.actionDescription?.kind.rawValue,
            diagnosticSummary: result.diagnosticSummary
        )
    }

    private struct AppRuntimeJumpReadModelMatrixFixture: Codable, Equatable {
        let rows: [AppRuntimeJumpReadModelMatrixRow]
    }

    private struct AppRuntimeJumpReadModelMatrixRow: Codable, Equatable {
        let id: String
        let isBridgeRunning: Bool
        let sessionCount: Int
        let planStatus: String
        let planHandlerId: String?
        let planFailureReason: String?
        let executionStatus: String
        let executionHandlerId: String?
        let executionBlockReason: String?
        let actionKind: String?
        let diagnosticSummary: String
    }
}

private final class AppRuntimeManualSessionEndCleanupScheduler: SessionEndCleanupScheduling, @unchecked Sendable {
    private var workItems: [@Sendable () -> Void] = []

    func schedule(_ work: @escaping @Sendable () -> Void) {
        workItems.append(work)
    }

    func runNext() {
        workItems.removeFirst()()
    }
}
