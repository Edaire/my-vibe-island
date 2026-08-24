import Foundation
import XCTest
@testable import MyVibeIslandCore
@testable import MyVibeIslandHooks

final class HookCLITests: XCTestCase {
    private final class OutputBox: @unchecked Sendable {
        private let lock = NSLock()
        private var output: String?
        private var error: Error?

        func record(_ result: Result<String, Error>) {
            lock.lock()
            switch result {
            case let .success(output):
                self.output = output
            case let .failure(error):
                self.error = error
            }
            lock.unlock()
        }

        func get() throws -> String {
            lock.lock()
            defer {
                lock.unlock()
            }

            if let error {
                throw error
            }
            return try XCTUnwrap(output)
        }
    }

    private final class EnvelopeBox: @unchecked Sendable {
        private let lock = NSLock()
        private var envelope: BridgeEnvelope?

        func record(_ envelope: BridgeEnvelope) {
            lock.lock()
            self.envelope = envelope
            lock.unlock()
        }

        func get() throws -> BridgeEnvelope {
            lock.lock()
            defer {
                lock.unlock()
            }
            return try XCTUnwrap(envelope)
        }
    }

    private final class FireAndForgetBox: @unchecked Sendable {
        private let lock = NSLock()
        private var envelope: BridgeEnvelope?

        func record(_ envelope: BridgeEnvelope) {
            lock.lock()
            self.envelope = envelope
            lock.unlock()
        }

        func get() throws -> BridgeEnvelope {
            lock.lock()
            defer { lock.unlock() }
            return try XCTUnwrap(envelope)
        }
    }

    private let helloEnvelopeJSON = #"{"schemaVersion":1,"clientRole":"hook","source":"codex","requestId":null,"command":"hello","payload":{}}"#

    func testHelpOutputNamesHookCommand() throws {
        let output = try HookCLI().run(arguments: ["--help"])
        XCTAssertTrue(output.contains("my-vibe-island-hooks"))
        XCTAssertTrue(output.contains("hook-event"))
    }

    func testOriginalStyleSourceEventBuildsHookEnvelopeFromInputJSON() throws {
        let captured = HookEnvironment(cwd: "/tmp/project", tmuxPane: "%9")
        let box = EnvelopeBox()

        _ = try HookCLI(
            environmentCapture: { captured },
            bridgeSendFireAndForget: { envelope, _, _ in
                box.record(envelope)
            }
        ).run(arguments: [
            "--source", "kimi",
            "--event", "SessionStart",
            "--socket", "/tmp/my-vibe-island-capture.sock",
            "--input", #"{"session_id":"abc","cwd":"/tmp/project","model":"gpt-5"}"#,
        ])

        let envelope = try box.get()
        XCTAssertEqual(envelope.clientRole, "hook")
        XCTAssertEqual(envelope.source, "kimi")
        XCTAssertEqual(envelope.command, .hookEvent)
        XCTAssertEqual(envelope.environment, captured)
        XCTAssertEqual(envelope.payload["_source"], .string("kimi"))
        XCTAssertEqual(envelope.payload["hook_event_name"], .string("SessionStart"))
        XCTAssertEqual(envelope.payload["session_id"], .string("abc"))
        XCTAssertEqual(envelope.payload["model"], .string("gpt-5"))
    }

    func testOriginalStyleHermesEventPreservesOriginalPluginPayload() throws {
        let box = EnvelopeBox()

        _ = try HookCLI(
            bridgeSend: { envelope, _, _ in
                box.record(envelope)
                return .ok(message: "captured")
            }
        ).run(arguments: [
            "--source", "hermes",
            "--wait-for-ack",
            "--input", #"{"hook_event_name":"Stop","session_id":"hermes-session","cwd":"/tmp/hermes","turn_id":"turn-1","event_id":"hermes:hermes-session:turn-1:terminal","last_assistant_message":"completed"}"#,
        ])

        let envelope = try box.get()
        XCTAssertEqual(envelope.source, "hermes")
        XCTAssertEqual(envelope.payload["hook_event_name"], .string("Stop"))
        XCTAssertEqual(envelope.payload["session_id"], .string("hermes-session"))
        XCTAssertEqual(envelope.payload["event_id"], .string("hermes:hermes-session:turn-1:terminal"))
        XCTAssertEqual(envelope.payload["last_assistant_message"], .string("completed"))
    }

