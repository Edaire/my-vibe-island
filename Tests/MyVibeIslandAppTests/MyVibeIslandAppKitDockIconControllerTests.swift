import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitDockIconControllerTests: XCTestCase {
    @MainActor
    func testDockIconControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DockIconControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/dock-icon-controller-matrix")
        )

        let actual = DockIconControllerMatrixFixture(rows: [
            row(
                id: "show-hide-sequence",
                initialState: DockIconControllerState(),
                visibilityRequests: [true, true, false]
            ),
            row(
                id: "already-visible-hide",
                initialState: DockIconControllerState(
                    preferredDockVisible: true,
                    currentPolicy: .regular,
                    lastPolicyChangeReason: .restoredSettings
                ),
                visibilityRequests: [true, false]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerAppliesDockPolicyOnlyWhenCoreModelPlansChange() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitDockIconController(
            applyActivationPolicy: { policy in
                events.append(policy.rawValue)
            }
        )

        let show = controller.setVisible(true)
        let unchanged = controller.setVisible(true)
        let hide = controller.setVisible(false)

        XCTAssertEqual(show.action, .setRegularPolicy)
        XCTAssertEqual(unchanged.action, .noChange)
        XCTAssertEqual(hide.action, .setAccessoryPolicy)
        XCTAssertFalse(controller.state.preferredDockVisible)
        XCTAssertEqual(events, ["regular", "accessory"])
    }

    @MainActor
    func testControllerPublishesLastDockIconPlanForOrchestration() {
        let controller = MyVibeIslandAppKitDockIconController(
            applyActivationPolicy: { _ in }
        )

        _ = controller.setVisible(true)

        XCTAssertEqual(controller.lastPlan?.action, .setRegularPolicy)
        XCTAssertEqual(controller.lastPlan?.nextState.preferredDockVisible, true)
    }

    @MainActor
    private func row(
        id: String,
        initialState: DockIconControllerState,
        visibilityRequests: [Bool]
    ) -> DockIconControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitDockIconController(
            state: initialState,
            applyActivationPolicy: { policy in
                events.append(policy.rawValue)
            }
        )
        let plans = visibilityRequests.map { isVisible in
            controller.setVisible(isVisible)
        }

        return DockIconControllerMatrixRow(
            id: id,
            initialState: DockIconControllerStateSnapshot(initialState),
            visibilityRequests: visibilityRequests,
            actions: plans.map(\.action.rawValue),
            finalState: DockIconControllerStateSnapshot(controller.state),
            lastPlanAction: controller.lastPlan?.action.rawValue,
            events: events
        )
    }
}

private struct DockIconControllerMatrixFixture: Codable, Equatable {
    let rows: [DockIconControllerMatrixRow]
}

private struct DockIconControllerMatrixRow: Codable, Equatable {
    let id: String
    let initialState: DockIconControllerStateSnapshot
    let visibilityRequests: [Bool]
    let actions: [String]
    let finalState: DockIconControllerStateSnapshot
    let lastPlanAction: String?
    let events: [String]
}

private struct DockIconControllerStateSnapshot: Codable, Equatable {
    let preferredDockVisible: Bool
    let currentPolicy: String
    let lastPolicyChangeReason: String
    let reopenBehavior: String

    init(_ state: DockIconControllerState) {
        self.preferredDockVisible = state.preferredDockVisible
        self.currentPolicy = state.currentPolicy.rawValue
        self.lastPolicyChangeReason = state.lastPolicyChangeReason.rawValue
        self.reopenBehavior = state.reopenBehavior.rawValue
    }
}
