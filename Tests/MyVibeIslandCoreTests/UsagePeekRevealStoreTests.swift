import XCTest
@testable import MyVibeIslandCore

final class UsagePeekRevealStoreTests: XCTestCase {
    func testUsagePeekRevealStoreMatrixMatchesFixtureSnapshot() async throws {
        let expected = try JSONDecoder().decode(
            UsagePeekRevealStoreMatrixFixture.self,
            from: try FixtureLoader.data("usage/peek-reveal-store-matrix")
        )

        let firstPassStore = UsagePeekRevealStore()
        let threshold = intent(key: "usageThreshold:codexRateLimits:primary:80")
        let limit = intent(key: "usageLimit:codexRateLimits:primary", kind: .limitReached)
        let firstPass = await firstPassStore.unrevealedIntents(from: [threshold, limit])

        let repeatedStore = UsagePeekRevealStore()
        _ = await repeatedStore.unrevealedIntents(from: [threshold])
        let repeated = await repeatedStore.unrevealedIntents(from: [threshold])

        let laterBatchStore = UsagePeekRevealStore()
        let reset = intent(
            key: "usageReset:codexRateLimits:2026-07-08T13:00:00Z",
            kind: .windowReset(resetAt: "2026-07-08T13:00:00Z")
        )
        _ = await laterBatchStore.unrevealedIntents(from: [threshold])
        let laterBatch = await laterBatchStore.unrevealedIntents(from: [threshold, reset])

        let resetStore = UsagePeekRevealStore()
        _ = await resetStore.unrevealedIntents(from: [threshold])
        await resetStore.resetForSettingsChange()
        let afterSettingsReset = await resetStore.unrevealedIntents(from: [threshold])

        let actual = UsagePeekRevealStoreMatrixFixture(rows: [
            UsagePeekRevealStoreMatrixRow(
                id: "first-pass",
                unrevealedKeys: firstPass.map(\.dedupeKey),
                revealedKeys: [
                    "usageThreshold:codexRateLimits:primary:80": await firstPassStore.hasRevealed(threshold.dedupeKey),
                    "usageLimit:codexRateLimits:primary": await firstPassStore.hasRevealed(limit.dedupeKey),
                ]
            ),
            UsagePeekRevealStoreMatrixRow(
                id: "repeated-pass",
                unrevealedKeys: repeated.map(\.dedupeKey),
                revealedKeys: [
                    "usageThreshold:codexRateLimits:primary:80": await repeatedStore.hasRevealed(threshold.dedupeKey),
                ]
            ),
            UsagePeekRevealStoreMatrixRow(
                id: "later-batch",
                unrevealedKeys: laterBatch.map(\.dedupeKey),
                revealedKeys: [
                    "usageThreshold:codexRateLimits:primary:80": await laterBatchStore.hasRevealed(threshold.dedupeKey),
                    "usageReset:codexRateLimits:2026-07-08T13:00:00Z": await laterBatchStore.hasRevealed(reset.dedupeKey),
                ]
            ),
            UsagePeekRevealStoreMatrixRow(
                id: "settings-reset",
                unrevealedKeys: afterSettingsReset.map(\.dedupeKey),
                revealedKeys: [
                    "usageThreshold:codexRateLimits:primary:80": await resetStore.hasRevealed(threshold.dedupeKey),
                ]
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testFirstPassReturnsAllIntentsAndRecordsKeys() async {
        let store = UsagePeekRevealStore()
        let intents = [
            intent(key: "usageThreshold:codexRateLimits:primary:80"),
            intent(key: "usageLimit:codexRateLimits:primary", kind: .limitReached)
        ]

        let unrevealed = await store.unrevealedIntents(from: intents)
        let revealedThreshold = await store.hasRevealed("usageThreshold:codexRateLimits:primary:80")
        let revealedLimit = await store.hasRevealed("usageLimit:codexRateLimits:primary")

        XCTAssertEqual(unrevealed, intents)
        XCTAssertTrue(revealedThreshold)
        XCTAssertTrue(revealedLimit)
    }

    func testRepeatedPassReturnsNoIntents() async {
        let store = UsagePeekRevealStore()
        let intents = [intent(key: "usageThreshold:codexRateLimits:primary:80")]

        _ = await store.unrevealedIntents(from: intents)
        let repeated = await store.unrevealedIntents(from: intents)

        XCTAssertEqual(repeated, [])
    }

    func testLaterBatchReturnsOnlyUnseenKeys() async {
        let store = UsagePeekRevealStore()
        let existing = intent(key: "usageThreshold:codexRateLimits:primary:80")
        let new = intent(key: "usageReset:codexRateLimits:2026-07-08T13:00:00Z", kind: .windowReset(resetAt: "2026-07-08T13:00:00Z"))

        _ = await store.unrevealedIntents(from: [existing])
        let unrevealed = await store.unrevealedIntents(from: [existing, new])

        XCTAssertEqual(unrevealed, [new])
    }

    func testSettingsResetAllowsSameIntentAgain() async {
        let store = UsagePeekRevealStore()
        let first = intent(key: "usageThreshold:codexRateLimits:primary:80")

        _ = await store.unrevealedIntents(from: [first])
        await store.resetForSettingsChange()
        let afterReset = await store.unrevealedIntents(from: [first])

        XCTAssertEqual(afterReset, [first])
    }

    func testClearRemovesAllRevealedState() async {
        let store = UsagePeekRevealStore()
        let first = intent(key: "usageLimit:codexRateLimits:primary", kind: .limitReached)

        _ = await store.unrevealedIntents(from: [first])
        await store.clear()
        let hasRevealed = await store.hasRevealed("usageLimit:codexRateLimits:primary")

        XCTAssertFalse(hasRevealed)
    }

    private func intent(
        key: String,
        kind: UsagePeekKind = .thresholdReached(thresholdPercent: 80)
    ) -> UsagePeekIntent {
        UsagePeekIntent(
            providerId: .codexRateLimits,
            windowId: "primary",
            kind: kind,
            title: "Usage",
            message: "Usage update",
            dedupeKey: key
        )
    }

    private struct UsagePeekRevealStoreMatrixFixture: Codable, Equatable {
        let rows: [UsagePeekRevealStoreMatrixRow]
    }

    private struct UsagePeekRevealStoreMatrixRow: Codable, Equatable {
        let id: String
        let unrevealedKeys: [String]
        let revealedKeys: [String: Bool]
    }
}
