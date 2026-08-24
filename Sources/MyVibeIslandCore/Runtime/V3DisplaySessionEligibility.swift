import Foundation

/// Exact reflected V3 policy shape. The policy is derived alongside a session
/// publication and is consumed by the display-decision path; it is not a
/// session-store retention decision.
public struct V3SensoryPolicy: Equatable, Sendable {
    public let hidePanel: Bool
    public let muteSound: Bool
    public let suppressExpand: Bool
    public let autoDismissOnStop: Bool
    public let matchedRuleIds: [UUID]

    public static let none = V3SensoryPolicy(
        hidePanel: false,
        muteSound: false,
        suppressExpand: false,
        autoDismissOnStop: false,
        matchedRuleIds: []
    )

    public init(
        hidePanel: Bool,
        muteSound: Bool,
        suppressExpand: Bool,
        autoDismissOnStop: Bool,
        matchedRuleIds: [UUID]
    ) {
        self.hidePanel = hidePanel
        self.muteSound = muteSound
        self.suppressExpand = suppressExpand
        self.autoDismissOnStop = autoDismissOnStop
        self.matchedRuleIds = matchedRuleIds
    }
}

/// Exact reflected V3 carrier passed to display decision resolution after a
/// session receipt has been accepted and published on the MainActor.
public struct V3DisplaySessionEligibility: Equatable, Sendable {
    public let session: AgentSession
    public let policy: V3SensoryPolicy
    public let usedEventShell: Bool

    public var isHidden: Bool { policy.hidePanel }

    public init(session: AgentSession, policy: V3SensoryPolicy, usedEventShell: Bool) {
        self.session = session
        self.policy = policy
        self.usedEventShell = usedEventShell
    }
}

public enum V3SilenceMatchField: String, Codable, Equatable, Sendable {
    case title
    case firstUserPrompt
    case cli
    case toolName
    case cwd
    case originator
    case subagentKind
    case permissionMode
}

public enum V3SilenceMatchType: String, Codable, Equatable, Sendable {
    case contains
    case equals
    case prefix
}

public struct V3SilenceMatcher: Codable, Equatable, Sendable {
    public let field: V3SilenceMatchField
    public let matchType: V3SilenceMatchType
    public let pattern: String
    public let caseSensitive: Bool

    public init(
        field: V3SilenceMatchField,
        matchType: V3SilenceMatchType,
        pattern: String,
        caseSensitive: Bool = false
    ) {
        self.field = field
        self.matchType = matchType
        self.pattern = pattern
        self.caseSensitive = caseSensitive
    }
}

public struct V3SilenceAction: Codable, Equatable, Sendable {
    public let hidePanel: Bool
    public let muteSound: Bool
    public let suppressExpand: Bool
    public let autoDismissOnStop: Bool

    public init(
        hidePanel: Bool,
        muteSound: Bool,
        suppressExpand: Bool,
        autoDismissOnStop: Bool
    ) {
        self.hidePanel = hidePanel
        self.muteSound = muteSound
        self.suppressExpand = suppressExpand
        self.autoDismissOnStop = autoDismissOnStop
    }
}

public struct V3SilenceRule: Codable, Equatable, Sendable {
    public let id: UUID
    public let isEnabled: Bool
    public let matchers: [V3SilenceMatcher]
    public let action: V3SilenceAction

    public init(
        id: UUID,
        isEnabled: Bool,
        matchers: [V3SilenceMatcher],
        action: V3SilenceAction
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.matchers = matchers
        self.action = action
    }
}

/// V3 `sub_10058D33C` evaluates enabled rules and returns the accumulated
/// SensoryPolicy. Unsupported source fields deliberately never match rather
/// than being guessed from unrelated local state.
public struct V3SensoryPolicyResolver: Sendable {
    public let rules: [V3SilenceRule]

    public init(rules: [V3SilenceRule]) {
        self.rules = rules
    }

    public func resolve(for session: AgentSession) -> V3SensoryPolicy {
        var policy = V3SensoryPolicy.none

        for rule in rules where rule.isEnabled && rule.matches(session) {
            policy = V3SensoryPolicy(
                hidePanel: policy.hidePanel || rule.action.hidePanel,
                muteSound: policy.muteSound || rule.action.muteSound,
                suppressExpand: policy.suppressExpand || rule.action.suppressExpand,
                autoDismissOnStop: policy.autoDismissOnStop || rule.action.autoDismissOnStop,
                matchedRuleIds: policy.matchedRuleIds + [rule.id]
            )
        }

        return policy
    }
}

private extension V3SilenceRule {
    func matches(_ session: AgentSession) -> Bool {
        !matchers.isEmpty && matchers.allSatisfy { $0.matches(session) }
    }
}

private extension V3SilenceMatcher {
    func matches(_ session: AgentSession) -> Bool {
        guard let candidate = value(from: session) else { return false }
        let lhs = caseSensitive ? candidate : candidate.lowercased()
        let rhs = caseSensitive ? pattern : pattern.lowercased()

        switch matchType {
        case .contains:
            return lhs.contains(rhs)
        case .equals:
            return lhs == rhs
        case .prefix:
            return lhs.hasPrefix(rhs)
        }
    }

    func value(from session: AgentSession) -> String? {
        switch field {
        case .title:
            nil
        case .firstUserPrompt:
            session.firstUserMessage
        case .cli:
            session.source
        case .toolName:
            session.activeTool
        case .cwd:
            session.cwd
        case .permissionMode:
            session.permissionMode
        case .originator, .subagentKind:
            nil
        }
    }
}
