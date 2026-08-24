public struct OverlayControllerState: Codable, Equatable, Sendable {
    public let panelState: OverlayPanelState
    public let menuSnapshot: AppMenuSnapshot
    public let lastRoutedAction: OverlayRoutedAction?

    public init(
        panelState: OverlayPanelState = OverlayPanelState(),
        menuSnapshot: AppMenuSnapshot = AppMenuSnapshot(),
        lastRoutedAction: OverlayRoutedAction? = nil
    ) {
        self.panelState = panelState
        self.menuSnapshot = menuSnapshot
        self.lastRoutedAction = lastRoutedAction
    }
}

public enum OverlaySessionGesture: Codable, Equatable, Sendable {
    case selectSession(sessionId: String)
    case jumpToSession(sessionId: String)
    case resolveAction(requestId: String, sessionId: String)
    case answerQuestion(requestId: String, sessionId: String)
    case submitActionResolution(ActionResolution)
    case openSettings
}

public enum OverlayRoutedAction: Codable, Equatable, Sendable {
    case selectSession(sessionId: String)
    case jumpToSession(sessionId: String)
    case resolveAction(requestId: String, sessionId: String)
    case answerQuestion(requestId: String, sessionId: String)
    case submitActionResolution(ActionResolution)
    case appCommand(AppCommand)
    case openSettings
}

public enum OverlayControllerCommand: Equatable, Sendable {
    case replacePresentation(NotchPresentationState)
    case panelPlacementChanged(DisplayPlacementPlan)
    case panelInteraction(PanelInteractionCommand)
    case sessionGesture(OverlaySessionGesture)
    case appCommand(AppCommand)
    case replaceMenuSnapshot(AppMenuSnapshot)
    case clearRoutedAction
}

public enum OverlayControllerAction: Equatable, Sendable {
    case renderPresentation(NotchPresentationState)
    case renderIslandSurface(IslandSurfaceRenderList)
    case applyPanelPlan(actions: [OverlayPanelAction])
    case routeAction(OverlayRoutedAction)
    case recordDisplayReason(DisplayIntentReason)
}

public struct OverlayControllerPlan: Equatable, Sendable {
    public let nextState: OverlayControllerState
    public let actions: [OverlayControllerAction]

    public init(nextState: OverlayControllerState, actions: [OverlayControllerAction]) {
        self.nextState = nextState
        self.actions = actions
    }
}

public struct OverlayControllerModel: Sendable {
    public let panelController: OverlayPanelControllerModel

    public init(panelController: OverlayPanelControllerModel = OverlayPanelControllerModel()) {
        self.panelController = panelController
    }

    public func plan(
        _ command: OverlayControllerCommand,
        from state: OverlayControllerState
    ) -> OverlayControllerPlan {
        switch command {
        case let .replacePresentation(presentationState):
            return replacePresentation(presentationState, from: state)
        case let .panelPlacementChanged(placementPlan):
            return delegatePanel(.replacePlacement(placementPlan), from: state, renderUpdatedPresentation: false)
        case let .panelInteraction(interactionCommand):
            let shouldRender: Bool
            if case .setMouseInMenuBarZone = interactionCommand {
                shouldRender = false
            } else {
                shouldRender = true
            }
            return delegatePanel(
                .interaction(interactionCommand),
                from: state,
                renderUpdatedPresentation: shouldRender
            )
        case let .sessionGesture(gesture):
            return route(routedAction(for: gesture), from: state)
        case let .appCommand(command):
            return route(.appCommand(command), from: state)
        case let .replaceMenuSnapshot(snapshot):
            return OverlayControllerPlan(
                nextState: OverlayControllerState(
                    panelState: state.panelState,
                    menuSnapshot: snapshot,
                    lastRoutedAction: state.lastRoutedAction
                ),
                actions: []
            )
        case .clearRoutedAction:
            return OverlayControllerPlan(
                nextState: OverlayControllerState(
                    panelState: state.panelState,
                    menuSnapshot: state.menuSnapshot
                ),
                actions: []
            )
        }
    }

    private func replacePresentation(
        _ presentationState: NotchPresentationState,
        from state: OverlayControllerState
    ) -> OverlayControllerPlan {
        let panelPlan = panelController.plan(
            .replacePresentation(presentationState),
            from: state.panelState
        )
        var actions: [OverlayControllerAction] = []
        if !panelPlan.actions.isEmpty {
            actions.append(.applyPanelPlan(actions: panelPlan.actions))
        }
        actions.append(.renderPresentation(presentationState))
        return OverlayControllerPlan(
            nextState: OverlayControllerState(
                panelState: panelPlan.nextState,
                menuSnapshot: state.menuSnapshot,
                lastRoutedAction: state.lastRoutedAction
            ),
            actions: actions
        )
    }

    private func delegatePanel(
        _ command: OverlayPanelCommand,
        from state: OverlayControllerState,
        renderUpdatedPresentation: Bool
    ) -> OverlayControllerPlan {
        let panelPlan = panelController.plan(command, from: state.panelState)
        var actions: [OverlayControllerAction] = []

        if !panelPlan.actions.isEmpty {
            actions.append(.applyPanelPlan(actions: panelPlan.actions))
        }
        if renderUpdatedPresentation {
            actions.append(.renderPresentation(panelPlan.nextState.presentationState))
        }
        if panelPlan.nextState.presentationState.displayReason != state.panelState.presentationState.displayReason,
           panelPlan.nextState.presentationState.displayReason != .none {
            actions.append(.recordDisplayReason(panelPlan.nextState.presentationState.displayReason))
        }

        return OverlayControllerPlan(
            nextState: OverlayControllerState(
                panelState: panelPlan.nextState,
                menuSnapshot: state.menuSnapshot,
                lastRoutedAction: state.lastRoutedAction
            ),
            actions: actions
        )
    }

    private func route(
        _ routedAction: OverlayRoutedAction,
        from state: OverlayControllerState
    ) -> OverlayControllerPlan {
        OverlayControllerPlan(
            nextState: OverlayControllerState(
                panelState: state.panelState,
                menuSnapshot: state.menuSnapshot,
                lastRoutedAction: routedAction
            ),
            actions: [.routeAction(routedAction)]
        )
    }

    private func routedAction(for gesture: OverlaySessionGesture) -> OverlayRoutedAction {
        switch gesture {
        case let .selectSession(sessionId):
            return .selectSession(sessionId: sessionId)
        case let .jumpToSession(sessionId):
            return .jumpToSession(sessionId: sessionId)
        case let .resolveAction(requestId, sessionId):
            return .resolveAction(requestId: requestId, sessionId: sessionId)
        case let .answerQuestion(requestId, sessionId):
            return .answerQuestion(requestId: requestId, sessionId: sessionId)
        case let .submitActionResolution(resolution):
            return .submitActionResolution(resolution)
        case .openSettings:
            return .openSettings
        }
    }
}
