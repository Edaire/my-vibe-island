import XCTest
@testable import MyVibeIslandCore

final class CursorAdapterTests: XCTestCase {
    func testNativeBeforeShellExecutionFixtureNormalizesToBlockingPermission() throws {
        let event = try CursorAdapter().hookEvent(from: envelope(
            payload: try FixtureLoader.bridgePayload("cursor/hook-before-shell-execution")
        ))

        XCTAssertEqual(event.rawEventName, "PermissionRequest")
        XCTAssertEqual(event.source, "cursor")
        XCTAssertEqual(event.sessionId, "cursor-conversation-1")
        XCTAssertEqual(event.requestId, "cursor-generation-1")
        XCTAssertEqual(event.cwd, "/tmp/cursor-project")
        XCTAssertEqual(event.model, "cursor-small")
        XCTAssertEqual(event.toolName, "Shell")
        XCTAssertEqual(event.message, "swift test")
    }

    func testCursorPermissionDirectiveUsesCursorNativeShape() {
        let request = ActionableRequest(
            requestId: "cursor-generation-1",
            sessionId: "cursor-conversation-1",
            source: "cursor",
            kind: .permission,
            toolName: "Shell"
        )

        XCTAssertEqual(CursorAdapter().directive(
            for: request,
            resolution: ActionResolution(requestId: request.requestId, sessionId: request.sessionId, kind: .deny)
        ), .json(.object([
            "continue": .bool(true),
            "permission": .string("deny"),
            "agentMessage": .string("User denied the permission request"),
        ])))
        XCTAssertNotNil(CursorAdapter().blockingTimeout(for: request))
    }

    func testNativeBeforeMCPExecutionFixtureSupportsAllowAndDeny() throws {
        let adapter = CursorAdapter()
        let event = try adapter.hookEvent(from: envelope(
            payload: try FixtureLoader.bridgePayload("cursor/hook-before-mcp-execution")
        ))
        let request = ActionableRequest(
            requestId: try XCTUnwrap(event.requestId),
            sessionId: event.sessionId,
            source: event.source,
            kind: .permission,
            toolName: try XCTUnwrap(event.toolName)
        )

        XCTAssertEqual(event.rawEventName, "PermissionRequest")
        XCTAssertEqual(event.toolName, "write_file")
        XCTAssertEqual(adapter.directive(
            for: request,
            resolution: ActionResolution(requestId: request.requestId, sessionId: request.sessionId, kind: .approve)
        ), .json(.object([
            "continue": .bool(true),
            "permission": .string("allow"),
        ])))
        XCTAssertEqual(adapter.directive(
            for: request,
            resolution: ActionResolution(requestId: request.requestId, sessionId: request.sessionId, kind: .deny)
        ), .json(.object([
            "continue": .bool(true),
            "permission": .string("deny"),
            "agentMessage": .string("User denied the permission request"),
        ])))
    }

    func testCursorApproveAlwaysFailsClosed() {
        let request = ActionableRequest(
            requestId: "cursor-generation-1",
            sessionId: "cursor-conversation-1",
            source: "cursor",
            kind: .permission,
            toolName: "Shell"
        )

        XCTAssertEqual(CursorAdapter().directive(
            for: request,
            resolution: ActionResolution(requestId: request.requestId, sessionId: request.sessionId, kind: .approveAlways)
        ), .none)
    }

    func testNativeNonblockingFixturesUseAllowlistedEventsWithoutRequestIds() throws {
        let adapter = CursorAdapter()
        let rows = [
            ("cursor/hook-before-submit-prompt", "SessionStart"),
            ("cursor/hook-stop", "Stop"),
            ("cursor/hook-after-file-edit", "afterFileEdit"),
        ]

        for (fixture, expectedEventName) in rows {
            let event = try adapter.hookEvent(from: envelope(
                payload: try FixtureLoader.bridgePayload(fixture)
            ))
            XCTAssertEqual(event.rawEventName, expectedEventName, fixture)
            XCTAssertNil(event.requestId, fixture)
        }
    }

    func testUnknownNativeCursorEventFailsClosed() throws {
        var payload = try FixtureLoader.bridgePayload("cursor/hook-before-submit-prompt")
        payload["hook_event_name"] = .string("futureUnknownEvent")

        XCTAssertThrowsError(try CursorAdapter().hookEvent(from: envelope(payload: payload))) { error in
            XCTAssertEqual(error as? AgentAdapterError, .invalidHookPayload)
        }
    }

    func testRegisteredCursorSourceRejectsGenericCompatibilityPayload() {
        let generic = envelope(payload: [
            "rawEventName": .string("SessionStart"),
            "sessionId": .string("generic-cursor"),
            "cwd": .string("/tmp/generic-cursor"),
        ])

        XCTAssertThrowsError(try AgentAdapterRegistry.default.hookEvent(from: generic)) { error in
            XCTAssertEqual(error as? AgentAdapterError, .invalidHookPayload)
        }
    }

    private func envelope(payload: [String: BridgeJSONValue]) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "cursor",
            requestId: nil,
            command: .hookEvent,
            payload: payload
        )
    }
}
