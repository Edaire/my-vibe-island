import XCTest
@testable import MyVibeIslandCore

final class PanelInteractionModelsTests: XCTestCase {
    func testPanelInteractionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            PanelInteractionMatrixFixture.self,
            from: try FixtureLoader.data("runtime/panel-interaction-matrix")
        )
        let hoverController = PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.35))
        let dwellController = PanelInteractionController(settings: BehaviourSettings(transientRevealDwellSeconds: 4.0))
        let defaultController = PanelInteractionController()

        let actual = PanelInteractionMatrixFixture(rows: [
            PanelInteractionMatrixRow(
                id: "menu-hover-open",
                plan: hoverController.plan(.setMenuBarHover(true), from: PanelInteractionState())
            ),
            PanelInteractionMatrixRow(
                id: "expanded-leave-auto-collapse",
                plan: dwellController.plan(
                    .setExpandedPanelHover(false),
                    from: PanelInteractionState(
                        displayState: .expanded,
                        isMouseInExpandedPanel: true,
                        autoCollapseGeneration: 4,
                        expandedSince: 1
                    )
                )
            ),
            PanelInteractionMatrixRow(
                id: "transient-notification-reveal",
                plan: dwellController.plan(
                    .transientReveal(kind: .attentionReminder, displayState: .notificationPeek),
                    from: PanelInteractionState()
                )
            ),
            PanelInteractionMatrixRow(
                id: "matching-auto-collapse-tick",
                plan: defaultController.plan(
                    .autoCollapseTick(generation: 3),
                    from: PanelInteractionState(displayState: .expanded, autoCollapseGeneration: 3)
                )
            ),
            PanelInteractionMatrixRow(
                id: "pinned-outside-click-ignored",
                plan: defaultController.plan(
                    .outsideClick,
                    from: PanelInteractionState(displayState: .expanded, isPinned: true)
                )
            ),
            PanelInteractionMatrixRow(
                id: "keyboard-focus-request",
                plan: defaultController.plan(.setKeyboardFocusNeeded(true), from: PanelInteractionState())
            ),
            PanelInteractionMatrixRow(
                id: "onboarding-blocks-auto-collapse",
                plan: defaultController.plan(
                    .setExpandedPanelHover(false),
                    from: PanelInteractionState(
                        displayState: .expanded,
                        isMouseInExpandedPanel: true,
                        onboardingActive: true
                    )
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testMenuBarHoverSchedulesRevealWhenHoverExpandIsEnabled() {
        let controller = PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.35))

        let plan = controller.plan(.setMenuBarHover(true), from: PanelInteractionState())

        XCTAssertTrue(plan.nextState.isHovering)
        XCTAssertFalse(plan.nextState.isMouseInMenuBarZone)
        XCTAssertEqual(plan.nextState.displayState, .closed)
        XCTAssertEqual(plan.nextState.rootContentStatus, .compact)
        XCTAssertEqual(plan.actions, [
            .scheduleHoverReveal(delay: 0.35, generation: 1)
        ])
    }

    func testRepeatedMenuBarHoverDoesNotReplaceThePendingV3Reveal() {
        let controller = PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.35))
        let pending = controller.plan(.setMenuBarHover(true), from: PanelInteractionState()).nextState

        let repeated = controller.plan(.setMenuBarHover(true), from: pending)

        XCTAssertEqual(repeated.nextState, pending)
        XCTAssertEqual(repeated.actions, [])
    }

    func testNotificationPeekHoverCapsConfiguredDelayAtOriginalTwoTenthsOfASecond() {
        let controller = PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.35))
        let peek = PanelInteractionState(
            displayState: .notificationPeek,
            rootContentStatus: .compact
        )

        let plan = controller.plan(.setMenuBarHover(true), from: peek)

        XCTAssertEqual(plan.actions, [
            .scheduleHoverReveal(delay: 0.2, generation: 1)
        ])
    }

    func testExpandedHoverDoesNotScheduleAnInapplicableReveal() {
        let controller = PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.35))
        let expanded = PanelInteractionState(
            displayState: .expanded,
            rootContentStatus: .expanded
        )

        let plan = controller.plan(.setMenuBarHover(true), from: expanded)

        XCTAssertTrue(plan.nextState.isHovering)
        XCTAssertEqual(plan.actions, [])
    }

    func testMenuBarZoneUpdatesIndependentlyFromHoverFeedback() {
        let controller = PanelInteractionController()
        let hovering = controller.plan(.setMenuBarHover(true), from: PanelInteractionState()).nextState

        let insideZone = controller.plan(.setMouseInMenuBarZone(true), from: hovering)

        XCTAssertTrue(insideZone.nextState.isHovering)
        XCTAssertTrue(insideZone.nextState.isMouseInMenuBarZone)
        XCTAssertEqual(insideZone.actions, [])
    }

    func testHoverRevealTickExpandsOnlyWhilePointerRemainsInHoverRect() {
        let controller = PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.35))
        let pending = controller.plan(.setMenuBarHover(true), from: PanelInteractionState()).nextState

        let expanded = controller.plan(.hoverRevealTick(generation: 1), from: pending)
        let left = controller.plan(.setMenuBarHover(false), from: pending).nextState
        let ignored = controller.plan(.hoverRevealTick(generation: 1), from: left)

        XCTAssertEqual(expanded.nextState.displayState, .expanded)
        XCTAssertEqual(expanded.actions, [.setDisplayState(.expanded)])
        XCTAssertEqual(ignored.nextState, left)
        XCTAssertEqual(ignored.actions, [])
    }

    func testHoverRevealPromotesNotificationPeekWhilePointerRemainsInHoverRect() {
        let controller = PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.15))
        let peek = PanelInteractionState(
            displayState: .notificationPeek,
            rootContentStatus: .compact
        )
        let pending = controller.plan(.setMenuBarHover(true), from: peek).nextState

        let expanded = controller.plan(
            .hoverRevealTick(generation: pending.autoCollapseGeneration),
            from: pending
        )

        XCTAssertEqual(expanded.nextState.displayState, .expanded)
        XCTAssertEqual(expanded.nextState.rootContentStatus, .expanded)
        XCTAssertEqual(expanded.actions, [.setDisplayState(.expanded)])
    }

    func testMenuBarHoverLeaveCancelsPendingRevealAndAdvancesGeneration() {
        let controller = PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.35))
        let pending = controller.plan(.setMenuBarHover(true), from: PanelInteractionState()).nextState

        let plan = controller.plan(.setMenuBarHover(false), from: pending)

        XCTAssertFalse(plan.nextState.isHovering)
        XCTAssertEqual(plan.nextState.autoCollapseGeneration, 2)
        XCTAssertEqual(plan.actions, [.cancelHoverReveal])
    }

    func testToggleExpandedSwitchesBetweenCompactAndExpandedStates() {
        let controller = PanelInteractionController()

        let expanded = controller.plan(
            .toggleExpanded,
            from: PanelInteractionState(isMouseInMenuBarZone: true)
        )
        let closed = controller.plan(.toggleExpanded, from: expanded.nextState)

        XCTAssertEqual(expanded.nextState.displayState, .expanded)
        XCTAssertEqual(expanded.actions, [.setDisplayState(.expanded)])
        XCTAssertEqual(closed.nextState.displayState, .closed)
        XCTAssertEqual(closed.actions, [.setDisplayState(.closed)])
    }

    func testToggleExpandedUsesRevealDwellBeforeAutoCollapseWhenPointerIsOutsideInteractiveSurface() {
        let controller = PanelInteractionController(settings: BehaviourSettings(transientRevealDwellSeconds: 4.0))

        let plan = controller.plan(.toggleExpanded, from: PanelInteractionState())

        XCTAssertEqual(plan.nextState.displayState, .expanded)
        XCTAssertEqual(plan.nextState.autoCollapseGeneration, 1)
        XCTAssertEqual(plan.actions, [
            .setDisplayState(.expanded),
            .scheduleAutoCollapse(delay: 4.0, generation: 1),
        ])
    }

    func testExpandedPanelLeaveUsesOrdinaryMouseLeaveDelay() {
        let controller = PanelInteractionController(settings: BehaviourSettings(transientRevealDwellSeconds: 3.5))
        let expanded = PanelInteractionState(
            displayState: .expanded,
            isMouseInExpandedPanel: true,
            autoCollapseGeneration: 4,
            expandedSince: 1
        )

        let plan = controller.plan(.setExpandedPanelHover(false), from: expanded)

        XCTAssertFalse(plan.nextState.isMouseInExpandedPanel)
        XCTAssertEqual(plan.nextState.autoCollapseGeneration, 4)
        XCTAssertEqual(plan.nextState.mouseLeaveCollapseGeneration, 1)
        XCTAssertEqual(plan.actions, [
            .scheduleMouseLeaveCollapse(delay: 0.25, generation: 1)
        ])
    }

    func testExpandedIntentWithoutExpandedRootDoesNotScheduleMouseLeaveCollapse() {
        let controller = PanelInteractionController()
        let state = PanelInteractionState(
            displayState: .expanded,
            rootContentStatus: .compact,
            isMouseInExpandedPanel: true,
            expandedSince: 1
        )

        let plan = controller.plan(.setExpandedPanelHover(false), from: state)

        XCTAssertFalse(plan.nextState.isMouseInExpandedPanel)
        XCTAssertNil(plan.nextState.mouseLeaveCollapseGeneration)
        XCTAssertEqual(plan.actions, [.cancelMouseLeaveCollapse])
    }

    func testExpandedPanelReentryPreservesTransientDwellTimer() {
        let controller = PanelInteractionController()
        let state = PanelInteractionState(
            displayState: .expanded,
            isMouseInExpandedPanel: false,
            autoCollapseGeneration: 4
        )

        let plan = controller.plan(.setExpandedPanelHover(true), from: state)

        XCTAssertFalse(plan.actions.contains(.cancelAutoCollapse))
    }

    func testExpandedPanelLeaveImmediatelyAfterEntrySchedulesTheOriginalMouseLeaveWorkItem() {
        let controller = PanelInteractionController(now: { 10.0 })
        let justExpanded = PanelInteractionState(
            displayState: .expanded,
            isMouseInExpandedPanel: true,
            autoCollapseGeneration: 4,
            expandedSince: 9.96
        )

        let plan = controller.plan(.setExpandedPanelHover(false), from: justExpanded)

        XCTAssertFalse(plan.nextState.isMouseInExpandedPanel)
        XCTAssertEqual(plan.nextState.autoCollapseGeneration, 4)
        XCTAssertEqual(plan.nextState.mouseLeaveCollapseGeneration, 1)
        XCTAssertEqual(plan.actions, [.scheduleMouseLeaveCollapse(delay: 0.25, generation: 1)])
    }

    func testExpandedPanelLeaveUsesTheSameMouseLeaveWorkItemAfterExpandedHasExistedForMoreThanFiftyMilliseconds() {
        let controller = PanelInteractionController(now: { 10.0 })
        let expanded = PanelInteractionState(
            displayState: .expanded,
            isMouseInExpandedPanel: true,
            autoCollapseGeneration: 4,
            expandedSince: 9.94
        )

        let plan = controller.plan(.setExpandedPanelHover(false), from: expanded)

        XCTAssertEqual(plan.nextState.autoCollapseGeneration, 4)
        XCTAssertEqual(plan.nextState.mouseLeaveCollapseGeneration, 1)
        XCTAssertEqual(plan.actions, [.scheduleMouseLeaveCollapse(delay: 0.25, generation: 1)])
    }

    func testExpandedLeaveCollapsesWhenOnlyTheStaleMenuBarFlagRemains() {
        let controller = PanelInteractionController()
        let state = PanelInteractionState(
            displayState: .expanded,
            isMouseInMenuBarZone: true,
            isMouseInExpandedPanel: false,
            autoCollapseGeneration: 5,
            expandedSince: 1
        )

        let plan = controller.plan(.autoCollapseTick(generation: 5), from: state)

        XCTAssertEqual(plan.nextState.displayState, .closed)
        XCTAssertEqual(plan.actions, [
            .setDisplayState(.closed),
            .collapsePanel(reason: .autoCollapse),
        ])
    }

    func testHoverRevealRecordsTheExpandedEntryTime() {
        let controller = PanelInteractionController(now: { 10.0 })
        let pending = controller.plan(.setMenuBarHover(true), from: PanelInteractionState()).nextState

        let plan = controller.plan(.hoverRevealTick(generation: 1), from: pending)

        XCTAssertEqual(plan.nextState.displayState, .expanded)
        XCTAssertEqual(plan.nextState.expandedSince, 10.0)
    }

    func testPinnedPanelDoesNotScheduleAutoCollapseButKeyboardFocusedPanelStillDoes() {
        let controller = PanelInteractionController()
        let pinned = PanelInteractionState(
            displayState: .expanded,
            isPinned: true,
            isMouseInExpandedPanel: true,
            expandedSince: 1
        )
        let focused = PanelInteractionState(
            displayState: .expanded,
            isMouseInExpandedPanel: true,
            needsKeyboardFocus: true,
            expandedSince: 1
        )

        XCTAssertEqual(controller.plan(.setExpandedPanelHover(false), from: pinned).actions, [
            .cancelMouseLeaveCollapse
        ])
        XCTAssertEqual(controller.plan(.setExpandedPanelHover(false), from: focused).actions, [
            .scheduleMouseLeaveCollapse(delay: 0.25, generation: 1)
        ])
    }

    func testOpenSwitcherDoesNotScheduleMouseLeaveCollapse() {
        let controller = PanelInteractionController()
        let switcher = PanelInteractionState(
            displayState: .switcher,
            isMouseInExpandedPanel: true
        )

        let plan = controller.plan(.setExpandedPanelHover(false), from: switcher)

        XCTAssertFalse(plan.nextState.isMouseInExpandedPanel)
        XCTAssertNil(plan.nextState.mouseLeaveCollapseGeneration)
        XCTAssertEqual(plan.actions, [.cancelMouseLeaveCollapse])
    }

    func testOpeningSwitcherCancelsStaleTimersWithoutSchedulingTransientDwell() {
        let controller = PanelInteractionController(now: { 42 })
        let state = PanelInteractionState(
            displayState: .notificationPeek,
            isHovering: true,
            isMouseInExpandedPanel: true,
            autoCollapseGeneration: 7,
            mouseLeaveCollapseGeneration: 3
        )

        let plan = controller.plan(.openSwitcher, from: state)

        XCTAssertEqual(plan.nextState.displayState, .switcher)
        XCTAssertEqual(plan.nextState.rootContentStatus, .expanded)
        XCTAssertEqual(plan.nextState.autoCollapseGeneration, 8)
        XCTAssertNil(plan.nextState.mouseLeaveCollapseGeneration)
        XCTAssertNil(plan.nextState.expandedSince)
        XCTAssertEqual(plan.actions, [
            .cancelHoverReveal,
            .cancelAutoCollapse,
            .cancelMouseLeaveCollapse,
            .setDisplayState(.switcher),
        ])
        XCTAssertFalse(plan.actions.contains { action in
            if case .scheduleAutoCollapse = action {
                return true
            }
            return false
        })

        let staleTick = controller.plan(
            .autoCollapseTick(generation: state.autoCollapseGeneration),
            from: plan.nextState
        )
        XCTAssertEqual(staleTick.nextState, plan.nextState)
        XCTAssertEqual(staleTick.actions, [])
    }

    func testTransientRevealSchedulesDwellAutoCollapse() {
        let controller = PanelInteractionController(settings: BehaviourSettings(transientRevealDwellSeconds: 4.0))

        let plan = controller.plan(
            .transientReveal(kind: .attentionReminder, displayState: .notificationPeek),
            from: PanelInteractionState()
        )

        XCTAssertEqual(plan.nextState.displayState, .notificationPeek)
        XCTAssertEqual(plan.nextState.autoCollapseGeneration, 1)
        XCTAssertEqual(plan.actions, [
            .cancelMouseLeaveCollapse,
            .setDisplayState(.notificationPeek),
            .scheduleAutoCollapse(delay: 4.0, generation: 1)
        ])
    }

    func testAutoCollapseTickCollapsesOnlyMatchingGeneration() {
        let controller = PanelInteractionController()
        let state = PanelInteractionState(displayState: .expanded, autoCollapseGeneration: 3)

        let stale = controller.plan(.autoCollapseTick(generation: 2), from: state)
        XCTAssertEqual(stale.actions, [])
        XCTAssertEqual(stale.nextState, state)

        let current = controller.plan(.autoCollapseTick(generation: 3), from: state)
        XCTAssertEqual(current.nextState.displayState, .closed)
        XCTAssertEqual(current.actions, [
            .setDisplayState(.closed),
            .collapsePanel(reason: .autoCollapse)
        ])
    }

    func testAutoCollapseTickDoesNothingWhilePointerRemainsInsideExpandedPanel() {
        let controller = PanelInteractionController()
        let state = PanelInteractionState(
            displayState: .notificationPeek,
            isMouseInExpandedPanel: true,
            autoCollapseGeneration: 3
        )

        let plan = controller.plan(.autoCollapseTick(generation: 3), from: state)

        XCTAssertEqual(plan.nextState, state)
        XCTAssertEqual(plan.actions, [])
    }

    func testAutoCollapseResultKeepsCompactPillVisible() {
        let controller = PanelInteractionController()
        let result = controller.plan(
            .autoCollapseTick(generation: 3),
            from: PanelInteractionState(displayState: .expanded, autoCollapseGeneration: 3)
        )
        let displayStatus = NotchDisplayStatus(displayState: result.nextState.displayState)
        let surface = IslandSurfaceSnapshot(
            displayStatus: displayStatus,
            layoutMode: .compact,
            focusedSessionId: nil,
            presentationState: NotchPresentationState(
                displayState: result.nextState.displayState,
                interactionState: result.nextState
            ),
            sessionSets: NotchSessionSets(),
            contentDimensions: NotchContentDimensions(
                closedSize: DisplaySize(width: 220, height: 36),
                activeContentSize: DisplaySize(width: 220, height: 36)
            ),
            pillSnapshot: PillSnapshot(visualState: .idle),
            completionUnreadDot: CompletionUnreadDot(),
            stateIndicator: StateIndicator(kind: .idle)
        )

        XCTAssertTrue(IslandSurfaceSections(surface: surface).visibleSections.contains(.compactPill))
    }

    func testBlockingRequestAndOnboardingKeepTheExpandedPanelOpen() {
        let controller = PanelInteractionController()
        let blocking = PanelInteractionState(
            displayState: .expanded,
            isMouseInExpandedPanel: true,
            expandedSince: 1,
            blockingActionVisible: true
        )
        let onboarding = PanelInteractionState(displayState: .expanded, isMouseInExpandedPanel: true, onboardingActive: true)

        XCTAssertEqual(controller.plan(.setExpandedPanelHover(false), from: blocking).actions, [
            .cancelMouseLeaveCollapse
        ])
        XCTAssertEqual(controller.plan(.setExpandedPanelHover(false), from: onboarding).actions, [
            .cancelMouseLeaveCollapse
        ])
    }

    func testDisplayBlockingKindDerivesFromInteractionState() {
        XCTAssertEqual(
            DisplayBlockingKind(state: PanelInteractionState(displayState: .expanded, isPinned: true)),
            .pinned
        )
        XCTAssertEqual(
            DisplayBlockingKind(state: PanelInteractionState(displayState: .expanded, needsKeyboardFocus: true)),
            .keyboardFocus
        )
        XCTAssertEqual(
            DisplayBlockingKind(state: PanelInteractionState(displayState: .expanded, blockingActionVisible: true)),
            .blockingAction
        )
        XCTAssertEqual(
            DisplayBlockingKind(state: PanelInteractionState(displayState: .expanded, onboardingActive: true)),
            .onboarding
        )
    }

    func testDisplayCollapseReasonMapsPanelCollapseReason() {
        XCTAssertEqual(DisplayCollapseReason(panelReason: .autoCollapse), .autoCollapse)
        XCTAssertEqual(DisplayCollapseReason(panelReason: .outsideClick), .outsideClick)
        XCTAssertEqual(DisplayCollapseReason(panelReason: .keyboardShortcut), .keyboardShortcut)
    }

    func testDisplayHoverPolicyDerivesFromPreferencesAndState() {
        let disabled = BehaviourSettings(hoverToExpandEnabled: false)
        let enabled = BehaviourSettings(hoverToExpandEnabled: true)

        XCTAssertEqual(DisplayHoverPolicy(settings: disabled, state: PanelInteractionState()), .disabled)
        XCTAssertEqual(
            DisplayHoverPolicy(settings: enabled, state: PanelInteractionState(hoverCooldownUntil: 10)),
            .coolingDown
        )
        XCTAssertEqual(
            DisplayHoverPolicy(settings: enabled, state: PanelInteractionState(isPinned: true)),
            .pinnedOpen
        )
        XCTAssertEqual(DisplayHoverPolicy(settings: enabled, state: PanelInteractionState()), .enabled)
    }

    func testTransientAutoRevealKindUsesV3ProducerReasonsAndDoesNotInferFromPanelState() {
        XCTAssertEqual(TransientAutoRevealKind.allCases, [
            .attentionReminder,
            .taskComplete,
            .compactionComplete,
            .statusWarning,
            .usageLimit,
        ])
        XCTAssertNil(TransientAutoRevealKind(displayState: .notificationPeek))
        XCTAssertNil(TransientAutoRevealKind(displayState: .switcher))
        XCTAssertNil(TransientAutoRevealKind(displayState: .onboarding))
        XCTAssertNil(TransientAutoRevealKind(displayState: .expanded))
    }

    func testStateRoundTripsThroughJSON() throws {
        let state = PanelInteractionState(
            displayState: .switcher,
            isPinned: true,
            isHovering: true,
            isMouseInMenuBarZone: true,
            isMouseInExpandedPanel: false,
            needsKeyboardFocus: true,
            autoCollapseGeneration: 8,
            hoverCooldownUntil: 12.5,
            transientRevealDwellSeconds: 4.0,
            blockingActionVisible: false,
            onboardingActive: true
        )

        let decoded = try JSONDecoder().decode(
            PanelInteractionState.self,
            from: try JSONEncoder().encode(state)
        )

        XCTAssertEqual(decoded, state)
    }

    func testLegacyStateDecodingDerivesMissingRootContentStatus() throws {
        let data = Data("""
        {
          "displayState": "notificationPeek",
          "isPinned": false,
          "isHovering": false,
          "isMouseInMenuBarZone": false,
          "isMouseInExpandedPanel": false,
          "needsKeyboardFocus": false,
          "autoCollapseGeneration": 3,
          "mouseLeaveCollapseGeneration": null,
          "expandedSince": null,
          "hoverCooldownUntil": null,
          "transientRevealDwellSeconds": 5,
          "blockingActionVisible": false,
          "onboardingActive": false
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(PanelInteractionState.self, from: data)

        XCTAssertEqual(decoded.displayState, .notificationPeek)
        XCTAssertEqual(decoded.rootContentStatus, .compact)
    }
}

private struct PanelInteractionMatrixFixture: Codable, Equatable {
    let rows: [PanelInteractionMatrixRow]
}

private struct PanelInteractionMatrixRow: Codable, Equatable {
    let id: String
    let displayState: PanelDisplayState
    let isPinned: Bool
    let isHovering: Bool
    let isMouseInMenuBarZone: Bool
    let isMouseInExpandedPanel: Bool
    let needsKeyboardFocus: Bool
    let autoCollapseGeneration: Int
    let blockingKind: DisplayBlockingKind?
    let transientAutoRevealKind: TransientAutoRevealKind?
    let hoverPolicyWhenEnabled: DisplayHoverPolicy
    let actionSummaries: [String]

    init(id: String, plan: PanelInteractionPlan) {
        self.id = id
        let state = plan.nextState
        displayState = state.displayState
        isPinned = state.isPinned
        isHovering = state.isHovering
        isMouseInMenuBarZone = state.isMouseInMenuBarZone
        isMouseInExpandedPanel = state.isMouseInExpandedPanel
        needsKeyboardFocus = state.needsKeyboardFocus
        autoCollapseGeneration = state.autoCollapseGeneration
        blockingKind = DisplayBlockingKind(state: state)
        transientAutoRevealKind = state.transientAutoRevealKind
        hoverPolicyWhenEnabled = DisplayHoverPolicy(settings: BehaviourSettings(), state: state)
        actionSummaries = plan.actions.map(Self.describe(_:))
    }

    private static func describe(_ action: PanelInteractionAction) -> String {
        switch action {
        case let .setDisplayState(displayState):
            return "setDisplayState:\(displayState.rawValue)"
        case let .scheduleHoverReveal(delay, generation):
            return "scheduleHoverReveal:\(delay):\(generation)"
        case .cancelHoverReveal:
            return "cancelHoverReveal"
        case .cancelAutoCollapse:
            return "cancelAutoCollapse"
        case let .scheduleAutoCollapse(delay, generation):
            return "scheduleAutoCollapse:\(delay):\(generation)"
        case .cancelMouseLeaveCollapse:
            return "cancelMouseLeaveCollapse"
        case let .scheduleMouseLeaveCollapse(delay, generation):
            return "scheduleMouseLeaveCollapse:\(delay):\(generation)"
        case let .collapsePanel(reason):
            return "collapsePanel:\(reason.rawValue)"
        case .requestKeyboardFocus:
            return "requestKeyboardFocus"
        case .releaseKeyboardFocus:
            return "releaseKeyboardFocus"
        }
    }
}
