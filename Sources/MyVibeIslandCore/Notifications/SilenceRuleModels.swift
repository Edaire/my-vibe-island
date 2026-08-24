import Foundation

public enum SilenceRuleScope: String, Codable, Equatable, Sendable {
    case agent
    case workspace
    case session
    case category
    case timeWindow
}

public struct SilenceMatcher: Codable, Equatable, Sendable {
    public let scope: SilenceRuleScope
    public let target: String

    public init(
        scope: SilenceRuleScope,
        target: String
    ) {
        self.scope = scope
        self.target = target
    }

    public func matches(_ input: NotificationPolicyInput) -> Bool {
        switch scope {
        case .agent:
            return input.agent == target
        case .workspace:
            return input.workspace == target
        case .session:
            return input.sessionId == target
        case .category:
            return input.category.rawValue == target
        case .timeWindow:
            return input.timeWindowKey == target
        }
    }
}

public struct SilenceAction: Codable, Equatable, Sendable {
    public let suppressesPeek: Bool
    public let suppressesSound: Bool

    public init(
        suppressesPeek: Bool,
        suppressesSound: Bool
    ) {
        self.suppressesPeek = suppressesPeek
        self.suppressesSound = suppressesSound
    }
}

public struct SilenceRule: Codable, Equatable, Sendable {
    public let id: String
    public let enabled: Bool
    public let matcher: SilenceMatcher
    public let action: SilenceAction
    public let expiresAt: String?
    public let createdAt: String

    public init(
        id: String,
        enabled: Bool,
        matcher: SilenceMatcher,
        action: SilenceAction,
        expiresAt: String? = nil,
        createdAt: String
    ) {
        self.id = id
        self.enabled = enabled
        self.matcher = matcher
        self.action = action
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}
