import XCTest
@testable import MyVibeIslandCore

final class SSHPortCleanupPlanTests: XCTestCase {
    func testPortCleanupPlanMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHPortCleanupPlanMatrixFixture.self,
            from: try FixtureLoader.data("remote/port-cleanup-plan-matrix")
        )

        let actual = SSHPortCleanupPlanMatrixFixture(rows: [
            row(
                id: "free-port",
                plan: SSHPortCleanupPlan(conflict: SSHPortConflict(
                    hostId: "freebox",
                    port: 42042,
                    checkedByLsof: true,
                    checkedBySS: true,
                    decision: .free
                ))
            ),
            row(
                id: "same-user-stale-sorted-pids",
                plan: SSHPortCleanupPlan(conflict: SSHPortConflict(
                    hostId: "devbox",
                    port: 42042,
                    listenerOwners: ["dev:sshd"],
                    sameUserSSHPids: [102, 101],
                    checkedByLsof: true,
                    checkedBySS: true,
                    decision: .sameUserStaleSSHDCleanupAllowed
                ))
            ),
            row(
                id: "same-user-stale-missing-ss-evidence",
                plan: SSHPortCleanupPlan(conflict: SSHPortConflict(
                    hostId: "partialbox",
                    port: 42042,
                    listenerOwners: ["dev:sshd"],
                    sameUserSSHPids: [201],
                    checkedByLsof: true,
                    checkedBySS: false,
                    decision: .sameUserStaleSSHDCleanupAllowed
                ))
            ),
            row(
                id: "same-user-stale-live-established",
                plan: SSHPortCleanupPlan(conflict: SSHPortConflict(
                    hostId: "livebox",
                    port: 42042,
                    listenerOwners: ["dev:sshd"],
                    sameUserSSHPids: [301],
                    liveEstablishedPids: [301],
                    checkedByLsof: true,
                    checkedBySS: true,
                    decision: .sameUserStaleSSHDCleanupAllowed
                ))
            ),
            row(
                id: "foreign-owner-fail-closed",
                plan: SSHPortCleanupPlan(conflict: SSHPortConflict(
                    hostId: "foreignbox",
                    port: 42042,
                    foreignOwners: ["root"],
                    checkedByLsof: true,
                    checkedBySS: true,
                    decision: .foreignOccupied
                ))
            ),
            row(
                id: "unknown-fail-closed",
                plan: SSHPortCleanupPlan(conflict: SSHPortConflict(
                    hostId: "unknownbox",
                    port: 42042,
                    checkedByLsof: false,
                    checkedBySS: false,
                    decision: .unknownFailClosed
                ))
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCleanupPlanAllowsOnlyProvenSameUserStaleSSHD() throws {
        let conflict = SSHPortConflict(
            hostId: "devbox",
            port: 42042,
            listenerOwners: ["dev:sshd"],
            sameUserSSHPids: [101, 102],
            checkedByLsof: true,
            checkedBySS: true,
            decision: .sameUserStaleSSHDCleanupAllowed
        )

        let plan = SSHPortCleanupPlan(conflict: conflict)
        let decoded = try JSONDecoder().decode(SSHPortCleanupPlan.self, from: try JSONEncoder().encode(plan))

        XCTAssertEqual(decoded, plan)
        XCTAssertEqual(plan.action, .cleanupSameUserStaleSSHD)
        XCTAssertEqual(plan.pidsEligibleForCleanup, [101, 102])
        XCTAssertFalse(plan.requiresManualCleanup)
        XCTAssertEqual(plan.diagnosticSummary, "devbox port 42042 cleanup limited to same-user stale sshd")
    }

    func testCleanupPlanFailsClosedForForeignNonSSHDLiveOrUnknownListeners() {
        let conflicts = [
            SSHPortConflict(
                hostId: "foreign",
                port: 42042,
                foreignOwners: ["root"],
                checkedByLsof: true,
                checkedBySS: true,
                decision: .foreignOccupied
            ),
            SSHPortConflict(
                hostId: "non-sshd",
                port: 42042,
                listenerOwners: ["dev:node"],
                checkedByLsof: true,
                checkedBySS: true,
                decision: .nonSSHDOccupied
            ),
            SSHPortConflict(
                hostId: "live",
                port: 42042,
                sameUserSSHPids: [201],
                liveEstablishedPids: [201],
                checkedByLsof: true,
                checkedBySS: true,
                decision: .liveTunnelOccupied
            ),
            SSHPortConflict(
                hostId: "unknown",
                port: 42042,
                checkedByLsof: false,
                checkedBySS: false,
                decision: .unknownFailClosed
            )
        ]

        let plans = conflicts.map(SSHPortCleanupPlan.init(conflict:))

        XCTAssertEqual(plans.map(\.action), Array(repeating: .failClosed, count: conflicts.count))
        XCTAssertTrue(plans.allSatisfy(\.requiresManualCleanup))
        XCTAssertTrue(plans.allSatisfy { $0.pidsEligibleForCleanup.isEmpty })
    }

    private func row(id: String, plan: SSHPortCleanupPlan) -> SSHPortCleanupPlanRowFixture {
        SSHPortCleanupPlanRowFixture(
            id: id,
            hostId: plan.hostId,
            port: plan.port,
            action: plan.action.rawValue,
            pidsEligibleForCleanup: plan.pidsEligibleForCleanup,
            requiresManualCleanup: plan.requiresManualCleanup,
            diagnosticSummary: plan.diagnosticSummary
        )
    }

    private struct SSHPortCleanupPlanMatrixFixture: Codable, Equatable {
        let rows: [SSHPortCleanupPlanRowFixture]
    }

    private struct SSHPortCleanupPlanRowFixture: Codable, Equatable {
        let id: String
        let hostId: String
        let port: Int
        let action: String
        let pidsEligibleForCleanup: [Int]
        let requiresManualCleanup: Bool
        let diagnosticSummary: String
    }
}
