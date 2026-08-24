import XCTest
@testable import MyVibeIslandCore

final class LabsAvailabilityModelsTests: XCTestCase {
    func testLabsAvailabilityMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            LabsAvailabilityMatrixFixture.self,
            from: try FixtureLoader.data("settings/labs-availability-matrix")
        )

        let actual = LabsAvailabilityMatrixFixture(rows: [
            row(id: "none-detected", availability: LabsAvailability()),
            row(
                id: "claude-and-cursor",
                availability: LabsAvailability(
                    toolAvailability: LabsToolAvailability(
                        hasClaude: true,
                        hasCursor: true
                    ),
                    lastCheckedAt: "2026-07-09T01:30:00Z"
                )
            ),
            row(
                id: "codex-gate-available",
                availability: LabsAvailability(
                    toolAvailability: LabsToolAvailability(
                        hasCodex: true
                    )
                )
            ),
            row(
                id: "disabled-claude-gate",
                availability: LabsAvailability(
                    toolAvailability: LabsToolAvailability(
                        hasClaude: true,
                        hasCodex: true
                    ),
                    gates: [
                        .autoPermissionBypass: LabsGate(
                            toolId: .claude,
                            isEnabled: false,
                            reason: .userDisabled
                        ),
                    ]
                )
            ),
            row(
                id: "kiro-gate-enabled-but-tool-missing",
                availability: LabsAvailability(
                    toolAvailability: LabsToolAvailability(
                        hasClaude: true,
                        hasCodex: true
                    ),
                    gates: [
                        .experimentalKiroSupport: LabsGate(toolId: .kiro),
                    ]
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testLabsToolAvailabilityRoundTripsObservedFields() throws {
        let toolAvailability = LabsToolAvailability(
            hasClaude: true,
            hasCodex: true,
            hasCursor: false,
            hasKiro: false
        )

        let data = try JSONEncoder().encode(toolAvailability)
        let decoded = try JSONDecoder().decode(LabsToolAvailability.self, from: data)

        XCTAssertEqual(decoded, toolAvailability)
        XCTAssertTrue(decoded.hasClaude)
        XCTAssertFalse(decoded.hasKiro)
    }

    func testLabsAvailabilityDerivesToolStatusesFromObservedFields() {
        let availability = LabsAvailability(
            toolAvailability: LabsToolAvailability(
                hasClaude: true,
                hasCodex: false,
                hasCursor: true,
                hasKiro: false
            ),
            lastCheckedAt: "2026-07-08T09:00:00Z"
        )

        XCTAssertEqual(availability.status(for: .claude), .available)
        XCTAssertEqual(availability.status(for: .codex), .unavailable)
        XCTAssertEqual(availability.reason(for: .codex), .toolNotDetected)
        XCTAssertEqual(availability.availableToolIds, [.claude, .cursor])
        XCTAssertEqual(availability.lastCheckedAt, "2026-07-08T09:00:00Z")
    }

    func testLabsAvailabilityBuildsStableSettingsRows() throws {
        let availability = LabsAvailability(
            toolAvailability: LabsToolAvailability(
                hasClaude: true,
                hasCodex: false,
                hasCursor: true,
                hasKiro: false
            ),
            lastCheckedAt: "2026-07-09T01:30:00Z"
        )

        let rows = availability.toolRows
        let decoded = try JSONDecoder().decode(
            [LabsToolAvailabilityRow].self,
            from: try JSONEncoder().encode(rows)
        )

        XCTAssertEqual(decoded, rows)
        XCTAssertEqual(rows.map(\.toolId), [.claude, .codex, .cursor, .kiro])
        XCTAssertEqual(rows.map(\.status), [.available, .unavailable, .available, .unavailable])
        XCTAssertEqual(rows[1].reason, .toolNotDetected)
        XCTAssertEqual(rows[1].lastCheckedAt, "2026-07-09T01:30:00Z")
    }

    func testLabsAvailabilityAppliesLocalExperimentalGatesWithoutCommunityRegistry() {
        let availability = LabsAvailability(
            toolAvailability: LabsToolAvailability(
                hasClaude: true,
                hasCodex: true,
                hasCursor: false,
                hasKiro: false
            ),
            gates: [
                .autoPermissionBypass: LabsGate(toolId: .claude, isEnabled: false, reason: .userDisabled),
                .experimentalKiroSupport: LabsGate(toolId: .kiro, isEnabled: true, reason: nil),
            ]
        )

        XCTAssertFalse(availability.isGateAvailable(.autoPermissionBypass))
        XCTAssertFalse(availability.isGateAvailable(.experimentalKiroSupport))
        XCTAssertTrue(availability.isGateAvailable(.codexExperimentalUsage))
    }

    func testLabsAvailabilityDiagnosticSummaryIsAggregateOnly() {
        let availability = LabsAvailability(
            toolAvailability: LabsToolAvailability(
                hasClaude: true,
                hasCodex: false,
                hasCursor: true,
                hasKiro: false
            ),
            gates: [
                .autoPermissionBypass: LabsGate(toolId: .claude, isEnabled: false, reason: .userDisabled),
            ]
        )

        let summary = availability.diagnosticSummary

        XCTAssertEqual(summary.availableToolCount, 2)
        XCTAssertEqual(summary.unavailableToolCount, 2)
        XCTAssertEqual(summary.disabledGateCount, 1)
        XCTAssertFalse(summary.includesCommunityRegistry)
    }

    private func row(
        id: String,
        availability: LabsAvailability
    ) -> LabsAvailabilityMatrixRow {
        LabsAvailabilityMatrixRow(
            id: id,
            availableToolIds: availability.availableToolIds.map(\.rawValue),
            rows: availability.toolRows.map { row in
                LabsToolAvailabilityRowFixture(
                    toolId: row.toolId.rawValue,
                    status: row.status.rawValue,
                    reason: row.reason?.rawValue,
                    lastCheckedAt: row.lastCheckedAt
                )
            },
            gates: LabsGateAvailabilityFixture(
                autoPermissionBypass: availability.isGateAvailable(.autoPermissionBypass),
                codexExperimentalUsage: availability.isGateAvailable(.codexExperimentalUsage),
                experimentalKiroSupport: availability.isGateAvailable(.experimentalKiroSupport)
            ),
            diagnosticSummary: availability.diagnosticSummary
        )
    }

    private struct LabsAvailabilityMatrixFixture: Codable, Equatable {
        let rows: [LabsAvailabilityMatrixRow]
    }

    private struct LabsAvailabilityMatrixRow: Codable, Equatable {
        let id: String
        let availableToolIds: [String]
        let rows: [LabsToolAvailabilityRowFixture]
        let gates: LabsGateAvailabilityFixture
        let diagnosticSummary: LabsAvailabilityDiagnosticSummary
    }

    private struct LabsToolAvailabilityRowFixture: Codable, Equatable {
        let toolId: String
        let status: String
        let reason: String?
        let lastCheckedAt: String?
    }

    private struct LabsGateAvailabilityFixture: Codable, Equatable {
        let autoPermissionBypass: Bool
        let codexExperimentalUsage: Bool
        let experimentalKiroSupport: Bool
    }
}