    func testOriginalStyleCodexSourceUsesCodexHandlerNormalization() throws {
        let box = EnvelopeBox()

        _ = try HookCLI(
            bridgeSend: { envelope, _, _ in
                box.record(envelope)
                return .ok(message: "captured")
            }
        ).run(arguments: [
            "--source", "codex",
            "--event", "PermissionRequest",
            "--socket", "/tmp/my-vibe-island-capture.sock",
            "--input", #"{"session_id":"abc","cwd":"/tmp/project","turn_id":"turn-1","transcript_path":"/tmp/t.jsonl","last_assistant_message":"Running bash"}"#,
        ])

        let envelope = try box.get()
        XCTAssertEqual(envelope.payload["session_id"], .string("codex-abc"))
        XCTAssertEqual(envelope.payload["codex_thread_id"], .string("codex-abc"))
        XCTAssertEqual(envelope.payload["codex_turn_id"], .string("turn-1"))
        XCTAssertEqual(envelope.payload["codex_transcript_path"], .string("/tmp/t.jsonl"))
        XCTAssertEqual(envelope.payload["codex_last_assistant_message"], .string("Running bash"))
    }

    func testOriginalStyleCodexPermissionRequestAddsCorrelationFieldsToTrace() throws {
        let box = EnvelopeBox()

        _ = try HookCLI(
            bridgeSend: { envelope, _, _ in
                box.record(envelope)
                return .ok(message: "captured")
            }
        ).run(arguments: [
            "--source", "codex",
            "--event", "PermissionRequest",
            "--socket", "/tmp/my-vibe-island-capture.sock",
            "--input", #"{"session_id":"approval-session","cwd":"/tmp/project","tool_use_id":"tool-approval-1","tool_name":"Bash","permission_mode":"on-request"}"#,
        ])

        let envelope = try box.get()
        XCTAssertEqual(envelope.requestId, "tool-approval-1")
        XCTAssertEqual(envelope.payload["hook_event_name"], .string("PermissionRequest"))
        XCTAssertEqual(envelope.payload["session_id"], .string("codex-approval-session"))
    }

    func testOriginalStyleCodexSourceSessionStartFlowsThroughSocketToStore() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let storeURL = temporaryStoreURL()
        let coordinator = SessionCoordinator()
        let store = JSONSessionStore(fileURL: storeURL)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(sessionCoordinator: coordinator, sessionStore: store)
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let output = try HookCLI().run(arguments: [
            "--source", "codex",
            "--event", "SessionStart",
            "--socket", socketPath,
            "--input", #"{"session_id":"socket-probe","cwd":"/tmp/socket-project","model":"gpt-5","permission_mode":"on-request","transcript_path":"/tmp/socket.jsonl","prompt":"inspect bridge flow"}"#,
        ])

