import XCTest
@testable import MyVibeIslandCore

final class UsagePeekNotificationPayloadTests: XCTestCase {
    func testUsagePeekNotificationPayloadMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsagePeekNotificationPayloadMatrixFixture.self,
            from: try FixtureLoader.data("usage/peek-notification-payload-matrix")
        )
        let threshold = peekIntent(
            kind: .thresholdReached(thresholdPercent: 80),
            title: "Usage threshold reached",
            message: "Primary reached 85% used",
            dedupeKey: "usageThreshold:codexRateLimits:primary:80"
        )
        let limit = peekIntent(
            kind: .limitReached,
            title: "Usage limit reached",
            message: "Primary reached 100% used",
            dedupeKey: "usageLimit:codexRateLimits:primary"
        )
        let reset = peekIntent(
            kind: .windowReset(resetAt: "2026-07-08T13:00:00Z"),
            title: "Usage window reset",
            message: "Primary resets at 2026-07-08T13:00:00Z",
            dedupeKey: "usageReset:codexRateLimits:2026-07-08T13:00:00Z"
        )

        let actual = UsagePeekNotificationPayloadMatrixFixture(rows: [
            UsagePeekNotificationPayloadMatrixRow(
                id: "silent",
                payloads: UsagePeekNotificationPayload.make(
                    intents: [threshold, limit, reset],
                    soundEnabled: false
                )
            ),
            UsagePeekNotificationPayloadMatrixRow(
                id: "audible",
                payloads: UsagePeekNotificationPayload.make(
                    intents: [threshold, limit, reset],
                    soundEnabled: true
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testThresholdPeekMapsToWarningNotificationPayload() {
        let intent = peekIntent(
            kind: .thresholdReached(thresholdPercent: 80),
            title: "Usage threshold reached",
            message: "Primary reached 85% used",
            dedupeKey: "usageThreshold:codexRateLimits:primary:80"
        )

        let payloads = UsagePeekNotificationPayload.make(intents: [intent], soundEnabled: false)

        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads.first?.id, intent.dedupeKey)
        XCTAssertEqual(payloads.first?.category, .usageThreshold)
        XCTAssertEqual(payloads.first?.severity, .warning)
        XCTAssertEqual(payloads.first?.title, intent.title)
        XCTAssertEqual(payloads.first?.body, intent.message)
        XCTAssertEqual(payloads.first?.sourceProviderId, .codexRateLimits)
        XCTAssertEqual(payloads.first?.windowId, "primary")
        XCTAssertFalse(payloads.first?.unread ?? true)
        XCTAssertNil(payloads.first?.soundCategory)
    }

    func testLimitPeekMapsToCriticalNotificationPayload() {
        let intent = peekIntent(
            kind: .limitReached,
            title: "Usage limit reached",
            message: "Primary reached 100% used",
            dedupeKey: "usageLimit:codexRateLimits:primary"
        )

        let payloads = UsagePeekNotificationPayload.make(intents: [intent], soundEnabled: true)

        XCTAssertEqual(payloads.map(\.category), [.usageLimit])
        XCTAssertEqual(payloads.map(\.severity), [.critical])
        XCTAssertEqual(payloads.map(\.soundCategory), [.usage])
    }

    func testResetPeekMapsToInfoNotificationPayload() {
        let intent = peekIntent(
            kind: .windowReset(resetAt: "2026-07-08T13:00:00Z"),
            title: "Usage window reset",
            message: "Primary resets at 2026-07-08T13:00:00Z",
            dedupeKey: "usageReset:codexRateLimits:2026-07-08T13:00:00Z"
        )

        let payloads = UsagePeekNotificationPayload.make(intents: [intent], soundEnabled: false)

        XCTAssertEqual(payloads.map(\.category), [.usageReset])
        XCTAssertEqual(payloads.map(\.severity), [.info])
        XCTAssertEqual(payloads.first?.dedupeKey, intent.dedupeKey)
    }

    func testSoundCategoryIsOnlyIncludedWhenEnabled() {
        let intent = peekIntent(
            kind: .limitReached,
            title: "Usage limit reached",
            message: "Primary reached 100% used",
            dedupeKey: "usageLimit:codexRateLimits:primary"
        )

        let silent = UsagePeekNotificationPayload.make(intents: [intent], soundEnabled: false)
        let audible = UsagePeekNotificationPayload.make(intents: [intent], soundEnabled: true)

        XCTAssertNil(silent.first?.soundCategory)
        XCTAssertEqual(audible.first?.soundCategory, .usage)
    }

    func testNotificationPayloadRoundTripsThroughJSON() throws {
        let intent = peekIntent(
            kind: .thresholdReached(thresholdPercent: 80),
            title: "Usage threshold reached",
            message: "Primary reached 85% used",
            dedupeKey: "usageThreshold:codexRateLimits:primary:80"
        )
        let payload = try XCTUnwrap(UsagePeekNotificationPayload.make(intents: [intent], soundEnabled: true).first)

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(UsagePeekNotificationPayload.self, from: data)

        XCTAssertEqual(decoded, payload)
    }

    private func peekIntent(
        kind: UsagePeekKind,
        title: String,
        message: String,
        dedupeKey: String
    ) -> UsagePeekIntent {
        UsagePeekIntent(
            providerId: .codexRateLimits,
            windowId: "primary",
            kind: kind,
            title: title,
            message: message,
            dedupeKey: dedupeKey
        )
    }

    private struct UsagePeekNotificationPayloadMatrixFixture: Codable, Equatable {
        let rows: [UsagePeekNotificationPayloadMatrixRow]
    }

    private struct UsagePeekNotificationPayloadMatrixRow: Codable, Equatable {
        let id: String
        let payloads: [UsagePeekNotificationPayload]
    }
}
