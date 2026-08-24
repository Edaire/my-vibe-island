import XCTest
@testable import MyVibeIslandCore

final class AppShellPlatformLaunchModelsTests: XCTestCase {
    func testAppShellPlatformLaunchMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppShellPlatformLaunchMatrixFixture.self,
            from: try FixtureLoader.data("settings/app-shell-platform-launch-matrix")
        )
        let planner = AppShellPlatformLaunchPlanner()
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 10, y: 20, width: 640, height: 420),
            anchor: DisplayPoint(x: 120, y: 20),
            safeAreaAdjustment: 20
        )

        let cases = [
            AppShellPlatformLaunchCase(
                name: "default-launch-plan-summary",
                projection: AppShellPlatformLaunchProjection(planner.makePlan(from: launchPlan))
            ),
            AppShellPlatformLaunchCase(
                name: "runtime-and-notch-event-actions",
                projection: AppShellPlatformLaunchProjection(intents: planner.makeIntents(from: [
                    .overlay(.routeAction(.appCommand(.openSettings))),
                    .openSettings(nil),
                    .notchWindow(.applyPlacement(placement)),
                    .quitApplication
                ]))
            ),
            AppShellPlatformLaunchCase(
                name: "preference-and-maintenance-actions",
                projection: AppShellPlatformLaunchProjection(intents: planner.makeIntents(from: [
                    .setDockIconVisible(true),
                    .setLaunchAtLoginEnabled(false),
                    .checkForUpdates,
                    .exportDiagnostics
                ]))
            ),
            AppShellPlatformLaunchCase(
                name: "menu-snapshot-action-without-status-menu-is-skipped",
                projection: AppShellPlatformLaunchProjection(intents: planner.makeIntents(from: [
                    .applyMenuSnapshot(AppMenuSnapshot(enabledCommands: [.openSettings])),
                    .showIsland
                ]))
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testDefaultBootstrapPlanMapsToOrderedPlatformIntents() {
        let launchPlan = AppShellLaunchBootstrap().buildLaunchPlan()

        let platformPlan = AppShellPlatformLaunchPlanner().makePlan(from: launchPlan)

        XCTAssertEqual(platformPlan.launchPlan, launchPlan)
        XCTAssertEqual(Array(platformPlan.intents.prefix(3)), [
            .lifecycle(.createRuntime),
            .lifecycle(.loadSettings),
            .lifecycle(.configureDockPolicy)
        ])
        XCTAssertTrue(platformPlan.intents.contains(.startRuntimeOwner(.bridgeServer)))
        XCTAssertTrue(platformPlan.intents.contains(.createNotchPanel))
        XCTAssertTrue(platformPlan.intents.contains(.installNotchEventMonitors))
        XCTAssertTrue(platformPlan.intents.contains(.applyTargetScreen("main")))
        XCTAssertTrue(platformPlan.intents.contains(.applyNotchPlacement(launchPlan.request.placement)))
        XCTAssertTrue(platformPlan.intents.contains(.showNotchPanel))
        XCTAssertEqual(platformPlan.intents.suffix(2), [
            .applyStatusItemMenu(launchPlan.statusItemMenu),
            .showIsland
        ])
    }

    func testSummaryGroupsLaunchIntentCountsForPlatformRunner() {
        let summary = AppShellPlatformLaunchPlanner()
            .makePlan(from: AppShellLaunchBootstrap().buildLaunchPlan())
            .summary

        XCTAssertEqual(summary.intentCount, 36)
        XCTAssertEqual(summary.lifecycleIntentCount, 10)
        XCTAssertEqual(summary.runtimeStartIntentCount, 19)
        XCTAssertEqual(summary.notchWindowIntentCount, 5)
        XCTAssertEqual(summary.statusItemMenuEntryCount, 14)
        XCTAssertEqual(summary.routeIntentCount, 1)
        XCTAssertEqual(summary.intentGroupDescription, "lifecycle, runtime, notch, statusMenu, route")
    }

    func testPlannerMapsShellActionsToPlatformIntentsForRuntimeEvents() {
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 10, y: 20, width: 640, height: 420),
            anchor: DisplayPoint(x: 120, y: 20),
            safeAreaAdjustment: 20
        )

        let intents = AppShellPlatformLaunchPlanner().makeIntents(from: [
            .overlay(.routeAction(.appCommand(.openSettings))),
            .openSettings(nil),
            .notchWindow(.applyPlacement(placement)),
            .quitApplication
        ])

        XCTAssertEqual(intents, [
            .overlay(.routeAction(.appCommand(.openSettings))),
            .openSettings(nil),
            .applyNotchPlacement(placement),
            .quitApplication
        ])
    }

    func testPlannerMapsPreferenceAndMaintenanceShellActionsToPlatformIntents() {
        let intents = AppShellPlatformLaunchPlanner().makeIntents(from: [
            .setDockIconVisible(true),
            .setLaunchAtLoginEnabled(false),
            .checkForUpdates,
            .exportDiagnostics
        ])

        XCTAssertEqual(intents, [
            .setDockIconVisible(true),
            .setLaunchAtLoginEnabled(false),
            .checkForUpdates,
            .exportDiagnostics
        ])
    }

    private struct AppShellPlatformLaunchMatrixFixture: Codable, Equatable {
        let cases: [AppShellPlatformLaunchCase]
    }

    private struct AppShellPlatformLaunchCase: Codable, Equatable {
        let name: String
        let projection: AppShellPlatformLaunchProjection
    }

    private struct AppShellPlatformLaunchProjection: Codable, Equatable {
        let intentCount: Int
        let lifecycleIntentCount: Int
        let runtimeStartIntentCount: Int
        let notchWindowIntentCount: Int
        let statusItemMenuEntryCount: Int
        let routeIntentCount: Int
        let intentGroupDescription: String
        let firstIntents: [String]
        let lastIntents: [String]
        let allIntents: [String]

        init(_ plan: AppShellPlatformLaunchPlan) {
            self.init(intents: plan.intents, summary: plan.summary)
        }

        init(intents: [AppShellPlatformLaunchIntent]) {
            let summary = AppShellPlatformLaunchSummary(
                intentCount: intents.count,
                lifecycleIntentCount: intents.filter(Self.isLifecycle).count,
                runtimeStartIntentCount: intents.filter(Self.isRuntimeStart).count,
                notchWindowIntentCount: intents.filter(Self.isNotchWindow).count,
                statusItemMenuEntryCount: 0,
                routeIntentCount: intents.filter(Self.isRoute).count
            )
            self.init(intents: intents, summary: summary)
        }

        private init(intents: [AppShellPlatformLaunchIntent], summary: AppShellPlatformLaunchSummary) {
            self.intentCount = summary.intentCount
            self.lifecycleIntentCount = summary.lifecycleIntentCount
            self.runtimeStartIntentCount = summary.runtimeStartIntentCount
            self.notchWindowIntentCount = summary.notchWindowIntentCount
            self.statusItemMenuEntryCount = summary.statusItemMenuEntryCount
            self.routeIntentCount = summary.routeIntentCount
            self.intentGroupDescription = summary.intentGroupDescription
            let labels = intents.map(Self.intentLabel)
            self.firstIntents = Array(labels.prefix(6))
            self.lastIntents = Array(labels.suffix(6))
            self.allIntents = labels.count <= 12 ? labels : []
        }

        private static func isLifecycle(_ intent: AppShellPlatformLaunchIntent) -> Bool {
            if case .lifecycle = intent {
                return true
            }
            return false
        }

        private static func isRuntimeStart(_ intent: AppShellPlatformLaunchIntent) -> Bool {
            if case .startRuntimeOwner = intent {
                return true
            }
            return false
        }

        private static func isNotchWindow(_ intent: AppShellPlatformLaunchIntent) -> Bool {
            switch intent {
            case .createNotchPanel,
                 .installNotchEventMonitors,
                 .removeNotchEventMonitors,
                 .applyTargetScreen,
                 .applyNotchPlacement,
                 .showNotchPanel,
                 .hideNotchPanel,
                 .closeNotchPanel:
                return true
            case .lifecycle,
                 .startRuntimeOwner,
                 .stopRuntimeOwner,
                 .overlay,
                 .applyStatusItemMenu,
                 .showIsland,
                 .openSettings,
                 .showOnboarding,
                 .setDockIconVisible,
                 .setLaunchAtLoginEnabled,
                 .checkForUpdates,
                 .exportDiagnostics,
                 .quitApplication,
                 .ignoredMenuCommand:
                return false
            }
        }

        private static func isRoute(_ intent: AppShellPlatformLaunchIntent) -> Bool {
            switch intent {
            case .showIsland, .openSettings, .showOnboarding:
                return true
            case .lifecycle,
                 .startRuntimeOwner,
                 .stopRuntimeOwner,
                 .createNotchPanel,
                 .installNotchEventMonitors,
                 .removeNotchEventMonitors,
                 .applyTargetScreen,
                 .applyNotchPlacement,
                 .showNotchPanel,
                 .hideNotchPanel,
                 .closeNotchPanel,
                 .overlay,
                 .applyStatusItemMenu,
                 .setDockIconVisible,
                 .setLaunchAtLoginEnabled,
                 .checkForUpdates,
                 .exportDiagnostics,
                 .quitApplication,
                 .ignoredMenuCommand:
                return false
            }
        }

        private static func intentLabel(_ intent: AppShellPlatformLaunchIntent) -> String {
            switch intent {
            case let .lifecycle(step):
                return "lifecycle:\(step.rawValue)"
            case let .startRuntimeOwner(owner):
                return "startRuntimeOwner:\(owner.rawValue)"
            case let .stopRuntimeOwner(owner):
                return "stopRuntimeOwner:\(owner.rawValue)"
            case .createNotchPanel:
                return "createNotchPanel"
            case .installNotchEventMonitors:
                return "installNotchEventMonitors"
            case .removeNotchEventMonitors:
                return "removeNotchEventMonitors"
            case let .applyTargetScreen(identifier):
                return "applyTargetScreen:\(identifier)"
            case let .applyNotchPlacement(placement):
                return "applyNotchPlacement:\(frameLabel(placement.closedFrame))"
            case .showNotchPanel:
                return "showNotchPanel"
            case .hideNotchPanel:
                return "hideNotchPanel"
            case .closeNotchPanel:
                return "closeNotchPanel"
            case let .overlay(action):
                return "overlay:\(overlayActionLabel(action))"
            case let .applyStatusItemMenu(menu):
                return "applyStatusItemMenu:\(menu.entries.count)"
            case .showIsland:
                return "showIsland"
            case let .openSettings(link):
                return "openSettings:\(link == nil ? "default" : "deepLink")"
            case .showOnboarding:
                return "showOnboarding"
            case let .setDockIconVisible(isVisible):
                return "setDockIconVisible:\(isVisible)"
            case let .setLaunchAtLoginEnabled(isEnabled):
                return "setLaunchAtLoginEnabled:\(isEnabled)"
            case .checkForUpdates:
                return "checkForUpdates"
            case .exportDiagnostics:
                return "exportDiagnostics"
            case .quitApplication:
                return "quitApplication"
            case let .ignoredMenuCommand(command):
                return "ignoredMenuCommand:\(commandLabel(command))"
            }
        }

        private static func overlayActionLabel(_ action: OverlayControllerAction) -> String {
            switch action {
            case .renderPresentation:
                return "renderPresentation"
            case .renderIslandSurface:
                return "renderIslandSurface"
            case .applyPanelPlan:
                return "applyPanelPlan"
            case let .routeAction(routedAction):
                return "routeAction:\(routedActionLabel(routedAction))"
            case let .recordDisplayReason(reason):
                return "recordDisplayReason:\(reason.rawValue)"
            }
        }

        private static func routedActionLabel(_ action: OverlayRoutedAction) -> String {
            switch action {
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
                return "appCommand:\(commandLabel(command))"
            case .openSettings:
                return "openSettings"
            }
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

        private static func frameLabel(_ frame: DisplayFrame) -> String {
            "\(frame.x),\(frame.y),\(frame.width)x\(frame.height)"
        }
    }
}
