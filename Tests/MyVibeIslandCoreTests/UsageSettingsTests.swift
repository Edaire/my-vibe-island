import XCTest
@testable import MyVibeIslandCore

final class UsageSettingsTests: XCTestCase {
    func testUsageSettingsMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsageSettingsMatrixFixture.self,
            from: try FixtureLoader.data("usage/settings-matrix")
        )

        let actual = UsageSettingsMatrixFixture(rows: [
            row(id: "default", settings: UsageSettingsSnapshot()),
            row(
                id: "enabled-ring-remaining",
                settings: UsageSettingsSnapshot(
                    preferredProviderId: .codexRateLimits,
                    displayStyle: .ringBadge,
                    valueMode: .remaining,
                    thresholdPeeksEnabled: true,
                    thresholdPercent: 75,
                    usageNotificationsEnabled: false,
                    usageSoundEnabled: true,
                    labsProviderIds: [.kimiUsage, .zaiQuota]
                )
            ),
            row(id: "threshold-low-clamp", settings: UsageSettingsSnapshot(thresholdPercent: -10)),
            row(id: "threshold-high-clamp", settings: UsageSettingsSnapshot(thresholdPercent: 125)),
            row(id: "labs-local", settings: UsageSettingsSnapshot(labsProviderIds: [.kimiUsage])),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testDefaultSettingsKeepUsageDisplayHidden() {
        let settings = UsageSettingsSnapshot()

        XCTAssertNil(settings.preferredProviderId)
        XCTAssertEqual(settings.displayStyle, .hidden)
        XCTAssertFalse(settings.isUsageDisplayEnabled)
        XCTAssertEqual(settings.valueMode, .used)
        XCTAssertFalse(settings.thresholdPeeksEnabled)
        XCTAssertEqual(settings.thresholdPercent, 80)
        XCTAssertTrue(settings.usageNotificationsEnabled)
        XCTAssertFalse(settings.usageSoundEnabled)
        XCTAssertTrue(settings.labsProviderIds.isEmpty)
    }

    func testSettingsRoundTripThroughJSON() throws {
        let settings = UsageSettingsSnapshot(
            preferredProviderId: .codexRateLimits,
            displayStyle: .ringBadge,
            valueMode: .remaining,
            thresholdPeeksEnabled: true,
            thresholdPercent: 75,
            usageNotificationsEnabled: false,
            usageSoundEnabled: true,
            labsProviderIds: [.kimiUsage, .zaiQuota]
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(UsageSettingsSnapshot.self, from: data)

        XCTAssertEqual(decoded, settings)
        XCTAssertTrue(decoded.isUsageDisplayEnabled)
        XCTAssertFalse(decoded.usageNotificationsEnabled)
        XCTAssertTrue(decoded.usageSoundEnabled)
    }

    func testThresholdPercentIsClampedToDisplayRange() {
        let low = UsageSettingsSnapshot(thresholdPercent: -10)
        let high = UsageSettingsSnapshot(thresholdPercent: 125)

        XCTAssertEqual(low.thresholdPercent, 0)
        XCTAssertEqual(high.thresholdPercent, 100)
    }

    func testLabsProviderChecksAreLocalAndDeterministic() {
        let settings = UsageSettingsSnapshot(labsProviderIds: [.kimiUsage])

        XCTAssertTrue(settings.isLabsProviderEnabled(.kimiUsage))
        XCTAssertFalse(settings.isLabsProviderEnabled(.zaiQuota))
    }

    private func row(
        id: String,
        settings: UsageSettingsSnapshot
    ) -> UsageSettingsMatrixRow {
        UsageSettingsMatrixRow(
            id: id,
            preferredProviderId: settings.preferredProviderId?.rawValue,
            displayStyle: settings.displayStyle.rawValue,
            isUsageDisplayEnabled: settings.isUsageDisplayEnabled,
            valueMode: settings.valueMode.rawValue,
            thresholdPeeksEnabled: settings.thresholdPeeksEnabled,
            thresholdPercent: settings.thresholdPercent,
            usageNotificationsEnabled: settings.usageNotificationsEnabled,
            usageSoundEnabled: settings.usageSoundEnabled,
            labsProviderIds: settings.labsProviderIds.map(\.rawValue).sorted(),
            kimiLabsEnabled: settings.isLabsProviderEnabled(.kimiUsage),
            zaiLabsEnabled: settings.isLabsProviderEnabled(.zaiQuota)
        )
    }

    private struct UsageSettingsMatrixFixture: Codable, Equatable {
        let rows: [UsageSettingsMatrixRow]
    }

    private struct UsageSettingsMatrixRow: Codable, Equatable {
        let id: String
        let preferredProviderId: String?
        let displayStyle: String
        let isUsageDisplayEnabled: Bool
        let valueMode: String
        let thresholdPeeksEnabled: Bool
        let thresholdPercent: Int
        let usageNotificationsEnabled: Bool
        let usageSoundEnabled: Bool
        let labsProviderIds: [String]
        let kimiLabsEnabled: Bool
        let zaiLabsEnabled: Bool
    }
}
