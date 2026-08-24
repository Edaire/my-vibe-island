import XCTest
@testable import MyVibeIslandCore

final class ConversationParserTests: XCTestCase {
    func testConversationParserMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ConversationParserMatrixFixture.self,
            from: try FixtureLoader.data("runtime/conversation-parser-matrix")
        )
        let parser = ConversationParser()

        let actual = ConversationParserMatrixFixture(rows: [
            ConversationParserMatrixRow(
                id: "safe-structured-metadata",
                result: parser.parse(request(metadata: safeMetadata()))
            ),
            ConversationParserMatrixRow(
                id: "sensitive-raw-fields-ignored",
                result: parser.parse(request(metadata: sensitiveMetadata()))
            ),
            ConversationParserMatrixRow(
                id: "invalid-source-fails-redacted",
                result: parser.parse(ConversationParseRequest(
                    source: "",
                    sessionId: "conversation-session",
                    metadata: sensitiveMetadata(),
                    readScope: .metadataOnly
                ))
            ),
            ConversationParserMatrixRow(
                id: "invalid-session-fails-redacted",
                result: parser.parse(ConversationParseRequest(
                    source: "codex",
                    sessionId: "",
                    metadata: sensitiveMetadata(),
                    readScope: .metadataOnly
                ))
            ),
            ConversationParserMatrixRow(
                id: "raw-transcript-does-not-create-work-items",
                result: parser.parse(request(metadata: [
                    "rawTranscript": .string("Task: ship all features\nTODO: leak this line"),
                    "transcript": .string("todo-raw-transcript"),
                    "content": .string("Implement from raw content"),
                ]))
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    func testMetadataOnlyParserExtractsSafeStructuredMetadata() {
        let parser = ConversationParser()
        let result = parser.parse(request(metadata: safeMetadata()))

        XCTAssertEqual(result, .parsed(ConversationParseSnapshot(
            source: "codex",
            sessionId: "conversation-session",
            title: "Structured title",
            statusSummary: "2 active tasks",
            tasks: [expectedTask],
            todos: [expectedTodo],
            redactionLevel: .metadataOnly
        )))
    }

    func testMetadataOnlyParserIgnoresRawTextFields() {
        let parser = ConversationParser()
        let result = parser.parse(request(metadata: sensitiveMetadata()))

        XCTAssertEqual(result, .parsed(ConversationParseSnapshot(
            source: "codex",
            sessionId: "conversation-session",
            title: nil,
            statusSummary: nil,
            tasks: [],
            todos: [],
            redactionLevel: .metadataOnly
        )))
    }

    func testMetadataOnlyParserReportsMetadataOnlyRedactionLevel() {
        let parser = ConversationParser()
        let result = parser.parse(request(metadata: safeMetadata()))

        guard case let .parsed(snapshot) = result else {
            return XCTFail("Expected parsed snapshot")
        }

        XCTAssertEqual(snapshot.redactionLevel, .metadataOnly)
    }

    func testInvalidIdentityReturnsRedactedFailure() {
        let parser = ConversationParser()
        let result = parser.parse(ConversationParseRequest(
            source: "",
            sessionId: "conversation-session",
            metadata: sensitiveMetadata(),
            readScope: .metadataOnly
        ))

        XCTAssertEqual(result, .failed(ConversationParseFailure(
            kind: .invalidIdentity,
            redactedMessage: "invalid conversation metadata",
            redactionLevel: .metadataOnly
        )))
    }

    func testRedactedFailureDoesNotIncludeSensitiveMetadataText() {
        let parser = ConversationParser()
        let secret = "SECRET_PROMPT_SHOULD_NOT_APPEAR"
        var metadata = sensitiveMetadata()
        metadata["prompt"] = .string(secret)

        let result = parser.parse(ConversationParseRequest(
            source: "codex",
            sessionId: "",
            metadata: metadata,
            readScope: .metadataOnly
        ))

        guard case let .failed(failure) = result else {
            return XCTFail("Expected redacted failure")
        }

        XCTAssertFalse(failure.redactedMessage.contains(secret))
        XCTAssertFalse(String(describing: failure).contains(secret))
    }

    func testRawTranscriptFieldsDoNotCreateTasksOrTodos() {
        let parser = ConversationParser()
        let result = parser.parse(request(metadata: [
            "rawTranscript": .string("Task: ship all features\nTODO: leak this line"),
            "transcript": .string("todo-raw-transcript"),
            "content": .string("Implement from raw content"),
        ]))

        guard case let .parsed(snapshot) = result else {
            return XCTFail("Expected parsed snapshot")
        }

        XCTAssertEqual(snapshot.tasks, [])
        XCTAssertEqual(snapshot.todos, [])
    }

    private var expectedTask: TaskItem {
        TaskItem(id: "task-1", subject: "Read metadata", status: .active)
    }

    private var expectedTodo: TodoItem {
        TodoItem(id: "todo-1", content: "Keep parser metadata-only", status: .pending)
    }

    private func request(metadata: [String: BridgeJSONValue]) -> ConversationParseRequest {
        ConversationParseRequest(
            source: "codex",
            sessionId: "conversation-session",
            metadata: metadata,
            readScope: .metadataOnly
        )
    }

    private func safeMetadata() -> [String: BridgeJSONValue] {
        [
            "title": .string("Structured title"),
            "statusSummary": .string("2 active tasks"),
            "tasks": .array([
                .object([
                    "id": .string("task-1"),
                    "subject": .string("Read metadata"),
                    "status": .string("active"),
                ]),
            ]),
            "todos": .array([
                .object([
                    "id": .string("todo-1"),
                    "content": .string("Keep parser metadata-only"),
                    "status": .string("pending"),
                ]),
            ]),
        ]
    }

    private func sensitiveMetadata() -> [String: BridgeJSONValue] {
        [
            "prompt": .string("raw prompt body"),
            "message": .string("assistant message body"),
            "content": .string("raw content body"),
            "transcript": .string("full transcript line"),
            "rawTranscript": .string("raw transcript body"),
            "toolInput": .string("tool input body"),
            "toolOutput": .string("tool output body"),
            "sourceCode": .string("source code body"),
        ]
    }
}

private struct ConversationParserMatrixFixture: Codable, Equatable {
    let rows: [ConversationParserMatrixRow]
}

private struct ConversationParserMatrixRow: Codable, Equatable {
    let id: String
    let outcome: String
    let source: String?
    let sessionId: String?
    let title: String?
    let statusSummary: String?
    let taskIds: [String]
    let todoIds: [String]
    let failureKind: ConversationParseFailureKind?
    let redactedMessage: String?
    let redactionLevel: RedactionLevel

    init(id: String, result: ConversationParseResult) {
        self.id = id
        switch result {
        case let .parsed(snapshot):
            outcome = "parsed"
            source = snapshot.source
            sessionId = snapshot.sessionId
            title = snapshot.title
            statusSummary = snapshot.statusSummary
            taskIds = snapshot.tasks.map(\.id)
            todoIds = snapshot.todos.map(\.id)
            failureKind = nil
            redactedMessage = nil
            redactionLevel = snapshot.redactionLevel
        case let .failed(failure):
            outcome = "failed"
            source = nil
            sessionId = nil
            title = nil
            statusSummary = nil
            taskIds = []
            todoIds = []
            failureKind = failure.kind
            redactedMessage = failure.redactedMessage
            redactionLevel = failure.redactionLevel
        }
    }
}
