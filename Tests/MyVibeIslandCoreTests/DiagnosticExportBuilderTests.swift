import XCTest
@testable import MyVibeIslandCore

final class DiagnosticExportBuilderTests: XCTestCase {
    func testDiagnosticExportBuilderMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DiagnosticExportBuilderMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/export-builder-matrix")
        )
        let manifest = DiagnosticBundleManifest(sections: [
            DiagnosticBundleSection(
                name: "system-info.txt",
                evidence: .idaString,
                isRequired: true,
                redactionLevel: .redacted
            ),
            DiagnosticBundleSection(
                name: "logs/",
                evidence: .privacyNote,
                isRequired: true,
                redactionLevel: .localOnly
            ),
            DiagnosticBundleSection(
                name: "hang-samples/",
                evidence: .privacyNote,
                isRequired: false,
                redactionLevel: .sensitive
            )
        ])
        let builder = DiagnosticExportBuilder(manifest: manifest)

        let sections = builder.buildSections(from: [
            DiagnosticExportSectionInput(
                name: "logs/",
                producer: "logger",
                allowedFields: ["lineCount", "latestTimestamp"],
                forbiddenFields: ["rawLine", "latestTimestamp"],
                fields: [
                    "lineCount": "3",
                    "latestTimestamp": "2026-07-09T09:00:00Z",
                    "rawLine": "raw diagnostic line"
                ]
            ),
            DiagnosticExportSectionInput(
                name: "system-info.txt",
                producer: "system",
                allowedFields: ["appVersion", "macOSVersion"],
                forbiddenFields: ["homePath"],
                fields: [
                    "appVersion": "1.0.0",
                    "macOSVersion": "15.5",
                    "homePath": "/Users/admin",
                    "ignored": "not-allowlisted"
                ]
            ),
            DiagnosticExportSectionInput(
                name: "unlisted.txt",
                producer: "debug",
                allowedFields: ["value"],
                forbiddenFields: [],
                fields: ["value": "ignored"]
            )
        ])

        XCTAssertEqual(sections, expected.sections)
    }

    func testDiagnosticExportSectionRoundTripsConfiguredFields() throws {
        let section = DiagnosticExportSection(
            name: "system-info.txt",
            producer: "system",
            allowedFields: ["appVersion", "macOSVersion"],
            forbiddenFields: ["homePath"],
            redactionLevel: .redacted,
            isRequired: true,
            fields: [
                "appVersion": "1.0",
                "macOSVersion": "14"
            ]
        )

        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(DiagnosticExportSection.self, from: data)

        XCTAssertEqual(decoded, section)
        XCTAssertEqual(decoded.name, "system-info.txt")
        XCTAssertEqual(decoded.producer, "system")
        XCTAssertEqual(decoded.allowedFields, ["appVersion", "macOSVersion"])
        XCTAssertEqual(decoded.forbiddenFields, ["homePath"])
        XCTAssertEqual(decoded.redactionLevel, .redacted)
        XCTAssertTrue(decoded.isRequired)
        XCTAssertEqual(decoded.fields["appVersion"], "1.0")
    }

    func testBuilderProducesManifestOrderedSectionsWithAllowlistedFieldsOnly() {
        let manifest = DiagnosticBundleManifest(sections: [
            DiagnosticBundleSection(name: "system-info.txt", evidence: .idaString, isRequired: true),
            DiagnosticBundleSection(name: "logs/", evidence: .privacyNote, isRequired: true)
        ])
        let builder = DiagnosticExportBuilder(manifest: manifest)

        let sections = builder.buildSections(from: [
            DiagnosticExportSectionInput(
                name: "logs/",
                producer: "logger",
                allowedFields: ["lineCount"],
                forbiddenFields: ["rawLine"],
                fields: [
                    "lineCount": "3",
                    "rawLine": "omitted"
                ]
            ),
            DiagnosticExportSectionInput(
                name: "system-info.txt",
                producer: "system",
                allowedFields: ["appVersion"],
                forbiddenFields: ["homePath"],
                fields: [
                    "appVersion": "1.0",
                    "homePath": "/Users/example"
                ]
            )
        ])

        XCTAssertEqual(sections.map(\.name), ["system-info.txt", "logs/"])
        XCTAssertEqual(sections.first?.fields, ["appVersion": "1.0"])
        XCTAssertEqual(sections.last?.fields, ["lineCount": "3"])
        XCTAssertEqual(sections.first?.producer, "system")
        XCTAssertEqual(sections.last?.producer, "logger")
        XCTAssertTrue(sections.allSatisfy { section in
            Set(section.fields.keys).isSubset(of: Set(section.allowedFields))
        })
    }

    func testBuilderKeepsRequiredManifestSectionWhenProducerInputIsMissing() {
        let manifest = DiagnosticBundleManifest(sections: [
            DiagnosticBundleSection(name: "sessions-snapshot.txt", evidence: .idaString, isRequired: true)
        ])
        let builder = DiagnosticExportBuilder(manifest: manifest)

        let sections = builder.buildSections(from: [])

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.name, "sessions-snapshot.txt")
        XCTAssertEqual(sections.first?.producer, "missing")
        XCTAssertEqual(sections.first?.fields, [:])
        XCTAssertTrue(sections.first?.isRequired == true)
    }

    private struct DiagnosticExportBuilderMatrixFixture: Codable, Equatable {
        let sections: [DiagnosticExportSection]
    }
}
