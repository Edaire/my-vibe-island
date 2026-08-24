/// Recovered from Vibe Island 3 Swift reflection metadata. These types model
/// the original decision output only; they deliberately do not resolve local
/// presentation predicates until those predicates are recovered.
public enum V3DisplayCollapseReason: String, Codable, Equatable, Sendable {
    case manual
    case autoTransient
    case system
}

public enum V3DisplayFocusMutation: Codable, Equatable, Sendable {
    case set(String?)
    case unchanged
}

public enum V3DisplayExpansion: Codable, Equatable, Sendable {
    case collapse(V3DisplayCollapseReason)
    case none
    case expand
    case peek
}

public enum V3DisplayTimerPolicy: Codable, Equatable, Sendable {
    case transient(TransientAutoRevealKind)
    case unchanged
    case cancel
}

public enum V3DisplayHoverPolicy: Codable, Equatable, Sendable {
    case unchanged
    case shortCooldown
}

/// The reflected V3 state cases. Payload layouts are intentionally not modeled
/// here because their exact source types have not yet been recovered.
public enum V3NotchDisplayState: String, Codable, Equatable, Sendable {
    case peek
    case blocking
    case transient
    case closed
    case manualExpanded
}

/// Exact reflected shape of the V3 decision passed from the resolver to its
/// accepted-decision consumer.
public struct V3DisplayDecision: Codable, Equatable, Sendable {
    public let accepted: Bool
    public let reason: String
    public let nextState: V3NotchDisplayState?
    public let focus: V3DisplayFocusMutation
    public let activeSessionId: V3DisplayFocusMutation
    public let expansion: V3DisplayExpansion
    public let timerPolicy: V3DisplayTimerPolicy
    public let hoverPolicy: V3DisplayHoverPolicy

    public init(
        accepted: Bool,
        reason: String,
        nextState: V3NotchDisplayState?,
        focus: V3DisplayFocusMutation,
        activeSessionId: V3DisplayFocusMutation,
        expansion: V3DisplayExpansion,
        timerPolicy: V3DisplayTimerPolicy,
        hoverPolicy: V3DisplayHoverPolicy
    ) {
        self.accepted = accepted
        self.reason = reason
        self.nextState = nextState
        self.focus = focus
        self.activeSessionId = activeSessionId
        self.expansion = expansion
        self.timerPolicy = timerPolicy
        self.hoverPolicy = hoverPolicy
    }
}

public enum V3DisplayDecisionConsumerOperation: Equatable, Sendable {
    case setNextState(V3NotchDisplayState)
    case setFocus(String?)
    case setActiveSessionId(String?)
    case applyExpansion(V3DisplayExpansion)
    case scheduleTransientTimer(TransientAutoRevealKind)
    case startShortHoverCooldown(until: Double)
}

public struct V3DisplayDecisionConsumerPlan: Equatable, Sendable {
    public let operations: [V3DisplayDecisionConsumerOperation]

    public init(operations: [V3DisplayDecisionConsumerOperation]) {
        self.operations = operations
    }
}

/// Pure representation of the parts of `sub_1000FCC00` proven from V3:
/// optional state, focus, active session, expansion, transient timer, then
/// hover cooldown. The caller remains responsible for the `accepted` gate.
public enum V3DisplayDecisionConsumer {
    public static let shortHoverCooldownSeconds = 0.6

    public static func plan(
        _ decision: V3DisplayDecision,
        now: Double
    ) -> V3DisplayDecisionConsumerPlan {
        var operations: [V3DisplayDecisionConsumerOperation] = []

        if let nextState = decision.nextState {
            operations.append(.setNextState(nextState))
        }
        if case let .set(sessionId) = decision.focus {
            operations.append(.setFocus(sessionId))
        }
        if case let .set(sessionId) = decision.activeSessionId {
            operations.append(.setActiveSessionId(sessionId))
        }
        if decision.expansion != .none {
            operations.append(.applyExpansion(decision.expansion))
        }
        if case let .transient(kind) = decision.timerPolicy {
            operations.append(.scheduleTransientTimer(kind))
        }
        if decision.hoverPolicy == .shortCooldown {
            operations.append(
                .startShortHoverCooldown(until: now + shortHoverCooldownSeconds)
            )
        }

        return V3DisplayDecisionConsumerPlan(operations: operations)
    }
}

/// The completion preconditions reached by `sub_10010AEE4` before it delegates
/// to the display-decision consumer. This carries only predicates proven by
/// the matching V3 assembly; terminal-focus resolution remains an external
/// input because its provider has not yet been reconstructed locally.
public struct V3TaskCompletionInput: Equatable, Sendable {
    public let onboardingActive: Bool
    public let blockingExpanded: Bool
    public let targetSessionExists: Bool
    public let targetSessionIsComplete: Bool
    public let quietSceneActive: Bool
    public let autoExpandOnTaskComplete: Bool
    public let decision: V3DisplayDecision
    public let automaticExpansionGateAccepted: Bool

    public init(
        onboardingActive: Bool,
        blockingExpanded: Bool,
        targetSessionExists: Bool,
        targetSessionIsComplete: Bool,
        quietSceneActive: Bool,
        autoExpandOnTaskComplete: Bool,
        decision: V3DisplayDecision,
        automaticExpansionGateAccepted: Bool
    ) {
        self.onboardingActive = onboardingActive
        self.blockingExpanded = blockingExpanded
        self.targetSessionExists = targetSessionExists
        self.targetSessionIsComplete = targetSessionIsComplete
        self.quietSceneActive = quietSceneActive
        self.autoExpandOnTaskComplete = autoExpandOnTaskComplete
        self.decision = decision
        self.automaticExpansionGateAccepted = automaticExpansionGateAccepted
    }

