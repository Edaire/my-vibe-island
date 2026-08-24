import Foundation

/// Exact reflected V3 effect cases. The selector is deliberately kept outside
/// the display-decision resolver because the original invokes it first.
public enum V3RootResponseNotificationEffect: String, Codable, Equatable, Sendable {
    case revealProgress
    case revealFinal
    case updateOnly
    case deferForAttention
    case duplicate
}

/// Strings recovered from the selector's mode comparisons.
public enum V3RootResponseNotificationMode: String, Codable, Equatable, Sendable {
    /// IDA string: `rootResponses`.
    case rootResponse = "rootResponses"
    case allChildrenFinished
    case everyChildCompletion
}

/// Reflected state owned per root session by V3's notification coordinator.
public struct V3RootResponseNotificationState: Equatable, Sendable {
    public var runtimeInstanceId: Int
    public var responseRevision: Int
    public var lastResponseIdentity: String?
    public var lastNotifiedRevision: Int
    public var lastViewedRevision: Int
    public var becameUnreadAt: Date
    public var rootTurnGeneration: Int
    public var finalNotifiedChildGeneration: Int?
    public var finalNotifiedRootTurnGeneration: Int?

    public init(
        runtimeInstanceId: Int,
        responseRevision: Int,
        lastResponseIdentity: String?,
        lastNotifiedRevision: Int,
        lastViewedRevision: Int,
        becameUnreadAt: Date,
        rootTurnGeneration: Int,
        finalNotifiedChildGeneration: Int?,
        finalNotifiedRootTurnGeneration: Int?
    ) {
        self.runtimeInstanceId = runtimeInstanceId
        self.responseRevision = responseRevision
        self.lastResponseIdentity = lastResponseIdentity
        self.lastNotifiedRevision = lastNotifiedRevision
        self.lastViewedRevision = lastViewedRevision
        self.becameUnreadAt = becameUnreadAt
        self.rootTurnGeneration = rootTurnGeneration
        self.finalNotifiedChildGeneration = finalNotifiedChildGeneration
        self.finalNotifiedRootTurnGeneration = finalNotifiedRootTurnGeneration
    }
}

/// Exact reflected input shape passed by V3's root-response handler.
public struct V3RootResponseNotificationContext: Equatable, Sendable {
    public let sessionId: String
    public let runtimeInstanceId: Int
    public let responseIdentity: String
    public let mode: V3RootResponseNotificationMode
    public let childTreeGeneration: Int
    public let childLifecycleRevision: Int
    public let childTreeHasAuthoritativeChildren: Bool
    public let runningAuthoritativeChildCount: Int
    public let hasSameTreeAttention: Bool

    public init(
        sessionId: String,
        runtimeInstanceId: Int,
        responseIdentity: String,
        mode: V3RootResponseNotificationMode,
        childTreeGeneration: Int,
        childLifecycleRevision: Int,
        childTreeHasAuthoritativeChildren: Bool,
        runningAuthoritativeChildCount: Int,
        hasSameTreeAttention: Bool
    ) {
        self.sessionId = sessionId
        self.runtimeInstanceId = runtimeInstanceId
        self.responseIdentity = responseIdentity
        self.mode = mode
        self.childTreeGeneration = childTreeGeneration
        self.childLifecycleRevision = childLifecycleRevision
        self.childTreeHasAuthoritativeChildren = childTreeHasAuthoritativeChildren
        self.runningAuthoritativeChildCount = runningAuthoritativeChildCount
        self.hasSameTreeAttention = hasSameTreeAttention
    }
}

public struct V3RootResponseNotificationSelection: Equatable, Sendable {
    /// Nil means the remaining V3 selector branches are not yet recovered.
    /// It must not be treated as a presentation request.
    public let effect: V3RootResponseNotificationEffect?
    public let state: V3RootResponseNotificationState

    public init(effect: V3RootResponseNotificationEffect?, state: V3RootResponseNotificationState) {
        self.effect = effect
        self.state = state
    }
}

/// Partial recovery of `sub_1001A97B8`. The selector first deduplicates on
/// response identity. A new response increments revision, replaces identity,
/// timestamps unread state, and then defers whenever the child tree already
/// has attention. Later branches remain unmounted until recovered exactly.
public enum V3RootResponseNotificationSelector {
    public static func select(
        context: V3RootResponseNotificationContext,
        state: V3RootResponseNotificationState,
        now: Date
    ) -> V3RootResponseNotificationSelection {
        guard state.lastResponseIdentity != context.responseIdentity else {
            return V3RootResponseNotificationSelection(effect: .duplicate, state: state)
        }

        var nextState = state
        nextState.responseRevision += 1
        nextState.lastResponseIdentity = context.responseIdentity
        nextState.becameUnreadAt = now

        if context.hasSameTreeAttention {
            return V3RootResponseNotificationSelection(effect: .deferForAttention, state: nextState)
        }

        let allAuthoritativeChildrenFinished = context.childTreeHasAuthoritativeChildren
            && context.childTreeGeneration != 0
            && context.runningAuthoritativeChildCount == 0

        if allAuthoritativeChildrenFinished,
           nextState.finalNotifiedChildGeneration != context.childTreeGeneration {
            nextState.finalNotifiedChildGeneration = context.childTreeGeneration
            nextState.finalNotifiedRootTurnGeneration = nextState.rootTurnGeneration
            nextState.lastNotifiedRevision = nextState.responseRevision
            return V3RootResponseNotificationSelection(effect: .revealFinal, state: nextState)
        }

        if allAuthoritativeChildrenFinished,
           nextState.finalNotifiedChildGeneration == context.childTreeGeneration,
           nextState.finalNotifiedRootTurnGeneration == nextState.rootTurnGeneration {
            nextState.lastNotifiedRevision = nextState.responseRevision
            return V3RootResponseNotificationSelection(effect: .updateOnly, state: nextState)
        }

        if context.mode == .allChildrenFinished,
           context.childTreeHasAuthoritativeChildren,
           context.childTreeGeneration != 0,
           context.runningAuthoritativeChildCount > 0 {
            nextState.lastNotifiedRevision = nextState.responseRevision
            return V3RootResponseNotificationSelection(effect: .updateOnly, state: nextState)
        }

        nextState.lastNotifiedRevision = nextState.responseRevision
        let effect: V3RootResponseNotificationEffect = nextState.lastViewedRevision
            >= state.lastNotifiedRevision
            ? .revealProgress
            : .updateOnly
        return V3RootResponseNotificationSelection(effect: effect, state: nextState)
    }
}
