import Foundation

public struct ShortcutRuntimeState: Codable, Equatable, Sendable {
    public let lastFiredAtMilliseconds: [String: Int]
    public let dedupWindowMilliseconds: Int
    public let switcherHasNavigated: Bool
    public let switcherOpenedAtMilliseconds: Int?
    public let modifierHoldThresholdMilliseconds: Int
    public let isModifierHeld: Bool
    public let modifierKey: ModifierKeyOption?
    public let reverseSwitcherEnabled: Bool

    public init(
        lastFiredAtMilliseconds: [String: Int] = [:],
        dedupWindowMilliseconds: Int = 250,
        switcherHasNavigated: Bool = false,
        switcherOpenedAtMilliseconds: Int? = nil,
        modifierHoldThresholdMilliseconds: Int = 300,
        isModifierHeld: Bool = false,
        modifierKey: ModifierKeyOption? = nil,
        reverseSwitcherEnabled: Bool = false
    ) {
        self.lastFiredAtMilliseconds = lastFiredAtMilliseconds.mapValues { max($0, 0) }
        self.dedupWindowMilliseconds = max(dedupWindowMilliseconds, 0)
        self.switcherHasNavigated = switcherHasNavigated
        self.switcherOpenedAtMilliseconds = switcherOpenedAtMilliseconds.map { max($0, 0) }
        self.modifierHoldThresholdMilliseconds = max(modifierHoldThresholdMilliseconds, 0)
        self.isModifierHeld = isModifierHeld
        self.modifierKey = modifierKey
        self.reverseSwitcherEnabled = reverseSwitcherEnabled
    }

    public func recordingFire(hotKeyId: String, atMilliseconds: Int) -> ShortcutRuntimeState {
        var nextLastFired = lastFiredAtMilliseconds
        nextLastFired[hotKeyId] = max(atMilliseconds, 0)
        return ShortcutRuntimeState(
            lastFiredAtMilliseconds: nextLastFired,
            dedupWindowMilliseconds: dedupWindowMilliseconds,
            switcherHasNavigated: switcherHasNavigated,
            switcherOpenedAtMilliseconds: switcherOpenedAtMilliseconds,
            modifierHoldThresholdMilliseconds: modifierHoldThresholdMilliseconds,
            isModifierHeld: isModifierHeld,
            modifierKey: modifierKey,
            reverseSwitcherEnabled: reverseSwitcherEnabled
        )
    }

    public func openingSwitcher(
        modifierKey: ModifierKeyOption,
        atMilliseconds: Int
    ) -> ShortcutRuntimeState {
        ShortcutRuntimeState(
            lastFiredAtMilliseconds: lastFiredAtMilliseconds,
            dedupWindowMilliseconds: dedupWindowMilliseconds,
            switcherHasNavigated: false,
            switcherOpenedAtMilliseconds: atMilliseconds,
            modifierHoldThresholdMilliseconds: modifierHoldThresholdMilliseconds,
            isModifierHeld: true,
            modifierKey: modifierKey,
            reverseSwitcherEnabled: reverseSwitcherEnabled
        )
    }
}

public enum ShortcutRuntimeHotKeyDecision: String, Codable, Equatable, Sendable {
    case dispatch
    case suppressedDuplicate
}

public struct ShortcutRuntimeHotKeyPlan: Codable, Equatable, Sendable {
    public let decision: ShortcutRuntimeHotKeyDecision
    public let hotKeyId: String
    public let nextState: ShortcutRuntimeState

    public init(
        decision: ShortcutRuntimeHotKeyDecision,
        hotKeyId: String,
        nextState: ShortcutRuntimeState
    ) {
        self.decision = decision
        self.hotKeyId = hotKeyId
        self.nextState = nextState
    }
}

public enum ShortcutRuntimeModifierDecision: String, Codable, Equatable, Sendable {
    case openSwitcher
    case keepWaiting
}

public struct ShortcutRuntimeModifierPlan: Codable, Equatable, Sendable {
    public let decision: ShortcutRuntimeModifierDecision
    public let modifierKey: ModifierKeyOption
    public let nextState: ShortcutRuntimeState

    public init(
        decision: ShortcutRuntimeModifierDecision,
        modifierKey: ModifierKeyOption,
        nextState: ShortcutRuntimeState
    ) {
        self.decision = decision
        self.modifierKey = modifierKey
        self.nextState = nextState
    }
}

public struct ShortcutRuntimeModel: Sendable {
    public init() {}

    public func planHotKeyDispatch(
        hotKeyId: String,
        atMilliseconds: Int,
        state: ShortcutRuntimeState
    ) -> ShortcutRuntimeHotKeyPlan {
        let checkedTime = max(atMilliseconds, 0)
        if let lastFiredAt = state.lastFiredAtMilliseconds[hotKeyId],
           checkedTime - lastFiredAt < state.dedupWindowMilliseconds {
            return ShortcutRuntimeHotKeyPlan(
                decision: .suppressedDuplicate,
                hotKeyId: hotKeyId,
                nextState: state
            )
        }

        return ShortcutRuntimeHotKeyPlan(
            decision: .dispatch,
            hotKeyId: hotKeyId,
            nextState: state.recordingFire(hotKeyId: hotKeyId, atMilliseconds: checkedTime)
        )
    }

    public func planModifierHold(
        modifierKey: ModifierKeyOption,
        heldForMilliseconds: Int,
        atMilliseconds: Int,
        state: ShortcutRuntimeState
    ) -> ShortcutRuntimeModifierPlan {
        guard heldForMilliseconds >= state.modifierHoldThresholdMilliseconds else {
            return ShortcutRuntimeModifierPlan(
                decision: .keepWaiting,
                modifierKey: modifierKey,
                nextState: state
            )
        }

        return ShortcutRuntimeModifierPlan(
            decision: .openSwitcher,
            modifierKey: modifierKey,
            nextState: state.openingSwitcher(
                modifierKey: modifierKey,
                atMilliseconds: max(atMilliseconds, 0)
            )
        )
    }
}
