import XCTest
@testable import MyVibeIslandCore

final class TerminalPermissionStatusModelsTests: XCTestCase {
    func testTerminalPermissionStatusMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            TerminalPermissionStatusMatrixFixture.self,
            from: try FixtureLoader.data("terminal/permission-status-matrix")
        )
        let denied = TerminalPermissionStatus(
            hostId: "iterm",
            permissionType: .automation,
            state: .denied,
            repairAction: "Open Automation settings",
            lastCheckedAt: "2026-07-08T17:08:00Z"
        )

        let actual = TerminalPermissionStatusMatrixFixture(rows: [
            TerminalPermissionStatusMatrixRow(
                id: "round-trip-denied",
                statuses: [try JSONDecoder().decode(
                    TerminalPermissionStatus.self,
                    from: try JSONEncoder().encode(denied)
                )]
            ),
            TerminalPermissionStatusMatrixRow(
                id: "terminal-granted-and-denied",
                statuses: TerminalPermissionStatusModel().statuses(
                    for: descriptor(
                        id: "iterm",
                        displayName: "iTerm",
                        category: .terminal,
                        requirements: [.automation, .accessibility]
                    ),
                    grantedPermissions: [.automation],
                    lastCheckedAt: "2026-07-08T17:08:00Z"
                )
            ),
            TerminalPermissionStatusMatrixRow(
                id: "no-permission-required",
                statuses: TerminalPermissionStatusModel().statuses(
                    for: descriptor(
                        id: "custom-url",
                        displayName: "Custom URL",
                        category: .desktopApp,
                        requirements: [.none]
                    ),
                    grantedPermissions: [],
                    lastCheckedAt: nil
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testTerminalPermissionStatusRoundTripsRowState() throws {
        let status = TerminalPermissionStatus(
            hostId: "iterm",
            permissionType: .automation,
            state: .denied,
            repairAction: "Open Automation settings",
            lastCheckedAt: "2026-07-08T17:08:00Z"
        )

        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(TerminalPermissionStatus.self, from: data)

        XCTAssertEqual(decoded, status)
        XCTAssertTrue(decoded.needsRepair)
    }

    func testPermissionStatusModelBuildsRowsFromTerminalDescriptor() {
        let descriptor = TerminalCapabilityDescriptor(
            id: "iterm",
            displayName: "iTerm",
            category: .terminal,
            supportLevel: .supported,
            supportedPrecisions: [.exactPane],
            permissionRequirements: [.automation, .accessibility]
        )

        let rows = TerminalPermissionStatusModel().statuses(
            for: descriptor,
            grantedPermissions: [.automation],
            lastCheckedAt: "2026-07-08T17:08:00Z"
        )

        XCTAssertEqual(rows.map(\.permissionType), [.automation, .accessibility])
        XCTAssertEqual(rows.map(\.state), [.granted, .denied])
        XCTAssertNil(rows.first?.repairAction)
        XCTAssertEqual(rows.last?.repairAction, "Grant Accessibility permission for iTerm")
    }

    func testPermissionStatusModelTreatsNoPermissionRequirementAsNotRequired() {
        let descriptor = TerminalCapabilityDescriptor(
            id: "custom-url",
            displayName: "Custom URL",
            category: .desktopApp,
            supportLevel: .supported,
            supportedPrecisions: [.exactPane],
            permissionRequirements: [.none]
        )

        let rows = TerminalPermissionStatusModel().statuses(
            for: descriptor,
            grantedPermissions: [],
            lastCheckedAt: nil
        )

        XCTAssertEqual(rows, [
            TerminalPermissionStatus(
                hostId: "custom-url",
                permissionType: .none,
                state: .notRequired
            ),
        ])
    }

    private func descriptor(
        id: String,
        displayName: String,
        category: TerminalHostCategory,
        requirements: [TerminalPermissionRequirement]
    ) -> TerminalCapabilityDescriptor {
        TerminalCapabilityDescriptor(
            id: id,
            displayName: displayName,
            category: category,
            supportLevel: .supported,
            supportedPrecisions: [.exactPane],
            permissionRequirements: requirements
        )
    }
}

private struct TerminalPermissionStatusMatrixFixture: Codable, Equatable {
    let rows: [TerminalPermissionStatusMatrixRow]
}

private struct TerminalPermissionStatusMatrixRow: Codable, Equatable {
    let id: String
    let statuses: [TerminalPermissionStatus]
    let needsRepairFlags: [Bool]

    init(id: String, statuses: [TerminalPermissionStatus]) {
        self.id = id
        self.statuses = statuses
        needsRepairFlags = statuses.map(\.needsRepair)
    }
}
