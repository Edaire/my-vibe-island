import XCTest
@testable import MyVibeIslandCore

final class UsagePeekIntentTests: XCTestCase {
    func testUsagePeekIntentMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsagePeekIntentMatrixFixture.self,
            from: try FixtureLoader.data("usage/peek-intent-matrix")
        )

        let actual = UsagePeekIntentMatrixFixture(rows: [
            UsagePeekIntentMatrixRow(
                id: "disabled",
                intents: UsagePeekIntent.make(
                    snapshot: snapshot(usedPercent: 95, resetAt: "2026-07-08T13:00:00Z"),
                    settings: UsageSettingsSnapshot(thresholdPeeksEnabled: false, thresholdPercent: 80)
                )
            ),
            UsagePeekIntentMatrixRow(
                id: "stale",
                intents: UsagePeekIntent.make(
                    snapshot: snapshot(freshness: .stale, usedPercent: 95),
                    settings: UsageSettingsSnapshot(thresholdPeeksEnabled: true, thresholdPercent: 80)
                )
            ),
            UsagePeekIntentMatrixRow(
                id: "threshold",
                intents: UsagePeekIntent.make(
                    snapshot: snapshot(usedPercent: 85),
                    settings: UsageSettingsSnapshot(thresholdPeeksEnabled: true, thresholdPercent: 80)
                )
            ),
            UsagePeekIntentMatrixRow(
                id: "limit",
                intents: UsagePeekIntent.make(
                    snapshot: snapshot(usedPercent: 100),
                    settings: UsageSettingsSnapshot(thresholdPeeksEnabled: true, thresholdPercent: 80)
                )
            ),
            UsagePeekIntentMatrixRow(
                id: "reset",
                intents: UsagePeekIntent.make(
                    snapshot: snapshot(usedPercent: 20, resetAt: "2026-07-08T13:00:00Z"),
                    settings: UsageSettingsSnapshot(thresholdPeeksEnabled: true, thresholdPercent: 80)
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testDisabledPeekSettingsProduceNoIntents() {
        let intents = UsagePeekIntent.make(
            snapshot: snapshot(usedPercent: 95, resetAt: "2026-07-08T13:00:00Z"),
            settings: UsageSettingsSnapshot(thresholdPeeksEnabled: false, thresholdPercent: 80)
        )

        XCTAssertEqual(intents, [])
    }

    func testStaleSnapshotProducesNoIntents() {
        let intents = UsagePeekIntent.make(
            snapshot: snapshot(freshness: .stale, usedPercent: 95),
            settings: UsageSettingsSnapshot(thresholdPeeksEnabled: true, thresholdPercent: 80)
        )

        XCTAssertEqual(intents, [])
    }

    func testThresholdReachedProducesDeterministicIntent() {
        let intents = UsagePeekIntent.make(
            snapshot: snapshot(usedPercent: 85),
            settings: UsageSettingsSnapshot(thresholdPeeksEnabled: true, thresholdPercent: 80)
        )

        XCTAssertEqual(intents.count, 1)
        XCTAssertEqual(intents.first?.kind, .thresholdReached(thresholdPercent: 80))
        XCTAssertEqual(intents.first?.dedupeKey, "usageThreshold:codexRateLimits:primary:80")
        XCTAssertEqual(intents.first?.message, "Primary reached 85% used")
    }

    func testLimitReachedProducesThresholdAndLimitIntents() {
        let intents = UsagePeekIntent.make(
            snapshot: snapshot(usedPercent: 100),
            settings: UsageSettingsSnapshot(thresholdPeeksEnabled: true, thresholdPercent: 80)
        )

        XCTAssertEqual(intents.map(\.dedupeKey), [
            "usageThreshold:codexRateLimits:primary:80",
            "usageLimit:codexRateLimits:primary"
        ])
        XCTAssertEqual(intents.map(\.kind), [
            .thresholdReached(thresholdPercent: 80),
            .limitReached
        ])
    }

    func testResetTimestampProducesResetIntent() {
        let intents = UsagePeekIntent.make(
            snapshot: snapshot(usedPercent: 20, resetAt: "2026-07-08T13:00:00Z"),
            settings: UsageSettingsSnapshot(thresholdPeeksEnabled: true, thresholdPercent: 80)
        )

        XCTAssertEqual(intents.count, 1)
        XCTAssertEqual(intents.first?.kind, .windowReset(resetAt: "2026-07-08T13:00:00Z"))
        XCTAssertEqual(intents.first?.dedupeKey, "usageReset:codexRateLimits:2026-07-08T13:00:00Z")
        XCTAssertEqual(intents.first?.title, "Usage window reset")
    }

    private func snapshot(
        freshness: UsageSnapshotFreshness = .fresh,
        usedPercent: Double,
        resetAt: String? = nil
    ) -> UsageSnapshot {
        UsageSnapshot(
            providerId: .codexRateLimits,
            source: .providerReported,
            freshness: freshness,
            primaryWindow: UsageLimitWindow(
                id: "primary",
                label: "Primary",
                kind: .fiveHour,
                usedPercent: usedPercent,
                resetAt: resetAt,
                sourceConfidence: .providerReported
            ),
            privacyLevel: .redacted
        )
    }

    private struct UsagePeekIntentMatrixFixture: Codable, Equatable {
        let rows: [UsagePeekIntentMatrixRow]
    }

    private struct UsagePeekIntentMatrixRow: Codable, Equatable {
        let id: String
        let intents: [UsagePeekIntent]
    }
}
