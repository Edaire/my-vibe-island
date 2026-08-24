import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppDelegateBridgeTests: XCTestCase {
    func testAppDelegateBridgeMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppDelegateBridgeMatrixFixture.self,
            from: try AppFixtureLoader.data("app/app-delegate-bridge-matrix")
        )
        let bridge = MyVibeIslandAppDelegateBridge(application: MyVibeIslandApplication())
        let first = bridge.handle(.didFinishLaunching, from: MyVibeIslandAppDelegateState())
        let repeated = bridge.handle(.didFinishLaunching, from: first.nextState)
        let actual = AppDelegateBridgeMatrixFixture(rows: [
            AppDelegateBridgeMatrixRow(id: "first-launch", plan: AppDelegateBridgePlanSummary(first)),
            AppDelegateBridgeMatrixRow(id: "repeated-launch", plan: AppDelegateBridgePlanSummary(repeated))
        ])

        XCTAssertEqual(actual, expected)
    }

    func testDidFinishLaunchingPreparesPlatformLaunchAndStoresState() {
        let bridge = MyVibeIslandAppDelegateBridge(application: MyVibeIslandApplication())

        let plan = bridge.handle(.didFinishLaunching, from: MyVibeIslandAppDelegateState())

        XCTAssertEqual(plan.nextState.lifecycle, .launched)
        XCTAssertNotNil(plan.nextState.launchPlan)
        XCTAssertEqual(plan.intents.count, 36)
        XCTAssertEqual(plan.intents.first, .lifecycle(.createRuntime))
        XCTAssertEqual(plan.intents.last, .showIsland)
    }

    func testRepeatedDidFinishLaunchingKeepsExistingLaunchPlan() {
        let bridge = MyVibeIslandAppDelegateBridge(application: MyVibeIslandApplication())
        let launched = bridge.handle(.didFinishLaunching, from: MyVibeIslandAppDelegateState()).nextState

        let repeated = bridge.handle(.didFinishLaunching, from: launched)

        XCTAssertEqual(repeated.nextState, launched)
        XCTAssertEqual(repeated.intents, [])
    }

    func testWillTerminatePlansCleanupOnceFromRetainedCoordinatorState() {
        let bridge = MyVibeIslandAppDelegateBridge(application: MyVibeIslandApplication())
        let launched = bridge.handle(.didFinishLaunching, from: MyVibeIslandAppDelegateState())

        let terminated = bridge.handle(.willTerminate, from: launched.nextState)
        let repeated = bridge.handle(.willTerminate, from: terminated.nextState)

        XCTAssertEqual(terminated.nextState.lifecycle, .terminated)
        XCTAssertTrue(terminated.intents.contains(.lifecycle(.stopBridge)))
        XCTAssertFalse(terminated.intents.contains { intent in
            if case .stopRuntimeOwner = intent { return true }
            return false
        })
        XCTAssertFalse(terminated.intents.contains(.quitApplication))
        XCTAssertEqual(repeated.nextState, terminated.nextState)
        XCTAssertEqual(repeated.intents, [])
    }
}

private struct AppDelegateBridgeMatrixFixture: Codable, Equatable {
    let rows: [AppDelegateBridgeMatrixRow]
}

private struct AppDelegateBridgeMatrixRow: Codable, Equatable {
    let id: String
    let plan: AppDelegateBridgePlanSummary
}

private struct AppDelegateBridgePlanSummary: Codable, Equatable {
    let lifecycle: String
    let hasLaunchPlan: Bool
    let intentCount: Int
    let firstIntentIsCreateRuntime: Bool
    let lastIntentIsShowIsland: Bool
    let platformIntentCount: Int?

    init(_ plan: MyVibeIslandAppDelegatePlan) {
        self.lifecycle = plan.nextState.lifecycle.rawValue
        self.hasLaunchPlan = plan.nextState.launchPlan != nil
        self.intentCount = plan.intents.count
        self.firstIntentIsCreateRuntime = plan.intents.first == .lifecycle(.createRuntime)
        self.lastIntentIsShowIsland = plan.intents.last == .showIsland
        self.platformIntentCount = plan.nextState.launchPlan?.summary.intentCount
    }
}
