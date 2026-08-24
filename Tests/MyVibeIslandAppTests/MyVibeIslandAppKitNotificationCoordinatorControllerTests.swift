import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitNotificationCoordinatorControllerTests: XCTestCase {
    @MainActor
    func testNotificationCoordinatorControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            NotificationCoordinatorControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/notification-coordinator-controller-matrix")
        )

        let actual = NotificationCoordinatorControllerMatrixFixture(rows: [
            row(
                id: "permission-delivery",
                notification: Self.peek(
                    id: "permission-1",
                    category: .permissionRequested,
                    soundCategory: .permission
                ),
                policyInput: NotificationPolicyInput(category: .permissionRequested, sessionId: "session-1", agent: "codex")
            ),
            row(
                id: "recent-reveal-suppresses",
                notification: Self.peek(
                    id: "repair-1",
                    category: .integrationRepairNeeded,
                    dedupeKey: "repair:codex"
                ),
                policyInput: NotificationPolicyInput(
                    category: .integrationRepairNeeded,
                    dedupeKey: "repair:codex",
                    recentRevealKeys: ["repair:codex"]
                )
            ),
            presentationBoundaryRow(
                id: "presentation-boundary-delivery",
                notification: Self.peek(
                    id: "permission-2",
                    category: .permissionRequested,
                    soundCategory: .permission
                ),
                policyInput: NotificationPolicyInput(category: .permissionRequested, sessionId: "session-1", agent: "codex")
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerPublishesPeekMarksUnreadAndRequestsSoundThroughInjectedClosures() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitNotificationCoordinatorController(
            publishPeek: { notification in
                events.append("peek:\(notification.id)")
            },
            markUnread: { notification in
                events.append("unread:\(notification.id)")
            },
            requestSound: { request in
                events.append("sound:\(request.notificationId):\(request.category.rawValue)")
            }
        )
        let notification = Self.peek(id: "permission-1", category: .permissionRequested, soundCategory: .permission)

        let plan = controller.deliver(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                sessionId: notification.sessionId,
                agent: notification.agent
            )
        )

        XCTAssertTrue(plan.publishPeek)
        XCTAssertTrue(plan.markUnread)
        XCTAssertEqual(plan.soundRequest?.category, .permission)
        XCTAssertEqual(controller.lastPlan, plan)
        XCTAssertEqual(events, [
            "peek:permission-1",
            "unread:permission-1",
            "sound:permission-1:permission"
        ])
    }

    @MainActor
    func testControllerSuppressesSideEffectsWhenPolicySuppressesNotification() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitNotificationCoordinatorController(
            publishPeek: { notification in
                events.append("peek:\(notification.id)")
            },
            markUnread: { notification in
                events.append("unread:\(notification.id)")
            },
            requestSound: { request in
                events.append("sound:\(request.notificationId)")
            }
        )
        let notification = Self.peek(
            id: "repair-1",
            category: .integrationRepairNeeded,
            dedupeKey: "repair:codex"
        )

        let plan = controller.deliver(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                dedupeKey: "repair:codex",
                recentRevealKeys: ["repair:codex"]
            )
        )

        XCTAssertFalse(plan.publishPeek)
        XCTAssertFalse(plan.markUnread)
        XCTAssertNil(plan.soundRequest)
        XCTAssertEqual(events, [])
    }

    @MainActor
    func testControllerUsesPersistedSilenceRulesProviderWhenRulesAreNotExplicit() {
        var events: [String] = []
        let rule = SilenceRule(
            id: "codex-completion",
            enabled: true,
            matcher: SilenceMatcher(scope: .agent, target: "codex"),
            action: SilenceAction(suppressesPeek: true, suppressesSound: true),
            createdAt: "2026-07-18T00:00:00Z"
        )
        let controller = MyVibeIslandAppKitNotificationCoordinatorController(
            silenceRulesProvider: { SilenceRulesSnapshot(customRules: [rule]) },
            publishPeek: { events.append("peek:\($0.id)") },
            markUnread: { events.append("unread:\($0.id)") },
            requestSound: { events.append("sound:\($0.notificationId)") }
        )
        let notification = Self.peek(
            id: "completion-1",
            category: .sessionCompleted,
            soundCategory: .completion
        )

        let plan = controller.deliver(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                sessionId: notification.sessionId,
                agent: notification.agent
            )
        )

        XCTAssertFalse(plan.publishPeek)
        XCTAssertTrue(plan.markUnread)
        XCTAssertNil(plan.soundRequest)
        XCTAssertEqual(events, ["unread:completion-1"])
    }

    @MainActor
    func testControllerCanRouteDeliveryThroughPresentationBoundary() {
        var events: [String] = []
        let presentationController = MyVibeIslandAppKitNotificationPresentationController(
            presentPeek: { notification in
                events.append("peek:\(notification.notification.id):\(notification.presentation.rawValue)")
            },
            markUnread: { notification in
                events.append("unread:\(notification.id)")
            },
            requestSound: { request in
                events.append("sound:\(request.notificationId):\(request.category.rawValue)")
            }
        )
        let controller = MyVibeIslandAppKitNotificationCoordinatorController(
            presentationController: presentationController
        )
        let notification = Self.peek(
            id: "permission-2",
            category: .permissionRequested,
            soundCategory: .permission
        )

        _ = controller.deliver(
            notification,
            policyInput: NotificationPolicyInput(
                category: notification.category,
                sessionId: notification.sessionId,
                agent: notification.agent
            )
        )

        XCTAssertEqual(
            presentationController.lastAction,
            .requestSound(NotificationSoundRequest(
                notificationId: "permission-2",
                category: .permission,
                source: "runtime"
            ))
        )
        XCTAssertEqual(events, [
            "peek:permission-2:compact",
            "unread:permission-2",
            "sound:permission-2:permission"
        ])
    }

    private static func peek(
        id: String,
        category: NotificationEventCategory,
        dedupeKey: String? = nil,
        soundCategory: NotificationSoundCategory? = nil
    ) -> PeekNotification {
        PeekNotification(
            id: id,
            category: category,
            sessionId: "session-1",
            agent: "codex",
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

    @MainActor
    private func row(
        id: String,
        notification: PeekNotification,
        policyInput: NotificationPolicyInput
    ) -> NotificationCoordinatorControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitNotificationCoordinatorController(
            publishPeek: { notification in
                events.append("peek:\(notification.id)")
            },
            markUnread: { notification in
                events.append("unread:\(notification.id)")
            },
            requestSound: { request in
                events.append("sound:\(request.notificationId):\(request.category.rawValue)")
            }
        )

        let plan = controller.deliver(notification, policyInput: policyInput)

        return NotificationCoordinatorControllerMatrixRow(
            id: id,
            notificationId: notification.id,
            plan: NotificationDeliveryPlanSummary(plan),
            lastPlan: controller.lastPlan.map(NotificationDeliveryPlanSummary.init),
            presentationLastAction: nil,
            events: events
        )
    }

    @MainActor
    private func presentationBoundaryRow(
        id: String,
        notification: PeekNotification,
        policyInput: NotificationPolicyInput
    ) -> NotificationCoordinatorControllerMatrixRow {
        var events: [String] = []
        let presentationController = MyVibeIslandAppKitNotificationPresentationController(
            presentPeek: { notification in
                events.append("peek:\(notification.notification.id):\(notification.presentation.rawValue)")
            },
            markUnread: { notification in
                events.append("unread:\(notification.id)")
            },
            requestSound: { request in
                events.append("sound:\(request.notificationId):\(request.category.rawValue)")
            }
        )
        let controller = MyVibeIslandAppKitNotificationCoordinatorController(
            presentationController: presentationController
        )

        let plan = controller.deliver(notification, policyInput: policyInput)

        return NotificationCoordinatorControllerMatrixRow(
            id: id,
            notificationId: notification.id,
            plan: NotificationDeliveryPlanSummary(plan),
            lastPlan: controller.lastPlan.map(NotificationDeliveryPlanSummary.init),
            presentationLastAction: presentationController.lastAction.map(
                NotificationCoordinatorPresentationActionSummary.init
            ),
            events: events
        )
    }
}

