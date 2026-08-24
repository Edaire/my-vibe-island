import Foundation

public enum PanelDisplayState: String, Codable, Equatable, Sendable {
    case closed
    case opening
    case expanded
    case notificationPeek
    case switcher
    case onboarding
    case hidden
    case autoHidden
}

public enum PanelCollapseReason: String, Codable, Equatable, Sendable {
    case autoCollapse
    case outsideClick
    case keyboardShortcut
}

public enum DisplayBlockingKind: String, Codable, Equatable, Sendable {
    case pinned
    case keyboardFocus
    case blockingAction
    case onboarding

    public init?(state: PanelInteractionState) {
        if state.blockingActionVisible {
            self = .blockingAction
        } else if state.onboardingActive {
            self = .onboarding
        } else if state.needsKeyboardFocus {
            self = .keyboardFocus
        } else if state.isPinned {
            self = .pinned
        } else {
            return nil
        }
    }
}

public enum DisplayCollapseReason: String, Codable, Equatable, Sendable {
    case autoCollapse
    case outsideClick
    case keyboardShortcut

    public init(panelReason: PanelCollapseReason) {
        switch panelReason {
        case .autoCollapse:
            self = .autoCollapse
        case .outsideClick:
            self = .outsideClick
        case .keyboardShortcut:
            self = .keyboardShortcut
        }
    }
}

public enum DisplayHoverPolicy: String, Codable, Equatable, Sendable {
    case disabled
    case coolingDown
    case pinnedOpen
    case enabled

    public init(settings: BehaviourSettings, state: PanelInteractionState) {
        if !settings.hoverToExpandEnabled {
            self = .disabled
        } else if state.hoverCooldownUntil != nil {
            self = .coolingDown
        } else if state.isPinned {
            self = .pinnedOpen
        } else {
            self = .enabled
        }
    }
}

/// V3's `TransientAutoRevealKind` is the producer classification stored in a
/// peek display state. It is not a synonym for the currently visible panel.
public enum TransientAutoRevealKind: String, Codable, Equatable, CaseIterable, Sendable {
    case attentionReminder
    case taskComplete
    case compactionComplete
    case statusWarning
    case usageLimit

    public init?(displayState: PanelDisplayState) {
        switch displayState {
        case .closed, .opening, .expanded, .notificationPeek, .switcher,
             .onboarding, .hidden, .autoHidden:
            return nil
        }
    }
}

public struct PanelInteractionState: Codable, Equatable, Sendable {
    public let displayState: PanelDisplayState
    public let rootContentStatus: NotchRootContentStatus
    public let isPinned: Bool
    public let isHovering: Bool
    public let isMouseInMenuBarZone: Bool
    public let isMouseInExpandedPanel: Bool
    public let needsKeyboardFocus: Bool
    public let autoCollapseGeneration: Int
    public let mouseLeaveCollapseGeneration: Int?
    public let expandedSince: Double?
    public let hoverCooldownUntil: Double?
    public let transientRevealDwellSeconds: Double
    public let transientAutoRevealKind: TransientAutoRevealKind?
    public let blockingActionVisible: Bool
    public let onboardingActive: Bool

    public init(
        displayState: PanelDisplayState = .closed,
        rootContentStatus: NotchRootContentStatus? = nil,
        isPinned: Bool = false,
        isHovering: Bool = false,
        isMouseInMenuBarZone: Bool = false,
        isMouseInExpandedPanel: Bool = false,
        needsKeyboardFocus: Bool = false,
        autoCollapseGeneration: Int = 0,
        mouseLeaveCollapseGeneration: Int? = nil,
        expandedSince: Double? = nil,
        hoverCooldownUntil: Double? = nil,
        transientRevealDwellSeconds: Double = 5.0,
        transientAutoRevealKind: TransientAutoRevealKind? = nil,
        blockingActionVisible: Bool = false,
        onboardingActive: Bool = false
    ) {
        self.displayState = displayState
        self.rootContentStatus = rootContentStatus
            ?? NotchRootContentStatus(displayStatus: NotchDisplayStatus(displayState: displayState))
        self.isPinned = isPinned
        self.isHovering = isHovering
        self.isMouseInMenuBarZone = isMouseInMenuBarZone
        self.isMouseInExpandedPanel = isMouseInExpandedPanel
        self.needsKeyboardFocus = needsKeyboardFocus
        self.autoCollapseGeneration = autoCollapseGeneration
        self.mouseLeaveCollapseGeneration = mouseLeaveCollapseGeneration
        self.expandedSince = expandedSince
        self.hoverCooldownUntil = hoverCooldownUntil
        self.transientRevealDwellSeconds = transientRevealDwellSeconds
        self.transientAutoRevealKind = transientAutoRevealKind
        self.blockingActionVisible = blockingActionVisible
        self.onboardingActive = onboardingActive
    }

