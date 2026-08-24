import XCTest
@testable import MyVibeIslandCore

final class SoundSourceSelectionModelsTests: XCTestCase {
    func testDefaultCompletionSelectionUsesEnabledSystemSound() {
        let selection = SoundSourceStore().resolve(category: .completion)

        XCTAssertEqual(selection.sourceKind, .appleSystem)
        XCTAssertTrue(selection.isEnabled)
        XCTAssertEqual(selection.volume, 1)
    }

    func testSoundSourceStorePersistedSnapshotMatchesFixture() throws {
        let expected = try JSONDecoder().decode(
            SoundSourceStoreSnapshot.self,
            from: try FixtureLoader.data("sound/default-source-selections")
        )
        let explicitRemote = SoundSourceSelection(
            category: .remote,
            sourceKind: .custom,
            soundId: "remote.soft",
            isEnabled: true,
            volume: 0.5,
            cooldownSeconds: 4,
            outputRouteBehavior: "selectedOutput",
            sourceId: "custom.remote",
            fallbackSourceId: "builtin8bit.remote"
        )
        let store = SoundSourceStore(selections: [.remote: explicitRemote])

        XCTAssertEqual(store.persistedSnapshot, expected)
    }

    func testSoundSourceSelectionRoundTripsAllSourceKinds() throws {
        let selections = [
            SoundSourceSelection(
                category: .permission,
                sourceKind: .off,
                soundId: nil,
                isEnabled: false,
                volume: 0,
                cooldownSeconds: 0,
                outputRouteBehavior: "default"
            ),
            SoundSourceSelection(
                category: .question,
                sourceKind: .builtin8bit,
                soundId: "builtin8bit.question",
                isEnabled: true,
                volume: 0.8,
                cooldownSeconds: 1,
                outputRouteBehavior: "default"
            ),
            SoundSourceSelection(
                category: .completion,
                sourceKind: .appleSystem,
                soundId: "Glass",
                isEnabled: true,
                volume: 0.5,
                cooldownSeconds: 2,
                outputRouteBehavior: "system"
            ),
            SoundSourceSelection(
                category: .warning,
                sourceKind: .custom,
                soundId: "custom.warning.soft",
                isEnabled: true,
                volume: 0.7,
                cooldownSeconds: 5,
                outputRouteBehavior: "selectedOutput"
            ),
        ]

        let data = try JSONEncoder().encode(selections)
        let decoded = try JSONDecoder().decode([SoundSourceSelection].self, from: data)

        XCTAssertEqual(decoded, selections)
        XCTAssertEqual(decoded.map(\.sourceKind), [.off, .builtin8bit, .appleSystem, .custom])
    }

    func testSoundSourceSelectionRoundTripsSourceAndFallbackIds() throws {
        let selection = SoundSourceSelection(
            category: .question,
            sourceKind: .custom,
            soundId: "question.soft",
            isEnabled: true,
            volume: 0.7,
            cooldownSeconds: 2,
            outputRouteBehavior: "selectedOutput",
            sourceId: "custom.pack.soft",
            fallbackSourceId: "builtin8bit.question"
        )

        let data = try JSONEncoder().encode(selection)
        let decoded = try JSONDecoder().decode(SoundSourceSelection.self, from: data)

        XCTAssertEqual(decoded, selection)
        XCTAssertEqual(decoded.sourceId, "custom.pack.soft")
        XCTAssertEqual(decoded.fallbackSourceId, "builtin8bit.question")
    }

    func testSoundSourceStoreDefaultsCoverDocumentedCategories() {
        let store = SoundSourceStore()

        XCTAssertEqual(Set(store.defaults.map(\.category)), Set(NotificationSoundCategory.allCases))
        XCTAssertTrue(store.resolve(category: .permission).isEnabled)
        XCTAssertTrue(store.resolve(category: .question).isEnabled)
        XCTAssertTrue(store.resolve(category: .failure).isEnabled)
        XCTAssertTrue(store.resolve(category: .completion).isEnabled)
        XCTAssertFalse(store.resolve(category: .usage).isEnabled)
    }

    func testSoundSourceStoreResolvesExplicitSelectionBeforeFallback() {
        let explicit = SoundSourceSelection(
            category: .remote,
            sourceKind: .appleSystem,
            soundId: "Ping",
            isEnabled: true,
            volume: 0.4,
            cooldownSeconds: 3,
            outputRouteBehavior: "system"
        )
        let store = SoundSourceStore(selections: [.remote: explicit])

        XCTAssertEqual(store.resolve(category: .remote), explicit)
        XCTAssertEqual(store.resolve(category: .permission), SoundSourceStore().resolve(category: .permission))
    }

    func testSoundSourceStoreBuildsVersionedPersistenceSnapshot() throws {
        let explicit = SoundSourceSelection(
            category: .remote,
            sourceKind: .custom,
            soundId: "remote.soft",
            isEnabled: true,
            volume: 0.5,
            cooldownSeconds: 4,
            outputRouteBehavior: "selectedOutput",
            sourceId: "custom.remote",
            fallbackSourceId: "builtin8bit.remote"
        )
        let store = SoundSourceStore(selections: [.remote: explicit])

        let snapshot = store.persistedSnapshot
        let decoded = try JSONDecoder().decode(
            SoundSourceStoreSnapshot.self,
            from: try JSONEncoder().encode(snapshot)
        )

        XCTAssertEqual(decoded.schemaVersion, "soundSourceSelections.v1")
        XCTAssertEqual(decoded.selections.map(\.category), NotificationSoundCategory.allCases)
        XCTAssertEqual(decoded.selections.last, explicit)
    }
}
