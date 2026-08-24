import XCTest
@testable import MyVibeIslandCore

final class SSHReconnectDecisionTests: XCTestCase {
    func testReconnectDecisionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHReconnectDecisionMatrixFixture.self,
            from: try FixtureLoader.data("remote/reconnect-decision-matrix")
        )

        let actual = SSHReconnectDecisionMatrixFixture(rows: [
            row(
                id: "below-threshold-observe",
                decision: SSHReconnectDecision(
                    hostId: "devbox",
                    policy: .automaticForKnownHost,
                    healthCheckFailureCount: 2,
                    failureThreshold: 3,
                    userDisconnected: false,
                    tunnelStatus: .connected,
                    failureKind: .heartbeatTimeout
                )
            ),
            row(
                id: "automatic-at-threshold",
                decision: SSHReconnectDecision(
                    hostId: "devbox",
                    policy: .automaticForKnownHost,
                    healthCheckFailureCount: 3,
                    failureThreshold: 3,
                    userDisconnected: false,
                    tunnelStatus: .connected,
                    failureKind: .heartbeatTimeout
                )
            ),
            row(
                id: "prompt-at-threshold",
                decision: SSHReconnectDecision(
                    hostId: "labbox",
                    policy: .promptBeforeReconnect,
                    healthCheckFailureCount: 4,
                    failureThreshold: 3,
                    userDisconnected: false,
                    tunnelStatus: .error,
                    failureKind: .authenticationFailed
                )
            ),
            row(
                id: "manual-policy-suppressed-with-clamped-threshold",
                decision: SSHReconnectDecision(
                    hostId: "manualbox",
                    policy: .manualOnly,
                    healthCheckFailureCount: 1,
                    failureThreshold: 0,
                    userDisconnected: false,
                    tunnelStatus: .disconnected,
                    failureKind: .deployMissing
                )
            ),
            row(
                id: "user-disconnect-suppressed",
                decision: SSHReconnectDecision(
                    hostId: "userbox",
                    policy: .automaticForKnownHost,
                    healthCheckFailureCount: 9,
                    failureThreshold: 3,
                    userDisconnected: true,
                    tunnelStatus: .connected,
                    failureKind: .heartbeatTimeout
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testReconnectDecisionPlansAutomaticReconnectOnlyAfterFailureThreshold() throws {
        let belowThreshold = SSHReconnectDecision(
            hostId: "devbox",
            policy: .automaticForKnownHost,
            healthCheckFailureCount: 2,
            failureThreshold: 3,
            userDisconnected: false,
            tunnelStatus: .connected,
            failureKind: .heartbeatTimeout
        )
        let atThreshold = SSHReconnectDecision(
            hostId: "devbox",
            policy: .automaticForKnownHost,
            healthCheckFailureCount: 3,
            failureThreshold: 3,
            userDisconnected: false,
            tunnelStatus: .connected,
            failureKind: .heartbeatTimeout
        )
        let decoded = try JSONDecoder().decode(SSHReconnectDecision.self, from: try JSONEncoder().encode(atThreshold))

        XCTAssertEqual(decoded, atThreshold)
        XCTAssertEqual(belowThreshold.action, .observe)
        XCTAssertEqual(atThreshold.action, .attemptReconnect)
        XCTAssertEqual(atThreshold.reconnectHint?.blockReason, .heartbeatTimeout)
        XCTAssertEqual(atThreshold.reconnectHint?.repairAction, .reconnectHostTunnel)
    }

    func testReconnectDecisionSuppressesReconnectAfterUserDisconnect() {
        let decision = SSHReconnectDecision(
            hostId: "labbox",
            policy: .automaticForKnownHost,
            healthCheckFailureCount: 5,
            failureThreshold: 3,
            userDisconnected: true,
            tunnelStatus: .connected,
            failureKind: .heartbeatTimeout
        )

        XCTAssertEqual(decision.action, .suppressedByUserDisconnect)
        XCTAssertNil(decision.reconnectHint)
        XCTAssertEqual(decision.diagnosticSummary, "labbox reconnect suppressed after user disconnect")
    }

    private func row(id: String, decision: SSHReconnectDecision) -> SSHReconnectDecisionRowFixture {
        SSHReconnectDecisionRowFixture(
            id: id,
            hostId: decision.hostId,
            policy: decision.policy.rawValue,
            healthCheckFailureCount: decision.healthCheckFailureCount,
            failureThreshold: decision.failureThreshold,
            userDisconnected: decision.userDisconnected,
            tunnelStatus: decision.tunnelStatus.rawValue,
            failureKind: decision.failureKind.rawValue,
            action: decision.action.rawValue,
            reconnectHintRepairAction: decision.reconnectHint?.repairAction.rawValue,
            reconnectHintBlockReason: decision.reconnectHint?.blockReason.rawValue,
            diagnosticSummary: decision.diagnosticSummary
        )
    }

    private struct SSHReconnectDecisionMatrixFixture: Codable, Equatable {
        let rows: [SSHReconnectDecisionRowFixture]
    }

    private struct SSHReconnectDecisionRowFixture: Codable, Equatable {
        let id: String
        let hostId: String
        let policy: String
        let healthCheckFailureCount: Int
        let failureThreshold: Int
        let userDisconnected: Bool
        let tunnelStatus: String
        let failureKind: String
        let action: String
        let reconnectHintRepairAction: String?
        let reconnectHintBlockReason: String?
        let diagnosticSummary: String
    }
}
