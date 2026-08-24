import XCTest
@testable import MyVibeIslandCore

final class NotchWindowControllerModelsTests: XCTestCase {
    func testNotchWindowControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            NotchWindowControllerMatrixFixture.self,
            from: try FixtureLoader.data("runtime/notch-window-controller-matrix")
        )
        let model = NotchWindowControllerModel()
        let visible = visiblePlacement()
        let hidden = hiddenPlacement()
        let created = model.plan(.create(target: target("main"), placement: visible), from: .init()).nextState
        let hiddenState = model.plan(.applyPlacement(hidden), from: created).nextState

        let actual = NotchWindowControllerMatrixFixture(rows: [
            NotchWindowControllerMatrixRow(
                id: "create-visible",
                plan: model.plan(.create(target: target("main"), placement: visible), from: .init())
            ),
            NotchWindowControllerMatrixRow(
                id: "apply-hidden-fullscreen",
                plan: model.plan(.applyPlacement(hidden), from: created)
            ),
            NotchWindowControllerMatrixRow(
                id: "target-unchanged",
                plan: model.plan(.updateTarget(target("main")), from: created)
            ),
            NotchWindowControllerMatrixRow(
                id: "target-changed",
                plan: model.plan(.updateTarget(target("side")), from: created)
            ),
            NotchWindowControllerMatrixRow(
                id: "hide-visible",
                plan: model.plan(.setVisibility(.hidden), from: created)
            ),
            NotchWindowControllerMatrixRow(
                id: "repeated-hide",
                plan: model.plan(.setVisibility(.hidden), from: hiddenState)
            ),
            NotchWindowControllerMatrixRow(
                id: "defer-hidden-fade",
                plan: model.plan(.setDeferringHiddenFade(true), from: hiddenState)
            ),
            NotchWindowControllerMatrixRow(
                id: "teardown-created",
                plan: model.plan(.teardown, from: created)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCreatePlansPanelMonitorPlacementAndShowInOrder() {
        let model = NotchWindowControllerModel()
        let placement = visiblePlacement()

        let plan = model.plan(.create(target: target("main"), placement: placement), from: NotchWindowControllerState())

        XCTAssertEqual(plan.actions, [
            .createPanel,
            .installEventMonitors,
            .applyTargetScreen("main"),
            .applyPlacement(placement),
            .showPanel
        ])
        XCTAssertTrue(plan.nextState.hasPanel)
        XCTAssertTrue(plan.nextState.monitorsInstalled)
        XCTAssertEqual(plan.nextState.targetScreen?.identifier, "main")
        XCTAssertEqual(plan.nextState.lastPlacement, placement)
        XCTAssertEqual(plan.nextState.visibility, .visible)
    }

    func testHiddenPlacementHidesPanelAndRecordsReason() {
        let model = NotchWindowControllerModel()
        let created = model.plan(.create(target: target("main"), placement: visiblePlacement()), from: .init()).nextState
        let hidden = DisplayPlacementPlan(
            closedFrame: .zero,
            expandedFrame: .zero,
            anchor: DisplayPoint(x: 500, y: 0),
            safeAreaAdjustment: 0,
            collapseReason: .fullscreenHidden
        )

        let plan = model.plan(.applyPlacement(hidden), from: created)

        XCTAssertEqual(plan.actions, [.applyPlacement(hidden), .hidePanel])
        XCTAssertEqual(plan.nextState.visibility, .hidden)
        XCTAssertEqual(plan.nextState.panelHiddenReason, .fullscreenHidden)
    }

    func testTargetUpdateIsIdempotentWhenIdentifierIsUnchanged() {
        let model = NotchWindowControllerModel()
        let created = model.plan(.create(target: target("main"), placement: visiblePlacement()), from: .init()).nextState

        let unchanged = model.plan(.updateTarget(target("main")), from: created)
        XCTAssertEqual(unchanged.actions, [])
        XCTAssertEqual(unchanged.nextState, created)

        let changed = model.plan(.updateTarget(target("side")), from: created)
        XCTAssertEqual(changed.actions, [.applyTargetScreen("side")])
        XCTAssertEqual(changed.nextState.targetScreen?.identifier, "side")
    }

    func testVisibilityCommandsAreIdempotent() {
        let model = NotchWindowControllerModel()
        let created = model.plan(.create(target: target("main"), placement: visiblePlacement()), from: .init()).nextState

        let show = model.plan(.setVisibility(.visible), from: created)
        XCTAssertEqual(show.actions, [])
        XCTAssertEqual(show.nextState, created)

        let hide = model.plan(.setVisibility(.hidden), from: created)
        XCTAssertEqual(hide.actions, [.hidePanel])
        XCTAssertEqual(hide.nextState.visibility, .hidden)

        let repeatedHide = model.plan(.setVisibility(.hidden), from: hide.nextState)
        XCTAssertEqual(repeatedHide.actions, [])
        XCTAssertEqual(repeatedHide.nextState, hide.nextState)
    }

    func testTeardownRemovesMonitorsBeforeClosingPanelAndIsIdempotent() {
        let model = NotchWindowControllerModel()
        let created = model.plan(.create(target: target("main"), placement: visiblePlacement()), from: .init()).nextState

        let plan = model.plan(.teardown, from: created)

        XCTAssertEqual(plan.actions, [.removeEventMonitors, .closePanel])
        XCTAssertFalse(plan.nextState.hasPanel)
        XCTAssertFalse(plan.nextState.monitorsInstalled)
        XCTAssertEqual(plan.nextState.visibility, .closed)

        let repeated = model.plan(.teardown, from: plan.nextState)
        XCTAssertEqual(repeated.actions, [])
        XCTAssertEqual(repeated.nextState, plan.nextState)
    }

    func testStateRoundTripsThroughJSON() throws {
        let state = NotchWindowControllerState(
            hasPanel: true,
            monitorsInstalled: true,
            targetScreen: target("main"),
            lastPlacement: visiblePlacement(),
            visibility: .visible,
            panelHiddenReason: nil,
            isDeferringHiddenFade: true
        )

        let decoded = try JSONDecoder().decode(
            NotchWindowControllerState.self,
            from: try JSONEncoder().encode(state)
        )

        XCTAssertEqual(decoded, state)
    }

    private func target(_ identifier: String) -> ScreenTarget {
        ScreenTarget(identifier: identifier, displayName: identifier, isBuiltIn: identifier == "main", isMain: identifier == "main")
    }

    private func visiblePlacement() -> DisplayPlacementPlan {
        DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 100, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 40, y: 20, width: 640, height: 420),
            anchor: DisplayPoint(x: 210, y: 20),
            safeAreaAdjustment: 20
        )
    }

    private func hiddenPlacement() -> DisplayPlacementPlan {
        DisplayPlacementPlan(
            closedFrame: .zero,
            expandedFrame: .zero,
            anchor: DisplayPoint(x: 500, y: 0),
            safeAreaAdjustment: 0,
            collapseReason: .fullscreenHidden
        )
    }
}

