import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitDiagnosticExportControllerTests: XCTestCase {
    @MainActor
    func testDiagnosticExportControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DiagnosticExportControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/diagnostic-export-controller-matrix")
        )

        let manifest = DiagnosticBundleManifest(sections: [
            DiagnosticBundleSection(name: "system-info.txt", evidence: .idaString, isRequired: true),
            DiagnosticBundleSection(name: "logs/", evidence: .privacyNote, isRequired: false)
        ])

        let actual = DiagnosticExportControllerMatrixFixture(rows: [
            row(
                id: "ready-redacted-export-plan",
                manifest: manifest,
                inputs: [
                    DiagnosticExportSectionInput(
                        name: "system-info.txt",
                        producer: "system",
                        allowedFields: ["cwd", "appVersion"],
                        forbiddenFields: [],
                        fields: ["cwd": "/Users/admin/project", "appVersion": "1.0"]
                    ),
                    DiagnosticExportSectionInput(
                        name: "logs/",
                        producer: "logger",
                        allowedFields: ["lineCount"],
                        forbiddenFields: [],
                        fields: ["lineCount": "2"]
                    )
                ]
            ),
            row(
                id: "required-section-fails-closed",
                manifest: manifest,
                inputs: [
                    DiagnosticExportSectionInput(
                        name: "logs/",
                        producer: "logger",
                        allowedFields: ["lineCount"],
                        forbiddenFields: [],
                        fields: ["lineCount": "2"]
                    )
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    func testContentAdapterBuildsExportPlanDescriptorRows() {
        let adapter = MyVibeIslandAppKitDiagnosticExportContentAdapter()
        let plan = DiagnosticExportWritePlan(
            status: .failedClosed,
            entries: [
                DiagnosticExportWriteEntry(
                    sectionName: "system-info.txt",
                    path: "system-info.txt",
                    redactionLevel: .redacted,
                    fields: ["cwd": "/Users/<user>/project", "appVersion": "1.0"]
                )
            ],
            failures: [
                DiagnosticExportWriteFailure(
                    sectionName: "logs/",
                    error: .sectionGenerationFailed
                )
            ]
        )

        let descriptor = adapter.makeDescriptor(from: plan)

        XCTAssertEqual(descriptor.status, .failedClosed)
        XCTAssertEqual(descriptor.entryCount, 1)
        XCTAssertEqual(descriptor.failureCount, 1)
        XCTAssertFalse(descriptor.canWriteArchive)
        XCTAssertEqual(descriptor.entryRows.map(\.sectionName), ["system-info.txt"])
        XCTAssertEqual(descriptor.entryRows[0].path, "system-info.txt")
        XCTAssertEqual(descriptor.entryRows[0].redactionLevel, .redacted)
        XCTAssertEqual(descriptor.entryRows[0].fieldCount, 2)
        XCTAssertEqual(descriptor.failureRows.map(\.sectionName), ["logs/"])
        XCTAssertEqual(descriptor.failureRows[0].error, .sectionGenerationFailed)
    }

    @MainActor
    func testControllerBuildsWritePlanFromCollectedInputs() {
        var events: [String] = []
        let manifest = DiagnosticBundleManifest(sections: [
            DiagnosticBundleSection(name: "system-info.txt", evidence: .idaString, isRequired: true),
            DiagnosticBundleSection(name: "logs/", evidence: .privacyNote, isRequired: false)
        ])
        let controller = MyVibeIslandAppKitDiagnosticExportController(
            builder: DiagnosticExportBuilder(manifest: manifest),
            collectInputs: {
                [
                    DiagnosticExportSectionInput(
                        name: "system-info.txt",
                        producer: "system",
                        allowedFields: ["cwd"],
                        forbiddenFields: [],
                        fields: ["cwd": "/Users/admin/project"]
                    ),
                    DiagnosticExportSectionInput(
                        name: "logs/",
                        producer: "logger",
                        allowedFields: ["lineCount"],
                        forbiddenFields: [],
                        fields: ["lineCount": "2"]
                    )
                ]
            },
            publishPlan: { plan in
                events.append("plan:\(plan.status.rawValue):\(plan.entries.count)")
            }
        )

        let plan = controller.exportDiagnostics()

        XCTAssertEqual(plan.status, .ready)
        XCTAssertEqual(plan.entries.map(\.path), ["system-info.txt", "logs/index.json"])
        XCTAssertEqual(plan.entries.first?.fields, ["cwd": "/Users/<user>/project"])
        XCTAssertEqual(controller.lastPlan, plan)
        XCTAssertEqual(events, ["plan:ready:2"])
    }

    @MainActor
    func testProductionControllerBuildsReadyPrivacySafeRequiredBundle() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandAppKitDiagnosticExportControllerTests.\(UUID().uuidString)"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        defer { runtime.stop() }
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandDiagnosticExport-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let controller = MyVibeIslandAppKitDiagnosticExportController.production(
            runtime: runtime,
            defaults: defaults,
            homeDirectory: home,
            appVersion: { "1.2.3" },
            buildVersion: { "456" }
        )

        let plan = controller.exportDiagnostics()

        XCTAssertEqual(plan.status, .ready)
        XCTAssertEqual(
            Set(plan.entries.map(\.sectionName)),
            Set(DiagnosticBundleManifest.default.sections.map(\.name))
        )
        let fields = plan.entries.flatMap { $0.fields }
        XCTAssertFalse(fields.contains { key, value in
            ["token", "secret", "credential", "prompt", "transcript", "toolInput"]
                .contains { key.localizedCaseInsensitiveContains($0) }
                || value.contains(FileManager.default.homeDirectoryForCurrentUser.path)
        })
        XCTAssertEqual(
            plan.entries.first { $0.sectionName == "system-info.txt" }?.fields["appVersion"],
            "1.2.3"
        )
    }

    @MainActor
    func testControllerExportsReadyPlanToArchiveDestination() throws {
        let manifest = DiagnosticBundleManifest(sections: [
            DiagnosticBundleSection(name: "system-info.txt", evidence: .idaString, isRequired: true)
        ])
        let controller = MyVibeIslandAppKitDiagnosticExportController(
            builder: DiagnosticExportBuilder(manifest: manifest),
            collectInputs: {
                [
                    DiagnosticExportSectionInput(
                        name: "system-info.txt",
                        producer: "system",
                        allowedFields: ["appVersion"],
                        forbiddenFields: [],
                        fields: ["appVersion": "1.0"]
                    )
                ]
            }
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandDiagnosticExportController-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let archiveURL = root.appendingPathComponent("diagnostics.zip")

        let result = try controller.exportDiagnostics(to: archiveURL)

        XCTAssertEqual(result, archiveURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))
    }

    @MainActor
    private func row(
        id: String,
        manifest: DiagnosticBundleManifest,
        inputs: [DiagnosticExportSectionInput]
    ) -> DiagnosticExportControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitDiagnosticExportController(
            builder: DiagnosticExportBuilder(manifest: manifest),
            collectInputs: { inputs },
            publishPlan: { plan in
                events.append("plan:\(plan.status.rawValue):\(plan.entries.count):\(plan.failures.count)")
            }
        )

        let plan = controller.exportDiagnostics()
        let descriptor = MyVibeIslandAppKitDiagnosticExportContentAdapter().makeDescriptor(from: plan)

        return DiagnosticExportControllerMatrixRow(
            id: id,
            plan: DiagnosticExportWritePlanSummary(plan),
            descriptor: DiagnosticExportDescriptorSummary(descriptor),
            lastPlan: controller.lastPlan.map(DiagnosticExportWritePlanSummary.init),
            events: events
        )
    }
}

private struct DiagnosticExportControllerMatrixFixture: Codable, Equatable {
    let rows: [DiagnosticExportControllerMatrixRow]
}

private struct DiagnosticExportControllerMatrixRow: Codable, Equatable {
    let id: String
    let plan: DiagnosticExportWritePlanSummary
    let descriptor: DiagnosticExportDescriptorSummary
    let lastPlan: DiagnosticExportWritePlanSummary?
    let events: [String]
}

private struct DiagnosticExportWritePlanSummary: Codable, Equatable {
    let status: String
    let entries: [DiagnosticExportEntrySummary]
    let failures: [DiagnosticExportFailureSummary]

    init(_ plan: DiagnosticExportWritePlan) {
        self.status = plan.status.rawValue
        self.entries = plan.entries.map(DiagnosticExportEntrySummary.init)
        self.failures = plan.failures.map(DiagnosticExportFailureSummary.init)
    }
}

private struct DiagnosticExportEntrySummary: Codable, Equatable {
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

private struct DiagnosticExportFailureSummary: Codable, Equatable {
    let sectionName: String
    let error: String

    init(_ failure: DiagnosticExportWriteFailure) {
        self.sectionName = failure.sectionName
        self.error = failure.error.rawValue
    }
}

private struct DiagnosticExportDescriptorSummary: Codable, Equatable {
    let status: String
    let entryCount: Int
    let failureCount: Int
    let canWriteArchive: Bool
    let entryRows: [DiagnosticExportEntryRowSummary]
    let failureRows: [DiagnosticExportFailureRowSummary]

    init(_ descriptor: MyVibeIslandAppKitDiagnosticExportContentDescriptor) {
        self.status = descriptor.status.rawValue
        self.entryCount = descriptor.entryCount
        self.failureCount = descriptor.failureCount
        self.canWriteArchive = descriptor.canWriteArchive
        self.entryRows = descriptor.entryRows.map(DiagnosticExportEntryRowSummary.init)
        self.failureRows = descriptor.failureRows.map(DiagnosticExportFailureRowSummary.init)
    }
}

private struct DiagnosticExportEntryRowSummary: Codable, Equatable {
    let sectionName: String
    let path: String
    let redactionLevel: String
    let fieldCount: Int

    init(_ row: MyVibeIslandAppKitDiagnosticExportEntryRowDescriptor) {
        self.sectionName = row.sectionName
        self.path = row.path
        self.redactionLevel = row.redactionLevel.rawValue
        self.fieldCount = row.fieldCount
    }
}

private struct DiagnosticExportFailureRowSummary: Codable, Equatable {
    let sectionName: String
    let error: String

    init(_ row: MyVibeIslandAppKitDiagnosticExportFailureRowDescriptor) {
        self.sectionName = row.sectionName
        self.error = row.error.rawValue
    }
}
