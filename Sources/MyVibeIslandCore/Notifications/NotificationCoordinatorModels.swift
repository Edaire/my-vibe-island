import Foundation

public struct NotificationSoundRequest: Codable, Equatable, Sendable {
    public let notificationId: String
    public let category: NotificationSoundCategory
    public let source: String

    public init(
        notificationId: String,
        category: NotificationSoundCategory,
        source: String
    ) {
        self.notificationId = notificationId
        self.category = category
        self.source = source
    }
}

public struct NotificationDeliveryPlan: Codable, Equatable, Sendable {
    public let notification: PeekNotification
    public let decision: NotificationPolicyDecision
    public let publishPeek: Bool
    public let markUnread: Bool
    public let soundRequest: NotificationSoundRequest?

    public init(
        notification: PeekNotification,
        decision: NotificationPolicyDecision,
        publishPeek: Bool,
        markUnread: Bool,
        soundRequest: NotificationSoundRequest?
    ) {
        self.notification = notification
        self.decision = decision
        self.publishPeek = publishPeek
        self.markUnread = markUnread
        self.soundRequest = soundRequest
    }
}

public struct NotificationCoordinator: Sendable {
    private let policy: NotificationPolicy

    public init(policy: NotificationPolicy = NotificationPolicy()) {
        self.policy = policy
    }

    public func planDelivery(
        _ notification: PeekNotification,
        policyInput: NotificationPolicyInput,
        silenceRules: SilenceRulesSnapshot = SilenceRulesSnapshot()
    ) -> NotificationDeliveryPlan {
        let input = NotificationPolicyInput(
            category: policyInput.category,
            sessionId: policyInput.sessionId,
            agent: policyInput.agent,
            workspace: policyInput.workspace,
            timeWindowKey: policyInput.timeWindowKey,
            dedupeKey: policyInput.dedupeKey,
            recentRevealKeys: policyInput.recentRevealKeys,
            silenceRules: silenceRules.effectiveRules + policyInput.silenceRules
        )
        let decision = policy.decision(for: input)

        return NotificationDeliveryPlan(
            notification: notification,
            decision: decision,
            publishPeek: decision.route == .showPeek,
            markUnread: decision.shouldMarkUnread,
            soundRequest: soundRequest(for: notification, decision: decision)
        )
    }

    private func soundRequest(
        for notification: PeekNotification,
        decision: NotificationPolicyDecision
    ) -> NotificationSoundRequest? {
        guard decision.shouldPlaySound,
              let category = notification.soundCategory
        else {
            return nil
        }

        return NotificationSoundRequest(
            notificationId: notification.id,
            category: category,
            source: notification.source
        )
    }
}
