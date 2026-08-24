import XCTest
@testable import MyVibeIslandCore

final class AgentAdapterRegistryTests: XCTestCase {
    private struct AdapterRoutingFixture: Decodable {
        let source: String
        let payloadFixture: String
        let expectedRawEventName: String
        let expectedSessionId: String
    }

    func testDefaultAdapterRoutingMatchesFixtureSnapshot() throws {
        let fixtures = try JSONDecoder().decode(
            [AdapterRoutingFixture].self,
            from: try FixtureLoader.data("agents/default-adapter-routing")
        )

        for fixture in fixtures {
            let envelope = BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: fixture.source,
                requestId: nil,
                command: .hookEvent,
                payload: try FixtureLoader.bridgePayload(fixture.payloadFixture)
            )

            let event = try AgentAdapterRegistry.default.hookEvent(from: envelope)

            XCTAssertEqual(event.source, fixture.source)
            XCTAssertEqual(event.rawEventName, fixture.expectedRawEventName, fixture.source)
            XCTAssertEqual(event.sessionId, fixture.expectedSessionId, fixture.source)
        }
    }

    func testDefaultRegistryUsesCodexAdapterForCodexSource() throws {
        let registry = AgentAdapterRegistry.default
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

        let event = try registry.hookEvent(from: envelope)

        XCTAssertEqual(event.rawEventName, "SessionStart")
        XCTAssertEqual(event.source, "codex")
        XCTAssertEqual(event.sessionId, "codex-session")
        XCTAssertEqual(event.cwd, "/tmp/codex")
        XCTAssertEqual(event.model, "gpt-5")
    }

    func testRegistryFallsBackToGenericAdapterForUnknownSource() throws {
        let registry = AgentAdapterRegistry.default
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "unknown-agent",
            requestId: "req-envelope",
            command: .hookEvent,
            payload: [
                "rawEventName": .string("PermissionRequest"),
                "sessionId": .string("s1"),
                "cwd": .string("/tmp/project"),
                "toolName": .string("Shell"),
            ]
        )

        let event = try registry.hookEvent(from: envelope)

        XCTAssertEqual(event.rawEventName, "PermissionRequest")
        XCTAssertEqual(event.source, "unknown-agent")
        XCTAssertEqual(event.sessionId, "s1")
        XCTAssertEqual(event.requestId, "req-envelope")
        XCTAssertEqual(event.cwd, "/tmp/project")
        XCTAssertEqual(event.toolName, "Shell")
    }

    func testDefaultRegistryUsesClaudeCompatibleAdapterForVerifiedClaudeLikeSources() throws {
        for source in ["claude", "qwen", "qoder", "factory", "codebuddy", "hermes"] {
            let registry = AgentAdapterRegistry.default
            let envelope = BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: source,
                requestId: nil,
                command: .hookEvent,
                payload: try FixtureLoader.bridgePayload("claude/hook-session-start")
            )

            let event = try registry.hookEvent(from: envelope)

            XCTAssertEqual(event.rawEventName, "SessionStart")
            XCTAssertEqual(event.source, source)
            XCTAssertEqual(event.sessionId, "claude-session")
        }
    }

    func testHermesStopPayloadUsesOriginalAssistantResponseField() throws {
        let event = try AgentAdapterRegistry.default.hookEvent(from: BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "hermes",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "hook_event_name": .string("Stop"),
                "session_id": .string("hermes-session"),
                "cwd": .string("/tmp/hermes"),
                "last_assistant_message": .string("Hermes completed the requested task."),
            ]
        ))

        XCTAssertEqual(event.rawEventName, "Stop")
        XCTAssertEqual(event.source, "hermes")
        XCTAssertEqual(event.sessionId, "hermes-session")
        XCTAssertEqual(event.message, "Hermes completed the requested task.")
    }

    func testDefaultRegistryAcceptsOnlyFixtureProvenKimiClaudeShape() throws {
        let registry = AgentAdapterRegistry.default
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

        XCTAssertEqual(try registry.hookEvent(from: native).sessionId, "kimi-session-1")
        XCTAssertThrowsError(try registry.hookEvent(from: generic)) { error in
            XCTAssertEqual(error as? AgentAdapterError, .invalidHookPayload)
        }
    }
}
