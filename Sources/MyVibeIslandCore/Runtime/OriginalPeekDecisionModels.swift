public enum OriginalPeekExpansion: String, Codable, Equatable, Sendable {
    case none
    case peek
}

public enum OriginalPeekTimerPolicy: String, Codable, Equatable, Sendable {
    case unchanged
    case cancel
    case transient
}

public enum OriginalPeekHoverPolicy: Codable, Equatable, Sendable {
    case unchanged
    case shortCooldown(Double)
}

public enum OriginalPeekDecisionIntent: Codable, Equatable, Sendable {
    case peek(OriginalPeekNotification, kind: OriginalPeekTransientKind)
    case collapseAutoTransient
}

public struct OriginalPeekDecision: Codable, Equatable, Sendable {
    public let accepted: Bool
    public let reason: String
    public let nextState: OriginalPeekDisplayState
    public let focusSessionId: String?
    public let activeSessionId: String?
    public let expansion: OriginalPeekExpansion
    public let timerPolicy: OriginalPeekTimerPolicy
    public let hoverPolicy: OriginalPeekHoverPolicy

    public init(
        accepted: Bool,
        reason: String,
        nextState: OriginalPeekDisplayState,
        focusSessionId: String?,
        activeSessionId: String?,
        expansion: OriginalPeekExpansion,
        timerPolicy: OriginalPeekTimerPolicy,
        hoverPolicy: OriginalPeekHoverPolicy
    ) {
        self.accepted = accepted
        self.reason = reason
        self.nextState = nextState
        self.focusSessionId = focusSessionId
        self.activeSessionId = activeSessionId
        self.expansion = expansion
        self.timerPolicy = timerPolicy
        self.hoverPolicy = hoverPolicy
    }

    public static func resolve(_ intent: OriginalPeekDecisionIntent) -> Self {
        switch intent {
        case let .peek(notification, kind):
            return Self(
                accepted: true,
                reason: "peek accepted",
                nextState: .peek(notification, kind: kind),
                focusSessionId: nil,
                activeSessionId: nil,
                expansion: .peek,
                timerPolicy: kind == .taskComplete ? .transient : .unchanged,
                hoverPolicy: .unchanged
            )
        case .collapseAutoTransient:
            return Self(
                accepted: true,
                reason: "collapse",
                nextState: .closed,
                focusSessionId: nil,
                activeSessionId: nil,
                expansion: .none,
                timerPolicy: .cancel,
                hoverPolicy: .shortCooldown(0.6)
            )
        }
    }
}
