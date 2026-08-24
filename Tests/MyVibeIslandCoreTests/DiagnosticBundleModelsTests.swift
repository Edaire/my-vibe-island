import XCTest
@testable import MyVibeIslandCore

final class DiagnosticBundleModelsTests: XCTestCase {
    func testDefaultDiagnosticBundleManifestMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DiagnosticBundleManifest.self,
            from: try FixtureLoader.data("diagnostics/default-bundle-manifest")
        )

        XCTAssertEqual(DiagnosticBundleManifest.default, expected)
    }

    func testDefaultDiagnosticBundleManifestUsesStableSectionNames() {
        let manifest = DiagnosticBundleManifest.default

        XCTAssertEqual(
            manifest.sections.map(\.name),
            [
                "system-info.txt",
                "config-snapshot.txt",
                "hooks-dump.txt",
                "environment-snapshot.txt",
                "codex-rollout-inventory.txt",
                "sessions-snapshot.txt",
                "logs/",
                "hang-samples/",
                "crash-reports/",
                "README-privacy.txt"
            ]
        )
        XCTAssertEqual(
            manifest.sections.map(\.evidence),
            [
                .idaString,
                .idaString,
                .privacyNote,
                .idaString,
                .idaString,
                .idaString,
                .privacyNote,
                .privacyNote,
                .privacyNote,
                .privacyDesign
            ]
        )
        XCTAssertEqual(
            manifest.sections.filter(\.isRequired).map(\.name),
            [
                "system-info.txt",
                "config-snapshot.txt",
                "hooks-dump.txt",
                "environment-snapshot.txt",
                "codex-rollout-inventory.txt",
                "sessions-snapshot.txt",
                "logs/",
                "README-privacy.txt"
            ]
        )
    }

    func testDiagnosticBundleManifestRoundTripsThroughJSON() throws {
        let manifest = DiagnosticBundleManifest.default

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(DiagnosticBundleManifest.self, from: data)

        XCTAssertEqual(decoded, manifest)
    }

    func testDiagnosticPrivacyNoteListsExcludedSensitiveData() {
        let note = DiagnosticReportPrivacyNote.default

        XCTAssertTrue(note.excludedData.contains(.prompts))
        XCTAssertTrue(note.excludedData.contains(.transcripts))
        XCTAssertTrue(note.excludedData.contains(.toolInput))
        XCTAssertTrue(note.excludedData.contains(.providerTokens))
        XCTAssertTrue(note.excludedData.contains(.environmentValues))
        XCTAssertTrue(note.excludedData.contains(.commercialState))
        XCTAssertEqual(note.redactionLevel, .redacted)
    }

    func testDefaultDiagnosticPrivacyNoteMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DiagnosticReportPrivacyNote.self,
            from: try FixtureLoader.data("diagnostics/default-privacy-note")
        )

        XCTAssertEqual(DiagnosticReportPrivacyNote.default, expected)
    }
}
