import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitLifecycleStepExecutorTests: XCTestCase {
    @MainActor
    func testExecutorRunsStartupAndTerminationStepsInOrderAndIsIdempotent() {
        var events: [String] = []
        let executor = MyVibeIslandAppKitLifecycleStepExecutor { step in
            events.append(step.rawValue)
        }
        let controller = MyVibeIslandAppKitLifecycleController(
            lifecycleStepExecutor: executor
        )

        controller.apply(.createRuntime)
        controller.apply(.createRuntime)
        controller.apply(.loadSettings)
        controller.apply(.persistSettingsAndSessions)
        controller.apply(.persistSettingsAndSessions)

        XCTAssertEqual(events, ["createRuntime", "loadSettings", "persistSettingsAndSessions"])
        XCTAssertEqual(controller.appliedSteps, [.createRuntime, .loadSettings, .persistSettingsAndSessions])
        XCTAssertTrue(executor.failures.isEmpty)
    }

    @MainActor
    func testExecutorReportsFailureWithoutClaimingTheStepCompleted() {
        let executor = MyVibeIslandAppKitLifecycleStepExecutor { step in
            if step == .startBridge {
                throw NSError(domain: "test", code: 1)
            }
        }
        let controller = MyVibeIslandAppKitLifecycleController(
            lifecycleStepExecutor: executor
        )

        controller.apply(.startBridge)

        XCTAssertEqual(controller.appliedSteps, [])
        XCTAssertEqual(controller.failedSteps, [.startBridge])
        XCTAssertEqual(executor.failures[.startBridge], "NSError")
    }
}
