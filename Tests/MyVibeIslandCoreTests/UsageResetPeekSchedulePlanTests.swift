import XCTest
@testable import MyVibeIslandCore

final class UsageResetPeekSchedulePlanTests: XCTestCase {
    func testUsageResetPeekSchedulePlanMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsageResetPeekSchedulePlanMatrixFixture.self,
            from: try FixtureLoader.data("usage/reset-peek-schedule-plan-matrix")
        )
        let reset = resetIntent(resetAt: "2026-07-08T13:00:00Z")
        let laterReset = resetIntent(resetAt: "2026-07-08T15:00:00Z")
        let threshold = UsagePeekIntent(
            providerId: .codexRateLimits,
            windowId: "primary",
            kind: .thresholdReached(thresholdPercent: 80),
            title: "Usage threshold reached",
            message: "Primary reached 85% used",
            dedupeKey: "usageThreshold:codexRateLimits:primary:80"
        )

        let actual = UsageResetPeekSchedulePlanMatrixFixture(rows: [
            UsageResetPeekSchedulePlanMatrixRow(
                id: "new-reset",
                plan: UsageResetPeekSchedulePlan.make(
                    currentIntents: [reset],
                    scheduledResetKeys: []
                )
            ),
            UsageResetPeekSchedulePlanMatrixRow(
                id: "already-scheduled",
                plan: UsageResetPeekSchedulePlan.make(
                    currentIntents: [reset],
                    scheduledResetKeys: [reset.dedupeKey]
                )
            ),
            UsageResetPeekSchedulePlanMatrixRow(
                id: "stale-scheduled-key",
                plan: UsageResetPeekSchedulePlan.make(
                    currentIntents: [],
                    scheduledResetKeys: [reset.dedupeKey]
                )
            ),
            UsageResetPeekSchedulePlanMatrixRow(
                id: "mixed-actions",
                plan: UsageResetPeekSchedulePlan.make(
                    currentIntents: [threshold, laterReset],
                    scheduledResetKeys: [
                        "usageReset:codexRateLimits:2026-07-08T09:00:00Z"
                    ]
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testNewResetIntentProducesScheduleAction() {
        let reset = resetIntent(resetAt: "2026-07-08T13:00:00Z")

        let plan = UsageResetPeekSchedulePlan.make(
            currentIntents: [reset],
            scheduledResetKeys: []
        )

        XCTAssertEqual(plan.actions, [.schedule(reset)])
        XCTAssertEqual(plan.scheduledIntents, [reset])
        XCTAssertEqual(plan.canceledKeys, [])
    }

    func testAlreadyScheduledResetIntentIsNotScheduledAgain() {
        let reset = resetIntent(resetAt: "2026-07-08T13:00:00Z")

        let plan = UsageResetPeekSchedulePlan.make(
            currentIntents: [reset],
            scheduledResetKeys: [reset.dedupeKey]
        )

        XCTAssertEqual(plan.actions, [])
        XCTAssertEqual(plan.scheduledIntents, [])
        XCTAssertEqual(plan.canceledKeys, [])
    }

    func testMissingResetIntentCancelsScheduledKey() {
        let plan = UsageResetPeekSchedulePlan.make(
            currentIntents: [],
            scheduledResetKeys: ["usageReset:codexRateLimits:2026-07-08T13:00:00Z"]
        )

        XCTAssertEqual(
            plan.actions,
            [.cancel(dedupeKey: "usageReset:codexRateLimits:2026-07-08T13:00:00Z")]
        )
        XCTAssertEqual(plan.scheduledIntents, [])
        XCTAssertEqual(plan.canceledKeys, ["usageReset:codexRateLimits:2026-07-08T13:00:00Z"])
    }

    func testThresholdAndLimitIntentsAreIgnoredByResetSchedulePlan() {
        let threshold = UsagePeekIntent(
            providerId: .codexRateLimits,
            windowId: "primary",
            kind: .thresholdReached(thresholdPercent: 80),
            title: "Usage threshold reached",
            message: "Primary reached 85% used",
            dedupeKey: "usageThreshold:codexRateLimits:primary:80"
        )
        let limit = UsagePeekIntent(
            providerId: .codexRateLimits,
            windowId: "primary",
            kind: .limitReached,
            title: "Usage limit reached",
            message: "Primary reached 100% used",
            dedupeKey: "usageLimit:codexRateLimits:primary"
        )

        let plan = UsageResetPeekSchedulePlan.make(
            currentIntents: [threshold, limit],
            scheduledResetKeys: []
        )

        XCTAssertEqual(plan.actions, [])
    }

    func testActionsAreDeterministicallyOrdered() {
        let laterReset = resetIntent(resetAt: "2026-07-08T15:00:00Z")
        let earlierReset = resetIntent(resetAt: "2026-07-08T13:00:00Z")

        let plan = UsageResetPeekSchedulePlan.make(
            currentIntents: [laterReset, earlierReset],
            scheduledResetKeys: [
                "usageReset:codexRateLimits:2026-07-08T10:00:00Z",
                "usageReset:codexRateLimits:2026-07-08T09:00:00Z"
            ]
        )

        XCTAssertEqual(
            plan.actions,
            [
                .schedule(laterReset),
                .schedule(earlierReset),
                .cancel(dedupeKey: "usageReset:codexRateLimits:2026-07-08T09:00:00Z"),
                .cancel(dedupeKey: "usageReset:codexRateLimits:2026-07-08T10:00:00Z")
            ]
        )
    }

    private func resetIntent(resetAt: String) -> UsagePeekIntent {
        UsagePeekIntent(
            providerId: .codexRateLimits,
            windowId: "primary",
            kind: .windowReset(resetAt: resetAt),
            title: "Usage window reset",
            message: "Primary resets at \(resetAt)",
            dedupeKey: "usageReset:codexRateLimits:\(resetAt)"
        )
    }

    private struct UsageResetPeekSchedulePlanMatrixFixture: Codable, Equatable {
        let rows: [UsageResetPeekSchedulePlanMatrixRow]
    }

    private struct UsageResetPeekSchedulePlanMatrixRow: Codable, Equatable {
        let id: String
        let plan: UsageResetPeekSchedulePlan
    }
}
