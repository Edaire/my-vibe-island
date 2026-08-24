import XCTest
@testable import MyVibeIslandCore

final class SoundPackPlayerPlanModelsTests: XCTestCase {
    func testSoundPackPlayerPlansMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SoundPackPlayerPlanFixture.self,
            from: try FixtureLoader.data("sound/pack-player-plans")
        )
        let player = SoundPackPlayer()
        let selectedStore = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.cleanPack],
            selectedPackId: "builtin.clean"
        ))
        let missingSelectionStore = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.cleanPack],
            selectedPackId: "missing-pack"
        ))
        let invalidAssetStore = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.invalidAssetPack],
            selectedPackId: "builtin.invalid"
        ))

        let actual = SoundPackPlayerPlanFixture(
            firstPermission: player.planPlayback(
                request: SoundPackPlaybackRequest(category: .permission),
                store: selectedStore
            ),
            explicitCompletion: player.planPlayback(
                request: SoundPackPlaybackRequest(category: .completion, soundId: "completion.clean"),
                store: selectedStore
            ),
            missingSelectedPack: player.planPlayback(
                request: SoundPackPlaybackRequest(category: .permission),
                store: missingSelectionStore
            ),
            missingCategorySound: player.planPlayback(
                request: SoundPackPlaybackRequest(category: .usage),
                store: selectedStore
            ),
            missingRequestedSound: player.planPlayback(
                request: SoundPackPlaybackRequest(category: .permission, soundId: "permission.missing"),
                store: selectedStore
            ),
            invalidAssetReference: player.planPlayback(
                request: SoundPackPlaybackRequest(category: .permission),
                store: invalidAssetStore
            )
        )

        XCTAssertEqual(actual, expected)
    }

    func testSoundPackPlaybackRequestRoundTrips() throws {
        let request = SoundPackPlaybackRequest(category: .permission, soundId: "permission.clean")

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SoundPackPlaybackRequest.self, from: data)

        XCTAssertEqual(decoded, request)
    }

    func testSoundPackPlayerPlansFirstCategoryEntryForSelectedPack() {
        let player = SoundPackPlayer()
        let store = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.cleanPack],
            selectedPackId: "builtin.clean"
        ))

        let plan = player.planPlayback(request: SoundPackPlaybackRequest(category: .permission), store: store)

        XCTAssertEqual(plan.outcome, .play)
        XCTAssertEqual(plan.packId, "builtin.clean")
        XCTAssertEqual(plan.entry?.id, "permission.clean")
        XCTAssertNil(plan.failureKind)
    }

    func testSoundPackPlayerPlansExplicitSoundIdWhenPresent() {
        let player = SoundPackPlayer()
        let store = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.cleanPack],
            selectedPackId: "builtin.clean"
        ))

        let plan = player.planPlayback(
            request: SoundPackPlaybackRequest(category: .completion, soundId: "completion.clean"),
            store: store
        )

        XCTAssertEqual(plan.outcome, .play)
        XCTAssertEqual(plan.entry?.id, "completion.clean")
    }

    func testSoundPackPlayerReportsMissingSelectedPackAndMissingSounds() {
        let player = SoundPackPlayer()
        let missingSelectionStore = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.cleanPack],
            selectedPackId: "missing-pack"
        ))
        let selectedStore = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.cleanPack],
            selectedPackId: "builtin.clean"
        ))

        XCTAssertEqual(
            player.planPlayback(request: SoundPackPlaybackRequest(category: .permission), store: missingSelectionStore).failureKind,
            .missingSelectedPack
        )
        XCTAssertEqual(
            player.planPlayback(request: SoundPackPlaybackRequest(category: .usage), store: selectedStore).failureKind,
            .missingCategorySound
        )
        XCTAssertEqual(
            player.planPlayback(
                request: SoundPackPlaybackRequest(category: .permission, soundId: "permission.missing"),
                store: selectedStore
            ).failureKind,
            .missingRequestedSound
        )
    }

    func testSoundPackPlayerReportsInvalidAssetReference() {
        let player = SoundPackPlayer()
        let store = SoundPackStore(snapshot: SoundPackStoreSnapshot(
            manifests: [Self.invalidAssetPack],
            selectedPackId: "builtin.invalid"
        ))

        let plan = player.planPlayback(request: SoundPackPlaybackRequest(category: .permission), store: store)

        XCTAssertEqual(plan.outcome, .fail)
        XCTAssertEqual(plan.failureKind, .invalidAssetReference)
        XCTAssertEqual(plan.entry?.id, "permission.invalid")
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
            SoundPackSoundEntry(
                id: "completion.clean",
                category: .completion,
                file: "completion-clean.aiff",
                label: "Completion Clean",
                durationMs: 700,
                loudness: .quiet
            ),
        ]
    )

    private static let invalidAssetPack = SoundPackManifest(
        cespVersion: 1,
        id: "builtin.invalid",
        name: "Invalid",
        displayName: "Invalid Pack",
        version: "1.0.0",
        author: SoundPackAuthor(name: "My Vibe Island", github: nil),
        contentRights: nil,
        categories: [.permission],
        sounds: [
            SoundPackSoundEntry(
                id: "permission.invalid",
                category: .permission,
                file: "",
                label: "Permission Invalid",
                durationMs: 900,
                loudness: .normal
            ),
        ]
    )

    private struct SoundPackPlayerPlanFixture: Codable, Equatable {
        let firstPermission: SoundPackPlaybackPlan
        let explicitCompletion: SoundPackPlaybackPlan
        let missingSelectedPack: SoundPackPlaybackPlan
        let missingCategorySound: SoundPackPlaybackPlan
        let missingRequestedSound: SoundPackPlaybackPlan
        let invalidAssetReference: SoundPackPlaybackPlan
    }
}
