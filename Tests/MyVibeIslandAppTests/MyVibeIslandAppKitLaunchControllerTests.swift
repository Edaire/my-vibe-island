import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitLaunchControllerTests: XCTestCase {
    @MainActor
    func testLaunchControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            LaunchControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/launch-controller-matrix")
        )
        var events: [String] = []
        var installedDelegate: MyVibeIslandAppKitDelegate?
        let application = MyVibeIslandApplication()
        let platformSummary = application.prepareLaunch().summary
        let controller = MyVibeIslandAppKitLaunchController(
            runner: MyVibeIslandAppKitRunner(application: application),
            executor: MyVibeIslandAppKitRunExecutor(
                setActivationPolicy: { events.append("policy:\($0.rawValue)") },
                installDelegate: {
                    installedDelegate = $0
                    events.append("delegate:\($0.state.lifecycle.rawValue)")
                },
                runApplication: {
                    events.append("run")
                    installedDelegate?.applicationDidFinishLaunching(
                        Notification(name: NSApplication.didFinishLaunchingNotification)
                    )
                }
            ),
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor(
                applyStatusItemMenu: { events.append("platform:statusMenu:\($0.entries.count)") },
                applyLifecycleStep: { if $0 == .createRuntime { events.append("platform:createRuntime") } },
                showIsland: { events.append("platform:showIsland") }
            )
        )

        let result = controller.launch()
        let actual = LaunchControllerMatrixFixture(rows: [
            LaunchControllerMatrixRow(
                id: "default-injected-launch",
                runIntents: result.executedIntents.map(\.summary),
                platformIntentCount: result.platformExecutionResult.executedIntents.count,
                platformSummary: LaunchPlatformSummary(platformSummary),
                events: events
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerPreparesAndExecutesRunPlan() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitLaunchController(
            runner: MyVibeIslandAppKitRunner(application: MyVibeIslandApplication()),
            executor: MyVibeIslandAppKitRunExecutor(
                setActivationPolicy: { policy in
                    events.append("policy:\(policy.rawValue)")
                },
                installDelegate: { delegate in
                    events.append("delegate:\(delegate.state.lifecycle.rawValue)")
                },
                runApplication: {
                    events.append("run")
                }
            )
        )

        let result = controller.launch()

        XCTAssertEqual(result.executedIntents, [
            .setActivationPolicy(.accessory),
            .installDelegate,
            .runApplication
        ])
        XCTAssertEqual(events, [
            "policy:accessory",
            "delegate:notLaunched",
            "run"
        ])
    }

    @MainActor
    func testControllerExecutesPlatformStatusMenuIntent() {
        var appliedSnapshots: [StatusItemMenuSnapshot] = []
        var installedDelegate: MyVibeIslandAppKitDelegate?
        let application = MyVibeIslandApplication()
        let expectedSnapshot = application.prepareLaunch().launchPlan.statusItemMenu
        let controller = MyVibeIslandAppKitLaunchController(
            runner: MyVibeIslandAppKitRunner(application: application),
            executor: MyVibeIslandAppKitRunExecutor(
                setActivationPolicy: { _ in },
                installDelegate: { installedDelegate = $0 },
                runApplication: {
                    installedDelegate?.applicationDidFinishLaunching(
                        Notification(name: NSApplication.didFinishLaunchingNotification)
                    )
                }
            ),
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor(
                applyStatusItemMenu: { snapshot in
                    appliedSnapshots.append(snapshot)
                }
            )
        )

        let result = controller.launch()

        XCTAssertEqual(appliedSnapshots, [expectedSnapshot])
        XCTAssertTrue(result.platformExecutionResult.executedIntents.contains(.applyStatusItemMenu(expectedSnapshot)))
    }

    @MainActor
    func testControllerExecutesPlatformLaunchIntentsAfterApplicationDidFinishLaunching() {
        var events: [String] = []
        var installedDelegate: MyVibeIslandAppKitDelegate?
        let application = MyVibeIslandApplication()
        let controller = MyVibeIslandAppKitLaunchController(
            runner: MyVibeIslandAppKitRunner(application: application),
            executor: MyVibeIslandAppKitRunExecutor(
                setActivationPolicy: { policy in
                    events.append("policy:\(policy.rawValue)")
                },
                installDelegate: { delegate in
                    installedDelegate = delegate
                    events.append("delegate")
                },
                runApplication: {
                    events.append("run")
                    installedDelegate?.applicationDidFinishLaunching(
                        Notification(name: NSApplication.didFinishLaunchingNotification)
                    )
                }
            ),
            platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor(
                applyStatusItemMenu: { _ in
                    events.append("platform:statusMenu")
                },
                applyLifecycleStep: { step in
                    if step == .createRuntime {
                        events.append("platform:createRuntime")
                    }
                },
                showIsland: {
                    events.append("platform:showIsland")
                }
            )
        )

        _ = controller.launch()

        XCTAssertEqual(events, [
            "policy:accessory",
            "delegate",
            "run",
            "platform:createRuntime",
            "platform:statusMenu",
            "platform:showIsland"
        ])
    }
}

private extension MyVibeIslandAppKitRunIntent {
    var summary: String {
        switch self {
        case let .setActivationPolicy(policy): "setActivationPolicy:\(policy.rawValue)"
        case .installDelegate: "installDelegate"
        case .runApplication: "runApplication"
        }
    }
}

private struct LaunchControllerMatrixFixture: Codable, Equatable {
    let rows: [LaunchControllerMatrixRow]
}

private struct LaunchControllerMatrixRow: Codable, Equatable {
    let id: String
    let runIntents: [String]
    let platformIntentCount: Int
    let platformSummary: LaunchPlatformSummary
    let events: [String]
}

private struct LaunchPlatformSummary: Codable, Equatable {
    let intentCount: Int
    let lifecycleIntentCount: Int
    let runtimeStartIntentCount: Int
    let notchWindowIntentCount: Int
    let statusItemMenuEntryCount: Int
    let routeIntentCount: Int

    init(_ summary: AppShellPlatformLaunchSummary) {
        self.intentCount = summary.intentCount
        self.lifecycleIntentCount = summary.lifecycleIntentCount
        self.runtimeStartIntentCount = summary.runtimeStartIntentCount
        self.notchWindowIntentCount = summary.notchWindowIntentCount
        self.statusItemMenuEntryCount = summary.statusItemMenuEntryCount
        self.routeIntentCount = summary.routeIntentCount
    }
}
