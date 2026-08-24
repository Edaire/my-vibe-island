import XCTest
@testable import MyVibeIslandCore

final class UsageNotificationDeliveryPlanTests: XCTestCase {
    func testUsageNotificationDeliveryPlanMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsageNotificationDeliveryPlanMatrixFixture.self,
            from: try FixtureLoader.data("usage/notification-delivery-plan-matrix")
        )
        let threshold = notificationPayload(key: "usageThreshold:codexRateLimits:primary:80")
        let limit = notificationPayload(key: "usageLimit:codexRateLimits:primary")
        let reset = notificationPayload(key: "usageReset:codexRateLimits:2026-07-08T13:00:00Z")

        let actual = UsageNotificationDeliveryPlanMatrixFixture(rows: [
            UsageNotificationDeliveryPlanMatrixRow(
                id: "all-new",
                plan: UsageNotificationDeliveryPlan.make(
                    payloads: [threshold, limit],
                    deliveredKeys: [],
                    notificationsEnabled: true
                )
            ),
            UsageNotificationDeliveryPlanMatrixRow(
                id: "already-delivered",
                plan: UsageNotificationDeliveryPlan.make(
                    payloads: [threshold, reset],
                    deliveredKeys: [threshold.dedupeKey],
                    notificationsEnabled: true
                )
            ),
            UsageNotificationDeliveryPlanMatrixRow(
                id: "disabled",
                plan: UsageNotificationDeliveryPlan.make(
                    payloads: [threshold, limit, reset],
                    deliveredKeys: [],
                    notificationsEnabled: false
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testNewPayloadProducesDeliveryAction() {
        let payload = notificationPayload(key: "usageThreshold:codexRateLimits:primary:80")

        let plan = UsageNotificationDeliveryPlan.make(
            payloads: [payload],
            deliveredKeys: [],
            notificationsEnabled: true
        )

        XCTAssertEqual(plan.actions, [.deliver(payload)])
        XCTAssertEqual(plan.deliverablePayloads, [payload])
        XCTAssertEqual(plan.suppressedKeys, [])
    }

    func testAlreadyDeliveredPayloadIsSuppressed() {
        let payload = notificationPayload(key: "usageThreshold:codexRateLimits:primary:80")

        let plan = UsageNotificationDeliveryPlan.make(
            payloads: [payload],
            deliveredKeys: [payload.dedupeKey],
            notificationsEnabled: true
        )

        XCTAssertEqual(
            plan.actions,
            [.suppress(dedupeKey: payload.dedupeKey, reason: .alreadyDelivered)]
        )
        XCTAssertEqual(plan.deliverablePayloads, [])
        XCTAssertEqual(plan.suppressedKeys, [payload.dedupeKey])
    }

    func testDisabledNotificationsSuppressAllPayloads() {
        let first = notificationPayload(key: "usageThreshold:codexRateLimits:primary:80")
        let second = notificationPayload(key: "usageLimit:codexRateLimits:primary")

        let plan = UsageNotificationDeliveryPlan.make(
            payloads: [first, second],
            deliveredKeys: [],
            notificationsEnabled: false
        )

        XCTAssertEqual(
            plan.actions,
            [
                .suppress(dedupeKey: first.dedupeKey, reason: .notificationsDisabled),
                .suppress(dedupeKey: second.dedupeKey, reason: .notificationsDisabled)
            ]
        )
        XCTAssertEqual(plan.deliverablePayloads, [])
        XCTAssertEqual(plan.suppressedKeys, [first.dedupeKey, second.dedupeKey])
    }

    func testMixedPayloadsKeepInputOrder() {
        let delivered = notificationPayload(key: "usageThreshold:codexRateLimits:primary:80")
        let fresh = notificationPayload(key: "usageReset:codexRateLimits:2026-07-08T13:00:00Z")

        let plan = UsageNotificationDeliveryPlan.make(
            payloads: [delivered, fresh],
            deliveredKeys: [delivered.dedupeKey],
            notificationsEnabled: true
        )

        XCTAssertEqual(
            plan.actions,
            [
                .suppress(dedupeKey: delivered.dedupeKey, reason: .alreadyDelivered),
                .deliver(fresh)
            ]
        )
    }

    func testDeliveryPlanRoundTripsThroughJSON() throws {
        let payload = notificationPayload(key: "usageLimit:codexRateLimits:primary")
        let plan = UsageNotificationDeliveryPlan.make(
            payloads: [payload],
            deliveredKeys: [],
            notificationsEnabled: true
        )

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(UsageNotificationDeliveryPlan.self, from: data)

        XCTAssertEqual(decoded, plan)
    }

    private func notificationPayload(key: String) -> UsagePeekNotificationPayload {
        let category: UsagePeekNotificationCategory
        let severity: UsagePeekNotificationSeverity
        if key.contains("usageLimit") {
            category = .usageLimit
            severity = .critical
        } else if key.contains("usageReset") {
            category = .usageReset
            severity = .info
        } else {
            category = .usageThreshold
            severity = .warning
        }

        return UsagePeekNotificationPayload(
            id: key,
            category: category,
            title: "Usage notification",
            body: "Usage body",
            severity: severity,
            dedupeKey: key,
            soundCategory: .usage,
            sourceProviderId: .codexRateLimits,
            windowId: "primary"
        )
    }

    private struct UsageNotificationDeliveryPlanMatrixFixture: Codable, Equatable {
        let rows: [UsageNotificationDeliveryPlanMatrixRow]
    }

    private struct UsageNotificationDeliveryPlanMatrixRow: Codable, Equatable {
        let id: String
        let plan: UsageNotificationDeliveryPlan
    }
}