    private enum CodingKeys: String, CodingKey {
        case displayState
        case rootContentStatus
        case isPinned
        case isHovering
        case isMouseInMenuBarZone
        case isMouseInExpandedPanel
        case needsKeyboardFocus
        case autoCollapseGeneration
        case mouseLeaveCollapseGeneration
        case expandedSince
        case hoverCooldownUntil
        case transientRevealDwellSeconds
        case transientAutoRevealKind
        case blockingActionVisible
        case onboardingActive
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let displayState = try container.decode(PanelDisplayState.self, forKey: .displayState)
        self.init(
            displayState: displayState,
            rootContentStatus: try container.decodeIfPresent(
                NotchRootContentStatus.self,
                forKey: .rootContentStatus
            ),
            isPinned: try container.decode(Bool.self, forKey: .isPinned),
            isHovering: try container.decode(Bool.self, forKey: .isHovering),
            isMouseInMenuBarZone: try container.decode(Bool.self, forKey: .isMouseInMenuBarZone),
            isMouseInExpandedPanel: try container.decode(Bool.self, forKey: .isMouseInExpandedPanel),
            needsKeyboardFocus: try container.decode(Bool.self, forKey: .needsKeyboardFocus),
            autoCollapseGeneration: try container.decode(Int.self, forKey: .autoCollapseGeneration),
            mouseLeaveCollapseGeneration: try container.decodeIfPresent(
                Int.self,
                forKey: .mouseLeaveCollapseGeneration
            ),
            expandedSince: try container.decodeIfPresent(Double.self, forKey: .expandedSince),
            hoverCooldownUntil: try container.decodeIfPresent(Double.self, forKey: .hoverCooldownUntil),
            transientRevealDwellSeconds: try container.decode(Double.self, forKey: .transientRevealDwellSeconds),
            transientAutoRevealKind: try container.decodeIfPresent(
                TransientAutoRevealKind.self,
                forKey: .transientAutoRevealKind
            ),
            blockingActionVisible: try container.decode(Bool.self, forKey: .blockingActionVisible),
            onboardingActive: try container.decode(Bool.self, forKey: .onboardingActive)
        )
    }
}

public enum PanelInteractionCommand: Equatable, Sendable {
    case toggleExpanded
    case openSwitcher
    case setMenuBarHover(Bool)
    case setMouseInMenuBarZone(Bool)
    case setExpandedPanelHover(Bool)
    case hoverRevealTick(generation: Int)
    case setPinned(Bool)
    case setKeyboardFocusNeeded(Bool)
    case transientReveal(kind: TransientAutoRevealKind, displayState: PanelDisplayState)
    case outsideClick
    case autoCollapseTick(generation: Int)
    case mouseLeaveCollapseTick(generation: Int)
}

public enum PanelInteractionAction: Codable, Equatable, Sendable {
    case setDisplayState(PanelDisplayState)
    case scheduleHoverReveal(delay: Double, generation: Int)
    case cancelHoverReveal
    case cancelAutoCollapse
    case scheduleAutoCollapse(delay: Double, generation: Int)
    case cancelMouseLeaveCollapse
    case scheduleMouseLeaveCollapse(delay: Double, generation: Int)
    case collapsePanel(reason: PanelCollapseReason)
    case requestKeyboardFocus
    case releaseKeyboardFocus
}

public struct PanelInteractionPlan: Equatable, Sendable {
    public let nextState: PanelInteractionState
    public let actions: [PanelInteractionAction]

    public init(nextState: PanelInteractionState, actions: [PanelInteractionAction]) {
        self.nextState = nextState
        self.actions = actions
    }
}

public struct PanelInteractionController: Sendable {
    public let settings: BehaviourSettings
    private let now: @Sendable () -> Double

    public init(
        settings: BehaviourSettings = BehaviourSettings(),
        now: @escaping @Sendable () -> Double = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.settings = settings
        self.now = now
    }

