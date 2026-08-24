import XCTest
@testable import MyVibeIslandCore

final class ClaudeCompatibleAdapterTests: XCTestCase {
    func testClaudeCompatibleAdapterMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ClaudeCompatibleAdapterMatrixFixture.self,
            from: try FixtureLoader.data("claude/adapter-matrix")
        )
        let adapter = ClaudeCompatibleAdapter()
        let environment = HookEnvironment(cwd: "/tmp/project", shell: "zsh", terminal: "Terminal.app", pid: 84, user: "fixture-user")

        let actual = ClaudeCompatibleAdapterMatrixFixture(rows: [
            row(id: "session-start", event: try adapter.hookEvent(from: claudeEnvelope(
                payload: try FixtureLoader.bridgePayload("claude/hook-session-start")
            ))),
            row(id: "permission-envelope-id", event: try adapter.hookEvent(from: claudeEnvelope(
                requestId: "req-envelope",
                payload: try FixtureLoader.bridgePayload("claude/hook-permission-request")
            ))),
            row(id: "permission-tool-id", event: try adapter.hookEvent(from: claudeEnvelope(
                payload: try FixtureLoader.bridgePayload("claude/hook-permission-request")
            ))),
            row(id: "pre-tool-use", event: try adapter.hookEvent(from: claudeEnvelope(
                payload: try FixtureLoader.bridgePayload("claude/hook-pre-tool-use")
            ))),
            row(id: "stop-content", event: try adapter.hookEvent(from: claudeEnvelope(
                payload: try FixtureLoader.bridgePayload("claude/hook-stop-with-content")
            ))),
            row(id: "generic-fallback", event: try adapter.hookEvent(from: claudeEnvelope(payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("generic-claude-session"),
                "cwd": .string("/tmp/generic-claude"),
            ]))),
            row(id: "environment", event: try adapter.hookEvent(from: claudeEnvelope(
                payload: try FixtureLoader.bridgePayload("claude/hook-session-start"),
                environment: environment
            ))),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testSessionStartFixtureNormalizesToHookEvent() throws {
        let adapter = ClaudeCompatibleAdapter()
        let event = try adapter.hookEvent(from: claudeEnvelope(
            payload: try FixtureLoader.bridgePayload("claude/hook-session-start")
        ))

        XCTAssertEqual(event.rawEventName, "SessionStart")
        XCTAssertEqual(event.source, "claude")
        XCTAssertEqual(event.sessionId, "claude-session")
        XCTAssertNil(event.requestId)
        XCTAssertEqual(event.cwd, "/tmp/claude")
        XCTAssertEqual(event.model, "claude-sonnet-4-5")
        XCTAssertEqual(event.permissionMode, "default")
    }

    func testPermissionRequestUsesEnvelopeRequestIdBeforeToolUseId() throws {
        let adapter = ClaudeCompatibleAdapter()
        let event = try adapter.hookEvent(from: claudeEnvelope(
            requestId: "req-envelope",
            payload: try FixtureLoader.bridgePayload("claude/hook-permission-request")
        ))

        XCTAssertEqual(event.requestId, "req-envelope")
        XCTAssertEqual(event.toolName, "Bash")
    }

    func testPermissionRequestFallsBackToToolUseId() throws {
        let adapter = ClaudeCompatibleAdapter()
        let event = try adapter.hookEvent(from: claudeEnvelope(
            payload: try FixtureLoader.bridgePayload("claude/hook-permission-request")
        ))

        XCTAssertEqual(event.requestId, "tool-use-claude-1")
        XCTAssertEqual(event.toolName, "Bash")
    }

    func testPreToolUseFallsBackToToolUseId() throws {
        let adapter = ClaudeCompatibleAdapter()
        let event = try adapter.hookEvent(from: claudeEnvelope(
            payload: try FixtureLoader.bridgePayload("claude/hook-pre-tool-use")
        ))

        XCTAssertEqual(event.rawEventName, "PreToolUse")
        XCTAssertEqual(event.requestId, "tool-use-claude-pre-1")
        XCTAssertEqual(event.toolName, "Edit")
    }

    func testStopFixturePreservesAssistantMessageAndNormalizedContent() throws {
        let adapter = ClaudeCompatibleAdapter()
        let event = try adapter.hookEvent(from: claudeEnvelope(
            payload: try FixtureLoader.bridgePayload("claude/hook-stop-with-content")
        ))

        XCTAssertEqual(event.rawEventName, "Stop")
        XCTAssertEqual(event.message, "Implemented parser coverage")
        XCTAssertEqual(event.tasks, [
            TaskItem(
                id: "task-claude-1",
                subject: "Add Claude fixture",
                description: "Cover Stop payload content",
                status: .completed,
                activeForm: "Adding fixture",
                owner: "claude"
            ),
        ])
        XCTAssertEqual(event.todos, [
            TodoItem(
                id: "todo-claude-1",
                content: "Run fixture tests",
                status: .completed,
                activeForm: "Verifying"
            ),
        ])
    }

    func testPermissionRequestWithoutStableIdThrowsInvalidPayload() throws {
        let adapter = ClaudeCompatibleAdapter()
        let envelope = claudeEnvelope(
            payload: try FixtureLoader.bridgePayload("claude/hook-permission-request-missing-id")
        )

        XCTAssertThrowsError(try adapter.hookEvent(from: envelope)) { error in
            XCTAssertEqual(error as? AgentAdapterError, .invalidHookPayload)
        }
    }

    func testGenericCompatibilityPayloadFallsBackToGenericAdapter() throws {
        let adapter = ClaudeCompatibleAdapter()
        let event = try adapter.hookEvent(from: claudeEnvelope(payload: [
            "rawEventName": .string("SessionStart"),
            "sessionId": .string("generic-claude-session"),
            "cwd": .string("/tmp/generic-claude"),
        ]))

        XCTAssertEqual(event.rawEventName, "SessionStart")
        XCTAssertEqual(event.sessionId, "generic-claude-session")
        XCTAssertEqual(event.cwd, "/tmp/generic-claude")
    }

    func testNativePayloadPreservesEnvelopeEnvironment() throws {
        let adapter = ClaudeCompatibleAdapter()
        let environment = HookEnvironment(cwd: "/tmp/project", shell: "zsh", terminal: "Terminal.app", pid: 84, user: "fixture-user")
        let event = try adapter.hookEvent(from: claudeEnvelope(
            payload: try FixtureLoader.bridgePayload("claude/hook-session-start"),
            environment: environment
        ))

        XCTAssertEqual(event.environment, environment)
    }

    func testGenericPayloadPreservesEnvelopeEnvironment() throws {
        let adapter = ClaudeCompatibleAdapter()
        let environment = HookEnvironment(cwd: "/tmp/project", shell: "fish", terminal: "WezTerm", pid: 126, user: "fixture-user")
        let event = try adapter.hookEvent(from: claudeEnvelope(
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("generic-claude-session"),
                "cwd": .string("/tmp/generic-claude"),
            ],
            environment: environment
        ))

        XCTAssertEqual(event.environment, environment)
    }

    private func claudeEnvelope(
        source: String = "claude",
        requestId: String? = nil,
        payload: [String: BridgeJSONValue],
        environment: HookEnvironment? = nil
    ) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: source,
            requestId: requestId,
            command: .hookEvent,
            payload: payload,
            environment: environment
        )
    }

    private func row(id: String, event: HookEvent) -> ClaudeCompatibleAdapterRowFixture {
        ClaudeCompatibleAdapterRowFixture(
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

    private struct ClaudeCompatibleAdapterMatrixFixture: Codable, Equatable {
        let rows: [ClaudeCompatibleAdapterRowFixture]
    }

    private struct ClaudeCompatibleAdapterRowFixture: Codable, Equatable {
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
