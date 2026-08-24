import XCTest
@testable import MyVibeIslandCore

final class SoundPackManifestModelsTests: XCTestCase {
    func testSoundPackManifestCategoryEntriesAndValidationMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SoundPackManifestFixture.self,
            from: try FixtureLoader.data("sound/pack-manifest-validation")
        )
        let validManifest = SoundPackManifest(
            cespVersion: 1,
            id: "builtin.clean",
            name: "Clean",
            displayName: "Clean Pack",
            version: "1.0.0",
            author: SoundPackAuthor(name: "My Vibe Island", github: nil),
            contentRights: "CC0-1.0",
            categories: [.permission, .completion],
            sounds: [
                SoundPackSoundEntry(
                    id: "permission.soft",
                    category: .permission,
                    file: "permission-soft.aiff",
                    label: "Permission Soft",
                    durationMs: 900,
                    loudness: .normal
                ),
                SoundPackSoundEntry(
                    id: "completion.soft",
                    category: .completion,
                    file: "completion-soft.aiff",
                    label: "Completion Soft",
                    durationMs: 700,
                    loudness: .quiet
                ),
            ]
        )
        let invalidManifest = SoundPackManifest(
            cespVersion: 1,
            id: "",
            name: "Broken",
            displayName: "Broken Pack",
            version: "1.0.0",
            author: SoundPackAuthor(name: "", github: nil),
            contentRights: nil,
            categories: [.permission],
            sounds: [
                SoundPackSoundEntry(
                    id: "usage.soft",
                    category: .usage,
                    file: "",
                    label: "",
                    durationMs: -10,
                    loudness: .normal
                ),
            ]
        )

        let actual = SoundPackManifestFixture(
            categoryEntries: validManifest.categoryEntries,
            permissionSoundIds: validManifest.sounds(for: .permission).map(\.id),
            usageSoundIds: validManifest.sounds(for: .usage).map(\.id),
            validationReport: invalidManifest.validationReport
        )

        XCTAssertEqual(actual, expected)
    }

    func testSoundPackManifestDecodesAndEncodesDocumentedWireFields() throws {
        let json = """
        {
          "cesp_version": 1,
          "id": "builtin.clean",
          "name": "Clean",
          "display_name": "Clean Pack",
          "version": "1.0.0",
          "author": {
            "name": "My Vibe Island",
            "github": "my-vibe-island"
          },
          "contentRights": "CC0-1.0",
          "categories": ["permission", "completion"],
          "sounds": [
            {
              "id": "permission.soft",
              "category": "permission",
              "file": "permission-soft.aiff",
              "label": "Permission Soft",
              "durationMs": 900,
              "loudness": "normal"
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(SoundPackManifest.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.cespVersion, 1)
        XCTAssertEqual(decoded.displayName, "Clean Pack")
        XCTAssertEqual(decoded.author.github, "my-vibe-island")
        XCTAssertEqual(decoded.contentRights, "CC0-1.0")
        XCTAssertEqual(decoded.sounds.first?.file, "permission-soft.aiff")

        let encoded = try JSONEncoder().encode(decoded)
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        XCTAssertEqual(object?["cesp_version"] as? Int, 1)
        XCTAssertEqual(object?["display_name"] as? String, "Clean Pack")
    }

    func testSoundPackManifestGroupsSoundsByCategory() {
        let manifest = SoundPackManifest(
            cespVersion: 1,
            id: "builtin.clean",
            name: "Clean",
            displayName: "Clean Pack",
            version: "1.0.0",
            author: SoundPackAuthor(name: "My Vibe Island", github: nil),
            contentRights: "CC0-1.0",
            categories: [.permission, .completion],
            sounds: [
                SoundPackSoundEntry(
                    id: "permission.soft",
                    category: .permission,
                    file: "permission-soft.aiff",
                    label: "Permission Soft",
                    durationMs: 900,
                    loudness: .normal
                ),
                SoundPackSoundEntry(
                    id: "completion.soft",
                    category: .completion,
                    file: "completion-soft.aiff",
                    label: "Completion Soft",
                    durationMs: 700,
                    loudness: .quiet
                ),
            ]
        )

        XCTAssertEqual(manifest.sounds(for: .permission).map(\.id), ["permission.soft"])
        XCTAssertEqual(manifest.sounds(for: .usage), [])
        XCTAssertEqual(manifest.categoryEntries.map(\.category), [.permission, .completion])
    }

    func testSoundPackManifestValidationReportsStructuralIssues() {
        let manifest = SoundPackManifest(
            cespVersion: 1,
            id: "",
            name: "Broken",
            displayName: "Broken Pack",
            version: "1.0.0",
            author: SoundPackAuthor(name: "", github: nil),
            contentRights: nil,
            categories: [.permission],
            sounds: [
                SoundPackSoundEntry(
                    id: "usage.soft",
                    category: .usage,
                    file: "",
                    label: "",
                    durationMs: -10,
                    loudness: .normal
                ),
            ]
        )

        let report = manifest.validationReport

        XCTAssertFalse(report.isValid)
        XCTAssertEqual(
            report.issues.map(\.kind),
            [.missingPackId, .missingAuthorName, .soundCategoryNotListed, .missingSoundFile, .missingSoundLabel, .invalidDuration]
        )
    }

    private struct SoundPackManifestFixture: Codable, Equatable {
        let categoryEntries: [SoundPackCategoryEntry]
        let permissionSoundIds: [String]
        let usageSoundIds: [String]
        let validationReport: SoundPackManifestValidationReport
    }
}