        XCTAssertEqual(output, "")
        for _ in 0..<20 {
            if coordinator.snapshot(sessionId: "codex-socket-probe") != nil {
                break
            }
            usleep(10_000)
        }
        XCTAssertEqual(coordinator.snapshot(sessionId: "codex-socket-probe")?.cwd, "/tmp/socket-project")
        XCTAssertEqual(store.loadSnapshot().sessions.map(\.id), ["codex-socket-probe"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testOriginalStyleHermesLifecycleFlowsThroughSocketToCompletedSession() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let storeURL = temporaryStoreURL()
        let coordinator = SessionCoordinator()
        let store = JSONSessionStore(fileURL: storeURL)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(sessionCoordinator: coordinator, sessionStore: store)
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let lifecycle: [(String, String)] = [
            ("SessionStart", #"{"session_id":"hermes-e2e","cwd":"/tmp/hermes-e2e"}"#),
            ("UserPromptSubmit", #"{"session_id":"hermes-e2e","cwd":"/tmp/hermes-e2e","prompt":"inspect Hermes lifecycle"}"#),
            ("PreToolUse", #"{"session_id":"hermes-e2e","cwd":"/tmp/hermes-e2e","tool_name":"Bash"}"#),
            ("PostToolUse", #"{"session_id":"hermes-e2e","cwd":"/tmp/hermes-e2e","tool_name":"Bash"}"#),
            ("Stop", #"{"session_id":"hermes-e2e","cwd":"/tmp/hermes-e2e","event_id":"hermes:hermes-e2e:turn-1:terminal","last_assistant_message":"Hermes lifecycle completed."}"#),
            ("SessionEnd", #"{"session_id":"hermes-e2e","cwd":"/tmp/hermes-e2e"}"#),
        ]

        for (event, input) in lifecycle {
            _ = try HookCLI().run(arguments: [
                "--source", "hermes",
                "--event", event,
                "--socket", socketPath,
                "--input", input,
            ])
        }

        let session = try XCTUnwrap(coordinator.snapshot(sessionId: "hermes-e2e"))
        XCTAssertEqual(session.source, "hermes")
        XCTAssertEqual(session.cwd, "/tmp/hermes-e2e")
        XCTAssertEqual(session.snapshot().status, .completed)
        XCTAssertEqual(session.firstUserMessage, "inspect Hermes lifecycle")
        XCTAssertEqual(session.lastAssistantMessage, "Hermes lifecycle completed.")
        XCTAssertEqual(store.loadSnapshot().sessions.map(\.id), ["hermes-e2e"])
    }

    func testOriginalStyleCodexPostToolUseProducesNoStdoutWithoutDirective() throws {
        let output = try HookCLI(
            bridgeSend: { _, _, _ in .ok(message: "event accepted") }
        ).run(arguments: [
            "--source", "codex",
            "--event", "PostToolUse",
            "--socket", "/tmp/my-vibe-island-capture.sock",
            "--input", #"{"session_id":"abc","cwd":"/tmp/project","tool_name":"Bash"}"#,
        ])

        XCTAssertEqual(output, "")
    }

    func testOriginalStyleCodexPostToolUseUsesFireAndForgetPath() throws {
        let fireAndForget = FireAndForgetBox()
        var waited = false

        let output = try HookCLI(
            bridgeSend: { _, _, _ in
                waited = true
                return .ok(message: "should not wait")
            },
            bridgeSendFireAndForget: { envelope, _, _ in
                fireAndForget.record(envelope)
            }
        ).run(arguments: [
            "--source", "codex",
            "--event", "PostToolUse",
            "--socket", "/tmp/my-vibe-island-capture.sock",
            "--input", #"{"session_id":"abc","cwd":"/tmp/project","tool_name":"Bash"}"#,
        ])

        XCTAssertEqual(output, "")
        XCTAssertFalse(waited)
        XCTAssertEqual(try fireAndForget.get().payload["hook_event_name"], .string("PostToolUse"))
    }

    func testOriginalStyleCodexPermissionRequestKeepsResponsePath() throws {
        var waited = false
        let output = try HookCLI(
            bridgeSend: { _, _, _ in
                waited = true
                return .ok(message: "approval response")
            },
            bridgeSendFireAndForget: { _, _, _ in
                XCTFail("permission request must not use fire-and-forget")
            }
        ).run(arguments: [
            "--source", "codex",
            "--event", "PermissionRequest",
            "--socket", "/tmp/my-vibe-island-capture.sock",
            "--input", #"{"session_id":"abc","cwd":"/tmp/project","tool_name":"Bash"}"#,
        ])

        XCTAssertTrue(waited)
        XCTAssertEqual(output, "")
    }

    func testOriginalStyleCodexPreToolUseUsesFireAndForgetPath() throws {
        let fireAndForget = FireAndForgetBox()
        var waited = false

        _ = try HookCLI(
            bridgeSend: { _, _, _ in
                waited = true
                return .ok(message: "should not wait")
            },
            bridgeSendFireAndForget: { envelope, _, _ in
                fireAndForget.record(envelope)
            }
        ).run(arguments: [
            "--source", "codex",
            "--event", "PreToolUse",
            "--socket", "/tmp/my-vibe-island-capture.sock",
            "--input", #"{"session_id":"abc","cwd":"/tmp/project","tool_name":"Bash"}"#,
        ])

        XCTAssertFalse(waited)
        XCTAssertEqual(try fireAndForget.get().payload["hook_event_name"], .string("PreToolUse"))
    }

    func testOriginalStyleCodexPostToolUseFailsOpenWithoutStdoutWhenBridgeOffline() throws {
        let output = try HookCLI().run(arguments: [
            "--source", "codex",
            "--event", "PostToolUse",
            "--socket", "/tmp/my-vibe-island-missing-test.sock",
            "--input", #"{"session_id":"abc","cwd":"/tmp/project","tool_name":"Bash"}"#,
        ])

        XCTAssertEqual(output, "")
    }

    func testOriginalStyleCodexStopReturnsContinueJSONWithoutDirective() throws {
        let output = try HookCLI(
            bridgeSend: { _, _, _ in .ok(message: "event accepted") }
        ).run(arguments: [
            "--source", "codex",
            "--event", "Stop",
            "--socket", "/tmp/my-vibe-island-capture.sock",
            "--input", #"{"session_id":"abc","cwd":"/tmp/project"}"#,
        ])

        let value = try JSONDecoder().decode(
            BridgeJSONValue.self,
            from: Data(output.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        )
        XCTAssertEqual(value, .object(["continue": .bool(true)]))
    }

    func testOriginalStyleCodexSubagentStopReturnsContinueJSONWithoutDirective() throws {
        let output = try HookCLI(
            bridgeSend: { _, _, _ in .ok(message: "event accepted") }
        ).run(arguments: [
            "--source", "codex",
            "--event", "SubagentStop",
            "--socket", "/tmp/my-vibe-island-capture.sock",
            "--input", #"{"session_id":"abc","cwd":"/tmp/project"}"#,
        ])

        let value = try JSONDecoder().decode(
            BridgeJSONValue.self,
            from: Data(output.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        )
        XCTAssertEqual(value, .object(["continue": .bool(true)]))
    }

    func testOriginalStyleCodexStopReturnsContinueJSONWhenBridgeIsOffline() throws {
        let output = try HookCLI().run(arguments: [
            "--source", "codex",
            "--event", "Stop",
            "--socket", "/tmp/my-vibe-island-missing-test.sock",
            "--input", #"{"session_id":"abc","cwd":"/tmp/project"}"#,
        ])

        let value = try JSONDecoder().decode(
            BridgeJSONValue.self,
            from: Data(output.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        )
        XCTAssertEqual(value, .object(["continue": .bool(true)]))
    }

    func testOriginalStyleSourceEventReadsHookJSONFromStdinWhenInputFlagIsOmitted() throws {
        let box = EnvelopeBox()

        _ = try HookCLI(
            standardInput: { #"{"session_id":"stdin-session","cwd":"/tmp/stdin"}"# },
            bridgeSendFireAndForget: { envelope, _, _ in
                box.record(envelope)
            }
        ).run(arguments: [
            "--source", "kimi",
            "--event", "SessionStart",
            "--socket", "/tmp/my-vibe-island-capture.sock",
        ])

        let envelope = try box.get()
        XCTAssertEqual(envelope.payload["session_id"], .string("stdin-session"))
        XCTAssertEqual(envelope.payload["hook_event_name"], .string("SessionStart"))
    }

    func testHookEventFailsOpenWhenSocketIsMissing() throws {
        let output = try HookCLI().run(arguments: [
            "hook-event",
            "--socket", "/tmp/my-vibe-island-missing-test.sock",
            "--input", helloEnvelopeJSON
        ])

        let response = try BridgeCodec().decodeResponseLine(output)
        XCTAssertEqual(response.ok, true)
        XCTAssertTrue(response.message?.contains("bridge offline") == true)
    }

    func testHookEventReturnsBridgeResponseWhenServerIsReachable() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let server = BridgeServer(socketPath: socketPath, handler: BridgeRequestHandler(sessionCoordinator: SessionCoordinator()))
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let output = try HookCLI().run(arguments: [
            "hook-event",
            "--socket", socketPath,
            "--input", helloEnvelopeJSON
        ])

        let response = try BridgeCodec().decodeResponseLine(output)
        XCTAssertEqual(response, .ok(message: "bridge reachable"))
    }

    func testHookEventAttachesCapturedEnvironmentWhenInputOmitsEnvironment() throws {
        let captured = HookEnvironment(
            cwd: "/tmp/captured",
            shell: "/bin/zsh",
            terminal: "iTerm.app",
            pid: 777,
            user: "fixture-user",
            tmuxPane: "%9"
        )
        let envelope = try captureOutboundEnvelope(input: helloEnvelopeJSON, capturedEnvironment: captured)

        XCTAssertEqual(envelope.environment, captured)
    }

    func testHookEventPreservesInputEnvironmentWhenAlreadyPresent() throws {
        let inputEnvironment = HookEnvironment(
            cwd: "/tmp/input",
            shell: "/bin/fish",
            terminal: "Terminal.app",
            pid: 111,
            user: "input-user",
            tmuxPane: "%1"
        )
        let captured = HookEnvironment(
            cwd: "/tmp/captured",
            shell: "/bin/zsh",
            terminal: "iTerm.app",
            pid: 777,
            user: "fixture-user",
            tmuxPane: "%9"
        )
        let input = try BridgeCodec().encodeEnvelopeLine(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hello,
            payload: [:],
            environment: inputEnvironment
        ))

        let envelope = try captureOutboundEnvelope(input: input, capturedEnvironment: captured)

        XCTAssertEqual(envelope.environment, inputEnvironment)
    }

    func testHookEventPrintsRawSourceDirectiveWhenBridgeResponseCarriesDirective() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        let server = BridgeServer(socketPath: socketPath, handler: BridgeRequestHandler(sessionCoordinator: coordinator))
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let input = try BridgeCodec().encodeEnvelopeLine(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "app",
            source: "my-vibe-island",
            requestId: nil,
            command: .resolveAction,
            payload: [
                "requestId": .string("r1"),
                "sessionId": .string("s1"),
                "action": .string("approve"),
            ]
        ))

        let output = try HookCLI().run(arguments: [
            "hook-event",
            "--socket", socketPath,
            "--input", input,
        ])

        let directive = try JSONDecoder().decode(BridgeJSONValue.self, from: Data(output.trimmingCharacters(in: .whitespacesAndNewlines).utf8))
        XCTAssertFalse(output.contains(#""ok""#))
        XCTAssertEqual(directive, .object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                ]),
            ]),
        ]))
    }

    func testHookEventWaitsForResolveActionAndPrintsRawSourceDirective() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 1.0)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: coordinator,
                blockingActionContinuations: continuations
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let input = try BridgeCodec().encodeEnvelopeLine(BridgeEnvelope(
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

        let hookCompleted = expectation(description: "hook cli completed")
        let outputBox = OutputBox()
        DispatchQueue.global().async {
            do {
                let output = try HookCLI().run(arguments: [
                    "hook-event",
                    "--socket", socketPath,
                    "--input", input,
                ])
                outputBox.record(.success(output))
            } catch {
                outputBox.record(.failure(error))
            }
            hookCompleted.fulfill()
        }

        let pendingAppeared = expectation(description: "pending action appeared")
        DispatchQueue.global().async {
            let deadline = Date().addingTimeInterval(1.0)
            while Date() < deadline {
                if coordinator.actionableRequests().contains(where: { $0.requestId == "r1" }) {
                    pendingAppeared.fulfill()
                    return
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        wait(for: [pendingAppeared], timeout: 1.1)

        _ = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "app",
            source: "my-vibe-island",
            requestId: nil,
            command: .resolveAction,
            payload: [
                "requestId": .string("r1"),
                "sessionId": .string("s1"),
                "action": .string("approve"),
            ]
        ))

        wait(for: [hookCompleted], timeout: 1.1)
        let output = try outputBox.get()
        let directive = try JSONDecoder().decode(
            BridgeJSONValue.self,
            from: Data(output.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        )

        XCTAssertFalse(output.contains(#""ok""#))
        XCTAssertEqual(directive, .object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                ]),
            ]),
        ]))
    }

    func testIdlessCodexSourcePermissionRequestStaysConnectedUntilLocalApproval() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 10)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: coordinator,
                blockingActionContinuations: continuations
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let hookCompleted = expectation(description: "id-less Codex source hook completed")
        let outputBox = OutputBox()
        DispatchQueue.global().async {
            do {
                let output = try HookCLI().run(arguments: [
                    "--source", "codex",
                    "--event", "PermissionRequest",
                    "--socket", socketPath,
                    "--input", #"{"session_id":"idless-source-session","turn_id":"turn-1","cwd":"/tmp/project","tool_name":"Bash","tool_input":{"command":"/usr/bin/whoami"}}"#,
                ])
                outputBox.record(.success(output))
            } catch {
                outputBox.record(.failure(error))
            }
            hookCompleted.fulfill()
        }

