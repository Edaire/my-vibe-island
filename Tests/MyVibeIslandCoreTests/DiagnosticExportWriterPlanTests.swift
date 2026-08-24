import XCTest
@testable import MyVibeIslandCore

final class DiagnosticExportWriterPlanTests: XCTestCase {
    func testWriterPlansMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DiagnosticExportWriterPlanFixture.self,
            from: try FixtureLoader.data("diagnostics/export-writer-plans")
        )
        let writer = DiagnosticExportWriter(redactor: DiagnosticRedactor())

        let readyPlan = writer.planWrite(sections: [
            DiagnosticExportSection(
                name: "system-info.txt",
                producer: "system",
                allowedFields: ["cwd", "token"],
                forbiddenFields: ["token"],
                redactionLevel: .redacted,
                isRequired: true,
                fields: [
                    "cwd": "/Users/admin/project",
                    "token": "secret-token-value"
                ]
            ),
            DiagnosticExportSection(
                name: "logs/",
                producer: "logger",
                allowedFields: ["lineCount"],
                forbiddenFields: [],
                redactionLevel: .redacted,
                isRequired: false,
                fields: ["lineCount": "2"]
            )
        ])
        let failedClosedPlan = writer.planWrite(sections: [
            DiagnosticExportSection(
                name: "sessions-snapshot.txt",
                producer: "missing",
                allowedFields: [],
                forbiddenFields: [],
                redactionLevel: .redacted,
                isRequired: true,
                fields: [:]
            )
        ])

        XCTAssertEqual(readyPlan, expected.ready)
        XCTAssertEqual(failedClosedPlan, expected.failedClosed)
    }

    func testWriterPlanCreatesStableRedactedSectionEntries() {
        let writer = DiagnosticExportWriter(redactor: DiagnosticRedactor())
        let sections = [
            DiagnosticExportSection(
                name: "system-info.txt",
                producer: "system",
                allowedFields: ["cwd"],
                forbiddenFields: [],
                redactionLevel: .redacted,
                isRequired: true,
                fields: ["cwd": "/Users/admin/project"]
            )
        ]

        let plan = writer.planWrite(sections: sections)

        XCTAssertEqual(plan.status, .ready)
        XCTAssertEqual(plan.entries.map(\.path), ["system-info.txt"])
        XCTAssertEqual(plan.entries.first?.fields, ["cwd": "/Users/<user>/project"])
        XCTAssertEqual(plan.entries.first?.redactionLevel, .redacted)
        XCTAssertEqual(plan.failures, [])
    }

    func testWriterPlanUsesDirectoryIndexForDirectoryNamedSections() {
        let writer = DiagnosticExportWriter()
        let sections = [
            DiagnosticExportSection(
                name: "logs/",
                producer: "logger",
                allowedFields: ["lineCount"],
                forbiddenFields: [],
                redactionLevel: .redacted,
                isRequired: false,
                fields: ["lineCount": "2"]
            )
        ]

        let plan = writer.planWrite(sections: sections)

        XCTAssertEqual(plan.entries.first?.path, "logs/index.json")
    }

    func testWriterPlanFailsClosedForMissingRequiredContent() {
        let writer = DiagnosticExportWriter()
        let sections = [
            DiagnosticExportSection(
                name: "sessions-snapshot.txt",
                producer: "missing",
                allowedFields: [],
                forbiddenFields: [],
                redactionLevel: .redacted,
                isRequired: true,
                fields: [:]
            )
        ]

        let plan = writer.planWrite(sections: sections)

        XCTAssertEqual(plan.status, .failedClosed)
        XCTAssertEqual(plan.entries, [])
        XCTAssertEqual(plan.failures.first?.sectionName, "sessions-snapshot.txt")
        XCTAssertEqual(plan.failures.first?.error, .sectionGenerationFailed)
    }

    private struct DiagnosticExportWriterPlanFixture: Codable, Equatable {
        let ready: DiagnosticExportWritePlan
        let failedClosed: DiagnosticExportWritePlan
    }
}
