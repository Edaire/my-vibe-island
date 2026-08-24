import MyVibeIslandCore

public struct MyVibeIslandAppKitPlatformIntentFailure: Equatable {
    public let intent: AppShellPlatformLaunchIntent
    public let reason: String

    public init(intent: AppShellPlatformLaunchIntent, reason: String) {
        self.intent = intent
        self.reason = reason
    }
}

public struct MyVibeIslandAppKitPlatformIntentExecutionResult: Equatable {
    public let executedIntents: [AppShellPlatformLaunchIntent]
    public let failedIntents: [MyVibeIslandAppKitPlatformIntentFailure]
    public let runtimeOwnerResults: [MyVibeIslandAppKitRuntimeOwnerResult]

    public init(
        executedIntents: [AppShellPlatformLaunchIntent],
        failedIntents: [MyVibeIslandAppKitPlatformIntentFailure] = [],
        runtimeOwnerResults: [MyVibeIslandAppKitRuntimeOwnerResult] = []
    ) {
        self.executedIntents = executedIntents
        self.failedIntents = failedIntents
        self.runtimeOwnerResults = runtimeOwnerResults
    }
}

public struct MyVibeIslandAppKitPlatformIntentExecutor {
    public let applyStatusItemMenu: @MainActor (StatusItemMenuSnapshot) -> Void
    public let applyLifecycleStep: @MainActor (AppLifecycleStep) throws -> Void
    public let startRuntimeOwner: @MainActor (AppRuntimeOwner) -> Void
    public let stopRuntimeOwner: @MainActor (AppRuntimeOwner) -> Void
    public let runtimeOwnerResult: @MainActor (AppRuntimeOwner) -> MyVibeIslandAppKitRuntimeOwnerResult?
    public let createNotchPanel: @MainActor () -> Void
    public let installNotchEventMonitors: @MainActor () -> Void
    public let removeNotchEventMonitors: @MainActor () -> Void
    public let applyTargetScreen: @MainActor (String) -> Void
    public let applyNotchPlacement: @MainActor (DisplayPlacementPlan) -> Void
    public let showNotchPanel: @MainActor () -> Void
    public let hideNotchPanel: @MainActor () -> Void
    public let closeNotchPanel: @MainActor () -> Void
    public let showIsland: @MainActor () -> Void
    public let openSettings: @MainActor (SettingsDeepLink?) -> Void
    public let showOnboarding: @MainActor () -> Void
    public let setDockIconVisible: @MainActor (Bool) -> Void
    public let setLaunchAtLoginEnabled: @MainActor (Bool) -> Void
    public let checkForUpdates: @MainActor () -> Void
    public let exportDiagnostics: @MainActor () -> Void
    public let quitApplication: @MainActor () -> Void
    public let ignoreMenuCommand: @MainActor (AppCommand) -> Void
    public let applyOverlayAction: @MainActor (OverlayControllerAction) -> Void

    public init(
        applyStatusItemMenu: @escaping @MainActor (StatusItemMenuSnapshot) -> Void = { _ in },
        applyLifecycleStep: @escaping @MainActor (AppLifecycleStep) throws -> Void = { _ in },
        startRuntimeOwner: @escaping @MainActor (AppRuntimeOwner) -> Void = { _ in },
        stopRuntimeOwner: @escaping @MainActor (AppRuntimeOwner) -> Void = { _ in },
        runtimeOwnerResult: @escaping @MainActor (AppRuntimeOwner) -> MyVibeIslandAppKitRuntimeOwnerResult? = { _ in nil },
        createNotchPanel: @escaping @MainActor () -> Void = {},
        installNotchEventMonitors: @escaping @MainActor () -> Void = {},
        removeNotchEventMonitors: @escaping @MainActor () -> Void = {},
        applyTargetScreen: @escaping @MainActor (String) -> Void = { _ in },
        applyNotchPlacement: @escaping @MainActor (DisplayPlacementPlan) -> Void = { _ in },
        showNotchPanel: @escaping @MainActor () -> Void = {},
        hideNotchPanel: @escaping @MainActor () -> Void = {},
        closeNotchPanel: @escaping @MainActor () -> Void = {},
        showIsland: @escaping @MainActor () -> Void = {},
        openSettings: @escaping @MainActor (SettingsDeepLink?) -> Void = { _ in },
        showOnboarding: @escaping @MainActor () -> Void = {},
        setDockIconVisible: @escaping @MainActor (Bool) -> Void = { _ in },
        setLaunchAtLoginEnabled: @escaping @MainActor (Bool) -> Void = { _ in },
        checkForUpdates: @escaping @MainActor () -> Void = {},
        exportDiagnostics: @escaping @MainActor () -> Void = {},
        quitApplication: @escaping @MainActor () -> Void = {},
        ignoreMenuCommand: @escaping @MainActor (AppCommand) -> Void = { _ in },
        applyOverlayAction: @escaping @MainActor (OverlayControllerAction) -> Void = { _ in }
    ) {
        self.applyStatusItemMenu = applyStatusItemMenu
        self.applyLifecycleStep = applyLifecycleStep
        self.startRuntimeOwner = startRuntimeOwner
        self.stopRuntimeOwner = stopRuntimeOwner
        self.runtimeOwnerResult = runtimeOwnerResult
        self.createNotchPanel = createNotchPanel
        self.installNotchEventMonitors = installNotchEventMonitors
        self.removeNotchEventMonitors = removeNotchEventMonitors
        self.applyTargetScreen = applyTargetScreen
        self.applyNotchPlacement = applyNotchPlacement
        self.showNotchPanel = showNotchPanel
        self.hideNotchPanel = hideNotchPanel
        self.closeNotchPanel = closeNotchPanel
        self.showIsland = showIsland
        self.openSettings = openSettings
        self.showOnboarding = showOnboarding
        self.setDockIconVisible = setDockIconVisible
        self.setLaunchAtLoginEnabled = setLaunchAtLoginEnabled
        self.checkForUpdates = checkForUpdates
        self.exportDiagnostics = exportDiagnostics
        self.quitApplication = quitApplication
        self.ignoreMenuCommand = ignoreMenuCommand
        self.applyOverlayAction = applyOverlayAction
    }

