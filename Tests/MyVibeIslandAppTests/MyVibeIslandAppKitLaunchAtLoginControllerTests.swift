import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitLaunchAtLoginControllerTests: XCTestCase {
    @MainActor
    func testLaunchAtLoginControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            LaunchAtLoginControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/launch-at-login-controller-matrix")
        )

        let actual = LaunchAtLoginControllerMatrixFixture(rows: [
            row(
                id: "enable-observed-mismatch-failure",
                initialState: LaunchAtLoginState(),
                commands: [
                    .setEnabled(true),
                    .observeEnabled(false),
                    .recordFailure("registration denied")
                ]
            ),
            row(
                id: "disable-observed-match",
                initialState: LaunchAtLoginState(
                    desiredEnabled: true,
                    observedEnabled: true,
                    reconciliationResult: .matched
                ),
                commands: [
                    .setEnabled(false),
                    .observeEnabled(false)
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerAppliesDesiredStateAndTracksObservedFailures() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitLaunchAtLoginController(
            applyDesiredEnabled: { isEnabled in
                events.append("desired:\(isEnabled)")
            },
            publishRepairHint: { error in
                events.append("repair:\(error)")
            }
        )

        let desired = controller.setEnabled(true)
        let observed = controller.observeEnabled(false)
        let failed = controller.recordFailure("registration denied")

        XCTAssertEqual(desired.action, .updateDesired)
        XCTAssertEqual(observed.action, .needsReconcile)
        XCTAssertEqual(failed.action, .recordRepairHint)
        XCTAssertEqual(controller.state.reconciliationResult, .failed)
        XCTAssertEqual(events, [
            "desired:true",
            "repair:registration denied"
        ])
    }

    @MainActor
    func testControllerPublishesLastLaunchAtLoginPlanForOrchestration() {
        let controller = MyVibeIslandAppKitLaunchAtLoginController(
            applyDesiredEnabled: { _ in },
            publishRepairHint: { _ in }
        )

        _ = controller.setEnabled(true)

        XCTAssertEqual(controller.lastPlan?.action, .updateDesired)
        XCTAssertEqual(controller.lastPlan?.nextState.desiredEnabled, true)
    }

    @MainActor
    private func row(
        id: String,
        initialState: LaunchAtLoginState,
        commands: [LaunchAtLoginControllerFixtureCommand]
    ) -> LaunchAtLoginControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitLaunchAtLoginController(
            state: initialState,
            applyDesiredEnabled: { isEnabled in
                events.append("desired:\(isEnabled)")
            },
            publishRepairHint: { error in
                events.append("repair:\(error)")
            }
        )
        let plans = commands.map { command in
            switch command {
            case let .setEnabled(isEnabled):
                return controller.setEnabled(isEnabled)
            case let .observeEnabled(isEnabled):
                return controller.observeEnabled(isEnabled)
            case let .recordFailure(error):
                return controller.recordFailure(error)
            }
        }

        return LaunchAtLoginControllerMatrixRow(
            id: id,
            initialState: LaunchAtLoginStateSnapshot(initialState),
            commands: commands.map(\.summary),
            actions: plans.map(\.action.rawValue),
            finalState: LaunchAtLoginStateSnapshot(controller.state),
            lastPlanAction: controller.lastPlan?.action.rawValue,
            events: events
        )
    }
}

private struct LaunchAtLoginControllerMatrixFixture: Codable, Equatable {
    let rows: [LaunchAtLoginControllerMatrixRow]
}

private struct LaunchAtLoginControllerMatrixRow: Codable, Equatable {
    let id: String
    let initialState: LaunchAtLoginStateSnapshot
    let commands: [String]
    let actions: [String]
    let finalState: LaunchAtLoginStateSnapshot
    let lastPlanAction: String?
    let events: [String]
}

private struct LaunchAtLoginStateSnapshot: Codable, Equatable {
    let desiredEnabled: Bool
    let observedEnabled: Bool
    let reconciliationResult: String
    let lastError: String?

    init(_ state: LaunchAtLoginState) {
        self.desiredEnabled = state.desiredEnabled
        self.observedEnabled = state.observedEnabled
        self.reconciliationResult = state.reconciliationResult.rawValue
        self.lastError = state.lastError
    }
}

private enum LaunchAtLoginControllerFixtureCommand {
    case setEnabled(Bool)
    case observeEnabled(Bool)
    case recordFailure(String)

    var summary: String {
        switch self {
        case let .setEnabled(isEnabled):
            return "setEnabled:\(isEnabled)"
        case let .observeEnabled(isEnabled):
            return "observeEnabled:\(isEnabled)"
        case let .recordFailure(error):
            return "recordFailure:\(error)"
        }
    }
}
