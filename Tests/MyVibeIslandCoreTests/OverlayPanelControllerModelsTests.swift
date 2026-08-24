import XCTest
@testable import MyVibeIslandCore

final class OverlayPanelControllerModelsTests: XCTestCase {
    func testOverlayPanelControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OverlayPanelControllerMatrixFixture.self,
            from: try FixtureLoader.data("runtime/overlay-panel-controller-matrix")
        )
        let controller = OverlayPanelControllerModel()
        let hoverController = OverlayPanelControllerModel(
            interactionController: PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.25))
        )
        let outsideClickController = OverlayPanelControllerModel(
            interactionController: PanelInteractionController(
                settings: BehaviourSettings(dismissTransientRevealOnOutsideClick: true)
            )
        )
        let hiddenPlacement = DisplayPlacementPlan(
            closedFrame: .zero,
            expandedFrame: .zero,
            anchor: DisplayPoint(x: 50, y: 10),
            safeAreaAdjustment: 0,
            collapseReason: .fullscreenHidden
        )
        let placement = placementPlan()

        let actual = OverlayPanelControllerMatrixFixture(rows: [
            OverlayPanelControllerMatrixRow(
                id: "hidden-placement",
                plan: controller.plan(
                    .replacePlacement(hiddenPlacement),
                    from: OverlayPanelState(presentationState: presentationState(displayState: .closed))
                )
            ),
            OverlayPanelControllerMatrixRow(
                id: "visible-placement-expanded",
                plan: controller.plan(
                    .replacePlacement(placement),
                    from: OverlayPanelState(presentationState: presentationState(displayState: .expanded))
                )
            ),
            OverlayPanelControllerMatrixRow(
                id: "interaction-hover-opening",
                plan: hoverController.plan(
                    .interaction(.setMenuBarHover(true)),
                    from: OverlayPanelState(
                        presentationState: presentationState(displayState: .closed),
                        placementPlan: placement
                    )
                )
            ),
            OverlayPanelControllerMatrixRow(
                id: "outside-click-collapse",
                plan: outsideClickController.plan(
                    .interaction(.outsideClick),
                    from: OverlayPanelState(
                        presentationState: presentationState(
                            displayState: .expanded,
                            interactionState: PanelInteractionState(displayState: .expanded)
                        ),
                        placementPlan: placement
                    )
                )
            ),
            OverlayPanelControllerMatrixRow(
                id: "replace-presentation",
                plan: controller.plan(
                    .replacePresentation(presentationState(displayState: .switcher)),
                    from: OverlayPanelState(
                        presentationState: presentationState(displayState: .expanded),
                        placementPlan: placement
                    )
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testPlacementCollapseHidesPanelAndRecordsFullscreenReason() {
        let controller = OverlayPanelControllerModel()
        let state = OverlayPanelState(presentationState: presentationState(displayState: .closed))
        let placement = DisplayPlacementPlan(
            closedFrame: .zero,
            expandedFrame: .zero,
            anchor: DisplayPoint(x: 50, y: 10),
            safeAreaAdjustment: 0,
            collapseReason: .fullscreenHidden
        )

        let plan = controller.plan(.replacePlacement(placement), from: state)

        XCTAssertEqual(plan.nextState.placementPlan, placement)
        XCTAssertEqual(plan.nextState.presentationState.displayState, .hidden)
        XCTAssertEqual(plan.nextState.presentationState.displayReason, .fullscreenHide)
        XCTAssertEqual(plan.actions, [
            .hidePanel(reason: .fullscreenHide),
            .recordDisplayReason(.fullscreenHide)
        ])
    }

    func testVisiblePlacementAppliesFrameForCurrentDisplayState() {
        let controller = OverlayPanelControllerModel(
            interactionController: PanelInteractionController(
                settings: BehaviourSettings(dismissTransientRevealOnOutsideClick: true)
            )
        )
        let state = OverlayPanelState(presentationState: presentationState(displayState: .expanded))
        let placement = placementPlan()

        let plan = controller.plan(.replacePlacement(placement), from: state)

        XCTAssertEqual(plan.nextState.placementPlan, placement)
        XCTAssertEqual(plan.nextState.presentationState.displayState, .expanded)
        XCTAssertEqual(plan.actions, [
            .applyFrame(placement.expandedFrame),
            .showPanel(displayState: .expanded)
        ])
    }

    func testPresentationExpansionReappliesExpandedFrame() {
        let controller = OverlayPanelControllerModel()
        let placement = placementPlan()
        let state = OverlayPanelState(
            presentationState: presentationState(displayState: .closed),
            placementPlan: placement
        )

        let plan = controller.plan(
            .replacePresentation(presentationState(displayState: .expanded)),
            from: state
        )

        XCTAssertEqual(plan.nextState.presentationState.displayState, .expanded)
        XCTAssertEqual(plan.actions, [
            .applyFrame(placement.expandedFrame),
            .showPanel(displayState: .expanded),
        ])
    }

    func testDirectPresentationExpansionRecordsEntryTimeForLeaveGate() {
        let controller = OverlayPanelControllerModel(
            interactionController: PanelInteractionController(now: { 10.0 })
        )

        let plan = controller.plan(
            .replacePresentation(presentationState(displayState: .expanded)),
            from: OverlayPanelState(presentationState: presentationState(displayState: .closed))
        )

        XCTAssertEqual(plan.nextState.presentationState.interactionState.expandedSince, 10.0)
    }

    func testInteractionCommandUpdatesPresentationDisplayStateAndForwardsActions() {
        let controller = OverlayPanelControllerModel(
            interactionController: PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.25))
        )
        let state = OverlayPanelState(
            presentationState: presentationState(displayState: .closed),
            placementPlan: placementPlan()
        )

        let plan = controller.plan(.interaction(.setMenuBarHover(true)), from: state)

        XCTAssertEqual(plan.nextState.presentationState.displayState, .closed)
        XCTAssertEqual(plan.nextState.presentationState.interactionState.isHovering, true)
        XCTAssertEqual(plan.nextState.presentationState.interactionState.isMouseInMenuBarZone, false)
        XCTAssertEqual(plan.actions, [
            .forwardInteractionAction(.scheduleHoverReveal(delay: 0.25, generation: 1))
        ])
    }

    func testMenuBarZoneMutationDoesNotReapplyTheUnchangedWindow() {
        let controller = OverlayPanelControllerModel()
        let state = OverlayPanelState(
            presentationState: presentationState(displayState: .closed),
            placementPlan: placementPlan()
        )

        let plan = controller.plan(.interaction(.setMouseInMenuBarZone(true)), from: state)

        XCTAssertTrue(plan.nextState.presentationState.interactionState.isMouseInMenuBarZone)
        XCTAssertEqual(plan.actions, [])
    }

    func testOutsideClickRecordsCollapseReason() {
        let controller = OverlayPanelControllerModel(
            interactionController: PanelInteractionController(
                settings: BehaviourSettings(dismissTransientRevealOnOutsideClick: true)
            )
        )
        let state = OverlayPanelState(
            presentationState: presentationState(
                displayState: .expanded,
                interactionState: PanelInteractionState(displayState: .expanded)
            ),
            placementPlan: placementPlan()
        )

        let plan = controller.plan(.interaction(.outsideClick), from: state)

        XCTAssertEqual(plan.nextState.presentationState.displayState, .closed)
        XCTAssertEqual(plan.nextState.presentationState.displayReason, .outsideClick)
        XCTAssertEqual(plan.actions, [
            .forwardInteractionAction(.setDisplayState(.closed)),
            .forwardInteractionAction(.collapsePanel(reason: .outsideClick)),
            .applyFrame(placementPlan().closedFrame),
            .showPanel(displayState: .closed),
            .recordDisplayReason(.outsideClick)
        ])
    }

    func testStateRoundTripsThroughJSON() throws {
        let state = OverlayPanelState(
            presentationState: presentationState(displayState: .switcher),
            placementPlan: placementPlan()
        )

        let decoded = try JSONDecoder().decode(
            OverlayPanelState.self,
            from: try JSONEncoder().encode(state)
        )

        XCTAssertEqual(decoded, state)
    }

    private func presentationState(
        displayState: PanelDisplayState,
        interactionState: PanelInteractionState? = nil
    ) -> NotchPresentationState {
        NotchPresentationState(
            displayState: displayState,
            interactionState: interactionState ?? PanelInteractionState(displayState: displayState),
            displayReason: .none
        )
    }

    private func placementPlan() -> DisplayPlacementPlan {
        DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 20, width: 680, height: 580),
            expandedFrame: DisplayFrame(x: 10, y: 20, width: 680, height: 580),
            anchor: DisplayPoint(x: 110, y: 20),
            safeAreaAdjustment: 0
        )
    }
}

