import XCTest
@testable import MyVibeIslandCore

final class NormalizedSessionContentPayloadTests: XCTestCase {
    func testNormalizedSessionContentPayloadMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            NormalizedSessionContentPayloadMatrixFixture.self,
            from: try FixtureLoader.data("runtime/normalized-session-content-payload-matrix")
        )

        var invalidPayload = genericPayload()
        invalidPayload["tasks"] = .array([
            taskValue,
            .object(["id": .string("missing-subject")]),
            .object(["subject": .string("missing id")]),
            .string("not an object"),
        ])
        invalidPayload["todos"] = .array([
            todoValue,
            .object(["id": .string("missing-content")]),
            .object(["content": .string("missing id")]),
            .number(1),
        ])

        var unknownStatusPayload = genericPayload()
        unknownStatusPayload["tasks"] = .array([
            .object([
                "id": .string("task-unknown"),
                "subject": .string("Unknown task status"),
                "status": .string("waiting-for-provider"),
            ]),
        ])
        unknownStatusPayload["todos"] = .array([
            .object([
                "id": .string("todo-unknown"),
                "content": .string("Unknown todo status"),
                "status": .string("waiting-for-provider"),
            ]),
        ])

        let actual = NormalizedSessionContentPayloadMatrixFixture(rows: [
            try row(id: "generic-normalized-content", event: GenericHookAdapter().hookEvent(
                from: genericEnvelope(payload: genericPayload())
            )),
            try row(id: "codex-normalized-content", event: CodexAdapter().hookEvent(
                from: codexEnvelope(payload: nativePayload())
            )),
            try row(id: "claude-compatible-normalized-content", event: ClaudeCompatibleAdapter().hookEvent(
                from: claudeEnvelope(payload: nativePayload())
            )),
            try row(id: "invalid-items-filtered", event: GenericHookAdapter().hookEvent(
                from: genericEnvelope(payload: invalidPayload)
            )),
            try row(id: "unknown-statuses-normalized", event: GenericHookAdapter().hookEvent(
                from: genericEnvelope(payload: unknownStatusPayload)
            )),
            try row(id: "missing-arrays-empty", event: GenericHookAdapter().hookEvent(
                from: genericEnvelope(payload: [
                    "rawEventName": .string("SessionStart"),
                    "sessionId": .string("session-normalized"),
                    "cwd": .string("/tmp/project"),
                ])
            )),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testGenericAdapterPreservesNormalizedTasksAndTodos() throws {
        let event = try GenericHookAdapter().hookEvent(from: genericEnvelope(payload: genericPayload()))

        XCTAssertEqual(event.tasks, [expectedTask])
        XCTAssertEqual(event.todos, [expectedTodo])
    }

    func testCodexAdapterPreservesNormalizedTasksAndTodos() throws {
        let event = try CodexAdapter().hookEvent(from: codexEnvelope(payload: nativePayload()))

        XCTAssertEqual(event.tasks, [expectedTask])
        XCTAssertEqual(event.todos, [expectedTodo])
    }

    func testClaudeCompatibleAdapterPreservesNormalizedTasksAndTodos() throws {
        let event = try ClaudeCompatibleAdapter().hookEvent(from: claudeEnvelope(payload: nativePayload()))

        XCTAssertEqual(event.tasks, [expectedTask])
        XCTAssertEqual(event.todos, [expectedTodo])
    }

    func testInvalidNormalizedContentItemsAreIgnored() throws {
        var payload = genericPayload()
        payload["tasks"] = .array([
            taskValue,
            .object(["id": .string("missing-subject")]),
            .object(["subject": .string("missing id")]),
            .string("not an object"),
        ])
        payload["todos"] = .array([
            todoValue,
            .object(["id": .string("missing-content")]),
            .object(["content": .string("missing id")]),
            .number(1),
        ])

        let event = try GenericHookAdapter().hookEvent(from: genericEnvelope(payload: payload))

        XCTAssertEqual(event.tasks, [expectedTask])
        XCTAssertEqual(event.todos, [expectedTodo])
    }

    func testUnknownStatusesMapToUnknown() throws {
        var payload = genericPayload()
        payload["tasks"] = .array([
            .object([
                "id": .string("task-unknown"),
                "subject": .string("Unknown task status"),
                "status": .string("waiting-for-provider"),
            ]),
        ])
        payload["todos"] = .array([
            .object([
                "id": .string("todo-unknown"),
                "content": .string("Unknown todo status"),
                "status": .string("waiting-for-provider"),
            ]),
        ])

        let event = try GenericHookAdapter().hookEvent(from: genericEnvelope(payload: payload))

        XCTAssertEqual(event.tasks.first?.status, .unknown)
        XCTAssertEqual(event.todos.first?.status, .unknown)
    }

    func testHookEventAgentEventsExpandsPrimaryEventBeforeContentEvents() {
        let hook = HookEvent(
            rawEventName: "SessionStart",
            source: "codex",
            sessionId: "session-normalized",
            cwd: "/tmp/project",
            tasks: [expectedTask],
            todos: [expectedTodo]
        )

        XCTAssertEqual(hook.agentEvents(), [
            .sessionStarted(source: "codex", sessionId: "session-normalized", cwd: "/tmp/project"),
            .taskUpdated(source: "codex", sessionId: "session-normalized", task: expectedTask),
            .todoUpdated(source: "codex", sessionId: "session-normalized", todo: expectedTodo),
        ])
    }

    func testHookEventAgentEventsDoesNotCreatePermissionPrimaryEventWithoutRequestId() {
        let hook = HookEvent(
            rawEventName: "PermissionRequest",
            source: "codex",
            sessionId: "session-normalized",
            cwd: "/tmp/project",
            toolName: "Shell",
            tasks: [expectedTask],
            todos: [expectedTodo]
        )

        XCTAssertEqual(hook.agentEvents(), [
            .taskUpdated(source: "codex", sessionId: "session-normalized", task: expectedTask),
            .todoUpdated(source: "codex", sessionId: "session-normalized", todo: expectedTodo),
        ])
    }

    private var expectedTask: TaskItem {
        TaskItem(
            id: "task-1",
            subject: "Implement normalized content",
            description: "Route bridge content into session state",
            status: .active,
            activeForm: "Implementing",
            blockedBy: "fixture blocker",
            owner: "codex"
        )
    }

    private var expectedTodo: TodoItem {
        TodoItem(
            id: "todo-1",
            content: "Write RED tests",
            status: .pending,
            activeForm: "Writing"
        )
    }

    private var taskValue: BridgeJSONValue {
        .object([
            "id": .string("task-1"),
            "subject": .string("Implement normalized content"),
            "description": .string("Route bridge content into session state"),
            "status": .string("active"),
            "activeForm": .string("Implementing"),
            "blockedBy": .string("fixture blocker"),
            "owner": .string("codex"),
        ])
    }

    private var todoValue: BridgeJSONValue {
        .object([
            "id": .string("todo-1"),
            "content": .string("Write RED tests"),
            "status": .string("pending"),
            "activeForm": .string("Writing"),
        ])
    }

    private func genericPayload() -> [String: BridgeJSONValue] {
        [
            "rawEventName": .string("SessionStart"),
            "sessionId": .string("session-normalized"),
            "cwd": .string("/tmp/project"),
            "tasks": .array([taskValue]),
            "todos": .array([todoValue]),
        ]
    }

    private func nativePayload() -> [String: BridgeJSONValue] {
        [
            "hook_event_name": .string("SessionStart"),
            "session_id": .string("session-normalized"),
            "cwd": .string("/tmp/project"),
            "tasks": .array([taskValue]),
            "todos": .array([todoValue]),
        ]
    }

    private func genericEnvelope(payload: [String: BridgeJSONValue]) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: payload
        )
    }

    private func codexEnvelope(payload: [String: BridgeJSONValue]) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: nil,
            command: .hookEvent,
            payload: payload
        )
    }

    private func claudeEnvelope(payload: [String: BridgeJSONValue]) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "claude",
            requestId: nil,
            command: .hookEvent,
            payload: payload
        )
    }

    private func row(
        id: String,
        event: HookEvent
    ) -> NormalizedSessionContentPayloadMatrixRow {
        NormalizedSessionContentPayloadMatrixRow(
            id: id,
            source: event.source,
            rawEventName: event.rawEventName,
            sessionId: event.sessionId,
            taskIds: event.tasks.map(\.id),
            taskSubjects: event.tasks.map(\.subject),
            taskStatuses: event.tasks.map(\.status.rawValue),
            taskOwners: event.tasks.map(\.owner),
            todoIds: event.todos.map(\.id),
            todoContents: event.todos.map(\.content),
            todoStatuses: event.todos.map(\.status.rawValue),
            agentEventKinds: event.agentEvents().map(agentEventKind)
        )
    }

    private func agentEventKind(_ event: AgentEvent) -> String {
        switch event {
        case .sessionStarted:
            "sessionStarted"
        case .sessionEnded:
            "sessionEnded"
        case .sessionActivityUpdated:
            "sessionActivityUpdated"
        case .permissionRequested:
            "permissionRequested"
        case .questionAsked:
            "questionAsked"
        case .messageReceived:
            "messageReceived"
        case .taskUpdated:
            "taskUpdated"
        case .todoUpdated:
            "todoUpdated"
        case .teamGroupingUpdated:
            "teamGroupingUpdated"
        case .jumpTargetUpdated:
            "jumpTargetUpdated"
        case .subagentLifecycleUpdated:
            "subagentLifecycleUpdated"
        case .actionResolved:
            "actionResolved"
        }
    }

    private struct NormalizedSessionContentPayloadMatrixFixture: Codable, Equatable {
        let rows: [NormalizedSessionContentPayloadMatrixRow]
    }

    private struct NormalizedSessionContentPayloadMatrixRow: Codable, Equatable {
        let id: String
        let source: String
        let rawEventName: String
        let sessionId: String
        let taskIds: [String]
        let taskSubjects: [String]
        let taskStatuses: [String]
        let taskOwners: [String?]
        let todoIds: [String]
        let todoContents: [String]
        let todoStatuses: [String]
        let agentEventKinds: [String]
    }
}