    public func plan(
        _ command: PanelInteractionCommand,
        from state: PanelInteractionState
    ) -> PanelInteractionPlan {
        switch command {
        case .toggleExpanded:
            let displayState: PanelDisplayState = state.displayState == .expanded
                ? .closed
                : .expanded
            if displayState == .expanded,
               !state.isMouseInMenuBarZone,
               !state.isMouseInExpandedPanel,
               shouldScheduleAutoCollapse(from: state, rootContentStatus: .expanded) {
                let generation = state.autoCollapseGeneration + 1
            return replace(
                state,
                displayState: displayState,
                rootContentStatus: displayState == .expanded ? .expanded : .compact,
                autoCollapseGeneration: generation,
                expandedSince: displayState == .expanded ? now() : nil,
                transientAutoRevealKind: .some(nil),
                actions: [
                    .setDisplayState(displayState),
                    .scheduleAutoCollapse(delay: settings.transientRevealDwellSeconds, generation: generation),
                ]
            )
            }
            return replace(
                state,
                displayState: displayState,
                rootContentStatus: displayState == .expanded ? .expanded : .compact,
                expandedSince: displayState == .expanded ? now() : nil,
                transientAutoRevealKind: .some(nil),
                actions: [.setDisplayState(displayState)]
            )
        case .openSwitcher:
            return openSwitcher(from: state)
        case let .setMenuBarHover(isHovering):
            return planMenuBarHover(isHovering, from: state)
        case let .setMouseInMenuBarZone(isInside):
            return replace(state, isMouseInMenuBarZone: isInside, actions: [])
        case let .setExpandedPanelHover(isHovering):
            return planExpandedPanelHover(isHovering, from: state)
        case let .hoverRevealTick(generation):
            return hoverRevealTick(generation: generation, from: state)
        case let .setPinned(isPinned):
            return replace(state, isPinned: isPinned, actions: [])
        case let .setKeyboardFocusNeeded(isNeeded):
            return replace(
                state,
                needsKeyboardFocus: isNeeded,
                actions: [isNeeded ? .requestKeyboardFocus : .releaseKeyboardFocus]
            )
        case let .transientReveal(kind, displayState):
            return transientReveal(kind: kind, displayState: displayState, from: state)
        case .outsideClick:
            return outsideClick(from: state)
        case let .autoCollapseTick(generation):
            return autoCollapseTick(generation: generation, from: state)
        case let .mouseLeaveCollapseTick(generation):
            return mouseLeaveCollapseTick(generation: generation, from: state)
        }
    }

    public func stateRecordingExpandedEntry(from state: PanelInteractionState) -> PanelInteractionState {
        PanelInteractionState(
            displayState: .expanded,
            rootContentStatus: .expanded,
            isPinned: state.isPinned,
            isHovering: state.isHovering,
            isMouseInMenuBarZone: state.isMouseInMenuBarZone,
            isMouseInExpandedPanel: state.isMouseInExpandedPanel,
            needsKeyboardFocus: state.needsKeyboardFocus,
            autoCollapseGeneration: state.autoCollapseGeneration,
            mouseLeaveCollapseGeneration: state.mouseLeaveCollapseGeneration,
            expandedSince: now(),
            hoverCooldownUntil: state.hoverCooldownUntil,
            transientRevealDwellSeconds: state.transientRevealDwellSeconds,
            transientAutoRevealKind: state.transientAutoRevealKind,
            blockingActionVisible: state.blockingActionVisible,
            onboardingActive: state.onboardingActive
        )
    }

    private func planMenuBarHover(_ isHovering: Bool, from state: PanelInteractionState) -> PanelInteractionPlan {
        // V3's hover setter does not replace its retained work item when
        // repeated AppKit pointer delivery carries the same Boolean value.
        guard isHovering != state.isHovering else {
            return PanelInteractionPlan(nextState: state, actions: [])
        }

        var actions: [PanelInteractionAction] = []
        let displayState = state.displayState
        let rootContentStatus = state.rootContentStatus
        let expandedSince = state.expandedSince
        var generation = state.autoCollapseGeneration

        if isHovering,
           settings.hoverToExpandEnabled,
           let delay = hoverRevealDelay(for: displayState) {
            generation += 1
            actions.append(
                .scheduleHoverReveal(
                    delay: delay,
                    generation: generation
                )
            )
        } else if !isHovering, state.isHovering {
            generation += 1
            actions = [.cancelHoverReveal]
        }

        return replace(
            state,
            displayState: displayState,
            rootContentStatus: rootContentStatus,
            isHovering: isHovering,
            autoCollapseGeneration: generation,
            expandedSince: expandedSince,
            actions: actions
        )
    }

