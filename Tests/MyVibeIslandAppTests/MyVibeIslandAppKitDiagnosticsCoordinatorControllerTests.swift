import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitDiagnosticsCoordinatorControllerTests: XCTestCase {
    @MainActor
    func testDiagnosticsCoordinatorControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DiagnosticsCoordinatorControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/diagnostics-coordinator-controller-matrix")
        )

        let actual = DiagnosticsCoordinatorControllerMatrixFixture(rows: [
            exportRow(),
            readinessRow(
                id: "partial-readiness-with-repair-hint",
                snapshot: DiagnosticsCoordinatorSnapshot(
                    environment: EnvironmentScanResult(
                        agents: [
                            EnvironmentAgentInfo(id: "codex", name: "Codex", isDetected: true)
                        ]
                    )
                ),
                repairHints: [
                    DiagnosticRepairHint(
                        source: "codex",
                        message: "Restart Codex",
                        repairability: .userActionRequired,
                        severity: .repairable
                    )
                ]
            ),
            readinessRow(
                id: "demo-only-readiness-without-agent",
                snapshot: DiagnosticsCoordinatorSnapshot(environment: EnvironmentScanResult()),
                repairHints: []
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerBuildsExportPlanFromCollectedInputsAndPublishesPlan() {
        var events: [String] = []
        let manifest = DiagnosticBundleManifest(sections: [
            DiagnosticBundleSection(name: "system-info.txt", evidence: .idaString, isRequired: true)
        ])
        let coordinator = DiagnosticsCoordinator(
            exportBuilder: DiagnosticExportBuilder(manifest: manifest),
            exportWriter: DiagnosticExportWriter(redactor: DiagnosticRedactor())
        )
        let controller = MyVibeIslandAppKitDiagnosticsCoordinatorController(
            coordinator: coordinator,
            collectInputs: {
                [
                    DiagnosticExportSectionInput(
                        name: "system-info.txt",
                        producer: "system",
                        allowedFields: ["cwd"],
                        forbiddenFields: [],
                        fields: ["cwd": "/Users/admin/project"]
                    )
                ]
            },
            publishExportPlan: { plan in
                events.append("export:\(plan.status.rawValue):\(plan.entries.count)")
            }
        )

        let plan = controller.exportDiagnostics()

        XCTAssertEqual(plan.status, .ready)
        XCTAssertEqual(plan.entries.first?.path, "system-info.txt")
        XCTAssertEqual(plan.entries.first?.fields["cwd"], "/Users/<user>/project")
        XCTAssertEqual(controller.lastExportPlan, plan)
        XCTAssertEqual(events, ["export:ready:1"])
    }

    @MainActor
    func testControllerBuildsReadinessSummaryFromCollectedSnapshotAndPublishesSummary() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitDiagnosticsCoordinatorController(
            collectSnapshot: {
                DiagnosticsCoordinatorSnapshot(
                    environment: EnvironmentScanResult(
                        agents: [
                            EnvironmentAgentInfo(id: "codex", name: "Codex", isDetected: true)
                        ]
                    )
                )
            },
            collectRepairHints: {
                [
                    DiagnosticRepairHint(
                        source: "codex",
                        message: "Restart Codex",
                        repairability: .userActionRequired,
                        severity: .repairable
                    )
                ]
            },
            publishReadinessSummary: { summary in
                events.append("readiness:\(summary.outcome.rawValue):\(summary.repairHints.count)")
            }
        )

        let summary = controller.refreshReadinessSummary()

        XCTAssertEqual(summary.outcome, .partial)
        XCTAssertEqual(summary.repairHints.first?.source, "codex")
        XCTAssertEqual(controller.lastReadinessSummary, summary)
        XCTAssertEqual(events, ["readiness:partial:1"])
    }

    @MainActor
    private func exportRow() -> DiagnosticsCoordinatorControllerMatrixRow {
        var events: [String] = []
        let manifest = DiagnosticBundleManifest(sections: [
            DiagnosticBundleSection(name: "system-info.txt", evidence: .idaString, isRequired: true)
        ])
        let coordinator = DiagnosticsCoordinator(
            exportBuilder: DiagnosticExportBuilder(manifest: manifest),
            exportWriter: DiagnosticExportWriter(redactor: DiagnosticRedactor())
        )
        let controller = MyVibeIslandAppKitDiagnosticsCoordinatorController(
            coordinator: coordinator,
            collectInputs: {
                [
                    DiagnosticExportSectionInput(
                        name: "system-info.txt",
                        producer: "system",
                        allowedFields: ["cwd"],
                        forbiddenFields: [],
                        fields: ["cwd": "/Users/admin/project"]
                    )
                ]
            },
            publishExportPlan: { plan in
                events.append("export:\(plan.status.rawValue):\(plan.entries.count):\(plan.failures.count)")
            }
        )

        let plan = controller.exportDiagnostics()

        return DiagnosticsCoordinatorControllerMatrixRow(
            id: "export-plan",
            exportPlan: DiagnosticsCoordinatorExportPlanSummary(plan),
            readinessSummary: nil,
            lastExportPlan: controller.lastExportPlan.map(DiagnosticsCoordinatorExportPlanSummary.init),
            lastReadinessSummary: nil,
            events: events
        )
    }

    @MainActor
    private func readinessRow(
        id: String,
        snapshot: DiagnosticsCoordinatorSnapshot,
        repairHints: [DiagnosticRepairHint]
    ) -> DiagnosticsCoordinatorControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitDiagnosticsCoordinatorController(
            collectSnapshot: { snapshot },
            collectRepairHints: { repairHints },
            publishReadinessSummary: { summary in
                events.append("readiness:\(summary.outcome.rawValue):\(summary.repairHints.count)")
            }
        )

        let summary = controller.refreshReadinessSummary()

        return DiagnosticsCoordinatorControllerMatrixRow(
            id: id,
            exportPlan: nil,
            readinessSummary: DiagnosticsCoordinatorReadinessSummary(summary),
            lastExportPlan: nil,
            lastReadinessSummary: controller.lastReadinessSummary.map(DiagnosticsCoordinatorReadinessSummary.init),
            events: events
        )
    }
}

