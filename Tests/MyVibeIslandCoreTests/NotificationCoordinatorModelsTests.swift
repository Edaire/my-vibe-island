import XCTest
@testable import MyVibeIslandCore

final class NotificationCoordinatorModelsTests: XCTestCase {
    func testNotificationDeliveryPlansMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            NotificationDeliveryPlanFixture.self,
            from: try FixtureLoader.data("notifications/delivery-plans")
        )

        let permission = peek(
            id: "permission-1",
            category: .permissionRequested,
            dedupeKey: "permission:session-1",
            soundCategory: .permission
        )
        let repair = peek(
            id: "repair-1",
            category: .integrationRepairNeeded,
            dedupeKey: "repair:codex"
        )
        let question = peek(
            id: "question-1",
            category: .questionAsked,
            agent: "codex",
            soundCategory: .question
        )
        let silenceRules = SilenceRulesSnapshot(customRules: [
            SilenceRule(
                id: "quiet-codex",
                enabled: true,
                matcher: SilenceMatcher(scope: .agent, target: "codex"),
                action: SilenceAction(suppressesPeek: true, suppressesSound: true),
                createdAt: "2026-07-08T18:00:00Z"
            )
        ])

        let actual = NotificationDeliveryPlanFixture(
            defaultPermission: NotificationCoordinator().planDelivery(
                permission,
                policyInput: NotificationPolicyInput(
                    category: permission.category,
                    sessionId: permission.sessionId,
                    agent: permission.agent,
                    dedupeKey: permission.dedupeKey
                )
            ),
            recentlyRevealedRepair: NotificationCoordinator().planDelivery(
                repair,
                policyInput: NotificationPolicyInput(
                    category: repair.category,
                    dedupeKey: "repair:codex",
                    recentRevealKeys: ["repair:codex"]
                )
            ),
            silenceRuleQuestion: NotificationCoordinator().planDelivery(
                question,
                policyInput: NotificationPolicyInput(
                    category: question.category,
                    agent: question.agent
                ),
                silenceRules: silenceRules
            )
        )

        XCTAssertEqual(actual, expected)
    }

    func testNotificationCoordinatorPlansPeekSoundAndUnreadDelivery() {
        let notification = peek(
            id: "permission-1",
            category: .permissionRequested,
            dedupeKey: "permission:session-1",
            soundCategory: .permission
        )

        let plan = NotificationCoordinator().planDelivery(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                sessionId: notification.sessionId,
                agent: notification.agent,
                dedupeKey: notification.dedupeKey
            )
        )

        XCTAssertEqual(plan.notification, notification)
        XCTAssertEqual(plan.decision.route, .showPeek)
        XCTAssertTrue(plan.publishPeek)
        XCTAssertTrue(plan.markUnread)
        XCTAssertEqual(plan.soundRequest?.category, .permission)
        XCTAssertEqual(plan.soundRequest?.notificationId, "permission-1")
    }

    func testNotificationCoordinatorSuppressesRecentlyRevealedNotifications() {
        let notification = peek(
            id: "repair-1",
            category: .integrationRepairNeeded,
            dedupeKey: "repair:codex"
        )

        let plan = NotificationCoordinator().planDelivery(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                dedupeKey: "repair:codex",
                recentRevealKeys: ["repair:codex"]
            )
        )

        XCTAssertEqual(plan.decision.route, .suppressEntirely)
        XCTAssertFalse(plan.publishPeek)
        XCTAssertFalse(plan.markUnread)
        XCTAssertNil(plan.soundRequest)
    }

    func testNotificationCoordinatorUsesEffectiveSilenceRules() {
        let notification = peek(
            id: "question-1",
            category: .questionAsked,
            agent: "codex",
            soundCategory: .question
        )
        let rules = SilenceRulesSnapshot(customRules: [
            SilenceRule(
                id: "quiet-codex",
                enabled: true,
                matcher: SilenceMatcher(scope: .agent, target: "codex"),
                action: SilenceAction(suppressesPeek: true, suppressesSound: true),
                createdAt: "2026-07-08T18:00:00Z"
            )
        ])

        let plan = NotificationCoordinator().planDelivery(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                agent: notification.agent
            ),
            silenceRules: rules
        )

        XCTAssertEqual(plan.decision.route, .updateUnreadOnly)
        XCTAssertFalse(plan.publishPeek)
        XCTAssertTrue(plan.markUnread)
        XCTAssertNil(plan.soundRequest)
    }

    private func peek(
        id: String,
        category: NotificationEventCategory,
        agent: String? = "codex",
        dedupeKey: String? = nil,
        soundCategory: NotificationSoundCategory? = nil
    ) -> PeekNotification {
        PeekNotification(
            id: id,
            category: category,
            sessionId: "session-1",
            agent: agent,
            title: "Title",
            body: "Body",
            severity: .warning,
            primaryAction: .jump,
            createdAt: "2026-07-08T18:00:00Z",
            dwellSeconds: 6,
            dedupeKey: dedupeKey,
            soundCategory: soundCategory,
            source: "runtime"
        )
    }

    private struct NotificationDeliveryPlanFixture: Codable, Equatable {
        let defaultPermission: NotificationDeliveryPlan
        let recentlyRevealedRepair: NotificationDeliveryPlan
        let silenceRuleQuestion: NotificationDeliveryPlan
    }
}
