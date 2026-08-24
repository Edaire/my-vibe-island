import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitNotchViewModelController {
    public private(set) var state: NotchViewModelState
    public private(set) var lastPlan: NotchViewModelPlan?

    private let reducer: NotchViewModelReducer
    private let overlayController: MyVibeIslandAppKitOverlayController
    private let autoHideWhenIdle: Bool
    private let setIdleHidden: @MainActor (Bool) -> Void
    private let automaticExpansionFocus: @MainActor ([AgentSession]) -> V3AutomaticExpansionFocus
    private var idleAutoHideTask: Task<Void, Never>?
    private var isIdleHidden = false

    public init(
        state: NotchViewModelState = NotchViewModelState(),
        reducer: NotchViewModelReducer = NotchViewModelReducer(),
        overlayController: MyVibeIslandAppKitOverlayController,
        autoHideWhenIdle: Bool = false,
        setIdleHidden: @escaping @MainActor (Bool) -> Void = { _ in },
        automaticExpansionFocus: @escaping @MainActor ([AgentSession]) -> V3AutomaticExpansionFocus = { _ in
            V3AutomaticExpansionFocus(frontmostBundleId: nil, activeTTYs: [])
        }
    ) {
        self.state = state
        self.reducer = reducer
        self.overlayController = overlayController
        self.autoHideWhenIdle = autoHideWhenIdle
        self.setIdleHidden = setIdleHidden
        self.automaticExpansionFocus = automaticExpansionFocus
    }

    public func replaceSessionPreviews(_ previews: [SessionCardPreview]) {
        let plan = reducer.reduce(.replaceSessionPreviews(previews), state: state)
        apply(plan)
        synchronizeIdleAutoHide()
    }

    public func synchronizePlacement(_ placement: DisplayPlacementPlan) {
        let plan = reducer.reduce(.synchronizePlacement(placement), state: state)
        if state.overlayState.panelState.presentationState.displayState == .closed {
            state = plan.nextState
            lastPlan = plan
            return
        }
        apply(plan)
    }

    public func toggleExpanded() {
        let plan = reducer.reduce(.toggleExpanded, state: state)
        apply(plan)
    }

    public func toggleManualSessionExpansion(_ sessionID: String) {
        let plan = reducer.reduce(
            .toggleManualSessionExpansion(sessionID: sessionID),
            state: state
        )
        apply(plan)
    }

    public func showCompletionRender(sessionId: String? = nil) {
        guard let sessionId else { return }
        let plan = reducer.reduce(.showCompletionRender(sessionId: sessionId), state: state)
        apply(plan)
    }

    /// `sub_10010AEE4` reaches the root response notification coordinator only
    /// after its non-quiet completion predicates and display decision accept.
    /// A quiet scene is its own earlier path and must remain eligible here.
    public func allowsTaskCompletionNotification(
        sessionId: String,
        quietSceneActive: Bool,
        sensoryPolicy: V3SensoryPolicy
    ) -> Bool {
        let input = taskCompletionInput(
            sessionId: sessionId,
            autoExpandOnTaskComplete: true,
            quietSceneActive: quietSceneActive,
            sensoryPolicy: sensoryPolicy
        )

        switch V3TaskCompletionConsumer.plan(input) {
        case .suppressed:
            return false
        case .markQuietScenePending, .incrementCompletionFlash,
             .leaveAcceptedDecisionUnconsumed, .consumeDecision:
            return true
        }
    }

    public func handleTaskCompletion(
        sessionId: String?,
        autoExpandOnTaskComplete: Bool,
        quietSceneActive: Bool = false,
        sensoryPolicy: V3SensoryPolicy = .none
    ) {
        guard let sessionId else { return }
        SessionCompletionTraceLog.append(
            stage: "completion.consumer_enter",
            sessionId: sessionId,
            metadata: [
                "autoExpand": String(autoExpandOnTaskComplete),
                "quietSceneActive": String(quietSceneActive),
                "displayState": String(describing: state.overlayState.panelState.presentationState.displayState),
                "previousFlashTick": String(state.originalCompactRuntimeState.completionFlashTick),
            ]
        )
        let targetSession = state.sessions.first { $0.id == sessionId }
        let focus = automaticExpansionFocus(state.sessions)
        let input = taskCompletionInput(
            sessionId: sessionId,
            autoExpandOnTaskComplete: autoExpandOnTaskComplete,
            quietSceneActive: quietSceneActive,
            sensoryPolicy: sensoryPolicy
        )
        SessionCompletionTraceLog.append(
            stage: "completion.v3_decision",
            sessionId: sessionId,
            metadata: [
                "decision": input.decision.reason,
                "accepted": String(input.decision.accepted),
                "displayState": String(describing: v3DisplayState(
                    presentation: state.overlayState.panelState.presentationState
                )),
                "focusBundle": focus.frontmostBundleId ?? "",
                "focusTTYs": focus.activeTTYs.sorted().joined(separator: ","),
                "targetSessionPresent": String(targetSession != nil),
                "targetBundle": targetSession?.jumpInput?.bundleId ?? "",
                "targetTTY": targetSession?.jumpInput?.tty ?? "",
                "targetTmuxClientTTY": targetSession?.jumpInput?.tmuxClientTTY ?? "",
                "gateAccepted": String(input.automaticExpansionGateAccepted),
            ]
        )
        let plan = reducer.reduce(.consumeV3TaskCompletion(input), state: state)
        apply(plan)

        if autoExpandOnTaskComplete, quietSceneActive {
            SessionCompletionTraceLog.append(
                stage: "completion.quiet_scene_suppressed",
                sessionId: sessionId,
                metadata: [
                    "displayState": String(describing: state.overlayState.panelState.presentationState.displayState),
                ]
            )
            return
        }
        guard autoExpandOnTaskComplete else {
            SessionCompletionTraceLog.append(
                stage: "completion.flash_tick_written",
                sessionId: sessionId,
                metadata: [
                    "flashTick": String(state.originalCompactRuntimeState.completionFlashTick),
                    "displayState": String(describing: state.overlayState.panelState.presentationState.displayState),
                ]
            )
            return
        }
    }

    private func taskCompletionInput(
        sessionId: String,
        autoExpandOnTaskComplete: Bool,
        quietSceneActive: Bool,
        sensoryPolicy: V3SensoryPolicy
    ) -> V3TaskCompletionInput {
        let targetPreview = state.sessionPreviews.first { $0.sessionId == sessionId }
        let targetSession = state.sessions.first { $0.id == sessionId }
        let interaction = state.overlayState.panelState.presentationState.interactionState
        let displayState = v3DisplayState(
            presentation: state.overlayState.panelState.presentationState
        )
        // Completion presentation requires a known session target, but neither
        // presentation nor the Kanban browser jump requires an attached tmux
        // client.
        let gateAccepted = targetSession?.jumpInput != nil

        return V3TaskCompletionInput(
            onboardingActive: interaction.onboardingActive
                || (state.onboardingState.map { $0.currentStep != .ready } ?? false),
            blockingExpanded: interaction.blockingActionVisible
                && state.overlayState.panelState.presentationState.displayState == .expanded,
            targetSessionExists: targetPreview != nil,
            targetSessionIsComplete: targetSession?.originalStatus == .ended
                || targetPreview?.unreadCompletionMarker == true,
            quietSceneActive: quietSceneActive,
            autoExpandOnTaskComplete: autoExpandOnTaskComplete,
            decision: V3TaskCompleteDecisionResolver.resolve(
                sessionId: sessionId,
                currentDisplayState: displayState,
                policy: sensoryPolicy
            ),
            automaticExpansionGateAccepted: gateAccepted
        )
    }

    private func v3DisplayState(
        presentation: NotchPresentationState
    ) -> V3NotchDisplayState {
        let interaction = presentation.interactionState
        if presentation.displayState == .expanded,
           interaction.isPinned || interaction.transientAutoRevealKind == nil {
            return .manualExpanded
        }
        switch presentation.displayState {
        case .notificationPeek:
            return .peek
        case .expanded, .opening:
            return .transient
        case .onboarding:
            return .blocking
        case .closed, .switcher, .hidden, .autoHidden:
            return .closed
        }
    }

    public func showNotificationPeek(_ previews: [SessionCardPreview]) {
        let plan = reducer.reduce(.showNotificationPeek(previews), state: state)
        apply(plan)
    }

    public func clearNotificationPeek() {
        let plan = reducer.reduce(.clearNotificationPeek, state: state)
        apply(plan)
    }

    public func applyInteractionCommand(_ command: PanelInteractionCommand) {
        let before = state.overlayState.panelState.presentationState.interactionState
        SessionCompletionTraceLog.append(
            stage: "hover.reducer_command",
            sessionId: nil,
            metadata: hoverTraceMetadata(
                command: command,
                interaction: before,
                displayState: state.overlayState.panelState.presentationState.displayState
            )
        )
        let plan = reducer.reduce(.panelInteraction(command), state: state)
        let after = plan.nextState.overlayState.panelState.presentationState.interactionState
        var metadata = hoverTraceMetadata(
            command: command,
            interaction: after,
            displayState: plan.nextState.overlayState.panelState.presentationState.displayState
        )
        metadata["actions"] = plan.actions.map(hoverActionSummary).joined(separator: " | ")
        SessionCompletionTraceLog.append(
            stage: "hover.reducer_result",
            sessionId: nil,
            metadata: metadata
        )
        apply(plan)
    }

    public func applyUsagePresentation(_ usagePresentation: UsagePresentationSnapshot) {
        let plan = reducer.reduce(.applyUsagePresentation(usagePresentation), state: state)
        apply(plan)
    }

    public func replaceIslandRuntimeSnapshot(_ snapshot: IslandRuntimeSnapshot) {
        let plan = reducer.reduce(.replaceRuntimeSnapshot(snapshot), state: state)
        apply(plan)
        synchronizeIdleAutoHide()
    }

    private func synchronizeIdleAutoHide() {
        let displayPreviews = state.overlayState.panelState.presentationState.sessionPreviews
        guard autoHideWhenIdle, displayPreviews.isEmpty else {
            idleAutoHideTask?.cancel()
            idleAutoHideTask = nil
            restoreFromIdleAutoHideIfNeeded()
            return
        }

        guard !isIdleHidden, idleAutoHideTask == nil else { return }
        idleAutoHideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            self.idleAutoHideTask = nil
            guard self.autoHideWhenIdle,
                  self.state.overlayState.panelState.presentationState.sessionPreviews.isEmpty,
                  !self.isIdleHidden else {
                return
            }
            self.isIdleHidden = true
            self.setIdleHidden(true)
        }
    }

    private func restoreFromIdleAutoHideIfNeeded() {
        guard isIdleHidden else { return }
        isIdleHidden = false
        setIdleHidden(false)
    }

    private func apply(_ plan: NotchViewModelPlan) {
        state = plan.nextState
        lastPlan = plan

        for action in plan.actions {
            if case let .overlay(overlayAction) = action {
                overlayController.apply(overlayAction)
            }
        }
    }

    private func hoverTraceMetadata(
        command: PanelInteractionCommand,
        interaction: PanelInteractionState,
        displayState: PanelDisplayState
    ) -> [String: String] {
        [
            "command": String(describing: command),
            "displayState": String(describing: displayState),
            "isHovering": String(interaction.isHovering),
            "inExpandedPanel": String(interaction.isMouseInExpandedPanel),
            "inMenuBar": String(interaction.isMouseInMenuBarZone),
            "isPinned": String(interaction.isPinned),
            "needsKeyboardFocus": String(interaction.needsKeyboardFocus),
            "blockingActionVisible": String(interaction.blockingActionVisible),
            "onboardingActive": String(interaction.onboardingActive),
            "generation": String(interaction.autoCollapseGeneration),
        ]
    }

    private func hoverActionSummary(_ action: NotchViewModelAction) -> String {
        switch action {
        case let .overlay(overlayAction):
            return overlayActionSummary(overlayAction)
        case .refreshUsageDisplay:
            return "refreshUsageDisplay"
        case .showNotificationPeek:
            return "showNotificationPeek"
        case .clearNotificationPeek:
            return "clearNotificationPeek"
        case .storeQuestionSelection:
            return "storeQuestionSelection"
        }
    }

    private func overlayActionSummary(_ action: OverlayControllerAction) -> String {
        switch action {
        case .renderPresentation:
            return "renderPresentation"
        case .renderIslandSurface:
            return "renderIslandSurface"
        case let .applyPanelPlan(actions):
            return "applyPanelPlan(\(actions.map(panelActionSummary).joined(separator: ",")))"
        case .routeAction:
            return "routeAction"
        case .recordDisplayReason:
            return "recordDisplayReason"
        }
    }

    private func panelActionSummary(_ action: OverlayPanelAction) -> String {
        switch action {
        case .applyFrame:
            return "applyFrame"
        case .showPanel:
            return "showPanel"
        case .hidePanel:
            return "hidePanel"
        case let .forwardInteractionAction(interactionAction):
            return "interaction(\(String(describing: interactionAction)))"
        case .recordDisplayReason:
            return "recordDisplayReason"
        }
    }
}
