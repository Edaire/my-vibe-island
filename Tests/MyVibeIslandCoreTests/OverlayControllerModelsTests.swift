import XCTest
@testable import MyVibeIslandCore

final class OverlayControllerModelsTests: XCTestCase {
    func testOverlayControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OverlayControllerMatrixFixture.self,
            from: try FixtureLoader.data("runtime/overlay-controller-matrix")
        )
        let controller = OverlayControllerModel()
        let hoverController = OverlayControllerModel(
            panelController: OverlayPanelControllerModel(
                interactionController: PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.2))
            )
        )
        let placement = placementPlan()

        let actual = OverlayControllerMatrixFixture(rows: [
            OverlayControllerMatrixRow(
                id: "replace-presentation",
                plan: controller.plan(
                    .replacePresentation(presentationState(displayState: .expanded, focusedSessionId: "session-1")),
                    from: OverlayControllerState()
                )
            ),
            OverlayControllerMatrixRow(
                id: "placement-changed",
                plan: controller.plan(
                    .panelPlacementChanged(placement),
                    from: OverlayControllerState(
                        panelState: OverlayPanelState(presentationState: presentationState(displayState: .expanded))
                    )
                )
            ),
            OverlayControllerMatrixRow(
                id: "interaction-hover",
                plan: hoverController.plan(
                    .panelInteraction(.setMenuBarHover(true)),
                    from: OverlayControllerState(
                        panelState: OverlayPanelState(
                            presentationState: presentationState(displayState: .closed),
                            placementPlan: placement
                        )
                    )
                )
            ),
            OverlayControllerMatrixRow(
                id: "session-jump-route",
                plan: controller.plan(
                    .sessionGesture(.jumpToSession(sessionId: "session-1")),
                    from: OverlayControllerState(
                        panelState: OverlayPanelState(presentationState: presentationState(displayState: .expanded))
                    )
                )
            ),
            OverlayControllerMatrixRow(
                id: "app-command-route",
                plan: controller.plan(
                    .appCommand(.openSettings),
                    from: OverlayControllerState(menuSnapshot: AppMenuSnapshot(enabledCommands: [.openSettings, .quit]))
                )
            ),
            OverlayControllerMatrixRow(
                id: "clear-routed-action",
                plan: controller.plan(
                    .clearRoutedAction,
                    from: OverlayControllerState(
                        panelState: OverlayPanelState(
                            presentationState: presentationState(displayState: .notificationPeek),
                            placementPlan: placement
                        ),
                        menuSnapshot: AppMenuSnapshot(enabledCommands: [.quit]),
                        lastRoutedAction: .appCommand(.quit)
                    )
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testReplacePresentationUpdatesPanelStateAndRequestsRender() {
        let controller = OverlayControllerModel()
        let state = OverlayControllerState()
        let presentation = presentationState(displayState: .expanded, focusedSessionId: "session-1")

        let plan = controller.plan(.replacePresentation(presentation), from: state)

        XCTAssertEqual(plan.nextState.panelState.presentationState.displayState, presentation.displayState)
        XCTAssertEqual(plan.nextState.panelState.presentationState.focusedSessionId, presentation.focusedSessionId)
        XCTAssertNotNil(plan.nextState.panelState.presentationState.interactionState.expandedSince)
        XCTAssertNil(plan.nextState.lastRoutedAction)
        XCTAssertEqual(plan.actions, [
            .renderPresentation(presentation)
        ])
    }

    func testReplacingClosedPresentationDoesNotReapplyPlacementFrame() {
        let controller = OverlayControllerModel()
        let placement = placementPlan()
        let state = OverlayControllerState(
            panelState: OverlayPanelState(
                presentationState: presentationState(displayState: .closed),
                placementPlan: placement
            )
        )
        let presentation = presentationState(displayState: .closed, focusedSessionId: "session-1")

        let plan = controller.plan(.replacePresentation(presentation), from: state)

        XCTAssertEqual(plan.actions, [.renderPresentation(presentation)])
    }

    func testPlacementCommandDelegatesToPanelController() {
        let controller = OverlayControllerModel()
        let state = OverlayControllerState(
            panelState: OverlayPanelState(presentationState: presentationState(displayState: .expanded))
        )
        let placement = placementPlan()

        let plan = controller.plan(.panelPlacementChanged(placement), from: state)

        XCTAssertEqual(plan.nextState.panelState.placementPlan, placement)
        XCTAssertEqual(plan.actions, [
            .applyPanelPlan(actions: [
                .applyFrame(placement.expandedFrame),
                .showPanel(displayState: .expanded)
            ])
        ])
    }

    func testInteractionCommandDelegatesAndRendersUpdatedPresentation() {
        let controller = OverlayControllerModel(
            panelController: OverlayPanelControllerModel(
                interactionController: PanelInteractionController(settings: BehaviourSettings(hoverExpandDelay: 0.2))
            )
        )
        let state = OverlayControllerState(
            panelState: OverlayPanelState(
                presentationState: presentationState(displayState: .closed),
                placementPlan: placementPlan()
            )
        )

        let plan = controller.plan(.panelInteraction(.setMenuBarHover(true)), from: state)

        XCTAssertEqual(plan.nextState.panelState.presentationState.displayState, .closed)
        XCTAssertEqual(plan.actions, [
            .applyPanelPlan(actions: [
                .forwardInteractionAction(.scheduleHoverReveal(delay: 0.2, generation: 1))
            ]),
            .renderPresentation(plan.nextState.panelState.presentationState)
        ])
    }

    func testMenuBarZoneMutationDoesNotRenderTheUnchangedSurface() {
        let controller = OverlayControllerModel()
        let state = OverlayControllerState(
            panelState: OverlayPanelState(
                presentationState: presentationState(displayState: .closed),
                placementPlan: placementPlan()
            )
        )

        let plan = controller.plan(.panelInteraction(.setMouseInMenuBarZone(true)), from: state)

        XCTAssertTrue(plan.nextState.panelState.presentationState.interactionState.isMouseInMenuBarZone)
        XCTAssertEqual(plan.actions, [])
    }

    func testSessionGestureCreatesRoutedActionWithoutMutatingPresentation() {
        let controller = OverlayControllerModel()
        let state = OverlayControllerState(
            panelState: OverlayPanelState(presentationState: presentationState(displayState: .expanded))
        )

        let plan = controller.plan(.sessionGesture(.jumpToSession(sessionId: "session-1")), from: state)

        XCTAssertEqual(plan.nextState.panelState, state.panelState)
        XCTAssertEqual(plan.nextState.lastRoutedAction, .jumpToSession(sessionId: "session-1"))
        XCTAssertEqual(plan.actions, [
            .routeAction(.jumpToSession(sessionId: "session-1"))
        ])
    }

    func testActionResolutionGestureRoutesCompleteTypedResolution() {
        let resolution = ActionResolution(
            requestId: "permission-1",
            sessionId: "session-1",
            kind: .deny
        )

        let plan = OverlayControllerModel().plan(
            .sessionGesture(.submitActionResolution(resolution)),
            from: OverlayControllerState()
        )

        XCTAssertEqual(plan.nextState.lastRoutedAction, .submitActionResolution(resolution))
        XCTAssertEqual(plan.actions, [
            .routeAction(.submitActionResolution(resolution))
        ])
    }

    func testAppCommandCreatesRoutedActionAndStoresMenuSnapshot() {
        let controller = OverlayControllerModel()
        let menu = AppMenuSnapshot(enabledCommands: [.openSettings, .quit])
        let state = OverlayControllerState(menuSnapshot: menu)

        let plan = controller.plan(.appCommand(.openSettings), from: state)

        XCTAssertEqual(plan.nextState.menuSnapshot, menu)
        XCTAssertEqual(plan.nextState.lastRoutedAction, .appCommand(.openSettings))
        XCTAssertEqual(plan.actions, [
            .routeAction(.appCommand(.openSettings))
        ])
    }

    func testClearRoutedActionPreservesPanelAndMenuState() {
        let panelState = OverlayPanelState(
            presentationState: presentationState(displayState: .notificationPeek),
            placementPlan: placementPlan()
        )
        let menu = AppMenuSnapshot(enabledCommands: [.quit])
        let state = OverlayControllerState(
            panelState: panelState,
            menuSnapshot: menu,
            lastRoutedAction: .appCommand(.quit)
        )

        let plan = OverlayControllerModel().plan(.clearRoutedAction, from: state)

        XCTAssertEqual(plan.nextState.panelState, panelState)
        XCTAssertEqual(plan.nextState.menuSnapshot, menu)
        XCTAssertNil(plan.nextState.lastRoutedAction)
        XCTAssertEqual(plan.actions, [])
    }

    func testStateRoundTripsThroughJSON() throws {
        let state = OverlayControllerState(
            panelState: OverlayPanelState(
                presentationState: presentationState(displayState: .switcher, focusedSessionId: "session-1"),
                placementPlan: placementPlan()
            ),
            menuSnapshot: AppMenuSnapshot(enabledCommands: [.openSettings]),
            lastRoutedAction: .selectSession(sessionId: "session-1")
        )

        let decoded = try JSONDecoder().decode(
            OverlayControllerState.self,
            from: try JSONEncoder().encode(state)
        )

        XCTAssertEqual(decoded, state)
    }

    private func presentationState(
        displayState: PanelDisplayState,
        focusedSessionId: String? = nil
    ) -> NotchPresentationState {
        NotchPresentationState(
            displayState: displayState,
            focusedSessionId: focusedSessionId,
            interactionState: PanelInteractionState(displayState: displayState)
        )
    }

    private func placementPlan() -> DisplayPlacementPlan {
        DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 20, width: 200, height: 36),
            expandedFrame: DisplayFrame(x: 4, y: 20, width: 640, height: 420),
            anchor: DisplayPoint(x: 110, y: 20),
            safeAreaAdjustment: 0
        )
    }
}

private struct OverlayControllerMatrixFixture: Codable, Equatable {
    let rows: [OverlayControllerMatrixRow]
}

private struct OverlayControllerMatrixRow: Codable, Equatable {
    let id: String
    let displayState: PanelDisplayState
    let focusedSessionId: String?
    let placementSummary: String?
    let menuCommandIds: [String]
    let lastRouteSummary: String?
    let actionSummaries: [String]

    init(id: String, plan: OverlayControllerPlan) {
        self.id = id
        let panel = plan.nextState.panelState
        displayState = panel.presentationState.displayState
        focusedSessionId = panel.presentationState.focusedSessionId
        placementSummary = panel.placementPlan.map {
            "\($0.closedFrame.width)x\($0.closedFrame.height)->\($0.expandedFrame.width)x\($0.expandedFrame.height)"
        }
        menuCommandIds = plan.nextState.menuSnapshot.enabledCommands.map { "\($0)" }
        lastRouteSummary = plan.nextState.lastRoutedAction.map(Self.describe(_:))
        actionSummaries = plan.actions.map(Self.describe(_:))
    }

    private static func describe(_ action: OverlayControllerAction) -> String {
        switch action {
        case .renderPresentation:
            return "renderPresentation"
        case .renderIslandSurface:
            return "renderIslandSurface"
        case let .applyPanelPlan(actions):
            return "applyPanelPlan:\(actions.map(describe(_:)).joined(separator: ","))"
        case let .routeAction(route):
            return "routeAction:\(describe(route))"
        case let .recordDisplayReason(reason):
            return "recordDisplayReason:\(reason.rawValue)"
        }
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

    private static func describe(_ route: OverlayRoutedAction) -> String {
        switch route {
        case let .selectSession(sessionId):
            return "selectSession:\(sessionId)"
        case let .jumpToSession(sessionId):
            return "jumpToSession:\(sessionId)"
        case let .resolveAction(requestId, sessionId):
            return "resolveAction:\(requestId):\(sessionId)"
        case let .answerQuestion(requestId, sessionId):
            return "answerQuestion:\(requestId):\(sessionId)"
        case let .submitActionResolution(resolution):
            return "submitActionResolution:\(resolution.requestId):\(resolution.kind.rawValue)"
        case let .appCommand(command):
            return "appCommand:\(command)"
        case .openSettings:
            return "openSettings"
        }
    }
}
