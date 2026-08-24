import XCTest
@testable import MyVibeIslandCore

final class WatchEventContentTests: XCTestCase {
    func testWatchEventContentMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            WatchEventContentMatrixFixture.self,
            from: try FixtureLoader.data("runtime/watch-event-content-matrix")
        )

        let actual = WatchEventContentMatrixFixture(rows: [
            WatchEventContentMatrixRow(id: "metadata-content", payload: metadataPayload()),
            WatchEventContentMatrixRow(id: "top-level-content", payload: topLevelPayload()),
            WatchEventContentMatrixRow(id: "missing-session-id", payload: payloadRemoving("sessionId", from: metadataPayload())),
            WatchEventContentMatrixRow(id: "missing-event-kind", payload: payloadRemoving("eventKind", from: metadataPayload())),
            WatchEventContentMatrixRow(
                id: "invalid-content-only",
                payload: [
                    "sessionId": .string("watch-session"),
                    "eventKind": .string("contentUpdated"),
                    "metadata": .object([
                        "tasks": .array([
                            .object(["id": .string("missing-subject")]),
                        ]),
                        "todos": .array([
                            .object(["id": .string("missing-content")]),
                        ]),
                    ]),
                ]
            ),
            WatchEventContentMatrixRow(
                id: "permission-event-content-only",
                payload: payloadMerging(
                    [
                        "eventKind": .string("PermissionRequest"),
                        "requestId": .string("watch-request"),
                        "toolName": .string("Shell"),
                    ],
                    into: metadataPayload()
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testWatchEventMetadataContentUpdatesSessionState() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let response = handler.handle(watchEnvelope(payload: metadataPayload()))

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "watch-session")?.tasks, [expectedTask])
        XCTAssertEqual(coordinator.snapshot(sessionId: "watch-session")?.todos, [expectedTodo])
    }

    func testWatchEventTopLevelContentUpdatesSessionState() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let response = handler.handle(watchEnvelope(payload: topLevelPayload()))

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "watch-session")?.tasks, [expectedTask])
        XCTAssertEqual(coordinator.snapshot(sessionId: "watch-session")?.todos, [expectedTodo])
    }

    func testWatchEventMetadataContentUpdatesSessionPresentation() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let response = handler.handle(watchEnvelope(payload: metadataPayload()))

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.sessionPresentations().first?.taskSummary, "1/1 active tasks")
        XCTAssertEqual(coordinator.sessionPresentations().first?.todoSummary, "1 todos")
    }

    func testWatchEventMissingSessionIdFailsWithoutMutation() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        var payload = metadataPayload()
        payload.removeValue(forKey: "sessionId")

        let response = handler.handle(watchEnvelope(payload: payload))

        XCTAssertEqual(response, .failure(message: "invalid watch payload"))
        XCTAssertEqual(coordinator.snapshots(), [])
    }

    func testWatchEventMissingEventKindFailsWithoutMutation() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        var payload = metadataPayload()
        payload.removeValue(forKey: "eventKind")

        let response = handler.handle(watchEnvelope(payload: payload))

        XCTAssertEqual(response, .failure(message: "invalid watch payload"))
        XCTAssertEqual(coordinator.snapshots(), [])
    }

    func testWatchEventInvalidContentOnlyFailsWithoutMutation() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let payload: [String: BridgeJSONValue] = [
            "sessionId": .string("watch-session"),
            "eventKind": .string("contentUpdated"),
            "metadata": .object([
                "tasks": .array([
                    .object(["id": .string("missing-subject")]),
                ]),
                "todos": .array([
                    .object(["id": .string("missing-content")]),
                ]),
            ]),
        ]

        let response = handler.handle(watchEnvelope(payload: payload))

        XCTAssertEqual(response, .failure(message: "unsupported command"))
        XCTAssertEqual(coordinator.snapshots(), [])
    }

    func testWatchEventCannotCreatePendingPermissionRequest() {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        var payload = metadataPayload()
        payload["eventKind"] = .string("PermissionRequest")
        payload["requestId"] = .string("watch-request")
        payload["toolName"] = .string("Shell")

        let response = handler.handle(watchEnvelope(payload: payload))

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "watch-session")?.pendingRequestIds, [])
    }

    private var expectedTask: TaskItem {
        TaskItem(id: "watch-task", subject: "Read watcher content", status: .active)
    }

    private var expectedTodo: TodoItem {
        TodoItem(id: "watch-todo", content: "Render watcher state", status: .pending)
    }

    private func metadataPayload() -> [String: BridgeJSONValue] {
        [
            "watcherId": .string("codex-session-watcher"),
            "sessionId": .string("watch-session"),
            "eventKind": .string("contentUpdated"),
            "metadata": .object(normalizedContent()),
        ]
    }

    private func topLevelPayload() -> [String: BridgeJSONValue] {
        [
            "watcherId": .string("codex-session-watcher"),
            "sessionId": .string("watch-session"),
            "eventKind": .string("contentUpdated"),
            "tasks": normalizedContent()["tasks"] ?? .array([]),
            "todos": normalizedContent()["todos"] ?? .array([]),
        ]
    }

    private func normalizedContent() -> [String: BridgeJSONValue] {
        [
            "tasks": .array([
                .object([
                    "id": .string("watch-task"),
                    "subject": .string("Read watcher content"),
                    "status": .string("active"),
                ]),
            ]),
            "todos": .array([
                .object([
                    "id": .string("watch-todo"),
                    "content": .string("Render watcher state"),
                    "status": .string("pending"),
                ]),
            ]),
        ]
    }

    private func watchEnvelope(payload: [String: BridgeJSONValue]) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "watcher",
            source: "codex",
            requestId: nil,
            command: .watchEvent,
            payload: payload
        )
    }
}

