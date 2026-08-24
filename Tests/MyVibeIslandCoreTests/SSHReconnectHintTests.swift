import XCTest
@testable import MyVibeIslandCore

final class SSHReconnectHintTests: XCTestCase {
    func testReconnectHintFailureKindMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHReconnectHintMatrixFixture.self,
            from: try FixtureLoader.data("remote/reconnect-hint-matrix")
        )

        let actual = SSHReconnectHintMatrixFixture(rows: SSHTunnelFailureKind.allFixtureCases.map { failureKind in
            let hint = SSHReconnectHint.fromFailureKind(
                failureKind,
                hostId: "devbox",
                nextReconnectAt: failureKind == .heartbeatTimeout ? "2026-07-09T09:00:00Z" : nil,
                failureCount: failureKind == .heartbeatTimeout ? 2 : 0,
                reconnectAttempt: failureKind == .heartbeatTimeout ? 1 : 0
            )
            return SSHReconnectHintRowFixture(
                failureKind: hint.failureKind.rawValue,
                blockReason: hint.blockReason.rawValue,
                repairAction: hint.repairAction.rawValue,
                message: hint.message,
                nextReconnectAt: hint.nextReconnectAt,
                failureCount: hint.failureCount,
                reconnectAttempt: hint.reconnectAttempt,
                requiresManualSetup: hint.requiresManualSetup,
                allowsReconnectAttempt: hint.allowsReconnectAttempt
            )
        })

        XCTAssertEqual(actual, expected)
    }

    func testReconnectHintMapsHeartbeatTimeoutToReconnectAction() throws {
        let observer = SSHReachabilityObserver(
            hostId: "devbox",
            heartbeatIntervalSeconds: 15,
            heartbeatTimeoutSeconds: 5,
            lastProbeResult: .heartbeatTimeout,
            failureCount: 2,
            reconnectAttempt: 1,
            currentReachability: .satisfied,
            nextReconnectAt: "2026-07-09T09:00:00Z"
        )

        let hint = SSHReconnectHint.fromReachability(observer)
        let decoded = try JSONDecoder().decode(SSHReconnectHint.self, from: try JSONEncoder().encode(hint))

        XCTAssertEqual(decoded, hint)
        XCTAssertEqual(hint.hostId, "devbox")
        XCTAssertEqual(hint.blockReason, .heartbeatTimeout)
        XCTAssertEqual(hint.failureKind, .heartbeatTimeout)
        XCTAssertEqual(hint.repairAction, .reconnectHostTunnel)
        XCTAssertEqual(hint.nextReconnectAt, "2026-07-09T09:00:00Z")
        XCTAssertFalse(hint.requiresManualSetup)
        XCTAssertTrue(hint.allowsReconnectAttempt)
    }

    func testReconnectHintMapsStaleListenerToManualSocketRepair() {
        let hint = SSHReconnectHint.fromFailureKind(.staleListener, hostId: "devbox")

        XCTAssertEqual(hint.blockReason, .staleSocket)
        XCTAssertEqual(hint.failureKind, .staleListener)
        XCTAssertEqual(hint.repairAction, .enableStreamLocalBindUnlinkOrRemoveSocket)
        XCTAssertTrue(hint.requiresManualSetup)
        XCTAssertFalse(hint.allowsReconnectAttempt)
    }

    func testReconnectHintMapsPortConflictToSafePortConflictRepair() {
        let conflict = SSHPortConflict(
            hostId: "devbox",
            port: 49152,
            foreignOwners: ["root"],
            checkedByLsof: true,
            checkedBySS: false,
            decision: .foreignOccupied
        )

        let hint = SSHReconnectHint.fromPortConflict(conflict)

        XCTAssertEqual(hint.hostId, "devbox")
        XCTAssertEqual(hint.blockReason, .foreignListener)
        XCTAssertEqual(hint.failureKind, .foreignListener)
        XCTAssertEqual(hint.repairAction, .chooseDifferentPort)
        XCTAssertTrue(hint.requiresManualSetup)
        XCTAssertFalse(hint.allowsReconnectAttempt)
    }

    private struct SSHReconnectHintMatrixFixture: Codable, Equatable {
        let rows: [SSHReconnectHintRowFixture]
    }

    private struct SSHReconnectHintRowFixture: Codable, Equatable {
        let failureKind: String
        let blockReason: String
        let repairAction: String
        let message: String
        let nextReconnectAt: String?
        let failureCount: Int
        let reconnectAttempt: Int
        let requiresManualSetup: Bool
        let allowsReconnectAttempt: Bool
    }
}

private extension SSHTunnelFailureKind {
    static let allFixtureCases: [SSHTunnelFailureKind] = [
        .hostUnreachable,
        .authenticationFailed,
        .deployMissing,
        .hookOutdated,
        .portConflict,
        .staleListener,
        .foreignListener,
        .heartbeatTimeout,
        .commandFailed,
        .unknown,
    ]
}
