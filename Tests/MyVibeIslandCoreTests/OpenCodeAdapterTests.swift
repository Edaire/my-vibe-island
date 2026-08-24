import XCTest
@testable import MyVibeIslandCore

final class OpenCodeAdapterTests: XCTestCase {
    func testOpenCodeAdapterMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OpenCodeAdapterMatrixFixture.self,
            from: try FixtureLoader.data("opencode/adapter-matrix")
        )
        let adapter = OpenCodeAdapter()

        let actual = OpenCodeAdapterMatrixFixture(rows: [
            row(id: "fixture-permission", event: try adapter.hookEvent(from: opencodeEnvelope(
                payload: try FixtureLoader.bridgePayload("opencode/hook-permission-request")
            ))),
            row(id: "fixture-question", event: try adapter.hookEvent(from: opencodeEnvelope(
                payload: try FixtureLoader.bridgePayload("opencode/hook-question-request")
            ))),
            row(id: "generic-fallback", event: try adapter.hookEvent(from: opencodeEnvelope(payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("generic-opencode-session"),
                "cwd": .string("/tmp/opencode"),
            ]))),
            row(id: "registry-permission", event: try AgentAdapterRegistry.default.hookEvent(from: opencodeEnvelope(payload: [
                "event": .string("permission"),
                "id": .string("perm-1"),
                "sessionID": .string("opencode-session"),
            ]))),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testHookFixturesNormalizePermissionAndQuestionRequests() throws {
        let permission = try OpenCodeAdapter().hookEvent(from: opencodeEnvelope(
            payload: try FixtureLoader.bridgePayload("opencode/hook-permission-request")
        ))
        let question = try OpenCodeAdapter().hookEvent(from: opencodeEnvelope(
            payload: try FixtureLoader.bridgePayload("opencode/hook-question-request")
        ))

        XCTAssertEqual(permission.rawEventName, "PermissionRequest")
        XCTAssertEqual(permission.source, "opencode")
        XCTAssertEqual(permission.sessionId, "opencode-session")
        XCTAssertEqual(permission.requestId, "perm-fixture-1")
        XCTAssertEqual(permission.cwd, "/tmp/opencode")
        XCTAssertEqual(permission.toolName, "bash")

        XCTAssertEqual(question.rawEventName, "QuestionRequest")
        XCTAssertEqual(question.source, "opencode")
        XCTAssertEqual(question.sessionId, "opencode-session")
        XCTAssertEqual(question.requestId, "question-fixture-1")
        XCTAssertEqual(question.cwd, "/tmp/opencode")
        XCTAssertEqual(question.toolName, "Question")
    }

    func testPermissionPayloadNormalizesToPermissionRequest() throws {
        let event = try OpenCodeAdapter().hookEvent(from: opencodeEnvelope(payload: [
            "event": .string("permission"),
            "id": .string("perm-1"),
            "sessionID": .string("opencode-session"),
            "permission": .string("bash"),
        ]))

        XCTAssertEqual(event.rawEventName, "PermissionRequest")
        XCTAssertEqual(event.source, "opencode")
        XCTAssertEqual(event.sessionId, "opencode-session")
        XCTAssertEqual(event.requestId, "perm-1")
        XCTAssertEqual(event.toolName, "bash")
    }

    func testQuestionPayloadNormalizesToQuestionRequest() throws {
        let event = try OpenCodeAdapter().hookEvent(from: opencodeEnvelope(payload: [
            "event": .string("question"),
            "id": .string("question-1"),
            "sessionID": .string("opencode-session"),
        ]))

        XCTAssertEqual(event.rawEventName, "QuestionRequest")
        XCTAssertEqual(event.source, "opencode")
        XCTAssertEqual(event.sessionId, "opencode-session")
        XCTAssertEqual(event.requestId, "question-1")
        XCTAssertEqual(event.toolName, "Question")
    }

    func testPermissionPayloadWithoutStableIdThrowsInvalidPayload() {
        XCTAssertThrowsError(try OpenCodeAdapter().hookEvent(from: opencodeEnvelope(payload: [
            "event": .string("permission"),
            "sessionID": .string("opencode-session"),
        ]))) { error in
            XCTAssertEqual(error as? AgentAdapterError, .invalidHookPayload)
        }
    }

    func testGenericCompatibilityPayloadFallsBackToGenericAdapter() throws {
        let event = try OpenCodeAdapter().hookEvent(from: opencodeEnvelope(payload: [
            "rawEventName": .string("SessionStart"),
            "sessionId": .string("generic-opencode-session"),
            "cwd": .string("/tmp/opencode"),
        ]))

        XCTAssertEqual(event.rawEventName, "SessionStart")
        XCTAssertEqual(event.sessionId, "generic-opencode-session")
        XCTAssertEqual(event.cwd, "/tmp/opencode")
    }

    func testDefaultRegistryUsesOpenCodeAdapterForOpenCodeSource() throws {
        let event = try AgentAdapterRegistry.default.hookEvent(from: opencodeEnvelope(payload: [
            "event": .string("permission"),
            "id": .string("perm-1"),
            "sessionID": .string("opencode-session"),
        ]))

        XCTAssertEqual(event.rawEventName, "PermissionRequest")
        XCTAssertEqual(event.source, "opencode")
        XCTAssertEqual(event.requestId, "perm-1")
    }

    private func opencodeEnvelope(payload: [String: BridgeJSONValue]) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "opencode",
            requestId: nil,
            command: .hookEvent,
            payload: payload
        )
    }

    private func row(id: String, event: HookEvent) -> OpenCodeAdapterRowFixture {
        OpenCodeAdapterRowFixture(
            id: id,
            rawEventName: event.rawEventName,
            source: event.source,
            sessionId: event.sessionId,
            requestId: event.requestId,
            cwd: event.cwd,
            toolName: event.toolName,
            messagePresent: event.message != nil,
            taskCount: event.tasks.count,
            todoCount: event.todos.count
        )
    }

    private struct OpenCodeAdapterMatrixFixture: Codable, Equatable {
        let rows: [OpenCodeAdapterRowFixture]
    }

    private struct OpenCodeAdapterRowFixture: Codable, Equatable {
        let id: String
        let rawEventName: String
        let source: String
        let sessionId: String
        let requestId: String?
        let cwd: String?
        let toolName: String?
        let messagePresent: Bool
        let taskCount: Int
        let todoCount: Int
    }
}