private struct NotificationCoordinatorControllerMatrixFixture: Codable, Equatable {
    let rows: [NotificationCoordinatorControllerMatrixRow]
}

private struct NotificationCoordinatorControllerMatrixRow: Codable, Equatable {
    let id: String
    let notificationId: String
    let plan: NotificationDeliveryPlanSummary
    let lastPlan: NotificationDeliveryPlanSummary?
    let presentationLastAction: NotificationCoordinatorPresentationActionSummary?
    let events: [String]
}

private struct NotificationDeliveryPlanSummary: Codable, Equatable {
    let notificationId: String
    let route: String
    let reason: String
    let publishPeek: Bool
    let markUnread: Bool
    let soundCategory: String?

    init(_ plan: NotificationDeliveryPlan) {
        self.notificationId = plan.notification.id
        self.route = plan.decision.route.rawValue
        self.reason = plan.decision.reason.rawValue
        self.publishPeek = plan.publishPeek
        self.markUnread = plan.markUnread
        self.soundCategory = plan.soundRequest?.category.rawValue
    }
}

private struct NotificationCoordinatorPresentationActionSummary: Codable, Equatable {
    let kind: String
    let notificationId: String
    let presentation: String?
    let soundCategory: String?

    init(_ action: MyVibeIslandAppKitNotificationPresentationAction) {
        switch action {
        case let .presentPeek(notification):
            self.kind = "presentPeek"
            self.notificationId = notification.notification.id
            self.presentation = notification.presentation.rawValue
            self.soundCategory = nil
        case let .markUnread(notification):
            self.kind = "markUnread"
            self.notificationId = notification.id
            self.presentation = nil
            self.soundCategory = nil
        case let .requestSound(request):
            self.kind = "requestSound"
            self.notificationId = request.notificationId
            self.presentation = nil
            self.soundCategory = request.category.rawValue
        }
    }
}
