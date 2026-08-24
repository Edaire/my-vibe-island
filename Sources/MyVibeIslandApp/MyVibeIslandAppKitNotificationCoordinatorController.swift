import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitNotificationCoordinatorController {
    public private(set) var lastPlan: NotificationDeliveryPlan?

    private let coordinator: NotificationCoordinator
    private let silenceRulesProvider: @MainActor () -> SilenceRulesSnapshot
    private let publishPeek: @MainActor (PeekNotification) -> Void
    private let markUnread: @MainActor (PeekNotification) -> Void
    private let requestSound: @MainActor (NotificationSoundRequest) -> Void

    public init(
        coordinator: NotificationCoordinator = NotificationCoordinator(),
        silenceRulesProvider: @escaping @MainActor () -> SilenceRulesSnapshot = { SilenceRulesSnapshot() },
        publishPeek: @escaping @MainActor (PeekNotification) -> Void = { _ in },
        markUnread: @escaping @MainActor (PeekNotification) -> Void = { _ in },
        requestSound: @escaping @MainActor (NotificationSoundRequest) -> Void = { _ in }
    ) {
        self.coordinator = coordinator
        self.silenceRulesProvider = silenceRulesProvider
        self.publishPeek = publishPeek
        self.markUnread = markUnread
        self.requestSound = requestSound
    }

    public convenience init(
        coordinator: NotificationCoordinator = NotificationCoordinator(),
        silenceRulesProvider: @escaping @MainActor () -> SilenceRulesSnapshot = { SilenceRulesSnapshot() },
        presentationController: MyVibeIslandAppKitNotificationPresentationController
    ) {
        self.init(
            coordinator: coordinator,
            silenceRulesProvider: silenceRulesProvider,
            publishPeek: { notification in
                presentationController.presentPeek(notification)
            },
            markUnread: { notification in
                presentationController.markUnread(notification)
            },
            requestSound: { request in
                presentationController.requestSound(request)
            }
        )
    }

    @discardableResult
    public func deliver(
        _ notification: PeekNotification,
        policyInput: NotificationPolicyInput,
        silenceRules: SilenceRulesSnapshot? = nil
    ) -> NotificationDeliveryPlan {
        let plan = coordinator.planDelivery(
            notification,
            policyInput: policyInput,
            silenceRules: silenceRules ?? silenceRulesProvider()
        )
        lastPlan = plan
        if notification.category == .sessionCompleted {
            SessionCompletionTraceLog.append(
                stage: "notification.deliver",
                sessionId: notification.sessionId ?? notification.id,
                metadata: [
                    "route": plan.decision.route.rawValue,
                    "reason": plan.decision.reason.rawValue,
                    "publishPeek": String(plan.publishPeek),
                    "markUnread": String(plan.markUnread),
                    "sound": plan.soundRequest?.category.rawValue ?? "nil",
                ]
            )
        }

        if plan.publishPeek {
            publishPeek(plan.notification)
        }
        if plan.markUnread {
            markUnread(plan.notification)
        }
        if let soundRequest = plan.soundRequest {
            SessionCompletionTraceLog.append(
                stage: "notification.sound_requested",
                sessionId: notification.sessionId ?? notification.id,
                metadata: [
                    "notificationId": soundRequest.notificationId,
                    "category": soundRequest.category.rawValue,
                    "source": soundRequest.source,
                ]
            )
            requestSound(soundRequest)
        }

        return plan
    }
}
