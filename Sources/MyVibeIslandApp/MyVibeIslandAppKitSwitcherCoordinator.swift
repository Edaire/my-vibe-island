import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSwitcherCoordinator {
    public private(set) var state = SwitcherRuntimeState()
    public var onStateChange: ((SwitcherRuntimeState) -> Void)?

    private let jumpToSession: (String) -> Void
    private let routePanelInteraction: (PanelInteractionCommand) -> Void
    private var availableSessionIDs: [String] = []
    private var availableFocusedID: String?

    public init(
        jumpToSession: @escaping (String) -> Void,
        routePanelInteraction: @escaping (PanelInteractionCommand) -> Void
    ) {
        self.jumpToSession = jumpToSession
        self.routePanelInteraction = routePanelInteraction
    }

    public func open(sessionIDs: [String], highlighted: String?) {
        state.open(sessionIDs: sessionIDs, highlightedID: highlighted)
        publishState()
    }

    /// Rendering refreshes the switcher's candidate data, but must not become
    /// the writer that opens the switcher or changes its selection.
    public func syncAvailableSessions(sessionIDs: [String], focusedID: String?) {
        availableSessionIDs = sessionIDs
        availableFocusedID = focusedID
    }

    /// Keyboard/shortcut handling is the local writer for switcher entry.
    public func openFromShortcut() {
        SessionCompletionTraceLog.append(
            stage: "switcher.open.writer",
            sessionId: availableFocusedID,
            metadata: [
                "candidateCount": String(availableSessionIDs.count),
                "focusedID": availableFocusedID ?? "-",
            ]
        )
        open(sessionIDs: availableSessionIDs, highlighted: availableFocusedID)
    }

    public func navigate(_ direction: SwitcherNavigationDirection, reverse: Bool = false) {
        let previousID = state.highlightedID
        state.navigate(direction, reversed: reverse)
        SessionCompletionTraceLog.append(
            stage: "switcher.navigate.writer",
            sessionId: state.highlightedID,
            metadata: [
                "direction": String(describing: direction),
                "previousID": previousID ?? "-",
                "highlightedID": state.highlightedID ?? "-",
            ]
        )
        publishState()
    }

    public func submitHighlighted() {
        guard let highlightedID = state.highlightedID else { return }
        jumpToSession(highlightedID)
        collapse()
    }

    public func modifierReleased() {
        state.collapseForModifierRelease()
        SessionCompletionTraceLog.append(
            stage: "switcher.collapse.modifier_release",
            sessionId: nil
        )
        publishState()
        routeCollapse()
    }

    public func outsideInteraction() {
        state.collapseForOutsideInteraction()
        SessionCompletionTraceLog.append(
            stage: "switcher.collapse.outside_interaction",
            sessionId: nil
        )
        publishState()
        routeCollapse()
    }

    public func collapse() {
        state.collapse()
        SessionCompletionTraceLog.append(
            stage: "switcher.collapse.writer",
            sessionId: nil
        )
        publishState()
        routeCollapse()
    }

    private func routeCollapse() {
        routePanelInteraction(.outsideClick)
        routePanelInteraction(.setKeyboardFocusNeeded(false))
    }

    private func publishState() {
        onStateChange?(state)
    }
}
