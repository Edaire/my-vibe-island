import Foundation

public enum NotificationPolicyRoute: String, Codable, Equatable, Sendable {
    case showPeek
    case updateUnreadOnly
    case playSoundOnly
    case suppressEntirely
}

public enum NotificationPolicyReason: String, Codable, Equatable, Sendable {
    case defaultPolicy
    case activityUpdateSuppressed
    case recentlyRevealed
    case silenceRuleMatched
}

public struct NotificationPolicyInput: Codable, Equatable, Sendable {
    public let category: NotificationEventCategory
    public let sessionId: String?
    public let agent: String?
    public let workspace: String?
    public let timeWindowKey: String?
    public let dedupeKey: String?
    public let recentRevealKeys: [String]
    public let silenceRules: [SilenceRule]

    public init(
        category: NotificationEventCategory,
        sessionId: String? = nil,
        agent: String? = nil,
        workspace: String? = nil,
        timeWindowKey: String? = nil,
        dedupeKey: String? = nil,
        recentRevealKeys: [String] = [],
        silenceRules: [SilenceRule] = []
    ) {
        self.category = category
        self.sessionId = sessionId
        self.agent = agent
        self.workspace = workspace
        self.timeWindowKey = timeWindowKey
        self.dedupeKey = dedupeKey
        self.recentRevealKeys = recentRevealKeys
        self.silenceRules = silenceRules
    }
}

public struct NotificationPolicyDecision: Codable, Equatable, Sendable {
    public let route: NotificationPolicyRoute
    public let shouldPlaySound: Bool
    public let shouldMarkUnread: Bool
    public let reason: NotificationPolicyReason

    public init(
        route: NotificationPolicyRoute,
        shouldPlaySound: Bool,
        shouldMarkUnread: Bool,
        reason: NotificationPolicyReason
    ) {
        self.route = route
        self.shouldPlaySound = shouldPlaySound
        self.shouldMarkUnread = shouldMarkUnread
        self.reason = reason
    }
}

public struct NotificationPolicy: Sendable {
    public init() {}

    public func decision(for input: NotificationPolicyInput) -> NotificationPolicyDecision {
        if let silenceAction = input.silenceRules.first(where: { $0.enabled && $0.matcher.matches(input) })?.action {
            let defaultDecision = defaultDecision(for: input.category)
            return NotificationPolicyDecision(
                route: silenceAction.suppressesPeek ? .updateUnreadOnly : defaultDecision.route,
                shouldPlaySound: silenceAction.suppressesSound ? false : defaultDecision.shouldPlaySound,
                shouldMarkUnread: defaultDecision.shouldMarkUnread,
                reason: .silenceRuleMatched
            )
        }

        if let dedupeKey = input.dedupeKey, input.recentRevealKeys.contains(dedupeKey) {
            return NotificationPolicyDecision(
                route: .suppressEntirely,
                shouldPlaySound: false,
                shouldMarkUnread: false,
                reason: .recentlyRevealed
            )
        }

        return defaultDecision(for: input.category)
    }

    private func defaultDecision(for category: NotificationEventCategory) -> NotificationPolicyDecision {
        switch category {
        case .permissionRequested, .questionAsked, .sessionFailed:
            return NotificationPolicyDecision(
                route: .showPeek,
                shouldPlaySound: true,
                shouldMarkUnread: true,
                reason: .defaultPolicy
            )
        case .sessionCompleted:
            return NotificationPolicyDecision(
                route: .showPeek,
                shouldPlaySound: true,
                shouldMarkUnread: true,
                reason: .defaultPolicy
            )
        case .usageThreshold, .usageLimit, .usageReset, .remoteDisconnected:
            return NotificationPolicyDecision(
                route: .showPeek,
                shouldPlaySound: false,
                shouldMarkUnread: false,
                reason: .defaultPolicy
            )
        case .agentWarning, .integrationRepairNeeded:
            return NotificationPolicyDecision(
                route: .showPeek,
                shouldPlaySound: false,
                shouldMarkUnread: false,
                reason: .defaultPolicy
            )
        case .activityUpdate:
            return NotificationPolicyDecision(
                route: .suppressEntirely,
                shouldPlaySound: false,
                shouldMarkUnread: false,
                reason: .activityUpdateSuppressed
            )
        }
    }
}
