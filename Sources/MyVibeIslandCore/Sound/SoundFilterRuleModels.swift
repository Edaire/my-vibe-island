import Foundation

public enum SoundFilterRuleType: String, Codable, Equatable, Sendable {
    case category
    case source
    case lifecycle
    case subagentState
}

public enum SoundFilterAction: String, Codable, Equatable, Sendable {
    case allowSound
    case suppressSound
}

public enum SoundFilterPendingLifecycleEvent: String, Codable, Equatable, Sendable {
    case started
    case waiting
    case completed
    case failed
}

public enum SoundFilterPendingSubagentState: String, Codable, Equatable, Sendable {
    case idle
    case active
    case blocked
    case completed
}

public struct SoundFilterRule: Codable, Equatable, Sendable {
    public let id: String
    public let type: SoundFilterRuleType
    public let action: SoundFilterAction
    public let isEnabled: Bool
    public let priority: Int
    public let category: NotificationSoundCategory?
    public let source: String?
    public let lifecycleEvent: SoundFilterPendingLifecycleEvent?
    public let subagentState: SoundFilterPendingSubagentState?
    public let cooldownSeconds: Int
    public let reason: String?

    public init(
        id: String,
        type: SoundFilterRuleType,
        action: SoundFilterAction,
        isEnabled: Bool = true,
        priority: Int = 0,
        category: NotificationSoundCategory? = nil,
        source: String? = nil,
        lifecycleEvent: SoundFilterPendingLifecycleEvent? = nil,
        subagentState: SoundFilterPendingSubagentState? = nil,
        cooldownSeconds: Int = 0,
        reason: String? = nil
    ) {
        self.id = id
        self.type = type
        self.action = action
        self.isEnabled = isEnabled
        self.priority = priority
        self.category = category
        self.source = source
        self.lifecycleEvent = lifecycleEvent
        self.subagentState = subagentState
        self.cooldownSeconds = cooldownSeconds
        self.reason = reason
    }

    public func matches(_ input: SoundFilterInput) -> Bool {
        if let category, category != input.category {
            return false
        }
        if let source, source != input.source {
            return false
        }
        if let lifecycleEvent, lifecycleEvent != input.lifecycleEvent {
            return false
        }
        if let subagentState, subagentState != input.subagentState {
            return false
        }
        return true
    }
}

public struct SoundFilterInput: Codable, Equatable, Sendable {
    public let category: NotificationSoundCategory
    public let source: String?
    public let lifecycleEvent: SoundFilterPendingLifecycleEvent?
    public let subagentState: SoundFilterPendingSubagentState?

    public init(
        category: NotificationSoundCategory,
        source: String? = nil,
        lifecycleEvent: SoundFilterPendingLifecycleEvent? = nil,
        subagentState: SoundFilterPendingSubagentState? = nil
    ) {
        self.category = category
        self.source = source
        self.lifecycleEvent = lifecycleEvent
        self.subagentState = subagentState
    }
}

public struct SoundFilterDecision: Codable, Equatable, Sendable {
    public let isAllowed: Bool
    public let category: NotificationSoundCategory
    public let matchedRuleId: String?
    public let reason: String?

    public init(
        isAllowed: Bool,
        category: NotificationSoundCategory,
        matchedRuleId: String? = nil,
        reason: String? = nil
    ) {
        self.isAllowed = isAllowed
        self.category = category
        self.matchedRuleId = matchedRuleId
        self.reason = reason
    }
}

public struct SoundFilter: Codable, Equatable, Sendable {
    public let autoDetectProbes: Bool
    public let rules: [SoundFilterRule]

    public init(
        autoDetectProbes: Bool = false,
        rules: [SoundFilterRule] = []
    ) {
        self.autoDetectProbes = autoDetectProbes
        self.rules = rules
    }

    public func decision(for input: SoundFilterInput) -> SoundFilterDecision {
        let matchingRule = rules
            .filter(\.isEnabled)
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.id < rhs.id
                }
                return lhs.priority > rhs.priority
            }
            .first { $0.matches(input) }

        guard let matchingRule else {
            return SoundFilterDecision(isAllowed: true, category: input.category)
        }

        return SoundFilterDecision(
            isAllowed: matchingRule.action == .allowSound,
            category: input.category,
            matchedRuleId: matchingRule.id,
            reason: matchingRule.reason
        )
    }
}
