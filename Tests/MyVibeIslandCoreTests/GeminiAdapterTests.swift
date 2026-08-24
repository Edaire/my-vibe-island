import XCTest
@testable import MyVibeIslandCore

final class GeminiAdapterTests: XCTestCase {
    func testNativeSessionStartFixtureNormalizesToSessionStart() throws {
        let event = try GeminiAdapter().hookEvent(from: envelope(
            payload: try FixtureLoader.bridgePayload("gemini/hook-session-start")
        ))

        XCTAssertEqual(event.rawEventName, "SessionStart")
        XCTAssertEqual(event.source, "gemini")
        XCTAssertEqual(event.sessionId, "gemini-session-1")
        XCTAssertEqual(event.cwd, "/tmp/gemini-project")
    }

    func testGeminiEventsAreFireAndForget() throws {
        let event = try GeminiAdapter().hookEvent(from: envelope(
            payload: try FixtureLoader.bridgePayload("gemini/hook-after-agent")
        ))
        let request = ActionableRequest(
            requestId: "ignored",
            sessionId: event.sessionId,
            source: "gemini",
            kind: .permission,
            toolName: "Shell"
        )

        XCTAssertEqual(event.rawEventName, "Stop")
        XCTAssertEqual(event.message, "Implemented the bridge protocol.")
        XCTAssertEqual(GeminiAdapter().directive(
            for: request,
            resolution: ActionResolution(requestId: request.requestId, sessionId: request.sessionId, kind: .approve)
        ), .none)
        XCTAssertNil(GeminiAdapter().blockingTimeout(for: request))
    }

    func testRegisteredGeminiSourceRejectsGenericCompatibilityPayload() {
        let generic = envelope(payload: [
            "rawEventName": .string("SessionStart"),
            "sessionId": .string("generic-gemini"),
            "cwd": .string("/tmp/generic-gemini"),
        ])

        XCTAssertThrowsError(try AgentAdapterRegistry.default.hookEvent(from: generic)) { error in
            XCTAssertEqual(error as? AgentAdapterError, .invalidHookPayload)
        }
    }

    func testKimiAcceptsOnlyFixtureProvenClaudeShapedPayload() throws {
        let native = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "kimi",
            requestId: nil,
            command: .hookEvent,
            payload: try FixtureLoader.bridgePayload("kimi/hook-session-start")
        )
        let generic = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "kimi",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("SessionStart"),
                "sessionId": .string("generic-kimi"),
                "cwd": .string("/tmp/generic-kimi"),
            ]
        )

        XCTAssertEqual(try AgentAdapterRegistry.default.hookEvent(from: native).sessionId, "kimi-session-1")
        XCTAssertThrowsError(try AgentAdapterRegistry.default.hookEvent(from: generic)) { error in
            XCTAssertEqual(error as? AgentAdapterError, .invalidHookPayload)
        }
    }

    func testKimiRejectsUnverifiedClaudeShapedEventsAndNeverBlocks() throws {
        let adapter = ClaudeCompatibleAdapter()
        let request = ActionableRequest(
            requestId: "kimi-request",
            sessionId: "kimi-session-1",
            source: "kimi",
            kind: .permission,
            toolName: "Shell"
        )

        for eventName in ["PreToolUse", "PermissionRequest", "Stop"] {
            var payload = try FixtureLoader.bridgePayload("kimi/hook-session-start")
            payload["hook_event_name"] = .string(eventName)
            payload["tool_use_id"] = .string("kimi-request")
            XCTAssertThrowsError(try adapter.hookEvent(from: BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: "kimi",
                requestId: nil,
                command: .hookEvent,
                payload: payload
            )), eventName) { error in
                XCTAssertEqual(error as? AgentAdapterError, .invalidHookPayload)
            }
        }

        XCTAssertEqual(adapter.directive(
            for: request,
            resolution: ActionResolution(requestId: request.requestId, sessionId: request.sessionId, kind: .approve)
        ), .none)
        XCTAssertNil(adapter.blockingTimeout(for: request))
    }

    private func envelope(payload: [String: BridgeJSONValue]) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "gemini",
            requestId: nil,
            command: .hookEvent,
            payload: payload
        )
    }
}
