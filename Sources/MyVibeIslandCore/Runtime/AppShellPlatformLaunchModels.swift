public enum AppShellPlatformLaunchIntent: Equatable, Sendable {
    case lifecycle(AppLifecycleStep)
    case startRuntimeOwner(AppRuntimeOwner)
    case stopRuntimeOwner(AppRuntimeOwner)
    case createNotchPanel
    case installNotchEventMonitors
    case removeNotchEventMonitors
    case applyTargetScreen(String)
    case applyNotchPlacement(DisplayPlacementPlan)
    case showNotchPanel
    case hideNotchPanel
    case closeNotchPanel
    case overlay(OverlayControllerAction)
    case applyStatusItemMenu(StatusItemMenuSnapshot)
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

public struct AppShellPlatformLaunchSummary: Equatable, Sendable {
    public let intentCount: Int
    public let lifecycleIntentCount: Int
    public let runtimeStartIntentCount: Int
    public let notchWindowIntentCount: Int
    public let statusItemMenuEntryCount: Int
    public let routeIntentCount: Int

    public init(
        intentCount: Int,
        lifecycleIntentCount: Int,
        runtimeStartIntentCount: Int,
        notchWindowIntentCount: Int,
        statusItemMenuEntryCount: Int,
        routeIntentCount: Int
    ) {
        self.intentCount = intentCount
        self.lifecycleIntentCount = lifecycleIntentCount
        self.runtimeStartIntentCount = runtimeStartIntentCount
        self.notchWindowIntentCount = notchWindowIntentCount
        self.statusItemMenuEntryCount = statusItemMenuEntryCount
        self.routeIntentCount = routeIntentCount
    }

    public var intentGroupDescription: String {
        var groups: [String] = []
        if lifecycleIntentCount > 0 {
            groups.append("lifecycle")
        }
        if runtimeStartIntentCount > 0 {
            groups.append("runtime")
        }
        if notchWindowIntentCount > 0 {
            groups.append("notch")
        }
        if statusItemMenuEntryCount > 0 {
            groups.append("statusMenu")
        }
        if routeIntentCount > 0 {
            groups.append("route")
        }
        return groups.isEmpty ? "none" : groups.joined(separator: ", ")
    }
}

public struct AppShellPlatformLaunchPlan: Equatable, Sendable {
    public let launchPlan: AppShellLaunchBootstrapPlan
    public let intents: [AppShellPlatformLaunchIntent]

    public init(
        launchPlan: AppShellLaunchBootstrapPlan,
        intents: [AppShellPlatformLaunchIntent]
    ) {
        self.launchPlan = launchPlan
        self.intents = intents
    }

    public var summary: AppShellPlatformLaunchSummary {
        AppShellPlatformLaunchSummary(
            intentCount: intents.count,
            lifecycleIntentCount: intents.filter(\.isLifecycle).count,
            runtimeStartIntentCount: intents.filter(\.isRuntimeStart).count,
            notchWindowIntentCount: intents.filter(\.isNotchWindow).count,
            statusItemMenuEntryCount: launchPlan.statusItemMenu.entries.count,
            routeIntentCount: intents.filter(\.isRoute).count
        )
    }
}

public struct AppShellPlatformLaunchPlanner: Sendable {
    public init() {}

    public func makePlan(from launchPlan: AppShellLaunchBootstrapPlan) -> AppShellPlatformLaunchPlan {
        AppShellPlatformLaunchPlan(
            launchPlan: launchPlan,
            intents: makeIntents(
                from: launchPlan.coordinatorPlan.actions,
                statusItemMenu: launchPlan.statusItemMenu
            )
        )
    }

    public func makeIntents(
        from actions: [AppShellAction]
    ) -> [AppShellPlatformLaunchIntent] {
        makeIntents(from: actions, statusItemMenu: nil)
    }

    private func makeIntents(
        from actions: [AppShellAction],
        statusItemMenu: StatusItemMenuSnapshot?
    ) -> [AppShellPlatformLaunchIntent] {
        actions.flatMap { intent(for: $0, statusItemMenu: statusItemMenu) }
    }

    private func intent(
        for action: AppShellAction,
        statusItemMenu: StatusItemMenuSnapshot?
    ) -> [AppShellPlatformLaunchIntent] {
        switch action {
        case let .lifecycle(step):
            return [.lifecycle(step)]
        case let .runtime(ownerAction):
            switch ownerAction.kind {
            case .start:
                return [.startRuntimeOwner(ownerAction.owner)]
            case .stop:
                return [.stopRuntimeOwner(ownerAction.owner)]
            }
        case let .notchWindow(action):
            return [intent(for: action)]
        case let .overlay(action):
            return [.overlay(action)]
        case .applyMenuSnapshot:
            guard let statusItemMenu else {
                return []
            }
            return [.applyStatusItemMenu(statusItemMenu)]
        case .showIsland:
            return [.showIsland]
        case let .openSettings(link):
            return [.openSettings(link)]
        case .showOnboarding:
            return [.showOnboarding]
        case let .setDockIconVisible(isVisible):
            return [.setDockIconVisible(isVisible)]
        case let .setLaunchAtLoginEnabled(isEnabled):
            return [.setLaunchAtLoginEnabled(isEnabled)]
        case .checkForUpdates:
            return [.checkForUpdates]
        case .exportDiagnostics:
            return [.exportDiagnostics]
        case .quitApplication:
            return [.quitApplication]
        case let .ignoredMenuCommand(command):
            return [.ignoredMenuCommand(command)]
        }
    }

    private func intent(for action: NotchWindowControllerAction) -> AppShellPlatformLaunchIntent {
        switch action {
        case .createPanel:
            return .createNotchPanel
        case .installEventMonitors:
            return .installNotchEventMonitors
        case .removeEventMonitors:
            return .removeNotchEventMonitors
        case let .applyTargetScreen(identifier):
            return .applyTargetScreen(identifier)
        case let .applyPlacement(placement):
            return .applyNotchPlacement(placement)
        case .showPanel:
            return .showNotchPanel
        case .hidePanel:
            return .hideNotchPanel
        case .closePanel:
            return .closeNotchPanel
        }
    }
}

private extension AppShellPlatformLaunchIntent {
    var isLifecycle: Bool {
        if case .lifecycle = self {
            return true
        }
        return false
    }

    var isRuntimeStart: Bool {
        if case .startRuntimeOwner = self {
            return true
        }
        return false
    }

    var isNotchWindow: Bool {
        switch self {
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

    var isRoute: Bool {
        switch self {
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
}
