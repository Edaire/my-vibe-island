import XCTest
@testable import MyVibeIslandCore

final class BridgeResolveActionTests: XCTestCase {
    func testBridgeResolveActionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            BridgeResolveActionMatrixFixture.self,
            from: try FixtureLoader.data("runtime/bridge-resolve-action-matrix")
        )

        let rows = [
            BridgeResolveActionMatrixRow(
                id: "approve-codex-permission",
                initialRequest: .permission,
                payload: resolvePayload(action: "approve")
            ),
            BridgeResolveActionMatrixRow(
                id: "deny-codex-permission",
                initialRequest: .permission,
                payload: resolvePayload(action: "deny")
            ),
            BridgeResolveActionMatrixRow(
                id: "dismiss-codex-permission",
                initialRequest: .permission,
                payload: resolvePayload(action: "dismiss")
            ),
            BridgeResolveActionMatrixRow(
                id: "answer-codex-question",
                initialRequest: .question,
                payload: resolvePayload(action: "answer", answer: "yes")
            ),
            BridgeResolveActionMatrixRow(
                id: "invalid-action",
                initialRequest: .permission,
                payload: resolvePayload(action: "updateRules")
            ),
            BridgeResolveActionMatrixRow(
                id: "unknown-request",
                initialRequest: .permission,
                payload: resolvePayload(requestId: "missing", action: "dismiss")
            ),
        ]

        let actual = BridgeResolveActionMatrixFixture(rows: rows)

        XCTAssertEqual(actual, expected)
    }

    func testActionResolutionPayloadParsesApproveAction() throws {
        let payload = try ActionResolutionPayload(payload: [
            "requestId": .string("r1"),
            "sessionId": .string("s1"),
            "action": .string("approve"),
        ])

        XCTAssertEqual(payload.resolution, ActionResolution(requestId: "r1", sessionId: "s1", kind: .approve))
    }

    func testActionResolutionPayloadParsesAnswerSelection() throws {
        let payload = try ActionResolutionPayload(payload: [
            "requestId": .string("r1"),
            "sessionId": .string("s1"),
            "action": .string("answer"),
            "answer": .string("yes"),
        ])

        XCTAssertEqual(payload.resolution, ActionResolution(requestId: "r1", sessionId: "s1", kind: .answer, selection: "yes"))
    }

    func testActionResolutionPayloadRejectsMissingRequiredFields() {
        XCTAssertThrowsError(try ActionResolutionPayload(payload: [
            "requestId": .string("r1"),
            "action": .string("approve"),
        ])) { error in
            XCTAssertEqual(error as? ActionResolutionPayloadError, .invalidPayload)
        }
    }

    func testActionResolutionPayloadRejectsUnsupportedAction() {
        XCTAssertThrowsError(try ActionResolutionPayload(payload: [
            "requestId": .string("r1"),
            "sessionId": .string("s1"),
            "action": .string("updateRules"),
        ])) { error in
            XCTAssertEqual(error as? ActionResolutionPayloadError, .invalidPayload)
        }
    }

    func testBridgeResolveActionResolvesLocalPendingRequestAndStoresSelection() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        let store = InMemorySessionStore()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator, sessionStore: store)

        let response = handler.handle(resolveEnvelope(payload: [
            "requestId": .string("r1"),
            "sessionId": .string("s1"),
            "action": .string("answer"),
            "answer": .string("yes"),
        ]))

        XCTAssertEqual(response, .ok(message: "action resolved locally"))
        XCTAssertEqual(coordinator.actionableRequests(), [])
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.pendingRequestIds, [])
        XCTAssertEqual(store.loadSnapshot().sessions.first?.pendingRequestIds, [])
        XCTAssertEqual(store.loadSnapshot().questionSelections, ["r1": "yes"])
    }

    func testBridgeResolveActionReturnsSourceDirectiveForCodexPermissionApproval() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)

        let response = handler.handle(resolveEnvelope(payload: [
            "requestId": .string("r1"),
            "sessionId": .string("s1"),
            "action": .string("approve"),
        ]))

        XCTAssertEqual(response, .ok(
            message: "action resolved locally",
            sourceDirective: .object([
                "continue": .bool(true),
                "hookSpecificOutput": .object([
                    "hookEventName": .string("PermissionRequest"),
                    "decision": .object([
                        "behavior": .string("allow"),
                    ]),
                ]),
            ])
        ))
        XCTAssertEqual(coordinator.actionableRequests(), [])
    }

    func testBridgeResolveActionInvalidPayloadFailsWithoutMutation() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator)

        let response = handler.handle(resolveEnvelope(payload: [
            "requestId": .string("r1"),
            "sessionId": .string("s1"),
            "action": .string("updateRules"),
        ]))

        XCTAssertEqual(response, .failure(message: "invalid resolve action payload"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.pendingRequestIds, ["r1"])
    }

    func testBridgeResolveActionUnknownRequestFailsWithoutMutation() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        let store = InMemorySessionStore()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator, sessionStore: store)

        let response = handler.handle(resolveEnvelope(payload: [
            "requestId": .string("missing"),
            "sessionId": .string("s1"),
            "action": .string("dismiss"),
        ]))

        XCTAssertEqual(response, .failure(message: "action request not found"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.pendingRequestIds, ["r1"])
        XCTAssertEqual(store.loadSnapshot().sessions, [])
    }

    private func resolveEnvelope(payload: [String: BridgeJSONValue]) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "app",
            source: "my-vibe-island",
            requestId: nil,
            command: .resolveAction,
            payload: payload
        )
    }
}

