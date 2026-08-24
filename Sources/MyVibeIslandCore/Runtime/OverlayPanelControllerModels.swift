public struct OverlayPanelState: Codable, Equatable, Sendable {
    public let presentationState: NotchPresentationState
    public let placementPlan: DisplayPlacementPlan?

    public init(
        presentationState: NotchPresentationState = NotchPresentationState(),
        placementPlan: DisplayPlacementPlan? = nil
    ) {
        self.presentationState = presentationState
        self.placementPlan = placementPlan
    }
}

public enum OverlayPanelCommand: Equatable, Sendable {
    case replacePlacement(DisplayPlacementPlan)
    case interaction(PanelInteractionCommand)
    case replacePresentation(NotchPresentationState)
}

public enum OverlayPanelAction: Codable, Equatable, Sendable {
    case applyFrame(DisplayFrame)
    case showPanel(displayState: PanelDisplayState)
    case hidePanel(reason: DisplayIntentReason)
    case forwardInteractionAction(PanelInteractionAction)
    case recordDisplayReason(DisplayIntentReason)
}

public struct OverlayPanelPlan: Equatable, Sendable {
    public let nextState: OverlayPanelState
    public let actions: [OverlayPanelAction]

    public init(nextState: OverlayPanelState, actions: [OverlayPanelAction]) {
        self.nextState = nextState
        self.actions = actions
    }
}

public struct OverlayPanelControllerModel: Sendable {
    public let interactionController: PanelInteractionController

    public init(interactionController: PanelInteractionController = PanelInteractionController()) {
        self.interactionController = interactionController
    }

    public func plan(
        _ command: OverlayPanelCommand,
        from state: OverlayPanelState
    ) -> OverlayPanelPlan {
        switch command {
        case let .replacePlacement(placementPlan):
            return replacePlacement(placementPlan, from: state)
        case let .interaction(command):
            return applyInteraction(command, from: state)
        case let .replacePresentation(presentationState):
            let nextPresentation = presentationState.displayState == .expanded
                && state.presentationState.displayState != .expanded
                ? replacing(
                    presentationState,
                    interactionState: interactionController.stateRecordingExpandedEntry(
                        from: presentationState.interactionState
                    )
                )
                : presentationState
            return OverlayPanelPlan(
                nextState: OverlayPanelState(
                    presentationState: nextPresentation,
                    placementPlan: state.placementPlan
                ),
                actions: state.placementPlan.map {
                    visiblePlacementActions(
                        displayState: nextPresentation.displayState,
                        placementPlan: $0
                    )
                } ?? []
            )
        }
    }

    private func replacePlacement(
        _ placementPlan: DisplayPlacementPlan,
        from state: OverlayPanelState
    ) -> OverlayPanelPlan {
        if let collapseReason = placementPlan.collapseReason {
            let displayReason = displayReason(for: collapseReason)
            let presentationState = replacing(
                state.presentationState,
                displayState: .hidden,
                displayReason: displayReason
            )
            return OverlayPanelPlan(
                nextState: OverlayPanelState(
                    presentationState: presentationState,
                    placementPlan: placementPlan
                ),
                actions: [
                    .hidePanel(reason: displayReason),
                    .recordDisplayReason(displayReason)
                ]
            )
        }

        return OverlayPanelPlan(
            nextState: OverlayPanelState(
                presentationState: state.presentationState,
                placementPlan: placementPlan
            ),
            actions: visiblePlacementActions(
                displayState: state.presentationState.displayState,
                placementPlan: placementPlan
            )
        )
    }

    private func applyInteraction(
        _ command: PanelInteractionCommand,
        from state: OverlayPanelState
    ) -> OverlayPanelPlan {
        let interactionPlan = interactionController.plan(
            command,
            from: state.presentationState.interactionState
        )
        let displayReason = displayReason(
            for: interactionPlan.actions
        ) ?? displayReason(for: command, transition: interactionPlan)
        let presentationState = replacing(
            state.presentationState,
            displayState: interactionPlan.nextState.displayState,
            interactionState: interactionPlan.nextState,
            displayReason: displayReason ?? state.presentationState.displayReason
        )
        var actions = interactionPlan.actions.map(OverlayPanelAction.forwardInteractionAction)

        if presentationState.displayState != state.presentationState.displayState,
           let placementPlan = state.placementPlan {
            actions.append(contentsOf: visiblePlacementActions(
                displayState: presentationState.displayState,
                placementPlan: placementPlan
            ))
        }

        if let displayReason {
            actions.append(.recordDisplayReason(displayReason))
        }

        return OverlayPanelPlan(
            nextState: OverlayPanelState(
                presentationState: presentationState,
                placementPlan: state.placementPlan
            ),
            actions: actions
        )
    }

    private func visiblePlacementActions(
        displayState: PanelDisplayState,
        placementPlan: DisplayPlacementPlan
    ) -> [OverlayPanelAction] {
        [
            .applyFrame(frame(for: displayState, placementPlan: placementPlan)),
            .showPanel(displayState: displayState)
        ]
    }

    private func frame(
        for displayState: PanelDisplayState,
        placementPlan: DisplayPlacementPlan
    ) -> DisplayFrame {
        switch displayState {
        case .expanded, .notificationPeek, .switcher, .onboarding:
            return placementPlan.expandedFrame
        case .closed, .opening, .hidden, .autoHidden:
            return placementPlan.closedFrame
        }
    }

    private func displayReason(
        for collapseReason: DisplayPlacementCollapseReason
    ) -> DisplayIntentReason {
        switch collapseReason {
        case .fullscreenHidden:
            return .fullscreenHide
        case .onboardingFullscreen:
            return .onboarding
        }
    }

    private func displayReason(
        for actions: [PanelInteractionAction]
    ) -> DisplayIntentReason? {
        for action in actions {
            if case let .collapsePanel(reason) = action {
                switch reason {
                case .autoCollapse:
                    return .autoCollapse
                case .outsideClick:
                    return .outsideClick
                case .keyboardShortcut:
                    return .keyboardShortcut
                }
            }
        }

        return nil
    }

    private func displayReason(
        for command: PanelInteractionCommand,
        transition: PanelInteractionPlan
    ) -> DisplayIntentReason? {
        guard transition.nextState.displayState == .expanded else {
            return nil
        }

        switch command {
        case .hoverRevealTick, .setExpandedPanelHover(true):
            return .userHover
        default:
            return nil
        }
    }

    private func replacing(
        _ state: NotchPresentationState,
        displayState: PanelDisplayState? = nil,
        interactionState: PanelInteractionState? = nil,
        displayReason: DisplayIntentReason? = nil
    ) -> NotchPresentationState {
        let nextDisplayState = displayState ?? state.displayState
        let keepsCompletionPreview = nextDisplayState == .expanded
        return NotchPresentationState(
            displayState: nextDisplayState,
            focusedSessionId: state.focusedSessionId,
            pillSnapshot: state.pillSnapshot,
            interactionState: interactionState ?? state.interactionState,
            sessionPreviews: state.sessionPreviews,
            notificationPreviews: state.notificationPreviews,
            displayReason: displayReason ?? state.displayReason,
            isPreviewingCompletionCard: keepsCompletionPreview && state.isPreviewingCompletionCard,
            completionPreviewSessionID: keepsCompletionPreview
                ? state.completionPreviewSessionID
                : nil,
            completionPreview: keepsCompletionPreview ? state.completionPreview : nil,
            completionPreviewSession: keepsCompletionPreview ? state.completionPreviewSession : nil
        )
    }
}