    public init(
        base: V3TaskCompletionInput,
        onboardingActive: Bool? = nil,
        blockingExpanded: Bool? = nil,
        targetSessionExists: Bool? = nil,
        targetSessionIsComplete: Bool? = nil,
        quietSceneActive: Bool? = nil,
        autoExpandOnTaskComplete: Bool? = nil,
        decision: V3DisplayDecision? = nil,
        automaticExpansionGateAccepted: Bool? = nil
    ) {
        self.init(
            onboardingActive: onboardingActive ?? base.onboardingActive,
            blockingExpanded: blockingExpanded ?? base.blockingExpanded,
            targetSessionExists: targetSessionExists ?? base.targetSessionExists,
            targetSessionIsComplete: targetSessionIsComplete ?? base.targetSessionIsComplete,
            quietSceneActive: quietSceneActive ?? base.quietSceneActive,
            autoExpandOnTaskComplete: autoExpandOnTaskComplete ?? base.autoExpandOnTaskComplete,
            decision: decision ?? base.decision,
            automaticExpansionGateAccepted: automaticExpansionGateAccepted
                ?? base.automaticExpansionGateAccepted
        )
    }
}

public enum V3TaskCompletionSuppression: Equatable, Sendable {
    case onboarding
    case blockingExpanded
    case missingTargetSession
    case targetNotComplete
    case rejectedDecision
}

/// The result of the task-completion path before the generic decision consumer
/// (`sub_1000FCC00`) runs.
public enum V3TaskCompletionPlan: Equatable, Sendable {
    case suppressed(V3TaskCompletionSuppression)
    case markQuietScenePending
    case incrementCompletionFlash
    case leaveAcceptedDecisionUnconsumed
    case consumeDecision(V3DisplayDecision)
}

/// Pure model of the V3 task-completion control flow in `sub_10010AEE4`.
/// The original first rejects onboarding, blocking-expanded, absent, and
/// incomplete targets. Quiet scenes become pending; only then may an accepted
/// decision produce either a flash or, after the terminal-focus gate accepts,
/// its normal consumer side effects.
public enum V3TaskCompletionConsumer {
    public static func plan(_ input: V3TaskCompletionInput) -> V3TaskCompletionPlan {
        if input.onboardingActive {
            return .suppressed(.onboarding)
        }
        if input.blockingExpanded {
            return .suppressed(.blockingExpanded)
        }
        if !input.targetSessionExists {
            return .suppressed(.missingTargetSession)
        }
        if !input.targetSessionIsComplete {
            return .suppressed(.targetNotComplete)
        }
        if input.quietSceneActive {
            return .markQuietScenePending
        }
        if !input.decision.accepted {
            return .suppressed(.rejectedDecision)
        }
        if !input.autoExpandOnTaskComplete {
            return .incrementCompletionFlash
        }
        if !input.automaticExpansionGateAccepted {
            return .leaveAcceptedDecisionUnconsumed
        }
        return .consumeDecision(input.decision)
    }
}

/// V3's task-complete dispatch produces a transient display decision unless a
/// manual expansion already owns the surface. The other V3 resolver branches
/// remain intentionally outside this narrow reconstruction until their input
/// predicates have matching local evidence.
public enum V3TaskCompleteDecisionResolver {
    public static func resolve(
        sessionId: String,
        currentDisplayState: V3NotchDisplayState
    ) -> V3DisplayDecision {
        resolve(
            sessionId: sessionId,
            currentDisplayState: currentDisplayState,
            policy: .none
        )
    }

    /// `sub_1000C9890` checks `SensoryPolicy.suppressExpand` at byte offset
    /// two and returns "suppressed by sensory policy" before it builds the
    /// transient display decision. The other policy bits need their own
    /// recovered consumer branches and must not be inferred here.
    public static func resolve(
        sessionId: String,
        currentDisplayState: V3NotchDisplayState,
        policy: V3SensoryPolicy
    ) -> V3DisplayDecision {
        if policy.hidePanel {
            return V3DisplayDecision(
                accepted: false,
                reason: "hidden session",
                nextState: nil,
                focus: .unchanged,
                activeSessionId: .unchanged,
                expansion: .none,
                timerPolicy: .unchanged,
                hoverPolicy: .unchanged
            )
        }

        if policy.suppressExpand {
            return V3DisplayDecision(
                accepted: false,
                reason: "suppressed by sensory policy",
                nextState: nil,
                focus: .unchanged,
                activeSessionId: .unchanged,
                expansion: .none,
                timerPolicy: .unchanged,
                hoverPolicy: .unchanged
            )
        }

        if currentDisplayState == .manualExpanded {
            return V3DisplayDecision(
                accepted: false,
                reason: "manual display active",
                nextState: nil,
                focus: .unchanged,
                activeSessionId: .unchanged,
                expansion: .none,
                timerPolicy: .unchanged,
                hoverPolicy: .unchanged
            )
        }

        return V3DisplayDecision(
            accepted: true,
            reason: "transient accepted",
            nextState: .transient,
            focus: .set(sessionId),
            activeSessionId: .set(sessionId),
            expansion: .expand,
            timerPolicy: .transient(.taskComplete),
            hoverPolicy: .shortCooldown
        )
    }
}