private enum BridgeResolveInitialRequest: String, Codable, Equatable {
    case permission
    case question
}

private struct BridgeResolveActionMatrixFixture: Codable, Equatable {
    let rows: [BridgeResolveActionMatrixRow]
}

private struct BridgeResolveActionMatrixRow: Codable, Equatable {
    let id: String
    let responseOK: Bool
    let responseMessage: String?
    let directiveBehavior: String?
    let coordinatorPendingIds: [String]
    let storedPendingIds: [String]
    let questionSelections: [String: String]

    init(
        id: String,
        initialRequest: BridgeResolveInitialRequest,
        payload: [String: BridgeJSONValue]
    ) {
        let coordinator = SessionCoordinator()
        switch initialRequest {
        case .permission:
            coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        case .question:
            coordinator.apply(.questionAsked(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Prompt"))
        }

        let store = InMemorySessionStore()
        let handler = BridgeRequestHandler(sessionCoordinator: coordinator, sessionStore: store)
        let response = handler.handle(Self.resolveEnvelope(payload: payload))
        let storedSnapshot = store.loadSnapshot()

        self.id = id
        self.responseOK = response.ok
        self.responseMessage = response.message
        self.directiveBehavior = response.sourceDirective?.codexDecisionBehavior
        self.coordinatorPendingIds = coordinator.snapshot(sessionId: "s1")?.pendingRequestIds ?? []
        self.storedPendingIds = storedSnapshot.sessions.first?.pendingRequestIds ?? []
        self.questionSelections = storedSnapshot.questionSelections
    }

    private static func resolveEnvelope(payload: [String: BridgeJSONValue]) -> BridgeEnvelope {
        BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "app",
            source: "my-vibe-island",
            requestId: nil,
            command: .resolveAction,
            payload: payload
        )
    }
}

private func resolvePayload(
    requestId: String = "r1",
    sessionId: String = "s1",
    action: String,
    answer: String? = nil
) -> [String: BridgeJSONValue] {
    var payload: [String: BridgeJSONValue] = [
        "requestId": .string(requestId),
        "sessionId": .string(sessionId),
        "action": .string(action),
    ]
    if let answer {
        payload["answer"] = .string(answer)
    }
    return payload
}

private extension BridgeJSONValue {
    var codexDecisionBehavior: String? {
        guard
            case let .object(root) = self,
            case let .object(output)? = root["hookSpecificOutput"],
            case let .object(decision)? = output["decision"],
            case let .string(behavior)? = decision["behavior"]
        else {
            return nil
        }

        return behavior
    }
}