    private func hoverRevealDelay(for displayState: PanelDisplayState) -> Double? {
        switch displayState {
        case .closed:
            // V3 `sub_100103AFC` schedules its closed-status work item with
            // the configured delay, without the peek-path cap.
            return settings.hoverExpandDelay
        case .notificationPeek:
            // V3 caps the separate compact-peek work item at 0.2 seconds.
            return min(0.2, settings.hoverExpandDelay)
        case .opening, .expanded, .switcher, .onboarding, .hidden, .autoHidden:
            return nil
        }
    }

    private func planExpandedPanelHover(_ isHovering: Bool, from state: PanelInteractionState) -> PanelInteractionPlan {
        if isHovering {
            return replace(
                state,
                isHovering: true,
                isMouseInExpandedPanel: true,
                mouseLeaveCollapseGeneration: .some(nil),
                actions: [.cancelMouseLeaveCollapse]
            )
        }

        guard shouldScheduleAutoCollapse(from: state) else {
            return replace(
                state,
                isHovering: false,
                isMouseInExpandedPanel: false,
                mouseLeaveCollapseGeneration: .some(nil),
                actions: [.cancelMouseLeaveCollapse]
            )
        }

        let generation = (state.mouseLeaveCollapseGeneration ?? 0) + 1
        return replace(
            state,
            isHovering: false,
            isMouseInExpandedPanel: false,
            mouseLeaveCollapseGeneration: generation,
            actions: [.scheduleMouseLeaveCollapse(delay: settings.mouseLeaveCollapseDelay, generation: generation)]
        )
    }

    private func transientReveal(
        kind: TransientAutoRevealKind,
        displayState: PanelDisplayState,
        from state: PanelInteractionState
    ) -> PanelInteractionPlan {
        let generation = state.autoCollapseGeneration + 1
        return replace(
            state,
            displayState: displayState,
            rootContentStatus: rootContentStatus(for: displayState),
            autoCollapseGeneration: generation,
            mouseLeaveCollapseGeneration: .some(nil),
            expandedSince: displayState == .expanded ? now() : nil,
            transientAutoRevealKind: .some(kind),
            actions: [
                .cancelMouseLeaveCollapse,
                .setDisplayState(displayState),
                .scheduleAutoCollapse(delay: settings.transientRevealDwellSeconds, generation: generation)
            ]
        )
    }

    private func openSwitcher(from state: PanelInteractionState) -> PanelInteractionPlan {
        let generation = state.autoCollapseGeneration + 1
        return replace(
            state,
            displayState: .switcher,
            rootContentStatus: .expanded,
            autoCollapseGeneration: generation,
            mouseLeaveCollapseGeneration: .some(nil),
            expandedSince: now(),
            transientAutoRevealKind: .some(nil),
            actions: [
                .cancelHoverReveal,
                .cancelAutoCollapse,
                .cancelMouseLeaveCollapse,
                .setDisplayState(.switcher),
            ]
        )
    }

    private func hoverRevealTick(generation: Int, from state: PanelInteractionState) -> PanelInteractionPlan {
        guard generation == state.autoCollapseGeneration,
              state.displayState == .closed || state.displayState == .notificationPeek,
              state.isHovering else {
            return PanelInteractionPlan(nextState: state, actions: [])
        }

        return replace(
            state,
            displayState: .expanded,
            rootContentStatus: .expanded,
            expandedSince: now(),
            transientAutoRevealKind: .some(nil),
            actions: [.setDisplayState(.expanded)]
        )
    }


    private func outsideClick(from state: PanelInteractionState) -> PanelInteractionPlan {
        guard settings.dismissTransientRevealOnOutsideClick, !state.isPinned else {
            return PanelInteractionPlan(nextState: state, actions: [])
        }

        return replace(
            state,
            displayState: .closed,
            rootContentStatus: .compact,
            transientAutoRevealKind: .some(nil),
            actions: [
                .setDisplayState(.closed),
                .collapsePanel(reason: .outsideClick)
            ]
        )
    }

