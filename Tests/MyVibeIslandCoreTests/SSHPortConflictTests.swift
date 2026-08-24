import XCTest
@testable import MyVibeIslandCore

final class SSHPortConflictTests: XCTestCase {
    func testPortConflictDecisionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHPortConflictMatrixFixture.self,
            from: try FixtureLoader.data("remote/port-conflict-matrix")
        )

        let actual = SSHPortConflictMatrixFixture(rows: [
            row(id: "free", conflict: conflict(decision: .free)),
            row(
                id: "same-user-stale-cleanup",
                conflict: conflict(
                    listenerOwners: ["dev:sshd"],
                    sameUserSSHPids: [101],
                    decision: .sameUserStaleSSHDCleanupAllowed
                )
            ),
            row(
                id: "foreign-occupied",
                conflict: conflict(
                    foreignOwners: ["root"],
                    decision: .foreignOccupied
                )
            ),
            row(
                id: "non-sshd-occupied",
                conflict: conflict(
                    listenerOwners: ["dev:node"],
                    decision: .nonSSHDOccupied
                )
            ),
            row(
                id: "live-tunnel-occupied",
                conflict: conflict(
                    sameUserSSHPids: [201],
                    liveEstablishedPids: [201],
                    decision: .liveTunnelOccupied
                )
            ),
            row(
                id: "unknown-fail-closed",
                conflict: conflict(
                    checkedByLsof: false,
                    checkedBySS: false,
                    decision: .unknownFailClosed
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testPortConflictRoundTripsOwnershipFields() throws {
        let conflict = SSHPortConflict(
            hostId: "devbox",
            port: 42042,
            listenerOwners: ["sshd:1001"],
            sameUserSSHPids: [101, 102],
            liveEstablishedPids: [103],
            foreignOwners: ["root:222"],
            checkedByLsof: true,
            checkedBySS: false,
            decision: .liveTunnelOccupied
        )

        let decoded = try JSONDecoder().decode(SSHPortConflict.self, from: try JSONEncoder().encode(conflict))

        XCTAssertEqual(decoded, conflict)
    }

    func testUnknownDecisionFailsClosed() {
        let conflict = SSHPortConflict(
            hostId: "devbox",
            port: 42042,
            checkedByLsof: false,
            checkedBySS: false,
            decision: .unknownFailClosed
        )

        XCTAssertFalse(conflict.allowsAutomaticCleanup)
        XCTAssertTrue(conflict.failsClosed)
    }

    func testSameUserStaleSSHDAllowsAutomaticCleanup() {
        let conflict = SSHPortConflict(
            hostId: "devbox",
            port: 42042,
            sameUserSSHPids: [101],
            checkedByLsof: true,
            checkedBySS: true,
            decision: .sameUserStaleSSHDCleanupAllowed
        )

        XCTAssertTrue(conflict.allowsAutomaticCleanup)
        XCTAssertFalse(conflict.failsClosed)
    }

    private func conflict(
        listenerOwners: [String] = [],
        sameUserSSHPids: [Int] = [],
        liveEstablishedPids: [Int] = [],
        foreignOwners: [String] = [],
        checkedByLsof: Bool = true,
        checkedBySS: Bool = true,
        decision: SSHPortConflictDecision
    ) -> SSHPortConflict {
        SSHPortConflict(
            hostId: "devbox",
            port: 42042,
            listenerOwners: listenerOwners,
            sameUserSSHPids: sameUserSSHPids,
            liveEstablishedPids: liveEstablishedPids,
            foreignOwners: foreignOwners,
            checkedByLsof: checkedByLsof,
            checkedBySS: checkedBySS,
            decision: decision
        )
    }

    private func row(id: String, conflict: SSHPortConflict) -> SSHPortConflictRowFixture {
        SSHPortConflictRowFixture(
            id: id,
            hostId: conflict.hostId,
            port: conflict.port,
            listenerOwners: conflict.listenerOwners,
            sameUserSSHPids: conflict.sameUserSSHPids,
            liveEstablishedPids: conflict.liveEstablishedPids,
            foreignOwners: conflict.foreignOwners,
            checkedByLsof: conflict.checkedByLsof,
            checkedBySS: conflict.checkedBySS,
            decision: conflict.decision.rawValue,
            allowsAutomaticCleanup: conflict.allowsAutomaticCleanup,
            failsClosed: conflict.failsClosed
        )
    }

    private struct SSHPortConflictMatrixFixture: Codable, Equatable {
        let rows: [SSHPortConflictRowFixture]
    }

    private struct SSHPortConflictRowFixture: Codable, Equatable {
        let id: String
        let hostId: String
        let port: Int
        let listenerOwners: [String]
        let sameUserSSHPids: [Int]
        let liveEstablishedPids: [Int]
        let foreignOwners: [String]
        let checkedByLsof: Bool
        let checkedBySS: Bool
        let decision: String
        let allowsAutomaticCleanup: Bool
        let failsClosed: Bool
    }
}
