public struct AppShellLaunchRequest: Codable, Equatable, Sendable {
    public let context: AppLaunchContext
    public let target: ScreenTarget
    public let placement: DisplayPlacementPlan
    public let menuSnapshot: AppMenuSnapshot

    public init(
        context: AppLaunchContext,
        target: ScreenTarget,
        placement: DisplayPlacementPlan,
        menuSnapshot: AppMenuSnapshot
    ) {
        self.context = context
        self.target = target
        self.placement = placement
        self.menuSnapshot = menuSnapshot
    }
}

public struct AppShellState: Codable, Equatable, Sendable {
    public let lifecycleState: AppLifecycleState
    public let runtimeSnapshot: AppRuntimeCompositionSnapshot
    public let notchWindowState: NotchWindowControllerState
    public let overlayState: OverlayControllerState
    public let menuSnapshot: AppMenuSnapshot

    public init(
        lifecycleState: AppLifecycleState = AppLifecycleState(),
        runtimeSnapshot: AppRuntimeCompositionSnapshot = .defaultAppShell(),
        notchWindowState: NotchWindowControllerState = NotchWindowControllerState(),
        overlayState: OverlayControllerState = OverlayControllerState(),
        menuSnapshot: AppMenuSnapshot = AppMenuSnapshot()
    ) {
        self.lifecycleState = lifecycleState
        self.runtimeSnapshot = runtimeSnapshot
        self.notchWindowState = notchWindowState
        self.overlayState = overlayState
        self.menuSnapshot = menuSnapshot
    }
}

public enum AppShellCommand: Equatable, Sendable {
    case launch(AppShellLaunchRequest)
    case reopen(AppReopenTarget)
    case terminate
    case overlay(OverlayControllerCommand)
    case menu(AppCommand)
    case replacePresentation(NotchPresentationState)
    case replaceMenuSnapshot(AppMenuSnapshot)
    case replacePlacement(DisplayPlacementPlan)
    case runtimeOwnerObserved(AppRuntimeOwner, isRunning: Bool)
}

public enum AppShellAction: Equatable, Sendable {
    case lifecycle(AppLifecycleStep)
    case runtime(AppRuntimeOwnerAction)
    case notchWindow(NotchWindowControllerAction)
    case overlay(OverlayControllerAction)
    case applyMenuSnapshot(AppMenuSnapshot)
    case showIsland
    case openSettings(SettingsDeepLink?)
    case showOnboarding
    case setDockIconVisible(Bool)
    case setLaunchAtLoginEnabled(Bool)
    case checkForUpdates
    case exportDiagnostics
    case quitApplication
    case ignoredMenuCommand(AppCommand)
}

public struct AppShellPlan: Equatable, Sendable {
    public let nextState: AppShellState
    public let actions: [AppShellAction]

    public init(nextState: AppShellState, actions: [AppShellAction]) {
        self.nextState = nextState
        self.actions = actions
    }
}

public struct AppShellModel: Sendable {
    public let lifecycleCoordinator: AppLifecycleCoordinator
    public let runtimeComposition: AppRuntimeComposition
    public let notchWindowController: NotchWindowControllerModel
    public let overlayController: OverlayControllerModel
    public let menuController: AppMenuController

    public init(
        lifecycleCoordinator: AppLifecycleCoordinator = AppLifecycleCoordinator(),
        runtimeComposition: AppRuntimeComposition = AppRuntimeComposition(),
        notchWindowController: NotchWindowControllerModel = NotchWindowControllerModel(),
        overlayController: OverlayControllerModel = OverlayControllerModel(),
        menuController: AppMenuController = AppMenuController()
    ) {
        self.lifecycleCoordinator = lifecycleCoordinator
        self.runtimeComposition = runtimeComposition
        self.notchWindowController = notchWindowController
        self.overlayController = overlayController
        self.menuController = menuController
    }

