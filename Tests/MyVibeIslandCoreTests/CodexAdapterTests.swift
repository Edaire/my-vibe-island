import XCTest
@testable import MyVibeIslandCore

final class CodexAdapterTests: XCTestCase {
    func testCodexAdapterMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CodexAdapterMatrixFixture.self,
            from: try FixtureLoader.data("codex/adapter-matrix")
        )
        let adapter = CodexAdapter()
        let environment = HookEnvironment(cwd: "/tmp/project", shell: "zsh", terminal: "iTerm.app", pid: 42, user: "fixture-user")

        let actual = CodexAdapterMatrixFixture(rows: [
            row(id: "session-start", event: try adapter.hookEvent(from: codexEnvelope(
                payload: try FixtureLoader.bridgePayload("codex/hook-session-start")
            ))),
            row(id: "permission-envelope-id", event: try adapter.hookEvent(from: codexEnvelope(
                requestId: "req-envelope",
                payload: try FixtureLoader.bridgePayload("codex/hook-permission-request")
            ))),
            row(id: "permission-tool-id", event: try adapter.hookEvent(from: codexEnvelope(
                payload: try FixtureLoader.bridgePayload("codex/hook-permission-request")
            ))),
            row(id: "permission-generic-id", event: try adapter.hookEvent(from: codexEnvelope(payload: [
                "hook_event_name": .string("PermissionRequest"),
                "session_id": .string("codex-session"),
                "requestId": .string("req-generic"),
                "cwd": .string("/tmp/codex"),
                "tool_name": .string("Shell"),
            ]))),
            row(id: "stop-content", event: try adapter.hookEvent(from: codexEnvelope(
                payload: try FixtureLoader.bridgePayload("codex/hook-stop-with-content")
            ))),
            row(id: "environment", event: try adapter.hookEvent(from: codexEnvelope(
                payload: try FixtureLoader.bridgePayload("codex/hook-session-start"),
                environment: environment
            ))),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testSessionStartFixtureNormalizesToHookEvent() throws {
        let adapter = CodexAdapter()
        let event = try adapter.hookEvent(from: codexEnvelope(
            payload: try FixtureLoader.bridgePayload("codex/hook-session-start")
        ))

        XCTAssertEqual(event.rawEventName, "SessionStart")
        XCTAssertEqual(event.source, "codex")
        XCTAssertEqual(event.sessionId, "codex-session")
        XCTAssertNil(event.requestId)
        XCTAssertEqual(event.cwd, "/tmp/codex")
        XCTAssertEqual(event.model, "gpt-5")
        XCTAssertEqual(event.permissionMode, "plan")
    }

    func testBareCodexHookSessionIdIsPrefixedLikeOriginalHook() throws {
        let adapter = CodexAdapter()
        let event = try adapter.hookEvent(from: codexEnvelope(payload: [
            "hook_event_name": .string("SessionStart"),
            "session_id": .string("019f36a7-b73f-7750-85db-081ea9257dbb"),
            "cwd": .string("/tmp/codex"),
        ]))

        XCTAssertEqual(event.sessionId, "codex-019f36a7-b73f-7750-85db-081ea9257dbb")
    }

    func testPermissionRequestUsesEnvelopeRequestIdBeforeToolUseId() throws {
        let adapter = CodexAdapter()
        let event = try adapter.hookEvent(from: codexEnvelope(
            requestId: "req-envelope",
            payload: try FixtureLoader.bridgePayload("codex/hook-permission-request")
        ))

        XCTAssertEqual(event.requestId, "req-envelope")
        XCTAssertEqual(event.toolName, "Shell")
    }

    func testPermissionRequestFallsBackToToolUseId() throws {
        let adapter = CodexAdapter()
        let event = try adapter.hookEvent(from: codexEnvelope(
            payload: try FixtureLoader.bridgePayload("codex/hook-permission-request")
        ))

        XCTAssertEqual(event.requestId, "tool-use-1")
    }

    func testPermissionRequestFallsBackToGenericRequestIdAfterToolUseId() throws {
        let adapter = CodexAdapter()
        let event = try adapter.hookEvent(from: codexEnvelope(payload: [
            "hook_event_name": .string("PermissionRequest"),
            "session_id": .string("codex-session"),
            "requestId": .string("req-generic"),
            "cwd": .string("/tmp/codex"),
            "tool_name": .string("Shell"),
        ]))

        XCTAssertEqual(event.requestId, "req-generic")
    }

    func testPermissionRequestUsesOriginalTwoHourBlockingTimeout() throws {
        let adapter = CodexAdapter()
        let request = ActionableRequest(
            requestId: "tool-use-1",
            sessionId: "codex-session",
            source: "codex",
            kind: .permission,
            toolName: "Shell"
        )

        XCTAssertEqual(adapter.blockingTimeout(for: request), 7_200)
    }

    func testStopFixturePreservesAssistantMessageAndNormalizedContent() throws {
        let adapter = CodexAdapter()
        let event = try adapter.hookEvent(from: codexEnvelope(
            payload: try FixtureLoader.bridgePayload("codex/hook-stop-with-content")
        ))

        XCTAssertEqual(event.rawEventName, "Stop")
        XCTAssertEqual(event.message, "Completed Codex task sync")
        XCTAssertEqual(event.tasks, [
            TaskItem(
                id: "task-codex-1",
                subject: "Sync Codex content",
                description: "Cover Stop payload normalization",
                status: .completed,
                activeForm: "Syncing Codex content",
                owner: "codex"
            ),
        ])
        XCTAssertEqual(event.todos, [
            TodoItem(
                id: "todo-codex-1",
                content: "Verify Codex fixture",
                status: .completed,
                activeForm: "Verifying Codex fixture"
            ),
        ])
    }

    func testUserPromptSubmitUsesPromptAsSessionActivityMessage() throws {
        let adapter = CodexAdapter()
        let event = try adapter.hookEvent(from: codexEnvelope(payload: [
            "hook_event_name": .string("UserPromptSubmit"),
            "session_id": .string("codex-session"),
            "cwd": .string("/tmp/codex"),
            "prompt": .string("Show the real current session"),
            "last_assistant_message": .string("Codex is working."),
        ]))

        XCTAssertEqual(event.message, "Show the real current session")
        XCTAssertEqual(event.agentEvents(), [
            .sessionActivityUpdated(
                source: "codex",
                sessionId: "codex-session",
                activity: SessionActivityUpdate(
                    status: .active,
                    summary: "Show the real current session",
                    firstUserMessage: "Show the real current session",
                    lastUserMessage: "Show the real current session",
                    startsNewTurn: true,
                    isBootstrapFirstUserMessage: true,
                    cwd: "/tmp/codex"
                )
            ),
        ])
    }

    func testUserPromptSubmitRecoversAuthoritativeFirstMessageFromTranscript() throws {
        let transcript = try temporaryDirectory()
            .appendingPathComponent("rollout.jsonl", isDirectory: false)
        try """
        {"timestamp":"2026-07-23T07:00:00.000Z","type":"event_msg","payload":{"type":"user_message","message":"原始首条请求"}}
        {"timestamp":"2026-07-23T07:01:00.000Z","type":"event_msg","payload":{"type":"agent_message","message":"处理中"}}
        """.write(to: transcript, atomically: true, encoding: .utf8)

        let event = try CodexAdapter().hookEvent(from: codexEnvelope(payload: [
            "hook_event_name": .string("UserPromptSubmit"),
            "session_id": .string("codex-session"),
            "cwd": .string("/tmp/codex"),
            "prompt": .string("当前这一轮请求"),
            "transcript_path": .string(transcript.path),
        ]))

        XCTAssertEqual(event.firstUserMessage, "原始首条请求")
        XCTAssertEqual(event.message, "当前这一轮请求")
        XCTAssertEqual(event.agentEvents(), [
            .sessionActivityUpdated(
                source: "codex",
                sessionId: "codex-session",
                activity: SessionActivityUpdate(
                    status: .active,
                    summary: "当前这一轮请求",
                    firstUserMessage: "原始首条请求",
                    lastUserMessage: "当前这一轮请求",
                    codexRolloutPath: transcript.path,
                    startsNewTurn: true,
                    isBootstrapFirstUserMessage: false,
                    cwd: "/tmp/codex"
                )
            ),
        ])
    }

    func testOriginalBridgeCodexAliasesNormalizeToHookEvent() throws {
        let adapter = CodexAdapter()
        let event = try adapter.hookEvent(from: codexEnvelope(payload: [
            "hook_event_name": .string("Stop"),
            "session_id": .string("codex-session"),
            "cwd": .string("/tmp/codex"),
            "codex_model": .string("gpt-5.6"),
            "codex_last_assistant_message": .string("done from original bridge"),
        ]))

        XCTAssertEqual(event.model, "gpt-5.6")
        XCTAssertEqual(event.message, "done from original bridge")
    }

    func testSubagentStopPreservesObservedCodexParentChildTransport() throws {
        let event = try CodexAdapter().hookEvent(from: codexEnvelope(payload: [
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

        XCTAssertEqual(event.sessionId, "codex-child-thread")
        XCTAssertEqual(event.subagentParentThreadId, "parent-thread")
        XCTAssertEqual(event.subagentKind, "task")
        XCTAssertEqual(event.subagentNickname, "Reviewer")
        XCTAssertEqual(event.subagentRole, "review")
        XCTAssertEqual(event.childModel, "gpt-5.6-terra")
        XCTAssertEqual(event.childReasoningEffort, "medium")
        XCTAssertEqual(event.agentId, "child-tool-use-1")
        XCTAssertEqual(event.agentType, "reviewer")
        XCTAssertEqual(event.childParentId, "parent-tool-use-1")
        XCTAssertEqual(event.childRuntimeSessionId, "child-runtime-1")
        XCTAssertEqual(event.childProcessIncarnation, "process-1")
    }

    func testStopBackfillsAssistantMessageFromTranscriptWhenHookPayloadOmitsIt() throws {
        let transcript = try temporaryDirectory()
            .appendingPathComponent("rollout.jsonl", isDirectory: false)
        try """
        {"timestamp":"2026-07-23T07:55:29.790Z","type":"event_msg","payload":{"type":"agent_message","message":"真实完成回复"}}
        {"timestamp":"2026-07-23T07:55:30.790Z","type":"event_msg","payload":{"type":"turn_complete"}}
        """.write(to: transcript, atomically: true, encoding: .utf8)

        let event = try CodexAdapter().hookEvent(from: codexEnvelope(payload: [
            "hook_event_name": .string("Stop"),
            "session_id": .string("codex-session"),
            "cwd": .string("/tmp/codex"),
            "transcript_path": .string(transcript.path),
            "prompt": .string("用户问题不应该当成完成回复"),
        ]))

        XCTAssertEqual(event.message, "真实完成回复")
    }

    func testPermissionRequestWithoutStableIdThrowsInvalidPayload() throws {
        let adapter = CodexAdapter()
        let envelope = codexEnvelope(
            payload: try FixtureLoader.bridgePayload("codex/hook-permission-request-missing-id")
        )

        XCTAssertThrowsError(try adapter.hookEvent(from: envelope)) { error in
            XCTAssertEqual(error as? AgentAdapterError, .invalidHookPayload)
        }
    }

    func testMissingRequiredSessionStartFieldsThrowInvalidPayload() {
        let adapter = CodexAdapter()
        let envelope = codexEnvelope(payload: [
            "hook_event_name": .string("SessionStart"),
            "session_id": .string("codex-session"),
        ])

        XCTAssertThrowsError(try adapter.hookEvent(from: envelope)) { error in
            XCTAssertEqual(error as? AgentAdapterError, .invalidHookPayload)
        }
    }

    func testNativePayloadPreservesEnvelopeEnvironment() throws {
        let adapter = CodexAdapter()
        let environment = HookEnvironment(cwd: "/tmp/project", shell: "zsh", terminal: "iTerm.app", pid: 42, user: "fixture-user")
        let event = try adapter.hookEvent(from: codexEnvelope(
            payload: try FixtureLoader.bridgePayload("codex/hook-session-start"),
            environment: environment
        ))

        XCTAssertEqual(event.environment, environment)
    }

    private func codexEnvelope(
        requestId: String? = nil,
        payload: [String: BridgeJSONValue],
        environment: HookEnvironment? = nil
    ) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: requestId,
            command: .hookEvent,
            payload: payload,
            environment: environment
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-codex-adapter-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func row(id: String, event: HookEvent) -> CodexAdapterRowFixture {
        CodexAdapterRowFixture(
            id: id,
            rawEventName: event.rawEventName,
            source: event.source,
            sessionId: event.sessionId,
            requestId: event.requestId,
            cwd: event.cwd,
            model: event.model,
            permissionMode: event.permissionMode,
            toolName: event.toolName,
            message: event.message,
            hasEnvironment: event.environment != nil,
            taskCount: event.tasks.count,
            todoCount: event.todos.count
        )
    }

    private struct CodexAdapterMatrixFixture: Codable, Equatable {
        let rows: [CodexAdapterRowFixture]
    }

    private struct CodexAdapterRowFixture: Codable, Equatable {
        let id: String
        let rawEventName: String
        let source: String
        let sessionId: String
        let requestId: String?
        let cwd: String?
        let model: String?
        let permissionMode: String?
        let toolName: String?
        let message: String?
        let hasEnvironment: Bool
        let taskCount: Int
        let todoCount: Int
    }
}
