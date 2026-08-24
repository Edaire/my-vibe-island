import XCTest
@testable import MyVibeIslandCore

final class AppShellLaunchBootstrapModelsTests: XCTestCase {
    func testAppShellLaunchBootstrapMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppShellLaunchBootstrapMatrixFixture.self,
            from: try FixtureLoader.data("settings/app-shell-launch-bootstrap-matrix")
        )
        let defaultBootstrap = AppShellLaunchBootstrap()
        let compactBootstrap = AppShellLaunchBootstrap(
            configuration: AppShellLaunchConfiguration(
                launchContext: AppLaunchContext(isFirstLaunch: true, hasPendingOnboarding: true),
                target: ScreenTarget(identifier: "side", displayName: "Studio Display", isBuiltIn: false, isMain: false),
                placementInput: DisplayPlacementInput(
                    screenFrame: DisplayFrame(x: 100, y: 50, width: 900, height: 700),
                    safeAreaTopInset: 24,
                    closedSize: DisplaySize(width: 180, height: 32),
                    expandedSize: DisplaySize(width: 480, height: 360)
                ),
                menuSnapshot: AppMenuSnapshot(
                    statusItemVisible: true,
                    enabledCommands: [.openSettings, .quit],
                    launchAtLoginEnabled: true,
                    dockIconVisible: false
                )
            )
        )

        let cases = [
            AppShellLaunchBootstrapCase(
                name: "default-launch-plan",
                projection: AppShellLaunchBootstrapProjection(defaultBootstrap.buildLaunchPlan())
            ),
            AppShellLaunchBootstrapCase(
                name: "first-launch-onboarding-context",
                projection: AppShellLaunchBootstrapProjection(compactBootstrap.buildLaunchPlan())
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testDefaultConfigurationBuildsDeterministicLaunchRequest() {
        let bootstrap = AppShellLaunchBootstrap()

        let request = bootstrap.makeLaunchRequest()

        XCTAssertEqual(request.context, AppLaunchContext())
        XCTAssertEqual(
            request.target,
            ScreenTarget(identifier: "main", displayName: "Built-in Display", isBuiltIn: true, isMain: true)
        )
        XCTAssertEqual(
            request.placement,
            DisplayPlacementPlan(
                closedFrame: DisplayFrame(x: 416, y: 402, width: 680, height: 580),
                expandedFrame: DisplayFrame(x: 416, y: 402, width: 680, height: 580),
                anchor: DisplayPoint(x: 756, y: 982),
                safeAreaAdjustment: 0
            )
        )
        XCTAssertTrue(request.menuSnapshot.statusItemVisible)
        XCTAssertEqual(request.menuSnapshot.selectedScreenMode, .builtInNotchDisplay)
        XCTAssertTrue(request.menuSnapshot.isEnabled(.openSettings))
        XCTAssertTrue(request.menuSnapshot.isEnabled(.toggleDockIcon))
        XCTAssertTrue(request.menuSnapshot.isEnabled(.toggleLaunchAtLogin))
        XCTAssertTrue(request.menuSnapshot.isEnabled(.quit))
    }

    func testBuildLaunchPlanRoutesDidFinishLaunchingThroughCoordinator() {
        let bootstrap = AppShellLaunchBootstrap()

        let plan = bootstrap.buildLaunchPlan()

        XCTAssertEqual(plan.request, bootstrap.makeLaunchRequest())
        XCTAssertEqual(plan.coordinatorPlan.commands, [.launch(plan.request)])
        XCTAssertEqual(plan.coordinatorPlan.nextState.shellState.lifecycleState.route, .island)
        XCTAssertEqual(plan.runtimeOwnerStartCount, AppRuntimeCompositionSnapshot.defaultAppShell().owners.count)
        XCTAssertEqual(plan.statusItemMenu.entries.first?.command, .openSettings)
        XCTAssertTrue(plan.coordinatorPlan.actions.contains(.notchWindow(.createPanel)))
        XCTAssertEqual(plan.coordinatorPlan.actions.last, .showIsland)
    }

    func testLaunchPlanSummaryIsStableForDryRunOutput() {
        let summary = AppShellLaunchBootstrap().buildLaunchPlan().summary

        XCTAssertEqual(summary.targetDisplayName, "Built-in Display")
        XCTAssertEqual(summary.route, .island)
        XCTAssertEqual(summary.runtimeOwnerStartCount, 19)
        XCTAssertEqual(summary.actionCount, 36)
        XCTAssertEqual(summary.statusItemMenuEntryCount, 14)
        XCTAssertEqual(summary.closedFrame, DisplayFrame(x: 416, y: 402, width: 680, height: 580))
    }

    private struct AppShellLaunchBootstrapMatrixFixture: Codable, Equatable {
        let cases: [AppShellLaunchBootstrapCase]
    }

    private struct AppShellLaunchBootstrapCase: Codable, Equatable {
        let name: String
        let projection: AppShellLaunchBootstrapProjection
    }

    private struct AppShellLaunchBootstrapProjection: Codable, Equatable {
        let target: ScreenTarget
        let context: AppLaunchContext
        let closedFrame: DisplayFrame
        let route: AppLifecycleRoute
        let runtimeOwnerStartCount: Int
        let actionCount: Int
        let statusItemMenuEntryCount: Int
        let firstStatusItemCommand: String?

        init(_ plan: AppShellLaunchBootstrapPlan) {
            self.target = plan.request.target
            self.context = plan.request.context
            self.closedFrame = plan.request.placement.closedFrame
            self.route = plan.summary.route
            self.runtimeOwnerStartCount = plan.summary.runtimeOwnerStartCount
            self.actionCount = plan.summary.actionCount
            self.statusItemMenuEntryCount = plan.summary.statusItemMenuEntryCount
            self.firstStatusItemCommand = plan.statusItemMenu.entries.first?.command.map(Self.commandLabel)
        }

        private static func commandLabel(_ command: AppCommand) -> String {
            switch command {
            case .openSettings:
                return "openSettings"
            case .checkForUpdates:
                return "checkForUpdates"
            case .exportDiagnostics:
                return "exportDiagnostics"
            case .quit:
                return "quit"
            case .toggleDockIcon:
                return "toggleDockIcon"
            case .toggleLaunchAtLogin:
                return "toggleLaunchAtLogin"
            case let .selectScreenMode(mode):
                return "selectScreenMode:\(mode.rawValue)"
            }
        }
    }
}
