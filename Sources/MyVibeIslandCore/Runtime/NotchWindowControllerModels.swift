public enum NotchWindowVisibility: String, Codable, Equatable, Sendable {
    case closed
    case hidden
    case visible
}

public struct NotchWindowControllerState: Codable, Equatable, Sendable {
    public let hasPanel: Bool
    public let monitorsInstalled: Bool
    public let targetScreen: ScreenTarget?
    public let lastPlacement: DisplayPlacementPlan?
    public let visibility: NotchWindowVisibility
    public let panelHiddenReason: DisplayPlacementCollapseReason?
    public let isDeferringHiddenFade: Bool

    public init(
        hasPanel: Bool = false,
        monitorsInstalled: Bool = false,
        targetScreen: ScreenTarget? = nil,
        lastPlacement: DisplayPlacementPlan? = nil,
        visibility: NotchWindowVisibility = .closed,
        panelHiddenReason: DisplayPlacementCollapseReason? = nil,
        isDeferringHiddenFade: Bool = false
    ) {
        self.hasPanel = hasPanel
        self.monitorsInstalled = monitorsInstalled
        self.targetScreen = targetScreen
        self.lastPlacement = lastPlacement
        self.visibility = visibility
        self.panelHiddenReason = panelHiddenReason
        self.isDeferringHiddenFade = isDeferringHiddenFade
    }
}

public enum NotchWindowControllerCommand: Equatable, Sendable {
    case create(target: ScreenTarget, placement: DisplayPlacementPlan)
    case applyPlacement(DisplayPlacementPlan)
    case updateTarget(ScreenTarget)
    case setVisibility(NotchWindowVisibility)
    case setDeferringHiddenFade(Bool)
    case teardown
}

public enum NotchWindowControllerAction: Codable, Equatable, Sendable {
    case createPanel
    case installEventMonitors
    case removeEventMonitors
    case applyTargetScreen(String)
    case applyPlacement(DisplayPlacementPlan)
    case showPanel
    case hidePanel
    case closePanel
}

public struct NotchWindowControllerPlan: Equatable, Sendable {
    public let nextState: NotchWindowControllerState
    public let actions: [NotchWindowControllerAction]

    public init(nextState: NotchWindowControllerState, actions: [NotchWindowControllerAction]) {
        self.nextState = nextState
        self.actions = actions
    }
}

public struct NotchWindowControllerModel: Sendable {
    public init() {}

    public func plan(
        _ command: NotchWindowControllerCommand,
        from state: NotchWindowControllerState
    ) -> NotchWindowControllerPlan {
        switch command {
        case let .create(target, placement):
            var actions: [NotchWindowControllerAction] = []
            if !state.hasPanel {
                actions.append(.createPanel)
            }
            if !state.monitorsInstalled {
                actions.append(.installEventMonitors)
            }
            if state.targetScreen?.identifier != target.identifier {
                actions.append(.applyTargetScreen(target.identifier))
            }
            actions.append(.applyPlacement(placement))
            let nextVisibility = visibility(for: placement)
            let hiddenReason = placement.collapseReason
            if nextVisibility == .visible {
                actions.append(.showPanel)
            } else {
                actions.append(.hidePanel)
            }
            return NotchWindowControllerPlan(
                nextState: NotchWindowControllerState(
                    hasPanel: true,
                    monitorsInstalled: true,
                    targetScreen: target,
                    lastPlacement: placement,
                    visibility: nextVisibility,
                    panelHiddenReason: hiddenReason,
                    isDeferringHiddenFade: state.isDeferringHiddenFade
                ),
                actions: actions
            )

        case let .applyPlacement(placement):
            let nextVisibility = visibility(for: placement)
            var actions: [NotchWindowControllerAction] = [.applyPlacement(placement)]
            if nextVisibility == .visible, state.visibility != .visible {
                actions.append(.showPanel)
            }
            if nextVisibility == .hidden, state.visibility != .hidden {
                actions.append(.hidePanel)
            }
            return NotchWindowControllerPlan(
                nextState: NotchWindowControllerState(
                    hasPanel: state.hasPanel,
                    monitorsInstalled: state.monitorsInstalled,
                    targetScreen: state.targetScreen,
                    lastPlacement: placement,
                    visibility: nextVisibility,
                    panelHiddenReason: placement.collapseReason,
                    isDeferringHiddenFade: state.isDeferringHiddenFade
                ),
                actions: actions
            )

        case let .updateTarget(target):
            guard state.targetScreen?.identifier != target.identifier else {
                return NotchWindowControllerPlan(nextState: state, actions: [])
            }
            return NotchWindowControllerPlan(
                nextState: NotchWindowControllerState(
                    hasPanel: state.hasPanel,
                    monitorsInstalled: state.monitorsInstalled,
                    targetScreen: target,
                    lastPlacement: state.lastPlacement,
                    visibility: state.visibility,
                    panelHiddenReason: state.panelHiddenReason,
                    isDeferringHiddenFade: state.isDeferringHiddenFade
                ),
                actions: [.applyTargetScreen(target.identifier)]
            )

        case let .setVisibility(visibility):
            guard state.visibility != visibility else {
                return NotchWindowControllerPlan(nextState: state, actions: [])
            }
            let action: NotchWindowControllerAction?
            switch visibility {
            case .visible:
                action = .showPanel
            case .hidden:
                action = .hidePanel
            case .closed:
                action = .closePanel
            }
            return NotchWindowControllerPlan(
                nextState: NotchWindowControllerState(
                    hasPanel: visibility != .closed && state.hasPanel,
                    monitorsInstalled: state.monitorsInstalled,
                    targetScreen: state.targetScreen,
                    lastPlacement: state.lastPlacement,
                    visibility: visibility,
                    panelHiddenReason: visibility == .hidden ? state.panelHiddenReason : nil,
                    isDeferringHiddenFade: state.isDeferringHiddenFade
                ),
                actions: action.map { [$0] } ?? []
            )

        case let .setDeferringHiddenFade(isDeferring):
            guard state.isDeferringHiddenFade != isDeferring else {
                return NotchWindowControllerPlan(nextState: state, actions: [])
            }
            return NotchWindowControllerPlan(
                nextState: NotchWindowControllerState(
                    hasPanel: state.hasPanel,
                    monitorsInstalled: state.monitorsInstalled,
                    targetScreen: state.targetScreen,
                    lastPlacement: state.lastPlacement,
                    visibility: state.visibility,
                    panelHiddenReason: state.panelHiddenReason,
                    isDeferringHiddenFade: isDeferring
                ),
                actions: []
            )

        case .teardown:
            guard state.hasPanel || state.monitorsInstalled else {
                return NotchWindowControllerPlan(nextState: state, actions: [])
            }
            var actions: [NotchWindowControllerAction] = []
            if state.monitorsInstalled {
                actions.append(.removeEventMonitors)
            }
            if state.hasPanel {
                actions.append(.closePanel)
            }
            return NotchWindowControllerPlan(
                nextState: NotchWindowControllerState(
                    hasPanel: false,
                    monitorsInstalled: false,
                    targetScreen: state.targetScreen,
                    lastPlacement: state.lastPlacement,
                    visibility: .closed,
                    panelHiddenReason: nil,
                    isDeferringHiddenFade: false
                ),
                actions: actions
            )
        }
    }

    private func visibility(for placement: DisplayPlacementPlan) -> NotchWindowVisibility {
        placement.collapseReason == nil ? .visible : .hidden
    }
}
