import Foundation

public enum UsageNotificationSuppressionReason: String, Codable, Equatable, Sendable {
    case notificationsDisabled
    case alreadyDelivered
}

public enum UsageNotificationDeliveryAction: Codable, Equatable, Sendable {
    case deliver(UsagePeekNotificationPayload)
    case suppress(dedupeKey: String, reason: UsageNotificationSuppressionReason)
}

public struct UsageNotificationDeliveryPlan: Codable, Equatable, Sendable {
    public let actions: [UsageNotificationDeliveryAction]

    public init(actions: [UsageNotificationDeliveryAction]) {
        self.actions = actions
    }

    public var deliverablePayloads: [UsagePeekNotificationPayload] {
        actions.compactMap { action in
            guard case let .deliver(payload) = action else {
                return nil
            }
            return payload
        }
    }

    public var suppressedKeys: [String] {
        actions.compactMap { action in
            guard case let .suppress(dedupeKey, _) = action else {
                return nil
            }
            return dedupeKey
        }
    }

    public static func make(
        payloads: [UsagePeekNotificationPayload],
        deliveredKeys: Set<String>,
        notificationsEnabled: Bool
    ) -> UsageNotificationDeliveryPlan {
        let actions = payloads.map { payload -> UsageNotificationDeliveryAction in
            guard notificationsEnabled else {
                return .suppress(
                    dedupeKey: payload.dedupeKey,
                    reason: .notificationsDisabled
                )
            }

            guard !deliveredKeys.contains(payload.dedupeKey) else {
                return .suppress(
                    dedupeKey: payload.dedupeKey,
                    reason: .alreadyDelivered
                )
            }

            return .deliver(payload)
        }

        return UsageNotificationDeliveryPlan(actions: actions)
    }
}