private struct OverlayPanelControllerMatrixFixture: Codable, Equatable {
    let rows: [OverlayPanelControllerMatrixRow]
}

private struct OverlayPanelControllerMatrixRow: Codable, Equatable {
    let id: String
    let displayState: PanelDisplayState
    let displayReason: DisplayIntentReason
    let interactionDisplayState: PanelDisplayState
    let isMenuBarHovering: Bool
    let placementSummary: String?
    let actionSummaries: [String]

    init(id: String, plan: OverlayPanelPlan) {
        self.id = id
        let presentation = plan.nextState.presentationState
        displayState = presentation.displayState
        displayReason = presentation.displayReason
        interactionDisplayState = presentation.interactionState.displayState
        isMenuBarHovering = presentation.interactionState.isMouseInMenuBarZone
        placementSummary = plan.nextState.placementPlan.map {
            "\($0.closedFrame.width)x\($0.closedFrame.height)->\($0.expandedFrame.width)x\($0.expandedFrame.height):\($0.collapseReason.map { "\($0)" } ?? "visible")"
        }
        actionSummaries = plan.actions.map(Self.describe(_:))
    }

    private static func describe(_ action: OverlayPanelAction) -> String {
        switch action {
        case let .applyFrame(frame):
            return "applyFrame:\(frame.width)x\(frame.height)"
        case let .showPanel(displayState):
            return "showPanel:\(displayState.rawValue)"
        case let .hidePanel(reason):
            return "hidePanel:\(reason.rawValue)"
        case let .forwardInteractionAction(action):
            return "forwardInteraction:\(describe(action))"
        case let .recordDisplayReason(reason):
            return "recordDisplayReason:\(reason.rawValue)"
        }
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
