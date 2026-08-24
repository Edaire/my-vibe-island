import XCTest
@testable import MyVibeIslandCore

final class SoundPackStoreModelsTests: XCTestCase {
    func testSoundPackStoreResolutionAndValidationMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SoundPackStoreFixture.self,
            from: try FixtureLoader.data("sound/pack-store-resolution")
        )
        let invalidPack = SoundPackManifest(
            cespVersion: 1,
            id: "invalid-pack",
            name: "",
            displayName: "Invalid Pack",
            version: "1.0.0",
            author: SoundPackAuthor(name: "My Vibe Island", github: nil),
            contentRights: nil,
            categories: [],
            sounds: []
        )
        let selectedStore = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.cleanPack, Self.arcadePack],
            selectedPackId: "builtin.arcade"
        ))
        let missingSelectionStore = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.cleanPack, Self.cleanPack, invalidPack],
            selectedPackId: "missing-pack"
        ))

        let actual = SoundPackStoreFixture(
            selectedManifestId: selectedStore.selectedManifest?.id,
            cleanDisplayName: selectedStore.manifest(id: "builtin.clean")?.displayName,
            questionSoundIds: selectedStore.sounds(for: .question).map(\.id),
            usageSoundIds: selectedStore.sounds(for: .usage).map(\.id),
            missingSelectedManifestId: missingSelectionStore.selectedManifest?.id,
            missingSelectionPermissionSoundIds: missingSelectionStore.sounds(for: .permission).map(\.id),
            validationReport: missingSelectionStore.validationReport
        )

        XCTAssertEqual(actual, expected)
    }

    func testSoundPackStoreSnapshotRoundTripsManifestsAndSelection() throws {
        let snapshot = SoundPackStoreSnapshot(
            manifests: [Self.cleanPack, Self.arcadePack],
            selectedPackId: "builtin.arcade"
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SoundPackStoreSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.selectedPackId, "builtin.arcade")
        XCTAssertEqual(decoded.manifests.map(\.id), ["builtin.clean", "builtin.arcade"])
    }

    func testSoundPackStoreResolvesSelectedManifestAndSounds() {
        let store = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.cleanPack, Self.arcadePack],
            selectedPackId: "builtin.arcade"
        ))

        XCTAssertEqual(store.selectedManifest?.id, "builtin.arcade")
        XCTAssertEqual(store.manifest(id: "builtin.clean")?.displayName, "Clean Pack")
        XCTAssertEqual(store.sounds(for: .question).map(\.id), ["question.arcade"])
        XCTAssertEqual(store.sounds(for: .usage), [])
    }

    func testSoundPackStoreReturnsNoSoundsWhenSelectedPackIsMissing() {
        let store = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.cleanPack],
            selectedPackId: "missing-pack"
        ))

        XCTAssertNil(store.selectedManifest)
        XCTAssertEqual(store.sounds(for: .permission), [])
    }

    func testSoundPackStoreValidationReportsDuplicateMissingSelectionAndInvalidManifest() {
        let invalidPack = SoundPackManifest(
            cespVersion: 1,
            id: "invalid-pack",
            name: "",
            displayName: "Invalid Pack",
            version: "1.0.0",
            author: SoundPackAuthor(name: "My Vibe Island", github: nil),
            contentRights: nil,
            categories: [],
            sounds: []
        )
        let store = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.cleanPack, Self.cleanPack, invalidPack],
            selectedPackId: "missing-pack"
        ))

        let report = store.validationReport

        XCTAssertFalse(report.isValid)
        XCTAssertEqual(
            report.issues.map(\.kind),
            [.duplicateManifestId, .missingSelectedManifest, .invalidManifest]
        )
        XCTAssertEqual(report.issues.map(\.manifestId), ["builtin.clean", "missing-pack", "invalid-pack"])
    }

    private static let cleanPack = SoundPackManifest(
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
                id: "permission.clean",
                category: .permission,
                file: "permission-clean.aiff",
                label: "Permission Clean",
                durationMs: 900,
                loudness: .normal
            ),
        ]
    )

    private static let arcadePack = SoundPackManifest(
        cespVersion: 1,
        id: "builtin.arcade",
        name: "Arcade",
        displayName: "Arcade Pack",
        version: "1.0.0",
        author: SoundPackAuthor(name: "My Vibe Island", github: nil),
        contentRights: "CC0-1.0",
        categories: [.question, .failure],
        sounds: [
            SoundPackSoundEntry(
                id: "question.arcade",
                category: .question,
                file: "question-arcade.aiff",
                label: "Question Arcade",
                durationMs: 750,
                loudness: .normal
            ),
        ]
    )

    private struct SoundPackStoreFixture: Codable, Equatable {
        let selectedManifestId: String?
        let cleanDisplayName: String?
        let questionSoundIds: [String]
        let usageSoundIds: [String]
        let missingSelectedManifestId: String?
        let missingSelectionPermissionSoundIds: [String]
        let validationReport: SoundPackStoreValidationReport
    }
}
