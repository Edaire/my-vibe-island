public struct AppShellLaunchConfiguration: Codable, Equatable, Sendable {
    public let launchContext: AppLaunchContext
    public let target: ScreenTarget
    public let placementInput: DisplayPlacementInput
    public let menuSnapshot: AppMenuSnapshot

    public init(
        launchContext: AppLaunchContext = AppLaunchContext(),
        target: ScreenTarget = ScreenTarget(
            identifier: "main",
            displayName: "Built-in Display",
            isBuiltIn: true,
            isMain: true
        ),
        placementInput: DisplayPlacementInput = DisplayPlacementInput(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
            closedSize: OriginalIslandGeometryResolver.panelSize,
            expandedSize: OriginalIslandGeometryResolver.panelSize
        ),
        menuSnapshot: AppMenuSnapshot = AppMenuSnapshot(
            enabledCommands: [
                .openSettings,
                .checkForUpdates,
                .toggleDockIcon,
                .toggleLaunchAtLogin,
                .selectScreenMode(.builtInNotchDisplay),
                .selectScreenMode(.mainDisplay),
                .selectScreenMode(.followKeyboardFocus),
                .selectScreenMode(.manualDisplay),
                .quit
            ]
        )
    ) {
        self.launchContext = launchContext
        self.target = target
        self.placementInput = placementInput
        self.menuSnapshot = menuSnapshot
    }
}

public struct AppShellLaunchPlanSummary: Equatable, Sendable {
    public let targetDisplayName: String
    public let route: AppLifecycleRoute
    public let runtimeOwnerStartCount: Int
    public let actionCount: Int
    public let statusItemMenuEntryCount: Int
    public let closedFrame: DisplayFrame

    public init(
        targetDisplayName: String,
        route: AppLifecycleRoute,
        runtimeOwnerStartCount: Int,
        actionCount: Int,
        statusItemMenuEntryCount: Int,
        closedFrame: DisplayFrame
    ) {
        self.targetDisplayName = targetDisplayName
        self.route = route
        self.runtimeOwnerStartCount = runtimeOwnerStartCount
        self.actionCount = actionCount
        self.statusItemMenuEntryCount = statusItemMenuEntryCount
        self.closedFrame = closedFrame
    }
}

public struct AppShellLaunchBootstrapPlan: Equatable, Sendable {
    public let request: AppShellLaunchRequest
    public let coordinatorPlan: AppShellCoordinatorPlan
    public let statusItemMenu: StatusItemMenuSnapshot

    public init(
        request: AppShellLaunchRequest,
        coordinatorPlan: AppShellCoordinatorPlan,
        statusItemMenu: StatusItemMenuSnapshot
    ) {
        self.request = request
        self.coordinatorPlan = coordinatorPlan
        self.statusItemMenu = statusItemMenu
    }

    public var runtimeOwnerStartCount: Int {
        coordinatorPlan.actions.filter { action in
            if case let .runtime(ownerAction) = action {
                return ownerAction.kind == .start
            }
            return false
        }.count
    }

    public var summary: AppShellLaunchPlanSummary {
        AppShellLaunchPlanSummary(
            targetDisplayName: request.target.displayName,
            route: coordinatorPlan.nextState.shellState.lifecycleState.route,
            runtimeOwnerStartCount: runtimeOwnerStartCount,
            actionCount: coordinatorPlan.actions.count,
            statusItemMenuEntryCount: statusItemMenu.entries.count,
            closedFrame: request.placement.closedFrame
        )
    }
}

public struct AppShellLaunchBootstrap: Sendable {
    public let configuration: AppShellLaunchConfiguration
    public let placementResolver: DisplayPlacementResolver
    public let coordinator: AppShellCoordinatorModel
    public let menuBuilder: StatusItemMenuBuilder

    public init(
        configuration: AppShellLaunchConfiguration = AppShellLaunchConfiguration(),
        placementResolver: DisplayPlacementResolver = DisplayPlacementResolver(),
        coordinator: AppShellCoordinatorModel = AppShellCoordinatorModel(),
        menuBuilder: StatusItemMenuBuilder = StatusItemMenuBuilder()
    ) {
        self.configuration = configuration
        self.placementResolver = placementResolver
        self.coordinator = coordinator
        self.menuBuilder = menuBuilder
    }

    public func makeLaunchRequest() -> AppShellLaunchRequest {
        AppShellLaunchRequest(
            context: configuration.launchContext,
            target: configuration.target,
            placement: placementResolver.resolve(configuration.placementInput),
            menuSnapshot: configuration.menuSnapshot
        )
    }

    public func buildLaunchPlan() -> AppShellLaunchBootstrapPlan {
        let request = makeLaunchRequest()
        return AppShellLaunchBootstrapPlan(
            request: request,
            coordinatorPlan: coordinator.apply(
                .didFinishLaunching(request),
                from: AppShellCoordinatorState()
            ),
            statusItemMenu: menuBuilder.build(from: request.menuSnapshot, surface: .statusItem)
        )
    }
}
