import Foundation
import XCTest
@testable import MyVibeIslandCore

final class SoundPreferencesStoreTests: XCTestCase {
    func testDefaultsMatchRecoveredSoundManagerConstructor() throws {
        let store = SoundPreferencesStore(defaults: try defaults())

        XCTAssertEqual(store.loadManagerSettings(), SoundManagerSettings(
            selectedPackId: nil,
            isEnabled: true,
            volume: 1.0,
            quietHoursEnabled: false,
            quietHoursStartMinutes: 22 * 60,
            quietHoursEndMinutes: 8 * 60
        ))
        XCTAssertEqual(store.loadFilter(), SoundFilter())
        XCTAssertEqual(store.loadSourceSelections(), SoundSourceStore(selections: [:]).persistedSnapshot)
    }

    func testManagerFilterAndSourceSelectionsRoundTripRecoveredKeys() throws {
        let defaults = try defaults()
        let store = SoundPreferencesStore(defaults: defaults)
        let manager = SoundManagerSettings(
            selectedPackId: "pack-1",
            isEnabled: false,
            volume: 0.65,
            quietHoursEnabled: true,
            quietHoursStartMinutes: 21 * 60,
            quietHoursEndMinutes: 6 * 60
        )
        let filter = SoundFilter(autoDetectProbes: true, rules: [
            SoundFilterRule(
                id: "probe",
                type: .source,
                action: .suppressSound,
                source: "ClaudeProbe"
            ),
        ])
        let sources = SoundSourceStoreSnapshot(selections: [
            SoundSourceSelection(
                category: .permission,
                sourceKind: .appleSystem,
                soundId: "Ping",
                isEnabled: true,
                volume: 0.8,
                cooldownSeconds: 2,
                outputRouteBehavior: "default"
            ),
        ])

        store.saveManagerSettings(manager)
        store.saveFilter(filter)
        store.saveSourceSelections(sources)

        XCTAssertEqual(defaults.object(forKey: "soundEnabled") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "soundVolume") as? Double, 0.65)
        XCTAssertEqual(defaults.string(forKey: "soundSelectedPack"), "pack-1")
        XCTAssertEqual(defaults.object(forKey: "soundQuietHoursEnabled") as? Bool, true)
        XCTAssertEqual(defaults.integer(forKey: "soundQuietHoursStartMinutes"), 21 * 60)
        XCTAssertEqual(defaults.integer(forKey: "soundQuietHoursEndMinutes"), 6 * 60)
        XCTAssertEqual(store.loadManagerSettings(), manager)
        XCTAssertEqual(store.loadFilter(), filter)
        XCTAssertEqual(store.loadSourceSelections(), sources)
    }

    func testLoadManagerSnapshotCombinesPersistedPlaybackState() throws {
        let store = SoundPreferencesStore(defaults: try defaults())
        store.saveManagerSettings(SoundManagerSettings(volume: 0.4))
        store.saveFilter(SoundFilter(autoDetectProbes: true))
        store.saveSourceSelections(SoundSourceStoreSnapshot(selections: [
            SoundSourceSelection(
                category: .permission,
                sourceKind: .appleSystem,
                soundId: "Ping",
                isEnabled: true,
                volume: 0.5,
                cooldownSeconds: 2,
                outputRouteBehavior: "default"
            ),
        ]))

        let snapshot = store.loadManagerSnapshot()
        let plan = SoundManager(snapshot: snapshot).planPlayback(SoundManagerPlaybackRequest(
            category: .permission,
            minuteOfDay: 12 * 60
        ))

        XCTAssertEqual(snapshot.filter, SoundFilter(autoDetectProbes: true))
        XCTAssertEqual(snapshot.sourceSelections[.permission]?.soundId, "Ping")
        XCTAssertEqual(plan.action, .playAppleSystem)
        XCTAssertEqual(plan.effectiveVolume, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(plan.cooldownSeconds, 2)
    }

    private func defaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "SoundPreferencesStoreTests.\(UUID().uuidString)"))
    }
}
