import MyVibeIslandCore

public enum MyVibeIslandAppKitShortcutHintOverlayPresentationAction: Equatable {
    case present(ShortcutHintOverlayState)
    case hide(ShortcutHintOverlayState)
}

@MainActor
public final class MyVibeIslandAppKitShortcutHintOverlayController {
    public private(set) var state: ShortcutHintOverlayState
    public private(set) var settings: ShortcutSettings
    public private(set) var lastPresentationAction: MyVibeIslandAppKitShortcutHintOverlayPresentationAction?

    private var lastModifierKey: ModifierKeyOption
    private var lastIsPanelExpanded: Bool
    private let model: ShortcutHintOverlayModel
    private let presentOverlay: @MainActor (ShortcutHintOverlayState) -> Void
    private let hideOverlay: @MainActor () -> Void

    public init(
        settings: ShortcutSettings = ShortcutSettings(),
        state: ShortcutHintOverlayState = ShortcutHintOverlayState(isVisible: false, modifierKey: .command),
        model: ShortcutHintOverlayModel = ShortcutHintOverlayModel(),
        presentOverlay: @escaping @MainActor (ShortcutHintOverlayState) -> Void = { _ in },
        hideOverlay: @escaping @MainActor () -> Void = {}
    ) {
        self.settings = settings
        self.state = state
        self.lastModifierKey = state.modifierKey
        self.lastIsPanelExpanded = false
        self.model = model
        self.presentOverlay = presentOverlay
        self.hideOverlay = hideOverlay
    }

    @discardableResult
    public func update(
        modifierKey: ModifierKeyOption,
        isPanelExpanded: Bool
    ) -> ShortcutHintOverlayState {
        lastModifierKey = modifierKey
        lastIsPanelExpanded = isPanelExpanded
        return applyState(modifierKey: modifierKey, isPanelExpanded: isPanelExpanded)
    }

    @discardableResult
    public func updateSettings(_ settings: ShortcutSettings) -> ShortcutHintOverlayState {
        self.settings = settings
        return applyState(modifierKey: lastModifierKey, isPanelExpanded: lastIsPanelExpanded)
    }

    public func hide() {
        state = ShortcutHintOverlayState(isVisible: false, modifierKey: lastModifierKey)
        lastPresentationAction = .hide(state)
        hideOverlay()
    }

    private func applyState(
        modifierKey: ModifierKeyOption,
        isPanelExpanded: Bool
    ) -> ShortcutHintOverlayState {
        let nextState: ShortcutHintOverlayState
        if settings.keyboardShortcutsEnabled {
            nextState = model.state(
                settings: settings,
                modifierKey: modifierKey,
                isPanelExpanded: isPanelExpanded
            )
        } else {
            nextState = ShortcutHintOverlayState(isVisible: false, modifierKey: modifierKey)
        }

        state = nextState
        if nextState.isVisible {
            lastPresentationAction = .present(nextState)
            presentOverlay(nextState)
        } else {
            lastPresentationAction = .hide(nextState)
            hideOverlay()
        }
        return nextState
    }
}