    @MainActor
    public func execute(
        _ intents: [AppShellPlatformLaunchIntent]
    ) -> MyVibeIslandAppKitPlatformIntentExecutionResult {
        var executedIntents: [AppShellPlatformLaunchIntent] = []
        var failedIntents: [MyVibeIslandAppKitPlatformIntentFailure] = []
        var runtimeOwnerResults: [MyVibeIslandAppKitRuntimeOwnerResult] = []

        for intent in intents {
            switch intent {
            case let .lifecycle(step):
                do {
                    try applyLifecycleStep(step)
                    executedIntents.append(intent)
                } catch {
                    failedIntents.append(MyVibeIslandAppKitPlatformIntentFailure(
                        intent: intent,
                        reason: String(describing: type(of: error))
                    ))
                }
            case let .applyStatusItemMenu(snapshot):
                applyStatusItemMenu(snapshot)
                executedIntents.append(intent)
            case let .startRuntimeOwner(owner):
                startRuntimeOwner(owner)
                executedIntents.append(intent)
                if let result = runtimeOwnerResult(owner) { runtimeOwnerResults.append(result) }
            case let .stopRuntimeOwner(owner):
                stopRuntimeOwner(owner)
                executedIntents.append(intent)
                if let result = runtimeOwnerResult(owner) { runtimeOwnerResults.append(result) }
            case .createNotchPanel:
                createNotchPanel()
                executedIntents.append(intent)
            case .installNotchEventMonitors:
                installNotchEventMonitors()
                executedIntents.append(intent)
            case .removeNotchEventMonitors:
                removeNotchEventMonitors()
                executedIntents.append(intent)
            case let .applyTargetScreen(identifier):
                applyTargetScreen(identifier)
                executedIntents.append(intent)
            case let .applyNotchPlacement(placement):
                applyNotchPlacement(placement)
                executedIntents.append(intent)
            case .showNotchPanel:
                showNotchPanel()
                executedIntents.append(intent)
            case .hideNotchPanel:
                hideNotchPanel()
                executedIntents.append(intent)
            case .closeNotchPanel:
                closeNotchPanel()
                executedIntents.append(intent)
            case .showIsland:
                showIsland()
                executedIntents.append(intent)
            case let .openSettings(link):
                openSettings(link)
                executedIntents.append(intent)
            case .showOnboarding:
                showOnboarding()
                executedIntents.append(intent)
            case let .setDockIconVisible(isVisible):
                setDockIconVisible(isVisible)
                executedIntents.append(intent)
            case let .setLaunchAtLoginEnabled(isEnabled):
                setLaunchAtLoginEnabled(isEnabled)
                executedIntents.append(intent)
            case .checkForUpdates:
                checkForUpdates()
                executedIntents.append(intent)
            case .exportDiagnostics:
                exportDiagnostics()
                executedIntents.append(intent)
            case .quitApplication:
                quitApplication()
                executedIntents.append(intent)
            case let .ignoredMenuCommand(command):
                ignoreMenuCommand(command)
                executedIntents.append(intent)
            case let .overlay(action):
                applyOverlayAction(action)
                executedIntents.append(intent)
            }
        }

        return MyVibeIslandAppKitPlatformIntentExecutionResult(
            executedIntents: executedIntents,
            failedIntents: failedIntents,
            runtimeOwnerResults: runtimeOwnerResults
        )
    }
}