    public func plan(_ command: AppShellCommand, from state: AppShellState) -> AppShellPlan {
        switch command {
        case let .launch(request):
            return launch(request, from: state)
        case let .reopen(target):
            return reopen(target, from: state)
        case .terminate:
            return terminate(from: state)
        case let .overlay(command):
            return forwardOverlay(command, from: state)
        case let .menu(command):
            return routeMenu(command, from: state)
        case let .replacePresentation(presentation):
            return forwardOverlay(.replacePresentation(presentation), from: state)
        case let .replaceMenuSnapshot(snapshot):
            return replaceMenuSnapshot(snapshot, from: state)
        case let .replacePlacement(placement):
            return replacePlacement(placement, from: state)
        case let .runtimeOwnerObserved(owner, isRunning):
            let runtimePlan = runtimeComposition.plan(
                isRunning ? .markRunning(owner) : .markStopped(owner),
                from: state.runtimeSnapshot
            )
            return AppShellPlan(
                nextState: replacing(state, runtimeSnapshot: runtimePlan.nextSnapshot),
                actions: []
            )
        }
    }

    private func launch(_ request: AppShellLaunchRequest, from state: AppShellState) -> AppShellPlan {
        let lifecyclePlan = lifecycleCoordinator.plan(.launch(context: request.context), from: state.lifecycleState)
        let runtimePlan = runtimeComposition.plan(.startAll, from: state.runtimeSnapshot)
        let windowPlan = notchWindowController.plan(
            .create(target: request.target, placement: request.placement),
            from: state.notchWindowState
        )
        let overlayPlan = overlayController.plan(
            .replaceMenuSnapshot(request.menuSnapshot),
            from: state.overlayState
        )

        var actions = lifecyclePlan.steps.map(AppShellAction.lifecycle)
        actions.append(contentsOf: runtimePlan.actions.map(AppShellAction.runtime))
        actions.append(contentsOf: windowPlan.actions.map(AppShellAction.notchWindow))
        actions.append(.applyMenuSnapshot(request.menuSnapshot))
        actions.append(contentsOf: routeActions(for: lifecyclePlan.nextState))

        return AppShellPlan(
            nextState: AppShellState(
                lifecycleState: lifecyclePlan.nextState,
                runtimeSnapshot: runtimePlan.nextSnapshot,
                notchWindowState: windowPlan.nextState,
                overlayState: overlayPlan.nextState,
                menuSnapshot: request.menuSnapshot
            ),
            actions: actions
        )
    }

    private func reopen(_ target: AppReopenTarget, from state: AppShellState) -> AppShellPlan {
        let lifecyclePlan = lifecycleCoordinator.plan(.reopen(target: target), from: state.lifecycleState)
        var actions = lifecyclePlan.steps.map(AppShellAction.lifecycle)
        actions.append(contentsOf: routeActions(for: lifecyclePlan.nextState))

        return AppShellPlan(
            nextState: replacing(state, lifecycleState: lifecyclePlan.nextState),
            actions: actions
        )
    }

    private func terminate(from state: AppShellState) -> AppShellPlan {
        let lifecyclePlan = lifecycleCoordinator.plan(.terminate, from: state.lifecycleState)
        let windowPlan = notchWindowController.plan(.teardown, from: state.notchWindowState)
        let runtimePlan = runtimeComposition.plan(.stopAll, from: state.runtimeSnapshot)

        var actions = lifecyclePlan.steps.map(AppShellAction.lifecycle)
        actions.append(contentsOf: windowPlan.actions.map(AppShellAction.notchWindow))
        actions.append(contentsOf: runtimePlan.actions.map(AppShellAction.runtime))

        return AppShellPlan(
            nextState: AppShellState(
                lifecycleState: lifecyclePlan.nextState,
                runtimeSnapshot: runtimePlan.nextSnapshot,
                notchWindowState: windowPlan.nextState,
                overlayState: state.overlayState,
                menuSnapshot: state.menuSnapshot
            ),
            actions: actions
        )
    }

    private func forwardOverlay(_ command: OverlayControllerCommand, from state: AppShellState) -> AppShellPlan {
        let overlayPlan = overlayController.plan(command, from: state.overlayState)
        return AppShellPlan(
            nextState: replacing(state, overlayState: overlayPlan.nextState),
            actions: overlayPlan.actions.map(AppShellAction.overlay)
        )
    }

