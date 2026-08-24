import XCTest
@testable import MyVibeIslandCore

final class SoundManagerSettingsModelsTests: XCTestCase {
    func testSoundManagerSettingsQuietHoursMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SoundManagerSettingsQuietHoursFixture.self,
            from: try FixtureLoader.data("sound/settings-quiet-hours")
        )
        let normalized = SoundManagerSettings(
            selectedPackId: "builtin.clean",
            isEnabled: true,
            volume: 1.7,
            quietHoursEnabled: true,
            quietHoursStartMinutes: -20,
            quietHoursEndMinutes: 2_000,
            isCeremonyLoadInProgress: true,
            shouldAutoplayCeremonyWhenReady: false,
            ceremonyLoadGeneration: -3
        )
        let disabled = SoundManagerSettings(
            quietHoursEnabled: false,
            quietHoursStartMinutes: 9 * 60,
            quietHoursEndMinutes: 17 * 60
        )
        let sameDay = SoundManagerSettings(
            quietHoursEnabled: true,
            quietHoursStartMinutes: 9 * 60,
            quietHoursEndMinutes: 17 * 60
        )
        let overnight = SoundManagerSettings(
            quietHoursEnabled: true,
            quietHoursStartMinutes: 22 * 60,
            quietHoursEndMinutes: 7 * 60
        )
        let fullDay = SoundManagerSettings(
            quietHoursEnabled: true,
            quietHoursStartMinutes: 8 * 60,
            quietHoursEndMinutes: 8 * 60
        )

        let actual = SoundManagerSettingsQuietHoursFixture(
            normalized: normalized,
            disabledAtTen: disabled.isQuiet(atMinuteOfDay: 10 * 60),
            sameDayAtNoon: sameDay.isQuiet(atMinuteOfDay: 12 * 60),
            sameDayAtEvening: sameDay.isQuiet(atMinuteOfDay: 18 * 60),
            overnightAtLateNight: overnight.isQuiet(atMinuteOfDay: 23 * 60),
            overnightAtEarlyMorning: overnight.isQuiet(atMinuteOfDay: 6 * 60),
            overnightAtNoon: overnight.isQuiet(atMinuteOfDay: 12 * 60),
            fullDayAtNoon: fullDay.isQuiet(atMinuteOfDay: 12 * 60)
        )

        XCTAssertEqual(actual, expected)
    }

    func testSoundManagerSettingsRoundTripsObservedStorageFields() throws {
        let settings = SoundManagerSettings(
            selectedPackId: "builtin.clean",
            isEnabled: true,
            volume: 0.75,
            quietHoursEnabled: true,
            quietHoursStartMinutes: 22 * 60,
            quietHoursEndMinutes: 7 * 60 + 30,
            isCeremonyLoadInProgress: true,
            shouldAutoplayCeremonyWhenReady: false,
            ceremonyLoadGeneration: 3
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SoundManagerSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(decoded.selectedPackId, "builtin.clean")
        XCTAssertEqual(decoded.ceremonyLoadGeneration, 3)
    }

    func testSoundManagerSettingsNormalizeVolumeAndQuietHourMinutes() {
        let settings = SoundManagerSettings(
            volume: 1.7,
            quietHoursStartMinutes: -20,
            quietHoursEndMinutes: 2_000
        )

        XCTAssertEqual(settings.volume, 1)
        XCTAssertEqual(settings.quietHoursStartMinutes, 0)
        XCTAssertEqual(settings.quietHoursEndMinutes, 1_439)
    }

    func testQuietHoursEvaluationHandlesDisabledSameDayAndOvernightWindows() {
        let disabled = SoundManagerSettings(
            quietHoursEnabled: false,
            quietHoursStartMinutes: 9 * 60,
            quietHoursEndMinutes: 17 * 60
        )
        XCTAssertFalse(disabled.isQuiet(atMinuteOfDay: 10 * 60))

        let sameDay = SoundManagerSettings(
            quietHoursEnabled: true,
            quietHoursStartMinutes: 9 * 60,
            quietHoursEndMinutes: 17 * 60
        )
        XCTAssertTrue(sameDay.isQuiet(atMinuteOfDay: 12 * 60))
        XCTAssertFalse(sameDay.isQuiet(atMinuteOfDay: 18 * 60))

        let overnight = SoundManagerSettings(
            quietHoursEnabled: true,
            quietHoursStartMinutes: 22 * 60,
            quietHoursEndMinutes: 7 * 60
        )
        XCTAssertTrue(overnight.isQuiet(atMinuteOfDay: 23 * 60))
        XCTAssertTrue(overnight.isQuiet(atMinuteOfDay: 6 * 60))
        XCTAssertFalse(overnight.isQuiet(atMinuteOfDay: 12 * 60))
    }

    private struct SoundManagerSettingsQuietHoursFixture: Codable, Equatable {
        let normalized: SoundManagerSettings
        let disabledAtTen: Bool
        let sameDayAtNoon: Bool
        let sameDayAtEvening: Bool
        let overnightAtLateNight: Bool
        let overnightAtEarlyMorning: Bool
        let overnightAtNoon: Bool
        let fullDayAtNoon: Bool
    }
}