        let requestID = "codex-terminal:codex-idless-source-session:turn-1"
        let pendingAppeared = expectation(description: "id-less request appeared")
        DispatchQueue.global().async {
            let deadline = Date().addingTimeInterval(1)
            while Date() < deadline {
                if coordinator.actionableRequests().contains(where: { $0.requestId == requestID }) {
                    pendingAppeared.fulfill()
                    return
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        wait(for: [pendingAppeared], timeout: 1.1)
        XCTAssertEqual(continuations.pendingCount, 1)

        let resolution = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "app",
            source: "my-vibe-island",
            requestId: nil,
            command: .resolveAction,
            payload: [
                "requestId": .string(requestID),
                "sessionId": .string("codex-idless-source-session"),
                "action": .string("approve"),
            ]
        ))

        XCTAssertNotNil(resolution.sourceDirective)
        wait(for: [hookCompleted], timeout: 1.1)
        let output = try outputBox.get()
        let directive = try JSONDecoder().decode(
            BridgeJSONValue.self,
            from: Data(output.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        )
        XCTAssertEqual(directive, .object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object(["behavior": .string("allow")]),
            ]),
        ]))
    }

    func testHookEventWaitsForOpenCodeQuestionAnswerAndPrintsRawSourceDirective() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let coordinator = SessionCoordinator()
        let continuations = PendingActionContinuations(timeout: 1.0)
        let server = BridgeServer(
            socketPath: socketPath,
            handler: BridgeRequestHandler(
                sessionCoordinator: coordinator,
                blockingActionContinuations: continuations
            )
        )
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let input = try BridgeCodec().encodeEnvelopeLine(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "opencode",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "event": .string("question"),
                "id": .string("opencode-question-1"),
                "sessionID": .string("opencode-session"),
            ]
        ))

        let hookCompleted = expectation(description: "opencode hook cli completed")
        let outputBox = OutputBox()
        DispatchQueue.global().async {
            do {
                let output = try HookCLI().run(arguments: [
                    "hook-event",
                    "--socket", socketPath,
                    "--input", input,
                ])
                outputBox.record(.success(output))
            } catch {
                outputBox.record(.failure(error))
            }
            hookCompleted.fulfill()
        }

        let pendingAppeared = expectation(description: "opencode pending question appeared")
        DispatchQueue.global().async {
            let deadline = Date().addingTimeInterval(1.0)
            while Date() < deadline {
                if coordinator.actionableRequests().contains(where: { $0.requestId == "opencode-question-1" }) {
                    pendingAppeared.fulfill()
                    return
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        wait(for: [pendingAppeared], timeout: 1.1)

        _ = try BridgeClient(socketPath: socketPath).send(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "app",
            source: "my-vibe-island",
            requestId: nil,
            command: .resolveAction,
            payload: [
                "requestId": .string("opencode-question-1"),
                "sessionId": .string("opencode-session"),
                "action": .string("answer"),
                "answer": .string("Use option A"),
            ]
        ))

        wait(for: [hookCompleted], timeout: 1.1)
        let output = try outputBox.get()
        let directive = try JSONDecoder().decode(
            BridgeJSONValue.self,
            from: Data(output.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        )

        XCTAssertFalse(output.contains(#""ok""#))
        XCTAssertEqual(directive, .object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object([
                    "behavior": .string("allow"),
                    "updatedInput": .object([
                        "answers": .object(["Question": .string("Use option A")]),
                    ]),
                ]),
            ]),
        ]))
    }

    func testHookEventMissingInputReturnsFailureResponse() throws {
        let output = try HookCLI().run(arguments: [
            "hook-event",
            "--socket", "/tmp/my-vibe-island-missing-input-test.sock"
        ])

        let response = try BridgeCodec().decodeResponseLine(output)
        XCTAssertEqual(response.ok, false)
        XCTAssertEqual(response.message, "missing --input")
    }

    func testHookEventSocketFlagWithoutValueReturnsFailureResponse() throws {
        let output = try HookCLI().run(arguments: [
            "hook-event",
            "--socket",
            "--input", helloEnvelopeJSON
        ])

        let response = try BridgeCodec().decodeResponseLine(output)
        XCTAssertEqual(response.ok, false)
        XCTAssertEqual(response.message, "missing --socket")
    }

    func testHookEventInputFlagWithoutValueReturnsFailureResponse() throws {
        let output = try HookCLI().run(arguments: [
            "hook-event",
            "--socket", "/tmp/my-vibe-island-missing-input-value-test.sock",
            "--input", "--socket"
        ])

        let response = try BridgeCodec().decodeResponseLine(output)
        XCTAssertEqual(response.ok, false)
        XCTAssertEqual(response.message, "missing --input")
    }

    private func captureOutboundEnvelope(
        input: String,
        capturedEnvironment: HookEnvironment
    ) throws -> BridgeEnvelope {
        let box = EnvelopeBox()

        _ = try HookCLI(
            environmentCapture: { capturedEnvironment },
            bridgeSend: { envelope, _, _ in
                box.record(envelope)
                return .ok(message: "captured")
            }
        ).run(arguments: [
            "hook-event",
            "--socket", "/tmp/my-vibe-island-capture.sock",
            "--input", input,
        ])

        return try box.get()
    }

    private func temporaryStoreURL() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-hook-cli-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root.appendingPathComponent("session-terminals.json")
    }
}
