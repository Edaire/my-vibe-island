import Foundation
import XCTest
@testable import MyVibeIslandCore

final class ActionableRequestLifecycleTests: XCTestCase {
    func testActionableRequestCodableKeepsTypedLifecycleTimestampAndDecodesLegacyPayload() throws {
        let timestamp = Date(timeIntervalSince1970: 123)
        let request = ActionableRequest(
            requestId: "request-1",
            sessionId: "session-1",
            source: "opencode",
            kind: .permission,
            toolName: "shell",
            actionableRequestLifecycleTimestamp: timestamp
        )

        let decoded = try JSONDecoder().decode(ActionableRequest.self, from: JSONEncoder().encode(request))
        XCTAssertEqual(decoded.actionableRequestLifecycleTimestamp, timestamp)

        let legacy = try JSONSerialization.data(withJSONObject: [
            "requestId": "legacy",
            "sessionId": "session-1",
            "source": "codex",
            "kind": "permission",
                "toolName": "shell",
        ])
        XCTAssertNil(try JSONDecoder().decode(ActionableRequest.self, from: legacy).actionableRequestLifecycleTimestamp)
    }

    func testBridgeRequestCreationTimestampReachesLiveSessionStateButNotRestoredSession() {
        let timestamp = Date(timeIntervalSince1970: 456)
        let coordinator = SessionCoordinator()
        let handler = BridgeRequestHandler(
            sessionCoordinator: coordinator,
            now: { timestamp }
        )

        _ = handler.handle(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "opencode",
            requestId: nil,
            command: .hookEvent,
            payload: [
                "rawEventName": .string("PermissionRequest"),
                "sessionId": .string("session-1"),
                "requestId": .string("request-1"),
                "cwd": .string("/tmp/project"),
                "toolName": .string("shell"),
            ]
        ))

        let request = coordinator.snapshot(sessionId: "session-1")?.actionableRequests.first
        XCTAssertEqual(request?.actionableRequestLifecycleTimestamp, timestamp)

        let restored = SessionState(agentSession: coordinator.snapshot(sessionId: "session-1")!.agentSession())
        XCTAssertTrue(restored.actionableRequests.isEmpty)
    }

    func testActionRequestPreviewExposesLifecycleTimestamp() {
        let timestamp = Date(timeIntervalSince1970: 789)
        let preview = ActionRequestPreview(request: ActionableRequest(
            requestId: "request-1",
            sessionId: "session-1",
            source: "codex",
            kind: .question,
            toolName: "question",
            actionableRequestLifecycleTimestamp: timestamp
        ))

        XCTAssertEqual(preview.actionableRequestLifecycleTimestamp, timestamp)
    }

    func testRepeatedRequestIdentityKeepsOriginalLifecycleTimestamp() {
        let coordinator = SessionCoordinator()
        let event = AgentEvent.permissionRequested(
            source: "codex",
            sessionId: "session-1",
            requestId: "request-1",
            toolName: "shell",
            details: nil
        )

        coordinator.apply(
            event,
            actionableRequestLifecycleTimestamp: Date(timeIntervalSince1970: 100)
        )
        coordinator.apply(
            event,
            actionableRequestLifecycleTimestamp: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(
            coordinator.snapshot(sessionId: "session-1")?.actionableRequests.first?.actionableRequestLifecycleTimestamp,
            Date(timeIntervalSince1970: 100)
        )
    }

    func testSessionStateRequestCreationPathAssignsLifecycleTimestamp() throws {
        var state = SessionState(sessionId: "session-1", source: "codex", cwd: "/tmp/project")
        let before = Date()

        state.apply(.questionAsked(
            source: "codex",
            sessionId: "session-1",
            requestId: "request-1",
            toolName: "question",
            details: nil
        ))

        let timestamp = try XCTUnwrap(state.actionableRequests.first?.actionableRequestLifecycleTimestamp)
        XCTAssertGreaterThanOrEqual(timestamp, before)
        XCTAssertLessThanOrEqual(timestamp, Date())
    }
}
