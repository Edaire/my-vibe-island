import XCTest
@testable import MyVibeIslandCore
import MyVibeIslandShared

final class BridgeRequestHandlerTests: XCTestCase {
    func testBridgeRequestHandlerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            BridgeRequestHandlerMatrixFixture.self,
            from: try FixtureLoader.data("runtime/bridge-request-handler-matrix")
        )

        let actual = BridgeRequestHandlerMatrixFixture(rows: [
            handlerRow(id: "hello", envelope: envelope(command: .hello)),
            handlerRow(
                id: "hook-session-start",
                envelope: envelope(command: .hookEvent, payload: [
                    "rawEventName": .string("SessionStart"),
                    "sessionId": .string("s1"),
                    "cwd": .string("/tmp/project"),
                ])
            ),
            handlerRow(
                id: "permission-request-envelope-id",
                envelope: envelope(requestId: "req-envelope", command: .hookEvent, payload: [
                    "rawEventName": .string("PermissionRequest"),
                    "sessionId": .string("s1"),
                    "cwd": .string("/tmp/project"),
                    "toolName": .string("Shell"),
                ])
            ),
            handlerRow(
                id: "permission-request-missing-stable-id",
                envelope: envelope(command: .hookEvent, payload: [
                    "rawEventName": .string("PermissionRequest"),
                    "sessionId": .string("s1"),
                    "cwd": .string("/tmp/project"),
                    "toolName": .string("Shell"),
                ])
            ),
            handlerRow(
                id: "watch-content",
                envelope: envelope(clientRole: "watcher", command: .watchEvent, payload: [
                    "eventKind": .string("content"),
                    "sessionId": .string("s1"),
                    "tasks": .array([
                        .object([
                            "id": .string("task-1"),
                            "subject": .string("Plan"),
                            "status": .string("active"),
                        ]),
                    ]),
                ])
            ),
            handlerRow(
                id: "resolve-codex-approval",
                initialEvent: .permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"),
                envelope: envelope(clientRole: "app", source: "my-vibe-island", command: .resolveAction, payload: [
                    "requestId": .string("r1"),
                    "sessionId": .string("s1"),
                    "action": .string("approve"),
                ])
            ),
            handlerRow(
                id: "resolve-question-selection",
                initialEvent: .questionAsked(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Prompt"),
                envelope: envelope(clientRole: "app", source: "my-vibe-island", command: .resolveAction, payload: [
                    "requestId": .string("r1"),
                    "sessionId": .string("s1"),
                    "action": .string("answer"),
                    "answer": .string("yes"),
                ])
            ),
            handlerRow(id: "unsupported-health-probe", envelope: envelope(command: .healthProbe)),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testHelloReturnsReachableResponse() {
        let handler = BridgeRequestHandler(sessionCoordinator: SessionCoordinator())
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hello,
            payload: [:]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "bridge reachable"))
    }

    func testHookEventSessionStartUpdatesSessionCoordinator() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("s1"),
                "cwd": .string("/tmp/project"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.source, "codex")
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.cwd, "/tmp/project")
    }

    func testRejectedCodexUserPromptSubmitRecordsAdmissionWithoutPublishingSession() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-admission-\(UUID().uuidString)", isDirectory: true)
        let rulesURL = root.appendingPathComponent("admission-rules.json", isDirectory: false)
        let ledgerURL = root.appendingPathComponent("session-admission-rejections.json", isDirectory: false)
        let rules = PersistedSessionAdmissionRulesV1(
            deniedAncestorBundles: [
                AppBundleAdmissionRule(bundleId: "com.example.denied")
            ]
        )
        try SessionAdmissionConfig.save(rules, to: rulesURL)

        let coordinator = SessionCoordinator()
        let publicationCount = ThreadSafeCounter()
        let now = Date(timeIntervalSinceReferenceDate: 123)
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            admissionRulesURL: rulesURL,
            admissionLedgerURL: ledgerURL,
            sessionsDidChange: { publicationCount.increment() },
            now: { now }
        )
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "hook_event_name": .string("UserPromptSubmit"),
                "session_id": .string("rejected-session"),
                "cwd": .string("/tmp/rejected"),
                "prompt": .string("do not publish"),
            ],
            environment: HookEnvironment(cfBundleIdentifier: "com.example.denied")
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertNil(coordinator.snapshot(sessionId: "codex-rejected-session"))
        XCTAssertEqual(publicationCount.value, 0)
        XCTAssertEqual(
            SessionAdmissionLedger.load(from: ledgerURL)["codex-rejected-session"],
            PersistedSessionAdmissionRejection(
                evidence: SessionAdmissionEvidence(
                    cwd: "/tmp/rejected",
                    bundleIdentifiers: ["com.example.denied"]
                ),
                rejectedAt: now,
                reason: "ancestor bundle denied: com.example.denied"
            )
        )
    }

    func testSuccessfulMutationPublishesOnceAndRejectedHookPublishesNothing() {
        let publicationCount = ThreadSafeCounter()
        let handler = BridgeRequestHandler(
            sessionCoordinator: SessionCoordinator(),
            sessionsDidChange: { publicationCount.increment() }
        )

        _ = handler.handle(envelope(command: .hookEvent, payload: [
            "rawEventName": .string("SessionStart"),
            "sessionId": .string("s1"),
            "cwd": .string("/tmp/project"),
        ]))
        _ = handler.handle(envelope(command: .hookEvent, payload: [:]))

        XCTAssertEqual(publicationCount.value, 1)
    }

    func testHookEventWithNormalizedContentUpdatesSessionState() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: normalizedSessionContentPayload(rawEventName: "SessionStart")
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "session-normalized")?.tasks, [normalizedTask])
        XCTAssertEqual(coordinator.snapshot(sessionId: "session-normalized")?.todos, [normalizedTodo])
    }

    func testHookEventWithNormalizedContentUpdatesSessionPresentation() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: normalizedSessionContentPayload(rawEventName: "SessionStart")
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.sessionPresentations().first?.taskSummary, "1/1 active tasks")
        XCTAssertEqual(coordinator.sessionPresentations().first?.todoSummary, "1 todos")
    }

    func testHookEventLogsMiddleLifecycleFieldsForPreToolUse() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-trace-\(UUID().uuidString)", isDirectory: true)
        let traceURL = root.appendingPathComponent("session-completion.log", isDirectory: false)
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            traceLogURL: traceURL
        )
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "hook_event_name": .string("PreToolUse"),
                "session_id": .string("codex-session"),
                "cwd": .string("/tmp/codex"),
                "tool_name": .string("Bash"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        let log = try String(contentsOf: traceURL)
        XCTAssertTrue(log.contains("stage=bridge.received"))
        XCTAssertTrue(log.contains("event=PreToolUse"))
        XCTAssertTrue(log.contains("stage=bridge.applied"))
        XCTAssertTrue(log.contains("activeTool=Bash"))
    }

    func testPermissionRequestWithoutRequestIdStillFailsWhenNormalizedContentIsPresent() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: normalizedSessionContentPayload(rawEventName: "PermissionRequest")
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "stable requestId required"))
        XCTAssertNil(coordinator.snapshot(sessionId: "session-normalized"))
    }

    func testCodexGenericCompatibilityFixtureUpdatesSessionCoordinator() throws {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: try FixtureLoader.bridgePayload("codex/hook-generic-session-start")
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "generic-codex-session")?.cwd, "/tmp/generic-codex")
    }

    func testClaudeCompatibleSessionStartUpdatesSessionCoordinator() throws {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "claude",
            requestId: nil,
            command: .hookEvent,
            payload: try FixtureLoader.bridgePayload("claude/hook-session-start")
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "claude-session")?.source, "claude")
        XCTAssertEqual(coordinator.snapshot(sessionId: "claude-session")?.cwd, "/tmp/claude")
    }

    func testClaudeCompatiblePermissionRequestUpdatesPendingRequestIds() throws {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "qwen",
            requestId: nil,
            command: .hookEvent,
            payload: try FixtureLoader.bridgePayload("claude/hook-permission-request")
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "claude-session")?.source, "qwen")
        XCTAssertEqual(coordinator.snapshot(sessionId: "claude-session")?.pendingRequestIds, ["tool-use-claude-1"])
    }

    func testCodexNativeSessionStartUpdatesSessionCoordinator() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "hook_event_name": .string("SessionStart"),
                "session_id": .string("codex-session"),
                "cwd": .string("/tmp/codex"),
                "model": .string("gpt-5"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "codex-session")?.source, "codex")
        XCTAssertEqual(coordinator.snapshot(sessionId: "codex-session")?.cwd, "/tmp/codex")
    }

    func testCodexSubagentStopDoesNotPublishAnUnreconciledChildCard() {
        let coordinator = SessionCoordinator(sessions: [
            SessionState(sessionId: "codex-parent-thread", source: "codex", cwd: "/tmp/codex"),
        ])
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)

        let response = handler.handle(envelope(command: .hookEvent, payload: [
            "hook_event_name": .string("SubagentStop"),
            "session_id": .string("child-thread"),
            "cwd": .string("/tmp/codex"),
            "subagent_parent_thread_id": .string("parent-thread"),
            "subagent_kind": .string("task"),
            "subagent_nickname": .string("Reviewer"),
            "subagent_role": .string("review"),
            "child_model": .string("gpt-5.6-terra"),
            "child_reasoning_effort": .string("medium"),
            "agent_id": .string("child-tool-use-1"),
            "agent_type": .string("reviewer"),
            "_child_parent_id": .string("parent-tool-use-1"),
            "_child_runtime_session_id": .string("child-runtime-1"),
            "_child_process_incarnation": .string("process-1"),
        ]))

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshots().map(\.sessionId), ["codex-parent-thread"])
        XCTAssertEqual(coordinator.snapshot(sessionId: "codex-parent-thread")?.subagents, [])
        XCTAssertFalse(coordinator.snapshot(sessionId: "codex-parent-thread")?.hasUnreadCompletion ?? true)
    }

    func testCodexNativeHookPersistsTerminalSessionMap() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-terminal-map-\(UUID().uuidString)", isDirectory: true)
        let terminalMapURL = root.appendingPathComponent("session-terminals.json")
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            terminalSessionMapURL: terminalMapURL
        )

        let response = handler.handle(envelope(command: .hookEvent, payload: [
            "hook_event_name": .string("UserPromptSubmit"),
            "session_id": .string("codex-live"),
            "cwd": .string("/tmp/codex-live"),
            "prompt": .string("run real hook"),
        ]))

        XCTAssertEqual(response, .ok(message: "event accepted"))
        let sessions = try CodexTerminalSessionMapReader(fileURL: terminalMapURL).readSessions()
        XCTAssertEqual(sessions.map(\.sessionId), ["codex-live"])
        XCTAssertEqual(sessions.first?.firstUserMessage, "run real hook")
        XCTAssertEqual(sessions.first?.lastUserMessage, "run real hook")
        XCTAssertEqual(sessions.first?.cwd, "/tmp/codex-live")
    }

    func testCodexPromptRecoversFirstMessageFromExistingRolloutPathWhenHookOmitsPath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-rollout-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let rollout = root.appendingPathComponent("rollout.jsonl", isDirectory: false)
        try """
        {"timestamp":"2026-07-23T07:00:00.000Z","type":"event_msg","payload":{"type":"user_message","message":"真实首条请求"}}
        {"timestamp":"2026-07-23T07:01:00.000Z","type":"event_msg","payload":{"type":"agent_message","message":"先前回复"}}
        """.write(to: rollout, atomically: true, encoding: .utf8)

        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "codex-live",
                source: "codex",
                cwd: "/tmp/codex-live",
                firstUserMessage: "错误的 hook 初始化消息",
                codexRolloutPath: rollout.path
            ),
        ])
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)

        let response = handler.handle(envelope(command: .hookEvent, payload: [
            "hook_event_name": .string("UserPromptSubmit"),
            "session_id": .string("live"),
            "cwd": .string("/tmp/codex-live"),
            "prompt": .string("当前请求"),
        ]))

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "codex-live")?.firstUserMessage, "真实首条请求")
        XCTAssertEqual(coordinator.snapshot(sessionId: "codex-live")?.lastUserMessage, "当前请求")
    }

    func testNonCodexHookDoesNotPersistTerminalSessionMap() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-terminal-map-\(UUID().uuidString)", isDirectory: true)
        let terminalMapURL = root.appendingPathComponent("session-terminals.json")
        let handler = BridgeRequestHandler(
            sessionCoordinator: SessionCoordinator(),
            terminalSessionMapURL: terminalMapURL
        )

        let response = handler.handle(envelope(source: "claude", command: .hookEvent, payload: [
            "rawEventName": .string("SessionStart"),
            "sessionId": .string("claude-live"),
            "cwd": .string("/tmp/claude-live"),
        ]))

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: terminalMapURL.path))
    }

    func testCodexNativePermissionRequestWithoutStableIdFailsWithoutMutatingSessionCoordinator() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "hook_event_name": .string("PermissionRequest"),
                "session_id": .string("codex-session"),
                "cwd": .string("/tmp/codex"),
                "tool_name": .string("Shell"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "stable requestId required"))
        XCTAssertEqual(coordinator.snapshots(), [])
    }

    func testCodexIdlessPermissionRequestUsesTurnScopedTerminalRouteIdentity() throws {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "hook_event_name": .string("PermissionRequest"),
                "session_id": .string("codex-live"),
                "cwd": .string("/tmp/codex"),
                "turn_id": .string("turn-42"),
                "tool_name": .string("Bash"),
                "tool_input": .object([
                    "command": .string("/usr/bin/whoami"),
                    "description": .string("Do you approve running /usr/bin/whoami?"),
                ]),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .nativeApprovalHandoff())
        XCTAssertEqual(coordinator.snapshot(sessionId: "codex-live")?.pendingRequestIds, ["codex-terminal:codex-live:turn-42"])
        let request = try XCTUnwrap(coordinator.actionableRequests().first)
        XCTAssertEqual(request.requestId, "codex-terminal:codex-live:turn-42")
        XCTAssertEqual(request.details?.command, "/usr/bin/whoami")
        XCTAssertEqual(request.details?.reason, "Do you approve running /usr/bin/whoami?")
    }

    func testCodexIdlessPermissionRequestImmediatelyHandsOffForTerminalTarget() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            codexApprovalTarget: { "terminal" }
        )

        let response = handler.handle(codexNativePermissionEnvelope())

        XCTAssertEqual(response, .nativeApprovalHandoff())
        XCTAssertTrue(coordinator.actionableRequests().isEmpty)
        XCTAssertNil(coordinator.snapshot(sessionId: "codex-live"))
    }

    func testCodexHideModeImmediatelyHandsOffWithoutCreatingIslandSession() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            codexApprovalTarget: { nil },
            codexApprovalMode: { "hide" }
        )

        let response = handler.handle(codexNativePermissionEnvelope())

        XCTAssertEqual(response, .nativeApprovalHandoff())
        XCTAssertTrue(coordinator.actionableRequests().isEmpty)
        XCTAssertNil(coordinator.snapshot(sessionId: "codex-live"))
    }

    func testCodexRemindModeKeepsPassiveCardWithoutBlockingBridge() {
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 10)
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            blockingActionContinuations: continuations,
            codexApprovalTarget: { nil },
            codexApprovalMode: { "remind" }
        )
        let envelope = codexNativePermissionEnvelope()

        let completed = expectation(description: "remind approval returns native handoff")
        DispatchQueue.global().async {
            XCTAssertEqual(handler.handle(envelope), .nativeApprovalHandoff())
            completed.fulfill()
        }

        wait(for: [completed], timeout: 0.2)
        XCTAssertEqual(
            coordinator.actionableRequests().map(\.requestId),
            ["codex-terminal:codex-live:turn-42"]
        )
        XCTAssertEqual(continuations.pendingCount, 0)
    }

    func testCodexIdlessPermissionRequestRetainsCardWhenOwningTerminalIsFrontmost() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            codexApprovalTarget: { "approve_here" },
            codexApprovalTerminalIsFrontmost: { _ in true }
        )

        let response = handler.handle(codexNativePermissionEnvelope())

        XCTAssertEqual(response, .nativeApprovalHandoff())
        XCTAssertEqual(
            coordinator.actionableRequests().map(\.requestId),
            ["codex-terminal:codex-live:turn-42"]
        )
        XCTAssertEqual(
            coordinator.snapshot(sessionId: "codex-live")?.pendingRequestIds,
            ["codex-terminal:codex-live:turn-42"]
        )
    }

    func testCodexDeadlineHandoffReleasesLocalOwnershipAndRemovesTerminalCard() throws {
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 10)
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            blockingActionContinuations: continuations,
            terminalRoutedCodexApprovalHandoffDelay: 0,
            codexApprovalOwnershipPollInterval: 0.001,
            codexApprovalTarget: { "approve_here" },
            codexApprovalTerminalIsFrontmost: { _ in false }
        )
        let envelope = codexNativePermissionEnvelope()
        let completed = expectation(description: "deadline returns native terminal handoff")

        DispatchQueue.global().async {
            XCTAssertEqual(handler.handle(envelope), .nativeApprovalHandoff())
            completed.fulfill()
        }

        wait(for: [completed], timeout: 0.5)

        XCTAssertTrue(coordinator.actionableRequests().isEmpty)
        XCTAssertTrue(coordinator.snapshot(sessionId: "codex-live")?.pendingRequestIds.isEmpty ?? true)
        XCTAssertEqual(continuations.pendingCount, 0)
    }

    func testDisconnectingIdlessCodexPermissionCancelsItsDerivedContinuationAndRemovesCard() {
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 10)
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            blockingActionContinuations: continuations,
            codexApprovalTarget: { "approve_here" }
        )
        let envelope = codexNativePermissionEnvelope()
        let completed = expectation(description: "id-less hook released after disconnect")

        DispatchQueue.global().async {
            _ = handler.handle(envelope)
            completed.fulfill()
        }

        let pendingDeadline = Date().addingTimeInterval(0.2)
        while Date() < pendingDeadline, continuations.pendingCount == 0 {
            Thread.sleep(forTimeInterval: 0.005)
        }
        XCTAssertEqual(continuations.pendingCount, 1)

        XCTAssertTrue(handler.clientDisconnected(envelope))
        wait(for: [completed], timeout: 0.4)
        XCTAssertTrue(coordinator.actionableRequests().isEmpty)
    }

    func testHookEventPermissionRequestWithoutRequestIdFailsWithoutPendingState() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("PermissionRequest"),
                "sessionId": .string("s1"),
                "cwd": .string("/tmp/project"),
                "toolName": .string("Shell"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "stable requestId required"))
        XCTAssertNil(coordinator.snapshot(sessionId: "s1"))
    }

    func testHookEventPermissionRequestWithEnvelopeRequestIdUpdatesPendingRequestIds() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: "req-envelope",
            command: .hookEvent,
            payload: [
                "rawEventName": .string("PermissionRequest"),
                "sessionId": .string("s1"),
                "cwd": .string("/tmp/project"),
                "toolName": .string("Shell"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.pendingRequestIds, ["req-envelope"])
    }

    func testHookEventPermissionRequestWithEnvelopeAndPayloadRequestIdsUsesEnvelopeRequestId() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: "req-envelope",
            command: .hookEvent,
            payload: [
                "rawEventName": .string("PermissionRequest"),
                "sessionId": .string("s1"),
                "requestId": .string("req-payload"),
                "cwd": .string("/tmp/project"),
                "toolName": .string("Shell"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.pendingRequestIds, ["req-envelope"])
    }

    func testHookEventPermissionRequestFallsBackToPayloadRequestIdWhenEnvelopeRequestIdIsMissing() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("PermissionRequest"),
                "sessionId": .string("s1"),
                "requestId": .string("req-payload"),
                "cwd": .string("/tmp/project"),
                "toolName": .string("Shell"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.pendingRequestIds, ["req-payload"])
    }

    func testHookEventMissingRawEventNameFailsWithoutMutatingSessionCoordinator() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "sessionId": .string("s1"),
                "cwd": .string("/tmp/project"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "invalid hook payload"))
        XCTAssertEqual(coordinator.snapshots(), [])
    }

    func testHookEventNonStringRawEventNameFailsWithoutMutatingSessionCoordinator() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .number(1),
                "sessionId": .string("s1"),
                "cwd": .string("/tmp/project"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "invalid hook payload"))
        XCTAssertEqual(coordinator.snapshots(), [])
    }

    func testHookEventEmptyRawEventNameFailsWithoutMutatingSessionCoordinator() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string(""),
                "sessionId": .string("s1"),
                "cwd": .string("/tmp/project"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "invalid hook payload"))
        XCTAssertEqual(coordinator.snapshots(), [])
    }

    func testHookEventMissingSessionIdFailsWithoutCreatingEmptyIdSession() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "cwd": .string("/tmp/project"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "invalid hook payload"))
        XCTAssertNil(coordinator.snapshot(sessionId: ""))
        XCTAssertEqual(coordinator.snapshots(), [])
    }

    func testHookEventNonStringSessionIdFails() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .bool(true),
                "cwd": .string("/tmp/project"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "invalid hook payload"))
    }

    func testHookEventEmptySessionIdFailsWithoutCreatingEmptyIdSession() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string(""),
                "cwd": .string("/tmp/project"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "invalid hook payload"))
        XCTAssertNil(coordinator.snapshot(sessionId: ""))
        XCTAssertEqual(coordinator.snapshots(), [])
    }

    func testHookEventSessionStartMissingCwdFailsWithoutMutatingSessionCoordinator() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("s1"),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "invalid hook payload"))
        XCTAssertEqual(coordinator.snapshots(), [])
    }

    func testHookEventSessionStartNonStringCwdFails() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("s1"),
                "cwd": .array([]),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "invalid hook payload"))
    }

    func testHookEventSessionStartEmptyCwdFailsWithoutMutatingSessionCoordinator() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("s1"),
                "cwd": .string(""),
            ]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "invalid hook payload"))
        XCTAssertEqual(coordinator.snapshots(), [])
    }

    func testUnsupportedCommandReturnsFailure() {
        let handler = BridgeRequestHandler(sessionCoordinator: SessionCoordinator())
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .healthProbe,
            payload: [:]
        )

        let response = handler.handle(envelope)

        XCTAssertEqual(response, .failure(message: "unsupported command"))
    }

    private var normalizedTask: TaskItem {
        TaskItem(
            id: "task-1",
            subject: "Implement normalized content",
            description: nil,
            status: .active,
            activeForm: nil,
            blockedBy: nil,
            owner: nil
        )
    }

    private var normalizedTodo: TodoItem {
        TodoItem(id: "todo-1", content: "Write RED tests", status: .pending, activeForm: nil)
    }

    private func normalizedSessionContentPayload(rawEventName: String) -> [String: BridgeJSONValue] {
        [
            "rawEventName": .string(rawEventName),
            "sessionId": .string("session-normalized"),
            "cwd": .string("/tmp/project"),
            "tasks": .array([
                .object([
                    "id": .string("task-1"),
                    "subject": .string("Implement normalized content"),
                    "status": .string("active"),
                ]),
            ]),
            "todos": .array([
                .object([
                    "id": .string("todo-1"),
                    "content": .string("Write RED tests"),
                    "status": .string("pending"),
                ]),
            ]),
        ]
    }

    private func codexNativePermissionEnvelope() -> BridgeEnvelope {
        envelope(command: .hookEvent, payload: [
            "hook_event_name": .string("PermissionRequest"),
            "session_id": .string("codex-live"),
            "cwd": .string("/tmp/codex"),
            "turn_id": .string("turn-42"),
            "tool_name": .string("Bash"),
            "tool_input": .object([
                "command": .string("/usr/bin/whoami"),
                "description": .string("Do you approve running /usr/bin/whoami?"),
            ]),
        ])
    }

    private func handlerRow(
        id: String,
        initialEvent: AgentEvent? = nil,
        envelope: BridgeEnvelope
    ) -> BridgeRequestHandlerMatrixRow {
        let coordinator = SessionCoordinator()
        if let initialEvent {
            coordinator.apply(initialEvent)
        }
        let store = InMemorySessionStore()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator, sessionStore: store)
        let response = handler.handle(envelope)
        let snapshot = coordinator.snapshot(sessionId: "s1")
        let storedSnapshot = store.loadSnapshot()

        return BridgeRequestHandlerMatrixRow(
            id: id,
            responseOK: response.ok,
            responseMessage: response.message,
            directiveBehavior: response.sourceDirective?.codexDecisionBehavior,
            coordinatorSessionIds: coordinator.snapshots().map(\.sessionId),
            pendingRequestIds: snapshot?.pendingRequestIds ?? [],
            taskIds: snapshot?.tasks.map(\.id) ?? [],
            storedSessionIds: storedSnapshot.sessions.map(\.id),
            storedPendingRequestIds: storedSnapshot.sessions.first?.pendingRequestIds ?? [],
            questionSelections: storedSnapshot.questionSelections
        )
    }

    private func envelope(
        clientRole: String = "hook",
        source: String = "codex",
        requestId: String? = nil,
        command: BridgeCommand,
        payload: [String: BridgeJSONValue] = [:]
    ) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: clientRole,
            source: source,
            requestId: requestId,
            command: command,
            payload: payload
        )
    }

    private struct BridgeRequestHandlerMatrixFixture: Codable, Equatable {
        let rows: [BridgeRequestHandlerMatrixRow]
    }

    private struct BridgeRequestHandlerMatrixRow: Codable, Equatable {
        let id: String
        let responseOK: Bool
        let responseMessage: String?
        let directiveBehavior: String?
        let coordinatorSessionIds: [String]
        let pendingRequestIds: [String]
        let taskIds: [String]
        let storedSessionIds: [String]
        let storedPendingRequestIds: [String]
        let questionSelections: [String: String]
    }
}

private final class ThreadSafeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}

private extension BridgeJSONValue {
    var codexDecisionBehavior: String? {
        guard
            case let .object(root) = self,
            case let .object(output)? = root["hookSpecificOutput"],
            case let .object(decision)? = output["decision"],
            case let .string(behavior)? = decision["behavior"]
        else {
            return nil
        }

        return behavior
    }
}
