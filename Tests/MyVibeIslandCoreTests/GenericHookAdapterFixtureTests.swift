import XCTest
@testable import MyVibeIslandCore

final class GenericHookAdapterFixtureTests: XCTestCase {
    func testGenericHookAdapterMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            GenericHookAdapterMatrixFixture.self,
            from: try FixtureLoader.data("generic/adapter-matrix")
        )
        let adapter = GenericHookAdapter()
        let environment = HookEnvironment(cwd: "/tmp/project", shell: "zsh", terminal: "Terminal.app", pid: 64, user: "fixture-user")

        let actual = GenericHookAdapterMatrixFixture(rows: [
            row(id: "permission", event: try adapter.hookEvent(from: envelope(
                payload: try FixtureLoader.bridgePayload("generic/hook-permission-request")
            ))),
            row(id: "question", event: try adapter.hookEvent(from: envelope(
                payload: try FixtureLoader.bridgePayload("generic/hook-question-request")
            ))),
            row(id: "stop-content", event: try adapter.hookEvent(from: envelope(
                payload: try FixtureLoader.bridgePayload("generic/hook-stop-with-content")
            ))),
            row(id: "envelope-request-id", event: try adapter.hookEvent(from: envelope(
                requestId: "req-envelope",
                payload: try FixtureLoader.bridgePayload("generic/hook-permission-request")
            ))),
            row(id: "environment", event: try adapter.hookEvent(from: envelope(
                payload: try FixtureLoader.bridgePayload("generic/hook-question-request"),
                environment: environment
            ))),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testGenericFixturesNormalizeCommonHookEvents() throws {
        let cases: [GenericHookCase] = [
            GenericHookCase(
                fixture: "generic/hook-permission-request",
                expectedRawEventName: "PermissionRequest",
                expectedSessionId: "generic-session",
                expectedRequestId: "generic-permission-1",
                expectedToolName: "Shell",
                expectedTaskCount: 0,
                expectedTodoCount: 0
            ),
            GenericHookCase(
                fixture: "generic/hook-question-request",
                expectedRawEventName: "QuestionRequest",
                expectedSessionId: "generic-session",
                expectedRequestId: "generic-question-1",
                expectedToolName: "Question",
                expectedTaskCount: 0,
                expectedTodoCount: 0
            ),
            GenericHookCase(
                fixture: "generic/hook-stop-with-content",
                expectedRawEventName: "Stop",
                expectedSessionId: "generic-session",
                expectedRequestId: nil,
                expectedToolName: nil,
                expectedTaskCount: 1,
                expectedTodoCount: 1
            ),
        ]

        for testCase in cases {
            let event = try GenericHookAdapter().hookEvent(from: envelope(
                payload: try FixtureLoader.bridgePayload(testCase.fixture)
            ))

            XCTAssertEqual(event.rawEventName, testCase.expectedRawEventName, testCase.fixture)
            XCTAssertEqual(event.source, "gemini", testCase.fixture)
            XCTAssertEqual(event.sessionId, testCase.expectedSessionId, testCase.fixture)
            XCTAssertEqual(event.requestId, testCase.expectedRequestId, testCase.fixture)
            XCTAssertEqual(event.cwd, "/tmp/generic-agent", testCase.fixture)
            XCTAssertEqual(event.toolName, testCase.expectedToolName, testCase.fixture)
            XCTAssertEqual(event.tasks.count, testCase.expectedTaskCount, testCase.fixture)
            XCTAssertEqual(event.todos.count, testCase.expectedTodoCount, testCase.fixture)
        }
    }

    private struct GenericHookCase {
        let fixture: String
        let expectedRawEventName: String
        let expectedSessionId: String
        let expectedRequestId: String?
        let expectedToolName: String?
        let expectedTaskCount: Int
        let expectedTodoCount: Int
    }

    private func envelope(
        requestId: String? = nil,
        payload: [String: BridgeJSONValue],
        environment: HookEnvironment? = nil
    ) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "gemini",
            requestId: requestId,
            command: .hookEvent,
            payload: payload,
            environment: environment
        )
    }

    private func row(id: String, event: HookEvent) -> GenericHookAdapterRowFixture {
        GenericHookAdapterRowFixture(
            id: id,
            rawEventName: event.rawEventName,
            source: event.source,
            sessionId: event.sessionId,
            requestId: event.requestId,
            cwd: event.cwd,
            toolName: event.toolName,
            message: event.message,
            hasEnvironment: event.environment != nil,
            taskCount: event.tasks.count,
            todoCount: event.todos.count
        )
    }

    private struct GenericHookAdapterMatrixFixture: Codable, Equatable {
        let rows: [GenericHookAdapterRowFixture]
    }

    private struct GenericHookAdapterRowFixture: Codable, Equatable {
        let id: String
        let rawEventName: String
        let source: String
        let sessionId: String
        let requestId: String?
        let cwd: String?
        let toolName: String?
        let message: String?
        let hasEnvironment: Bool
        let taskCount: Int
        let todoCount: Int
    }
}