private struct DiagnosticsCoordinatorControllerMatrixFixture: Codable, Equatable {
    let rows: [DiagnosticsCoordinatorControllerMatrixRow]
}

private struct DiagnosticsCoordinatorControllerMatrixRow: Codable, Equatable {
    let id: String
    let exportPlan: DiagnosticsCoordinatorExportPlanSummary?
    let readinessSummary: DiagnosticsCoordinatorReadinessSummary?
    let lastExportPlan: DiagnosticsCoordinatorExportPlanSummary?
    let lastReadinessSummary: DiagnosticsCoordinatorReadinessSummary?
    let events: [String]
}

private struct DiagnosticsCoordinatorExportPlanSummary: Codable, Equatable {
    let status: String
    let entries: [DiagnosticsCoordinatorExportEntrySummary]
    let failures: [DiagnosticsCoordinatorExportFailureSummary]

    init(_ plan: DiagnosticExportWritePlan) {
        self.status = plan.status.rawValue
        self.entries = plan.entries.map(DiagnosticsCoordinatorExportEntrySummary.init)
        self.failures = plan.failures.map(DiagnosticsCoordinatorExportFailureSummary.init)
    }
}

private struct DiagnosticsCoordinatorExportEntrySummary: Codable, Equatable {
    let sectionName: String
    let path: String
    let redactionLevel: String
    let fields: [String: String]

    init(_ entry: DiagnosticExportWriteEntry) {
        self.sectionName = entry.sectionName
        self.path = entry.path
        self.redactionLevel = entry.redactionLevel.rawValue
        self.fields = entry.fields
    }
}

private struct DiagnosticsCoordinatorExportFailureSummary: Codable, Equatable {
    let sectionName: String
    let error: String

    init(_ failure: DiagnosticExportWriteFailure) {
        self.sectionName = failure.sectionName
        self.error = failure.error.rawValue
    }
}

private struct DiagnosticsCoordinatorReadinessSummary: Codable, Equatable {
    let outcome: String
    let repairHints: [DiagnosticsCoordinatorRepairHintSummary]

    init(_ summary: DiagnosticReadinessSummary) {
        self.outcome = summary.outcome.rawValue
        self.repairHints = summary.repairHints.map(DiagnosticsCoordinatorRepairHintSummary.init)
    }
}

private struct DiagnosticsCoordinatorRepairHintSummary: Codable, Equatable {
    let source: String
    let repairability: String
    let severity: String

    init(_ hint: DiagnosticRepairHint) {
        self.source = hint.source
        self.repairability = hint.repairability.rawValue
        self.severity = hint.severity.rawValue
    }
}
