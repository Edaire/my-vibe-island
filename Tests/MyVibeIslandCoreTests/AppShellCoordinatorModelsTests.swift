import XCTest
@testable import MyVibeIslandCore

final class AppShellCoordinatorModelsTests: XCTestCase {
    func testAppShellCoordinatorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppShellCoordinatorMatrixFixture.self,
            from: try FixtureLoader.data("settings/app-shell-coordinator-matrix")
        )
        let coordinator = AppShellCoordinatorModel()
        let launched = launchedCoordinatorState()
        let disabled = StatusItemMenuEntry(
            kind: .command,
            title: "Export Diagnostics",
            command: .exportDiagnostics,
            isEnabled: false
        )
        let hiddenPlacement = DisplayPlacementPlan(
            closedFrame: .zero,
            expandedFrame: .zero,
            anchor: DisplayPoint(x: 0, y: 0),
            safeAreaAdjustment: 0,
            collapseReason: .fullscreenHidden
        )

        let cases = [
            AppShellCoordinatorCase(
                name: "launch-clears-ignored-reason",
                plan: AppShellCoordinatorPlanProjection(coordinator.apply(
                    .didFinishLaunching(launchRequest()),
                    from: AppShellCoordinatorState(lastIgnoredReason: .disabledMenuEntry)
                ))
            ),
            AppShellCoordinatorCase(
                name: "disabled-menu-entry-records-ignored-reason",
                plan: AppShellCoordinatorPlanProjection(coordinator.apply(
                    .menuEntrySelected(disabled),
                    from: launched
                ))
            ),
            AppShellCoordinatorCase(
                name: "menu-command-routes-settings",
                plan: AppShellCoordinatorPlanProjection(coordinator.apply(
                    .menuCommand(.openSettings),
                    from: launched
                ))
            ),
            AppShellCoordinatorCase(
                name: "placement-change-hides-window",
                plan: AppShellCoordinatorPlanProjection(coordinator.apply(
                    .placementChanged(hiddenPlacement),
                    from: launched
                ))
            ),
            AppShellCoordinatorCase(
                name: "sequential-settings-then-terminate",
                plan: AppShellCoordinatorPlanProjection(coordinator.applyCommands(
                    [.menu(.openSettings), .terminate],
                    from: launched
                ))
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testLaunchEventAppliesShellPlanAndClearsIgnoredReason() {
        let coordinator = AppShellCoordinatorModel()
        let initial = AppShellCoordinatorState(lastIgnoredReason: .disabledMenuEntry)
        let request = launchRequest()

        let plan = coordinator.apply(.didFinishLaunching(request), from: initial)

        XCTAssertEqual(plan.commands, [.launch(request)])
        XCTAssertNil(plan.nextState.lastIgnoredReason)
        XCTAssertEqual(plan.nextState.shellState.lifecycleState.route, .island)
        XCTAssertTrue(plan.nextState.shellState.runtimeSnapshot.owners.allSatisfy { !$0.isRunning })
        XCTAssertTrue(plan.actions.contains(.showIsland))
    }

    func testIgnoredEventRecordsReasonWithoutChangingShellState() {
        let coordinator = AppShellCoordinatorModel()
        let state = launchedCoordinatorState()
        let disabled = StatusItemMenuEntry(
            kind: .command,
            title: "Export Diagnostics",
            command: .exportDiagnostics,
            isEnabled: false
        )

        let plan = coordinator.apply(.menuEntrySelected(disabled), from: state)

        XCTAssertEqual(plan.commands, [])
        XCTAssertEqual(plan.actions, [])
        XCTAssertEqual(plan.nextState.shellState, state.shellState)
        XCTAssertEqual(plan.nextState.lastIgnoredReason, .disabledMenuEntry)
    }

    func testMenuCommandEventAppliesShellMenuPlan() {
        let coordinator = AppShellCoordinatorModel()
        let state = launchedCoordinatorState()

        let plan = coordinator.apply(.menuCommand(.openSettings), from: state)

        XCTAssertEqual(plan.commands, [.menu(.openSettings)])
        XCTAssertEqual(plan.nextState.shellState.overlayState.lastRoutedAction, .appCommand(.openSettings))
        XCTAssertEqual(plan.actions, [
            .overlay(.routeAction(.appCommand(.openSettings))),
            .openSettings(nil)
        ])
    }

    func testPlacementEventUpdatesWindowAndOverlayState() {
        let coordinator = AppShellCoordinatorModel()
        let state = launchedCoordinatorState()
        let hidden = DisplayPlacementPlan(
            closedFrame: .zero,
            expandedFrame: .zero,
            anchor: DisplayPoint(x: 0, y: 0),
            safeAreaAdjustment: 0,
            collapseReason: .fullscreenHidden
        )

        let plan = coordinator.apply(.placementChanged(hidden), from: state)

        XCTAssertEqual(plan.commands, [.replacePlacement(hidden)])
        XCTAssertEqual(plan.nextState.shellState.notchWindowState.visibility, .hidden)
        XCTAssertEqual(plan.nextState.shellState.overlayState.panelState.placementPlan, hidden)
    }

    func testApplyCommandsFoldsSequentially() {
        let coordinator = AppShellCoordinatorModel()
        let state = launchedCoordinatorState()

        let plan = coordinator.applyCommands([.menu(.openSettings), .terminate], from: state)

        XCTAssertEqual(plan.commands, [.menu(.openSettings), .terminate])
        XCTAssertTrue(plan.nextState.shellState.lifecycleState.isTerminated)
        XCTAssertEqual(plan.nextState.shellState.overlayState.lastRoutedAction, .appCommand(.openSettings))
        XCTAssertTrue(plan.actions.contains(.openSettings(nil)))
        XCTAssertFalse(plan.actions.contains(.quitApplication))
    }

    func testCoordinatorStateRoundTripsThroughJSON() throws {
        let state = launchedCoordinatorState(lastIgnoredReason: .nonCommandMenuEntry)

        let decoded = try JSONDecoder().decode(
            AppShellCoordinatorState.self,
            from: try JSONEncoder().encode(state)
        )

        XCTAssertEqual(decoded, state)
    }

    private func launchedCoordinatorState(
        lastIgnoredReason: AppShellIgnoredEventReason? = nil
    ) -> AppShellCoordinatorState {
        let shellPlan = AppShellModel().plan(.launch(launchRequest()), from: AppShellState())
        return AppShellCoordinatorState(
            shellState: shellPlan.nextState,
            lastIgnoredReason: lastIgnoredReason
        )
    }

    private func launchRequest() -> AppShellLaunchRequest {
        AppShellLaunchRequest(
            context: AppLaunchContext(),
            target: ScreenTarget(identifier: "main", displayName: "main", isBuiltIn: true, isMain: true),
            placement: visiblePlacement(),
            menuSnapshot: AppMenuSnapshot(enabledCommands: [.openSettings, .quit])
        )
    }

    private func visiblePlacement() -> DisplayPlacementPlan {
        DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 100, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 40, y: 20, width: 640, height: 420),
            anchor: DisplayPoint(x: 210, y: 20),
            safeAreaAdjustment: 20
        )
    }

    private struct AppShellCoordinatorMatrixFixture: Codable, Equatable {
        let cases: [AppShellCoordinatorCase]
    }

    private struct AppShellCoordinatorCase: Codable, Equatable {
        let name: String
        let plan: AppShellCoordinatorPlanProjection
    }

    private struct AppShellCoordinatorPlanProjection: Codable, Equatable {
        let state: AppShellCoordinatorStateProjection
        let commandLabels: [String]
        let actionLabels: [String]

        init(_ plan: AppShellCoordinatorPlan) {
            self.state = AppShellCoordinatorStateProjection(plan.nextState)
            self.commandLabels = plan.commands.map(Self.commandLabel)
            self.actionLabels = plan.actions.map(Self.actionLabel)
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
                return "menu:\(commandLabel(command))"
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

        private static func actionLabel(_ action: AppShellAction) -> String {
            switch action {
            case let .lifecycle(step):
                return "lifecycle:\(step.rawValue)"
            case .runtime:
                return "runtime"
            case .notchWindow:
                return "notchWindow"
            case .overlay:
                return "overlay"
            case .applyMenuSnapshot:
                return "applyMenuSnapshot"
            case .showIsland:
                return "showIsland"
            case let .openSettings(deepLink):
                return "openSettings:\(deepLinkLabel(deepLink))"
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

        private static func reopenTargetLabel(_ target: AppReopenTarget) -> String {
            switch target {
            case .defaultRoute:
                return "defaultRoute"
            case .island:
                return "island"
            case let .settings(deepLink):
                return "settings:\(deepLinkLabel(deepLink))"
            case .onboarding:
                return "onboarding"
            }
        }

        private static func deepLinkLabel(_ deepLink: SettingsDeepLink?) -> String {
            guard let deepLink else {
                return "none"
            }

            return "\(deepLink.section.rawValue):\(deepLink.rowId ?? "none")"
        }
    }

    private struct AppShellCoordinatorStateProjection: Codable, Equatable {
        let route: AppLifecycleRoute
        let isTerminated: Bool
        let lastIgnoredReason: AppShellIgnoredEventReason?
        let notchVisibility: NotchWindowVisibility
        let overlayLastActionLabel: String?

        init(_ state: AppShellCoordinatorState) {
            self.route = state.shellState.lifecycleState.route
            self.isTerminated = state.shellState.lifecycleState.isTerminated
            self.lastIgnoredReason = state.lastIgnoredReason
            self.notchVisibility = state.shellState.notchWindowState.visibility
            self.overlayLastActionLabel = state.shellState.overlayState.lastRoutedAction.map(Self.overlayActionLabel)
        }

        private static func overlayActionLabel(_ action: OverlayRoutedAction) -> String {
            switch action {
            case .openSettings:
                return "openSettings"
            case let .appCommand(command):
                return "appCommand:\(appCommandLabel(command))"
            case let .selectSession(sessionId):
                return "selectSession:\(sessionId)"
            case let .jumpToSession(sessionId):
                return "jumpToSession:\(sessionId)"
            case let .resolveAction(requestId, optionId):
                return "resolveAction:\(requestId):\(optionId)"
            case let .answerQuestion(requestId, answer):
                return "answerQuestion:\(requestId):\(answer)"
            case let .submitActionResolution(resolution):
                return "submitActionResolution:\(resolution.requestId):\(resolution.kind.rawValue)"
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
