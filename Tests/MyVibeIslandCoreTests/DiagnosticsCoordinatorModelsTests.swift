import XCTest
@testable import MyVibeIslandCore

final class DiagnosticsCoordinatorModelsTests: XCTestCase {
    func testDiagnosticsCoordinatorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DiagnosticsCoordinatorMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/coordinator-matrix")
        )
        let snapshot = fixtureSnapshot()
        let manifest = DiagnosticBundleManifest(sections: [
            DiagnosticBundleSection(name: "system-info.txt", evidence: .idaString, isRequired: true),
            DiagnosticBundleSection(name: "sessions-snapshot.txt", evidence: .idaString, isRequired: true)
        ])
        let coordinator = DiagnosticsCoordinator(
            exportBuilder: DiagnosticExportBuilder(manifest: manifest),
            exportWriter: DiagnosticExportWriter(redactor: DiagnosticRedactor())
        )
        let plan = coordinator.exportPlan(from: [
            DiagnosticExportSectionInput(
                name: "system-info.txt",
                producer: "system",
                allowedFields: ["cwd", "appVersion"],
                forbiddenFields: [],
                fields: [
                    "cwd": "/Users/admin/project",
                    "appVersion": "1.0.0"
                ]
            )
        ])

        XCTAssertEqual(snapshot, expected.snapshot)
        XCTAssertEqual(plan, expected.exportPlan)
    }

    func testCoordinatorSnapshotRoundTripsCollectedLocalDiagnostics() throws {
        let snapshot = fixtureSnapshot()

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(DiagnosticsCoordinatorSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.hangSamples.count, 1)
        XCTAssertEqual(decoded.logEntries.first?.redactedMessage, "snapshot collected")
    }

    func testCoordinatorBuildsRedactedExportPlanFromSectionInputs() {
        let manifest = DiagnosticBundleManifest(sections: [
            DiagnosticBundleSection(name: "system-info.txt", evidence: .idaString, isRequired: true)
        ])
        let coordinator = DiagnosticsCoordinator(
            exportBuilder: DiagnosticExportBuilder(manifest: manifest),
            exportWriter: DiagnosticExportWriter(redactor: DiagnosticRedactor())
        )

        let plan = coordinator.exportPlan(from: [
            DiagnosticExportSectionInput(
                name: "system-info.txt",
                producer: "system",
                allowedFields: ["cwd"],
                forbiddenFields: [],
                fields: ["cwd": "/Users/admin/project"]
            )
        ])

        XCTAssertEqual(plan.status, .ready)
        XCTAssertEqual(plan.entries.first?.path, "system-info.txt")
        XCTAssertEqual(plan.entries.first?.fields["cwd"], "/Users/<user>/project")
    }

    private struct DiagnosticsCoordinatorMatrixFixture: Codable, Equatable {
        let snapshot: DiagnosticsCoordinatorSnapshot
        let exportPlan: DiagnosticExportWritePlan
    }

    private func fixtureSnapshot() -> DiagnosticsCoordinatorSnapshot {
        DiagnosticsCoordinatorSnapshot(
            capturedAt: "2026-07-08T11:00:00Z",
            environment: EnvironmentScanResult(scannedAt: "2026-07-08T10:59:00Z"),
            provenance: ProvenanceAssessment(
                status: .trustedManaged,
                binarySnapshot: BinaryProvenanceSnapshot(
                    integrityStatus: "valid",
                    executableLoadStatus: "loaded",
                    externalHelperStatus: "present",
                    bundleIDMatchesOfficial: true,
                    helperBinaryPresent: true,
                    signingTeamMatchesOfficial: true,
                    hardenedRuntimeEnabled: true,
                    codeUniqueHash: "redacted-hash"
                ),
                redactionLevel: .redacted
            ),
            memory: MemoryFootprintSnapshot(
                virtualBytes: 4_096,
                residentBytes: 2_048,
                physicalFootprintBytes: 1_536,
                compressedBytes: 512,
                reusableBytes: 256
            ),
            displaySleep: DisplaySleepSnapshot(isDisplayAsleep: false),
            hangSamples: [
                MainThreadHangSnapshot(
                    detectedAt: "2026-07-08T10:58:00Z",
                    durationMilliseconds: 1_200,
                    threadStateSummary: "redacted wait",
                    recentEventCount: 3,
                    redactedStackAvailable: true
                )
            ],
            logEntries: [
                DiagnosticLogEntry(
                    eventID: "event-1",
                    category: .diagnostics,
                    severity: .info,
                    source: "coordinator",
                    redactedMessage: "snapshot collected",
                    createdAt: "2026-07-08T11:00:00Z"
                )
            ]
        )
    }
}
