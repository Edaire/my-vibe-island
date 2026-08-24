import AppKit
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitRunnerTests: XCTestCase {
    @MainActor
    func testRunnerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RunnerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/runner-matrix")
        )

        let actual = RunnerMatrixFixture(rows: [
            row(id: "default-accessory", activationPolicy: .accessory),
            row(id: "regular-policy", activationPolicy: .regular),
            row(id: "prohibited-policy", activationPolicy: .prohibited)
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testRunnerBuildsDelegateAndInstallPlanWithoutRunningApplication() {
        let runner = MyVibeIslandAppKitRunner(application: MyVibeIslandApplication())

        let plan = runner.prepareRun()

        XCTAssertEqual(plan.intents, [
            .setActivationPolicy(.accessory),
            .installDelegate,
            .runApplication
        ])
        XCTAssertEqual(plan.delegate.state.lifecycle, .notLaunched)
        XCTAssertNil(plan.delegate.lastPlan)
    }

    @MainActor
    private func row(
        id: String,
        activationPolicy: MyVibeIslandAppKitActivationPolicy
    ) -> RunnerMatrixRow {
        let runner = MyVibeIslandAppKitRunner(
            application: MyVibeIslandApplication(),
            activationPolicy: activationPolicy
        )
        let plan = runner.prepareRun()

        return RunnerMatrixRow(
            id: id,
            activationPolicy: activationPolicy.rawValue,
            intents: plan.intents.map(\.summary),
            delegateLifecycle: plan.delegate.state.lifecycle.rawValue,
            delegateHasLastPlan: plan.delegate.lastPlan != nil
        )
    }
}

private struct RunnerMatrixFixture: Codable, Equatable {
    let rows: [RunnerMatrixRow]
}

private struct RunnerMatrixRow: Codable, Equatable {
    let id: String
    let activationPolicy: String
    let intents: [String]
    let delegateLifecycle: String
    let delegateHasLastPlan: Bool
}

private extension MyVibeIslandAppKitRunIntent {
    var summary: String {
        switch self {
        case let .setActivationPolicy(policy):
            return "setActivationPolicy:\(policy.rawValue)"
        case .installDelegate:
            return "installDelegate"
        case .runApplication:
            return "runApplication"
        }
    }
}