private struct WatchEventContentMatrixFixture: Codable, Equatable {
    let rows: [WatchEventContentMatrixRow]
}

private struct WatchEventContentMatrixRow: Codable, Equatable {
    let id: String
    let responseOK: Bool
    let responseMessage: String?
    let sessionIds: [String]
    let taskSummaries: [String]
    let todoSummaries: [String]
    let pendingRequestIds: [String]
    let presentationTaskSummary: String?
    let presentationTodoSummary: String?

    init(id: String, payload: [String: BridgeJSONValue]) {
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)
        let response = handler.handle(Self.watchEnvelope(payload: payload))
        let snapshots = coordinator.snapshots()
        let firstSnapshot = snapshots.first
        let firstPresentation = coordinator.sessionPresentations().first

        self.id = id
        self.responseOK = response.ok
        self.responseMessage = response.message
        self.sessionIds = snapshots.map(\.sessionId)
        self.taskSummaries = (firstSnapshot?.tasks ?? []).map { "\($0.id):\($0.subject):\($0.status.rawValue)" }
        self.todoSummaries = (firstSnapshot?.todos ?? []).map { "\($0.id):\($0.content):\($0.status.rawValue)" }
        self.pendingRequestIds = firstSnapshot?.pendingRequestIds ?? []
        self.presentationTaskSummary = firstPresentation?.taskSummary
        self.presentationTodoSummary = firstPresentation?.todoSummary
    }

    private static func watchEnvelope(payload: [String: BridgeJSONValue]) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "watcher",
            source: "codex",
            requestId: nil,
            command: .watchEvent,
            payload: payload
        )
    }
}

private func payloadRemoving(
    _ key: String,
    from payload: [String: BridgeJSONValue]
) -> [String: BridgeJSONValue] {
    var payload = payload
    payload.removeValue(forKey: key)
    return payload
}

private func payloadMerging(
    _ update: [String: BridgeJSONValue],
    into payload: [String: BridgeJSONValue]
) -> [String: BridgeJSONValue] {
    var payload = payload
    for (key, value) in update {
        payload[key] = value
    }
    return payload
}