private struct NotchWindowControllerMatrixFixture: Codable, Equatable {
    let rows: [NotchWindowControllerMatrixRow]
}

private struct NotchWindowControllerMatrixRow: Codable, Equatable {
    let id: String
    let hasPanel: Bool
    let monitorsInstalled: Bool
    let targetScreenId: String?
    let visibility: NotchWindowVisibility
    let hiddenReason: DisplayPlacementCollapseReason?
    let isDeferringHiddenFade: Bool
    let placementSummary: String?
    let actionSummaries: [String]

    init(id: String, plan: NotchWindowControllerPlan) {
        self.id = id
        hasPanel = plan.nextState.hasPanel
        monitorsInstalled = plan.nextState.monitorsInstalled
        targetScreenId = plan.nextState.targetScreen?.identifier
        visibility = plan.nextState.visibility
        hiddenReason = plan.nextState.panelHiddenReason
        isDeferringHiddenFade = plan.nextState.isDeferringHiddenFade
        placementSummary = plan.nextState.lastPlacement.map(Self.describe(_:))
        actionSummaries = plan.actions.map(Self.describe(_:))
    }

    private static func describe(_ placement: DisplayPlacementPlan) -> String {
        "\(placement.closedFrame.width)x\(placement.closedFrame.height)->\(placement.expandedFrame.width)x\(placement.expandedFrame.height):\(placement.collapseReason.map { "\($0)" } ?? "visible")"
    }

    private static func describe(_ action: NotchWindowControllerAction) -> String {
        switch action {
        case .createPanel:
            return "createPanel"
        case .installEventMonitors:
            return "installEventMonitors"
        case .removeEventMonitors:
            return "removeEventMonitors"
        case let .applyTargetScreen(identifier):
            return "applyTargetScreen:\(identifier)"
        case let .applyPlacement(placement):
            return "applyPlacement:\(describe(placement))"
        case .showPanel:
            return "showPanel"
        case .hidePanel:
            return "hidePanel"
        case .closePanel:
            return "closePanel"
        }
    }
}