    private func routeMenu(_ command: AppCommand, from state: AppShellState) -> AppShellPlan {
        let menuPlan = menuController.plan(command, from: state.menuSnapshot)
        guard let routedCommand = menuPlan.routedCommand else {
            return AppShellPlan(nextState: state, actions: [.ignoredMenuCommand(command)])
        }

        let menuSyncedOverlay = overlayController.plan(
            .replaceMenuSnapshot(menuPlan.nextSnapshot),
            from: state.overlayState
        ).nextState
        let overlayPlan = overlayController.plan(.appCommand(routedCommand), from: menuSyncedOverlay)

        var actions = overlayPlan.actions.map(AppShellAction.overlay)
        actions.append(contentsOf: routeActions(for: routedCommand, snapshot: menuPlan.nextSnapshot))

        return AppShellPlan(
            nextState: AppShellState(
                lifecycleState: state.lifecycleState,
                runtimeSnapshot: state.runtimeSnapshot,
                notchWindowState: state.notchWindowState,
                overlayState: overlayPlan.nextState,
                menuSnapshot: menuPlan.nextSnapshot
            ),
            actions: actions
        )
    }

    private func replaceMenuSnapshot(_ snapshot: AppMenuSnapshot, from state: AppShellState) -> AppShellPlan {
        let overlayPlan = overlayController.plan(.replaceMenuSnapshot(snapshot), from: state.overlayState)
        return AppShellPlan(
            nextState: AppShellState(
                lifecycleState: state.lifecycleState,
                runtimeSnapshot: state.runtimeSnapshot,
                notchWindowState: state.notchWindowState,
                overlayState: overlayPlan.nextState,
                menuSnapshot: snapshot
            ),
            actions: [.applyMenuSnapshot(snapshot)]
        )
    }

    private func replacePlacement(_ placement: DisplayPlacementPlan, from state: AppShellState) -> AppShellPlan {
        let windowPlan = notchWindowController.plan(.applyPlacement(placement), from: state.notchWindowState)
        let overlayPlan = overlayController.plan(.panelPlacementChanged(placement), from: state.overlayState)

        var actions = windowPlan.actions.map(AppShellAction.notchWindow)
        actions.append(contentsOf: overlayPlan.actions.map(AppShellAction.overlay))

        return AppShellPlan(
            nextState: AppShellState(
                lifecycleState: state.lifecycleState,
                runtimeSnapshot: state.runtimeSnapshot,
                notchWindowState: windowPlan.nextState,
                overlayState: overlayPlan.nextState,
                menuSnapshot: state.menuSnapshot
            ),
            actions: actions
        )
    }

    private func routeActions(for lifecycleState: AppLifecycleState) -> [AppShellAction] {
        switch lifecycleState.route {
        case .none:
            return []
        case .island:
            return [.showIsland]
        case .settings:
            return [.openSettings(lifecycleState.pendingSettingsDeepLink)]
        case .onboarding:
            return [.showOnboarding]
        }
    }

    private func routeActions(for command: AppCommand, snapshot: AppMenuSnapshot) -> [AppShellAction] {
        switch command {
        case .openSettings:
            return [.openSettings(nil)]
        case .checkForUpdates:
            return [.checkForUpdates]
        case .exportDiagnostics:
            return [.exportDiagnostics]
        case .toggleDockIcon:
            return [.setDockIconVisible(snapshot.dockIconVisible)]
        case .toggleLaunchAtLogin:
            return [.setLaunchAtLoginEnabled(snapshot.launchAtLoginEnabled)]
        case .quit:
            return [.quitApplication]
        case .selectScreenMode:
            return []
        }
    }

    private func replacing(
        _ state: AppShellState,
        lifecycleState: AppLifecycleState? = nil,
        runtimeSnapshot: AppRuntimeCompositionSnapshot? = nil,
        overlayState: OverlayControllerState? = nil
    ) -> AppShellState {
        AppShellState(
            lifecycleState: lifecycleState ?? state.lifecycleState,
            runtimeSnapshot: runtimeSnapshot ?? state.runtimeSnapshot,
            notchWindowState: state.notchWindowState,
            overlayState: overlayState ?? state.overlayState,
            menuSnapshot: state.menuSnapshot
        )
    }
}
