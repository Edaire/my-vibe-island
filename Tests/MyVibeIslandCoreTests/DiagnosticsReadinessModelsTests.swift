import XCTest
@testable import MyVibeIslandCore

final class DiagnosticsReadinessModelsTests: XCTestCase {
    func testDiagnosticsReadinessMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DiagnosticsReadinessMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/readiness-matrix")
        )
        let coordinator = DiagnosticsCoordinator()

        let actual = DiagnosticsReadinessMatrixFixture(rows: [
            row(
                id: "ready-detected-agent",
                summary: coordinator.readinessSummary(
                    for: DiagnosticsCoordinatorSnapshot(
                        environment: EnvironmentScanResult(
                            agents: [EnvironmentAgentInfo(id: "codex", name: "Codex", isDetected: true)]
                        )
                    )
                )
            ),
            row(
                id: "partial-repairable-hint",
                summary: coordinator.readinessSummary(
                    for: DiagnosticsCoordinatorSnapshot(
                        environment: EnvironmentScanResult(
                            agents: [EnvironmentAgentInfo(id: "codex", name: "Codex", isDetected: true)]
                        )
                    ),
                    repairHints: [
                        DiagnosticRepairHint(
                            source: "codex",
                            message: "Restart the agent",
                            repairability: .userActionRequired,
                            severity: .repairable
                        )
                    ]
                )
            ),
            row(
                id: "blocked-manual-permission",
                summary: coordinator.readinessSummary(
                    for: DiagnosticsCoordinatorSnapshot(
                        environment: EnvironmentScanResult(
                            agents: [EnvironmentAgentInfo(id: "codex", name: "Codex", isDetected: true)]
                        )
                    ),
                    repairHints: [
                        DiagnosticRepairHint(
                            source: "terminal",
                            message: "Required permission is missing",
                            repairability: .manualOnly,
                            severity: .blocking
                        )
                    ]
                )
            ),
            row(
                id: "demo-only-without-detected-agent",
                summary: coordinator.readinessSummary(
                    for: DiagnosticsCoordinatorSnapshot(environment: EnvironmentScanResult())
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRepairHintRoundTripsRepairabilityAndSource() throws {
        let hint = DiagnosticRepairHint(
            source: "claude-code",
            message: "Managed hook block is stale",
            repairability: .appCanRepairManagedBlock,
            severity: .repairable
        )

        let data = try JSONEncoder().encode(hint)
        let decoded = try JSONDecoder().decode(DiagnosticRepairHint.self, from: data)

        XCTAssertEqual(decoded, hint)
        XCTAssertEqual(decoded.repairability, .appCanRepairManagedBlock)
    }

    func testCoordinatorDerivesReadinessOutcomeFromSnapshotAndRepairHints() {
        let coordinator = DiagnosticsCoordinator()
        let readySnapshot = DiagnosticsCoordinatorSnapshot(
            environment: EnvironmentScanResult(
                agents: [
                    EnvironmentAgentInfo(id: "codex", name: "Codex", isDetected: true)
                ]
            )
        )

        XCTAssertEqual(coordinator.readinessSummary(for: readySnapshot).outcome, .ready)

        let partial = coordinator.readinessSummary(
            for: readySnapshot,
            repairHints: [
                DiagnosticRepairHint(
                    source: "codex",
                    message: "Restart the agent",
                    repairability: .userActionRequired,
                    severity: .repairable
                )
            ]
        )
        XCTAssertEqual(partial.outcome, .partial)
        XCTAssertEqual(partial.repairHints.first?.source, "codex")

        let blocked = coordinator.readinessSummary(
            for: readySnapshot,
            repairHints: [
                DiagnosticRepairHint(
                    source: "terminal",
                    message: "Required permission is missing",
                    repairability: .manualOnly,
                    severity: .blocking
                )
            ]
        )
        XCTAssertEqual(blocked.outcome, .blocked)

        let demoOnly = coordinator.readinessSummary(
            for: DiagnosticsCoordinatorSnapshot(environment: EnvironmentScanResult())
        )
        XCTAssertEqual(demoOnly.outcome, .demoOnly)
    }

    private func row(
        id: String,
        summary: DiagnosticReadinessSummary
    ) -> DiagnosticsReadinessRowFixture {
        DiagnosticsReadinessRowFixture(
            id: id,
            outcome: summary.outcome.rawValue,
            repairHintCount: summary.repairHints.count,
            firstRepairHintSource: summary.repairHints.first?.source,
            firstRepairHintMessage: summary.repairHints.first?.message,
            firstRepairHintRepairability: summary.repairHints.first?.repairability.rawValue,
            firstRepairHintSeverity: summary.repairHints.first?.severity.rawValue
        )
    }

    private struct DiagnosticsReadinessMatrixFixture: Codable, Equatable {
        let rows: [DiagnosticsReadinessRowFixture]
    }

    private struct DiagnosticsReadinessRowFixture: Codable, Equatable {
        let id: String
        let outcome: String
        let repairHintCount: Int
        let firstRepairHintSource: String?
        let firstRepairHintMessage: String?
        let firstRepairHintRepairability: String?
        let firstRepairHintSeverity: String?
    }
}
