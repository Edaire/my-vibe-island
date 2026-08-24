import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitDelegateTests: XCTestCase {
    @MainActor
    func testAppKitDelegateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppKitDelegateMatrixFixture.self,
            from: try AppFixtureLoader.data("app/app-kit-delegate-matrix")
        )
        let delegate = MyVibeIslandAppKitDelegate(
            bridge: MyVibeIslandAppDelegateBridge(application: MyVibeIslandApplication())
        )
        let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
        delegate.applicationDidFinishLaunching(notification)
        let first = AppKitDelegateStateSummary(delegate)
        delegate.applicationDidFinishLaunching(notification)
        let repeated = AppKitDelegateStateSummary(delegate)
        let actual = AppKitDelegateMatrixFixture(rows: [
            AppKitDelegateMatrixRow(id: "first-notification", state: first),
            AppKitDelegateMatrixRow(id: "repeated-notification", state: repeated)
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testApplicationDidFinishLaunchingStoresBridgePlan() {
        let delegate = MyVibeIslandAppKitDelegate(
            bridge: MyVibeIslandAppDelegateBridge(application: MyVibeIslandApplication())
        )

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        XCTAssertEqual(delegate.state.lifecycle, .launched)
        XCTAssertEqual(delegate.lastPlan?.intents.count, 36)
        XCTAssertEqual(delegate.lastPlan?.intents.first, .lifecycle(.createRuntime))
        XCTAssertEqual(delegate.lastPlan?.intents.last, .showIsland)
    }

    @MainActor
    func testDelegateExecutesLaunchAndTerminationIntentsOnce() {
        var batches: [[AppShellPlatformLaunchIntent]] = []
        let delegate = MyVibeIslandAppKitDelegate(
            bridge: MyVibeIslandAppDelegateBridge(application: MyVibeIslandApplication()),
            executePlatformIntents: { intents in
                batches.append(intents)
                return MyVibeIslandAppKitPlatformIntentExecutionResult(executedIntents: intents)
            }
        )
        let launch = Notification(name: NSApplication.didFinishLaunchingNotification)
        let termination = Notification(name: NSApplication.willTerminateNotification)

        delegate.applicationDidFinishLaunching(launch)
        delegate.applicationDidFinishLaunching(launch)
        delegate.applicationWillTerminate(termination)
        delegate.applicationWillTerminate(termination)

        XCTAssertEqual(batches.count, 2)
        XCTAssertEqual(batches[0].first, .lifecycle(.createRuntime))
        XCTAssertTrue(batches[1].contains(.lifecycle(.stopBridge)))
        XCTAssertEqual(delegate.state.lifecycle, .terminated)
        XCTAssertEqual(delegate.lastPlatformExecutionResult?.executedIntents, batches[1])
    }
}

private struct AppKitDelegateMatrixFixture: Codable, Equatable {
    let rows: [AppKitDelegateMatrixRow]
}

private struct AppKitDelegateMatrixRow: Codable, Equatable {
    let id: String
    let state: AppKitDelegateStateSummary
}

private struct AppKitDelegateStateSummary: Codable, Equatable {
    let lifecycle: String
    let hasLaunchPlan: Bool
    let lastPlanIntentCount: Int?
    let firstIntentIsCreateRuntime: Bool
    let lastIntentIsShowIsland: Bool

    @MainActor
    init(_ delegate: MyVibeIslandAppKitDelegate) {
        self.lifecycle = delegate.state.lifecycle.rawValue
        self.hasLaunchPlan = delegate.state.launchPlan != nil
        self.lastPlanIntentCount = delegate.lastPlan?.intents.count
        self.firstIntentIsCreateRuntime = delegate.lastPlan?.intents.first == .lifecycle(.createRuntime)
        self.lastIntentIsShowIsland = delegate.lastPlan?.intents.last == .showIsland
    }
}
