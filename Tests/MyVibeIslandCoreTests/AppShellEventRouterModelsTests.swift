import XCTest
@testable import MyVibeIslandCore

final class AppShellEventRouterModelsTests: XCTestCase {
    func testAppShellEventRouterMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppShellEventRouterMatrixFixture.self,
            from: try FixtureLoader.data("settings/app-shell-event-router-matrix")
        )
        let router = AppShellEventRouter()
        let disabled = StatusItemMenuEntry(
            kind: .command,
            title: "Export Diagnostics",
            command: .exportDiagnostics,
            isEnabled: false
        )
        let commandless = StatusItemMenuEntry(
            kind: .command,
            title: "Missing Command",
            isEnabled: true
        )
        let separator = StatusItemMenuEntry(kind: .separator, title: "")

        let cases = [
            AppShellEventRouterCase(
                name: "launch",
                route: AppShellEventRouteProjection(router.route(.didFinishLaunching(launchRequest())))
            ),
            AppShellEventRouterCase(
                name: "reopen-island",
                route: AppShellEventRouteProjection(router.route(.reopen(behavior: .showIsland)))
            ),
            AppShellEventRouterCase(
                name: "reopen-settings",
                route: AppShellEventRouteProjection(router.route(.reopen(behavior: .openSettings)))
            ),
            AppShellEventRouterCase(
                name: "reopen-ignored",
                route: AppShellEventRouteProjection(router.route(.reopen(behavior: .ignore)))
            ),
            AppShellEventRouterCase(
                name: "will-terminate",
                route: AppShellEventRouteProjection(router.route(.willTerminate))
            ),
            AppShellEventRouterCase(
                name: "disabled-menu-entry",
                route: AppShellEventRouteProjection(router.route(.menuEntrySelected(disabled)))
            ),
            AppShellEventRouterCase(
                name: "commandless-menu-entry",
                route: AppShellEventRouteProjection(router.route(.menuEntrySelected(commandless)))
            ),
            AppShellEventRouterCase(
                name: "separator-menu-entry",
                route: AppShellEventRouteProjection(router.route(.menuEntrySelected(separator)))
            ),
            AppShellEventRouterCase(
                name: "direct-menu-command",
                route: AppShellEventRouteProjection(router.route(.menuCommand(.exportDiagnostics)))
            ),
            AppShellEventRouterCase(
                name: "overlay-gesture",
                route: AppShellEventRouteProjection(router.route(.overlayGesture(.jumpToSession(sessionId: "session-1"))))
            ),
            AppShellEventRouterCase(
                name: "placement-replacement",
                route: AppShellEventRouteProjection(router.route(.placementChanged(placementPlan())))
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testLaunchAndTerminateEventsMapToShellCommands() {
        let router = AppShellEventRouter()
        let request = launchRequest()

        XCTAssertEqual(router.route(.didFinishLaunching(request)).commands, [.launch(request)])
        XCTAssertEqual(router.route(.willTerminate).commands, [.terminate])
    }

    func testReopenBehaviorMapsToExpectedRouteOrIgnore() {
        let router = AppShellEventRouter()

        XCTAssertEqual(router.route(.reopen(behavior: .showIsland)).commands, [.reopen(.island)])
        XCTAssertEqual(router.route(.reopen(behavior: .openSettings)).commands, [.reopen(.settings(nil))])

        let ignored = router.route(.reopen(behavior: .ignore))
        XCTAssertEqual(ignored.commands, [])
        XCTAssertEqual(ignored.ignoredReason, .reopenIgnored)
    }

    func testEnabledMenuEntryRoutesCommand() {
        let router = AppShellEventRouter()
        let entry = StatusItemMenuEntry(
            kind: .command,
            title: "Open Settings",
            command: .openSettings,
            isEnabled: true
        )

        let route = router.route(.menuEntrySelected(entry))

        XCTAssertEqual(route.commands, [.menu(.openSettings)])
        XCTAssertNil(route.ignoredReason)
    }

    func testDisabledAndNonCommandMenuEntriesAreIgnored() {
        let router = AppShellEventRouter()
        let disabled = StatusItemMenuEntry(
            kind: .command,
            title: "Export Diagnostics",
            command: .exportDiagnostics,
            isEnabled: false
        )
        let separator = StatusItemMenuEntry(kind: .separator, title: "")

        XCTAssertEqual(router.route(.menuEntrySelected(disabled)).ignoredReason, .disabledMenuEntry)
        XCTAssertEqual(router.route(.menuEntrySelected(separator)).ignoredReason, .nonCommandMenuEntry)
    }

    func testDirectMenuCommandRoutesWithoutAvailabilityCheck() {
        let router = AppShellEventRouter()

        let route = router.route(.menuCommand(.exportDiagnostics))

        XCTAssertEqual(route.commands, [.menu(.exportDiagnostics)])
    }

    func testOverlayGestureRoutesToOverlayCommand() {
        let router = AppShellEventRouter()

        let route = router.route(.overlayGesture(.jumpToSession(sessionId: "session-1")))

        XCTAssertEqual(route.commands, [
            .overlay(.sessionGesture(.jumpToSession(sessionId: "session-1")))
        ])
    }

    func testReplacementEventsRouteToShellReplacementCommands() {
        let router = AppShellEventRouter()
        let placement = placementPlan()
        let presentation = NotchPresentationState(displayState: .expanded, focusedSessionId: "session-1")
        let menu = AppMenuSnapshot(enabledCommands: [.openSettings])

        XCTAssertEqual(router.route(.placementChanged(placement)).commands, [.replacePlacement(placement)])
        XCTAssertEqual(router.route(.presentationChanged(presentation)).commands, [.replacePresentation(presentation)])
        XCTAssertEqual(router.route(.menuSnapshotChanged(menu)).commands, [.replaceMenuSnapshot(menu)])
    }

    func testIgnoredReasonRoundTripsThroughJSON() throws {
        let reason = AppShellIgnoredEventReason.disabledMenuEntry

        let decoded = try JSONDecoder().decode(
            AppShellIgnoredEventReason.self,
            from: try JSONEncoder().encode(reason)
        )

        XCTAssertEqual(decoded, reason)
    }

    private func launchRequest() -> AppShellLaunchRequest {
        AppShellLaunchRequest(
            context: AppLaunchContext(),
            target: ScreenTarget(identifier: "main", displayName: "main", isBuiltIn: true, isMain: true),
            placement: placementPlan(),
            menuSnapshot: AppMenuSnapshot(enabledCommands: [.openSettings, .quit])
        )
    }

    private func placementPlan() -> DisplayPlacementPlan {
        DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 100, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 40, y: 20, width: 640, height: 420),
            anchor: DisplayPoint(x: 210, y: 20),
            safeAreaAdjustment: 20
        )
    }

    private struct AppShellEventRouterMatrixFixture: Codable, Equatable {
        let cases: [AppShellEventRouterCase]
    }

    private struct AppShellEventRouterCase: Codable, Equatable {
        let name: String
        let route: AppShellEventRouteProjection
    }

    private struct AppShellEventRouteProjection: Codable, Equatable {
        let commandLabels: [String]
        let ignoredReason: AppShellIgnoredEventReason?

        init(_ route: AppShellEventRoute) {
            self.commandLabels = route.commands.map(Self.commandLabel)
            self.ignoredReason = route.ignoredReason
        }

        private static func commandLabel(_ command: AppShellCommand) -> String {
            switch command {
            case .launch:
                return "launch"
            case let .reopen(target):
                return "reopen:\(reopenTargetLabel(target))"
            case .terminate:
                return "terminate"
            case .overlay:
                return "overlay"
            case let .menu(command):
                return "menu:\(appCommandLabel(command))"
            case .replacePresentation:
                return "replacePresentation"
            case .replaceMenuSnapshot:
                return "replaceMenuSnapshot"
            case .replacePlacement:
                return "replacePlacement"
            case let .runtimeOwnerObserved(owner, isRunning):
                return "runtimeOwnerObserved:\(owner.rawValue):\(isRunning)"
            }
        }

        private static func reopenTargetLabel(_ target: AppReopenTarget) -> String {
            switch target {
            case .defaultRoute:
                return "defaultRoute"
            case .island:
                return "island"
            case .settings:
                return "settings"
            case .onboarding:
                return "onboarding"
            }
        }

        private static func appCommandLabel(_ command: AppCommand) -> String {
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