    private func autoCollapseTick(generation: Int, from state: PanelInteractionState) -> PanelInteractionPlan {
        guard generation == state.autoCollapseGeneration,
              !state.isHovering,
              !state.isMouseInExpandedPanel,
              shouldScheduleAutoCollapse(from: state) else {
            return PanelInteractionPlan(nextState: state, actions: [])
        }

        return replace(
            state,
            displayState: .closed,
            rootContentStatus: .compact,
            transientAutoRevealKind: .some(nil),
            actions: [
                .setDisplayState(.closed),
                .collapsePanel(reason: .autoCollapse)
            ]
        )
    }

    private func mouseLeaveCollapseTick(generation: Int, from state: PanelInteractionState) -> PanelInteractionPlan {
        guard generation == state.mouseLeaveCollapseGeneration,
              !state.isMouseInExpandedPanel,
              shouldScheduleAutoCollapse(from: state) else {
            return PanelInteractionPlan(nextState: state, actions: [])
        }

        return replace(
            state,
            displayState: .closed,
            rootContentStatus: .compact,
            mouseLeaveCollapseGeneration: .some(nil),
            transientAutoRevealKind: .some(nil),
            actions: [
                .setDisplayState(.closed),
                .collapsePanel(reason: .autoCollapse)
            ]
        )
    }

    private func shouldScheduleAutoCollapse(
        from state: PanelInteractionState,
        rootContentStatus: NotchRootContentStatus? = nil
    ) -> Bool {
        settings.autoCollapseOnMouseLeave
            && (rootContentStatus ?? state.rootContentStatus) == .expanded
            && !state.isPinned
            && !state.blockingActionVisible
            && !state.onboardingActive
            // The original leave callback keeps the panel open while a
            // switcher selection exists. The local switcher always owns a
            // highlighted selection for its open lifetime.
            && state.displayState != .switcher
    }

    private func rootContentStatus(for displayState: PanelDisplayState) -> NotchRootContentStatus {
        NotchRootContentStatus(displayStatus: NotchDisplayStatus(displayState: displayState))
    }

    private func replace(
        _ state: PanelInteractionState,
        displayState: PanelDisplayState? = nil,
        rootContentStatus: NotchRootContentStatus? = nil,
        isPinned: Bool? = nil,
        isHovering: Bool? = nil,
        isMouseInMenuBarZone: Bool? = nil,
        isMouseInExpandedPanel: Bool? = nil,
        needsKeyboardFocus: Bool? = nil,
        autoCollapseGeneration: Int? = nil,
        mouseLeaveCollapseGeneration: Int?? = nil,
        expandedSince: Double? = nil,
        transientAutoRevealKind: TransientAutoRevealKind?? = nil,
        actions: [PanelInteractionAction]
    ) -> PanelInteractionPlan {
        let nextDisplayState = displayState ?? state.displayState
        let nextRootContentStatus = rootContentStatus ?? state.rootContentStatus
        return PanelInteractionPlan(
            nextState: PanelInteractionState(
                displayState: nextDisplayState,
                rootContentStatus: nextRootContentStatus,
                isPinned: isPinned ?? state.isPinned,
                isHovering: isHovering ?? state.isHovering,
                isMouseInMenuBarZone: isMouseInMenuBarZone ?? state.isMouseInMenuBarZone,
                isMouseInExpandedPanel: isMouseInExpandedPanel ?? state.isMouseInExpandedPanel,
                needsKeyboardFocus: needsKeyboardFocus ?? state.needsKeyboardFocus,
                autoCollapseGeneration: autoCollapseGeneration ?? state.autoCollapseGeneration,
                mouseLeaveCollapseGeneration: mouseLeaveCollapseGeneration ?? state.mouseLeaveCollapseGeneration,
                expandedSince: nextDisplayState == .expanded
                    ? (expandedSince ?? state.expandedSince)
                    : nil,
                hoverCooldownUntil: state.hoverCooldownUntil,
                transientRevealDwellSeconds: settings.transientRevealDwellSeconds,
                transientAutoRevealKind: transientAutoRevealKind ?? state.transientAutoRevealKind,
                blockingActionVisible: state.blockingActionVisible,
                onboardingActive: state.onboardingActive
            ),
            actions: actions
        )
    }
}
