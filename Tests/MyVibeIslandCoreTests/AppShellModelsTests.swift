import XCTest
@testable import MyVibeIslandCore

final class AppShellModelsTests: XCTestCase {
    func testAppShellModelMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppShellModelMatrixFixture.self,
            from: try FixtureLoader.data("settings/app-shell-model-matrix")
        )
        let model = AppShellModel()
        let launched = launchedState()
        let hidden = DisplayPlacementPlan(
            closedFrame: .zero,
            expandedFrame: .zero,
            anchor: DisplayPoint(x: 0, y: 0),
            safeAreaAdjustment: 0,
            collapseReason: .fullscreenHidden
        )
        let maintenanceState = AppShellState(
            overlayState: OverlayControllerState(menuSnapshot: AppMenuSnapshot()),
            menuSnapshot: AppMenuSnapshot(
                enabledCommands: [
                    .checkForUpdates,
                    .exportDiagnostics,
                    .toggleDockIcon,
                    .toggleLaunchAtLogin
                ],
                launchAtLoginEnabled: false,
                dockIconVisible: false,
                updateState: .upToDate,
                diagnosticsExportAvailable: true
            )
        )
        let launchRequest = AppShellLaunchRequest(
            context: AppLaunchContext(),
            target: target("main"),
            placement: visiblePlacement(),
            menuSnapshot: menuSnapshot()
        )
        let link = SettingsDeepLink(section: .integrations, rowId: "codex")

        let cases = [
            AppShellModelCase(
                name: "launch-starts-runtime-window-menu-and-island-route",
                projection: AppShellPlanProjection(model.plan(.launch(launchRequest), from: AppShellState()))
            ),
            AppShellModelCase(
                name: "reopen-settings-keeps-runtime-state",
                projection: AppShellPlanProjection(model.plan(.reopen(.settings(link)), from: launched))
            ),
            AppShellModelCase(
                name: "terminate-closes-window-and-stops-runtime",
                projection: AppShellPlanProjection(model.plan(.terminate, from: launched))
            ),
            AppShellModelCase(
                name: "overlay-jump-routes-through-overlay",
                projection: AppShellPlanProjection(
                    model.plan(.overlay(.sessionGesture(.jumpToSession(sessionId: "session-1"))), from: launched)
                )
            ),
            AppShellModelCase(
                name: "menu-open-settings-routes-overlay-and-platform",
                projection: AppShellPlanProjection(model.plan(.menu(.openSettings), from: launched))
            ),
            AppShellModelCase(
                name: "menu-toggle-dock-routes-preference-state",
                projection: AppShellPlanProjection(model.plan(.menu(.toggleDockIcon), from: maintenanceState))
            ),
            AppShellModelCase(
                name: "disabled-menu-command-is-ignored",
                projection: AppShellPlanProjection(
                    model.plan(.menu(.exportDiagnostics), from: AppShellState(menuSnapshot: AppMenuSnapshot(enabledCommands: [.openSettings])))
                )
            ),
            AppShellModelCase(
                name: "hidden-placement-updates-window-and-overlay",
                projection: AppShellPlanProjection(model.plan(.replacePlacement(hidden), from: launched))
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testLaunchPlansLifecycleRuntimeWindowMenuAndInitialRoute() {
        let model = AppShellModel()
        let request = AppShellLaunchRequest(
            context: AppLaunchContext(),
            target: target("main"),
            placement: visiblePlacement(),
            menuSnapshot: menuSnapshot()
        )

        let plan = model.plan(.launch(request), from: AppShellState())

        XCTAssertEqual(plan.nextState.lifecycleState.route, .island)
        XCTAssertTrue(plan.nextState.runtimeSnapshot.owners.allSatisfy { !$0.isRunning })
        XCTAssertEqual(plan.nextState.notchWindowState.visibility, .visible)
        XCTAssertEqual(plan.nextState.overlayState.menuSnapshot, menuSnapshot())
        XCTAssertEqual(plan.nextState.menuSnapshot, menuSnapshot())
        XCTAssertEqual(Array(plan.actions.prefix(3)), [
            .lifecycle(.createRuntime),
            .lifecycle(.loadSettings),
            .lifecycle(.configureDockPolicy)
        ])
        XCTAssertTrue(plan.actions.contains(.runtime(AppRuntimeOwnerAction(owner: .bridgeServer, kind: .start))))
        XCTAssertTrue(plan.actions.contains(.notchWindow(.createPanel)))
        XCTAssertEqual(plan.actions.suffix(2), [
            .applyMenuSnapshot(menuSnapshot()),
            .showIsland
        ])
    }

    func testReopenRoutesThroughLifecycleWithoutRestartingRuntime() {
        let model = AppShellModel()
        let launched = launchedState()
        let link = SettingsDeepLink(section: .integrations, rowId: "codex")

        let plan = model.plan(.reopen(.settings(link)), from: launched)

        XCTAssertEqual(plan.nextState.lifecycleState.route, .settings)
        XCTAssertEqual(plan.nextState.lifecycleState.pendingSettingsDeepLink, link)
        XCTAssertEqual(plan.nextState.runtimeSnapshot, launched.runtimeSnapshot)
        XCTAssertEqual(plan.actions, [
            .lifecycle(.showSettingsWindow),
            .openSettings(link)
        ])
    }

    func testTerminatePlansLifecycleWindowAndRuntimeShutdown() {
        let model = AppShellModel()
        let launched = launchedState()

        let plan = model.plan(.terminate, from: launched)

        XCTAssertTrue(plan.nextState.lifecycleState.isTerminated)
        XCTAssertEqual(plan.nextState.notchWindowState.visibility, .closed)
        XCTAssertTrue(plan.nextState.runtimeSnapshot.owners.allSatisfy { !$0.isRunning })
        XCTAssertEqual(Array(plan.actions.prefix(3)), [
            .lifecycle(.persistSettingsAndSessions),
            .lifecycle(.unregisterShortcuts),
            .lifecycle(.closeWindows)
        ])
        XCTAssertTrue(plan.actions.contains(.notchWindow(.removeEventMonitors)))
        XCTAssertTrue(plan.actions.contains(.notchWindow(.closePanel)))
        XCTAssertEqual(plan.actions.last, .notchWindow(.closePanel))
        XCTAssertFalse(plan.actions.contains(.quitApplication))
    }

    func testOverlayCommandUpdatesOverlayStateAndForwardsActions() {
        let model = AppShellModel()
        let launched = launchedState()

        let plan = model.plan(
            .overlay(.sessionGesture(.jumpToSession(sessionId: "session-1"))),
            from: launched
        )

        XCTAssertEqual(plan.nextState.overlayState.lastRoutedAction, .jumpToSession(sessionId: "session-1"))
        XCTAssertEqual(plan.actions, [
            .overlay(.routeAction(.jumpToSession(sessionId: "session-1")))
        ])
    }

    func testMenuCommandRoutesEnabledCommandThroughMenuAndOverlay() {
        let model = AppShellModel()
        let launched = launchedState()

        let plan = model.plan(.menu(.openSettings), from: launched)

        XCTAssertEqual(plan.nextState.overlayState.lastRoutedAction, .appCommand(.openSettings))
        XCTAssertEqual(plan.nextState.overlayState.menuSnapshot, launched.menuSnapshot)
        XCTAssertEqual(plan.actions, [
            .overlay(.routeAction(.appCommand(.openSettings))),
            .openSettings(nil)
        ])
    }

    func testMenuCommandRoutesMaintenanceAndPreferenceCommandsToPlatformActions() {
        let model = AppShellModel()
        let state = AppShellState(
            overlayState: OverlayControllerState(menuSnapshot: AppMenuSnapshot()),
            menuSnapshot: AppMenuSnapshot(
                enabledCommands: [
                    .checkForUpdates,
                    .exportDiagnostics,
                    .toggleDockIcon,
                    .toggleLaunchAtLogin
                ],
                launchAtLoginEnabled: false,
                dockIconVisible: false,
                updateState: .upToDate,
                diagnosticsExportAvailable: true
            )
        )

        let dockPlan = model.plan(.menu(.toggleDockIcon), from: state)
        let loginPlan = model.plan(.menu(.toggleLaunchAtLogin), from: state)
        let updatePlan = model.plan(.menu(.checkForUpdates), from: state)
        let diagnosticsPlan = model.plan(.menu(.exportDiagnostics), from: state)

        XCTAssertTrue(dockPlan.nextState.menuSnapshot.dockIconVisible)
        XCTAssertEqual(dockPlan.actions.suffix(1), [.setDockIconVisible(true)])
        XCTAssertTrue(loginPlan.nextState.menuSnapshot.launchAtLoginEnabled)
        XCTAssertEqual(loginPlan.actions.suffix(1), [.setLaunchAtLoginEnabled(true)])
        XCTAssertEqual(updatePlan.actions.suffix(1), [.checkForUpdates])
        XCTAssertEqual(diagnosticsPlan.actions.suffix(1), [.exportDiagnostics])
    }

    func testMenuCommandIgnoresDisabledCommand() {
        let model = AppShellModel()
        let state = AppShellState(menuSnapshot: AppMenuSnapshot(enabledCommands: [.openSettings]))

        let plan = model.plan(.menu(.exportDiagnostics), from: state)

        XCTAssertEqual(plan.nextState, state)
        XCTAssertEqual(plan.actions, [
            .ignoredMenuCommand(.exportDiagnostics)
        ])
    }

    func testPlacementCommandUpdatesWindowAndOverlayPanel() {
        let model = AppShellModel()
        let launched = launchedState()
        let hidden = DisplayPlacementPlan(
            closedFrame: .zero,
            expandedFrame: .zero,
            anchor: DisplayPoint(x: 0, y: 0),
            safeAreaAdjustment: 0,
            collapseReason: .fullscreenHidden
        )

        let plan = model.plan(.replacePlacement(hidden), from: launched)

        XCTAssertEqual(plan.nextState.notchWindowState.visibility, .hidden)
        XCTAssertEqual(plan.nextState.overlayState.panelState.placementPlan, hidden)
        XCTAssertEqual(plan.actions, [
            .notchWindow(.applyPlacement(hidden)),
            .notchWindow(.hidePanel),
            .overlay(.applyPanelPlan(actions: [
                .hidePanel(reason: .fullscreenHide),
                .recordDisplayReason(.fullscreenHide)
            ])),
            .overlay(.recordDisplayReason(.fullscreenHide))
        ])
    }

    func testStateRoundTripsThroughJSON() throws {
        let state = launchedState()

        let decoded = try JSONDecoder().decode(
            AppShellState.self,
            from: try JSONEncoder().encode(state)
        )

        XCTAssertEqual(decoded, state)
    }

    private func launchedState() -> AppShellState {
        let runtime = AppRuntimeComposition().plan(.startAll, from: .defaultAppShell()).nextSnapshot
        let window = NotchWindowControllerModel()
            .plan(.create(target: target("main"), placement: visiblePlacement()), from: .init())
            .nextState
        return AppShellState(
            lifecycleState: AppLifecycleState(hasLaunched: true, route: .island),
            runtimeSnapshot: runtime,
            notchWindowState: window,
            overlayState: OverlayControllerState(
                panelState: OverlayPanelState(placementPlan: visiblePlacement()),
                menuSnapshot: menuSnapshot()
            ),
            menuSnapshot: menuSnapshot()
        )
    }

    private func menuSnapshot() -> AppMenuSnapshot {
        AppMenuSnapshot(
            enabledCommands: [.openSettings, .toggleDockIcon, .quit],
            diagnosticsExportAvailable: false
        )
    }

    private func target(_ identifier: String) -> ScreenTarget {
        ScreenTarget(identifier: identifier, displayName: identifier, isBuiltIn: identifier == "main", isMain: identifier == "main")
    }

    private func visiblePlacement() -> DisplayPlacementPlan {
        DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 100, y: 20, width: 220, height: 36),
            expandedFrame: DisplayFrame(x: 40, y: 20, width: 640, height: 420),
            anchor: DisplayPoint(x: 210, y: 20),
            safeAreaAdjustment: 20
        )
    }

    private struct AppShellModelMatrixFixture: Codable, Equatable {
        let cases: [AppShellModelCase]
    }

    private struct AppShellModelCase: Codable, Equatable {
        let name: String
        let projection: AppShellPlanProjection
    }

    private struct AppShellPlanProjection: Codable, Equatable {
        let route: AppLifecycleRoute
        let isTerminated: Bool
        let runningOwnerCount: Int
        let windowVisibility: NotchWindowVisibility
        let menuEnabledCommands: [String]
        let dockIconVisible: Bool
        let launchAtLoginEnabled: Bool
        let lastRoutedAction: String?
        let actionCount: Int
        let firstActions: [String]
        let lastActions: [String]
        let allActions: [String]

        init(_ plan: AppShellPlan) {
            self.route = plan.nextState.lifecycleState.route
            self.isTerminated = plan.nextState.lifecycleState.isTerminated
            self.runningOwnerCount = plan.nextState.runtimeSnapshot.owners.filter(\.isRunning).count
            self.windowVisibility = plan.nextState.notchWindowState.visibility
            self.menuEnabledCommands = plan.nextState.menuSnapshot.enabledCommands.map(Self.commandLabel)
            self.dockIconVisible = plan.nextState.menuSnapshot.dockIconVisible
            self.launchAtLoginEnabled = plan.nextState.menuSnapshot.launchAtLoginEnabled
            self.lastRoutedAction = plan.nextState.overlayState.lastRoutedAction.map(Self.routedActionLabel)
            self.actionCount = plan.actions.count
            let labels = plan.actions.map(Self.actionLabel)
            self.firstActions = Array(labels.prefix(6))
            self.lastActions = Array(labels.suffix(6))
            self.allActions = labels.count <= 12 ? labels : []
        }

        private static func actionLabel(_ action: AppShellAction) -> String {
            switch action {
            case let .lifecycle(step):
                return "lifecycle:\(step.rawValue)"
            case let .runtime(ownerAction):
                return "runtime:\(ownerAction.kind.rawValue):\(ownerAction.owner.rawValue)"
            case let .notchWindow(action):
                return "notchWindow:\(notchWindowActionLabel(action))"
            case let .overlay(action):
                return "overlay:\(overlayActionLabel(action))"
            case .applyMenuSnapshot:
                return "applyMenuSnapshot"
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

        private static func notchWindowActionLabel(_ action: NotchWindowControllerAction) -> String {
            switch action {
            case .createPanel:
                return "createPanel"
            case .installEventMonitors:
                return "installEventMonitors"
            case .removeEventMonitors:
                return "removeEventMonitors"
            case let .applyTargetScreen(identifier):
                return "applyTargetScreen:\(identifier)"
            case let .applyPlacement(placement):
                return "applyPlacement:\(placement.closedFrame.x),\(placement.closedFrame.y),\(placement.closedFrame.width)x\(placement.closedFrame.height)"
            case .showPanel:
                return "showPanel"
            case .hidePanel:
                return "hidePanel"
            case .closePanel:
                return "closePanel"
            }
        }

        private static func overlayActionLabel(_ action: OverlayControllerAction) -> String {
            switch action {
            case .renderPresentation:
                return "renderPresentation"
            case .renderIslandSurface:
                return "renderIslandSurface"
            case let .applyPanelPlan(actions):
                return "applyPanelPlan:\(actions.map(overlayPanelActionLabel).joined(separator: ","))"
            case let .routeAction(routedAction):
                return "routeAction:\(routedActionLabel(routedAction))"
            case let .recordDisplayReason(reason):
                return "recordDisplayReason:\(reason.rawValue)"
            }
        }

        private static func overlayPanelActionLabel(_ action: OverlayPanelAction) -> String {
            switch action {
            case let .applyFrame(frame):
                return "applyFrame:\(frame.x),\(frame.y),\(frame.width)x\(frame.height)"
            case let .showPanel(displayState):
                return "showPanel:\(displayState.rawValue)"
            case let .hidePanel(reason):
                return "hidePanel:\(reason.rawValue)"
            case let .forwardInteractionAction(action):
                return "forwardInteractionAction:\(panelInteractionActionLabel(action))"
            case let .recordDisplayReason(reason):
                return "recordDisplayReason:\(reason.rawValue)"
            }
        }

        private static func panelInteractionActionLabel(_ action: PanelInteractionAction) -> String {
            switch action {
            case let .setDisplayState(state):
                return "setDisplayState:\(state.rawValue)"
            case let .scheduleHoverReveal(delay, generation):
                return "scheduleHoverReveal:\(delay):\(generation)"
            case .cancelHoverReveal:
                return "cancelHoverReveal"
            case .cancelAutoCollapse:
                return "cancelAutoCollapse"
            case let .scheduleAutoCollapse(delay, generation):
                return "scheduleAutoCollapse:\(delay):\(generation)"
            case .cancelMouseLeaveCollapse:
                return "cancelMouseLeaveCollapse"
            case let .scheduleMouseLeaveCollapse(delay, generation):
                return "scheduleMouseLeaveCollapse:\(delay):\(generation)"
            case let .collapsePanel(reason):
                return "collapsePanel:\(reason.rawValue)"
            case .requestKeyboardFocus:
                return "requestKeyboardFocus"
            case .releaseKeyboardFocus:
                return "releaseKeyboardFocus"
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
    }
}
