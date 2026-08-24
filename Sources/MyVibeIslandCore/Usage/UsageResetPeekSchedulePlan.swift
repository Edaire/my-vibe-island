import Foundation

public enum UsageResetPeekScheduleAction: Codable, Equatable, Sendable {
    case schedule(UsagePeekIntent)
    case cancel(dedupeKey: String)
}

public struct UsageResetPeekSchedulePlan: Codable, Equatable, Sendable {
    public let actions: [UsageResetPeekScheduleAction]

    public init(actions: [UsageResetPeekScheduleAction]) {
        self.actions = actions
    }

    public var scheduledIntents: [UsagePeekIntent] {
        actions.compactMap { action in
            guard case let .schedule(intent) = action else {
                return nil
            }
            return intent
        }
    }

    public var canceledKeys: [String] {
        actions.compactMap { action in
            guard case let .cancel(dedupeKey) = action else {
                return nil
            }
            return dedupeKey
        }
    }

    public static func make(
        currentIntents: [UsagePeekIntent],
        scheduledResetKeys: Set<String>
    ) -> UsageResetPeekSchedulePlan {
        let resetIntents = currentIntents.filter(\.isResetPeek)
        let currentResetKeys = Set(resetIntents.map(\.dedupeKey))

        let scheduleActions = resetIntents
            .filter { !scheduledResetKeys.contains($0.dedupeKey) }
            .map(UsageResetPeekScheduleAction.schedule)
        let cancelActions = scheduledResetKeys
            .subtracting(currentResetKeys)
            .sorted()
            .map { UsageResetPeekScheduleAction.cancel(dedupeKey: $0) }

        return UsageResetPeekSchedulePlan(actions: scheduleActions + cancelActions)
    }
}

private extension UsagePeekIntent {
    var isResetPeek: Bool {
        guard case .windowReset = kind else {
            return false
        }
        return true
    }
}
