import AppKit
import CoreGraphics
import MyVibeIslandCore
import MyVibeIslandShared

@MainActor
private func appKitOriginalCompactHostingScreenIdentifier(_ screen: NSScreen) -> String {
    let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    return displayID.map(String.init) ?? screen.localizedName
}

func appKitOriginalCompactHostingScreenSnapshot(
    candidates: [OriginalCompactHostingScreenCandidate],
    mainCandidate: OriginalCompactHostingScreenCandidate?
) -> (candidates: [OriginalCompactHostingScreenCandidate], mainIdentifier: String?) {
    var candidates = candidates
    if let mainCandidate, !candidates.contains(where: { $0.identifier == mainCandidate.identifier }) {
        candidates.append(mainCandidate)
    }
    return (candidates, mainCandidate?.identifier)
}

func appKitOriginalCompactHostingScreenInput(
    safeAreaTopInset: Double,
    frame: NSRect,
    visibleFrame: NSRect,
    auxiliaryTopLeftWidth: Double,
    auxiliaryTopRightWidth: Double
) -> OriginalNSScreenMetricsInput {
    OriginalNSScreenMetricsInput(
        safeAreaTopInset: safeAreaTopInset,
        frameWidth: Double(frame.width),
        auxiliaryTopLeftWidth: auxiliaryTopLeftWidth,
        auxiliaryTopRightWidth: auxiliaryTopRightWidth,
        screenFrame: DisplayFrame(
            x: Double(frame.origin.x),
            y: Double(frame.origin.y),
            width: Double(frame.width),
            height: Double(frame.height)
        ),
        visibleFrame: DisplayFrame(
            x: Double(visibleFrame.origin.x),
            y: Double(visibleFrame.origin.y),
            width: Double(visibleFrame.width),
            height: Double(visibleFrame.height)
        )
    )
}

@MainActor
private func appKitOriginalCompactHostingScreenCandidate(
    _ screen: NSScreen
) -> OriginalCompactHostingScreenCandidate {
    OriginalCompactHostingScreenCandidate(
        identifier: appKitOriginalCompactHostingScreenIdentifier(screen),
        input: appKitOriginalCompactHostingScreenInput(
            safeAreaTopInset: Double(screen.safeAreaInsets.top),
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            auxiliaryTopLeftWidth: Double(screen.auxiliaryTopLeftArea?.width ?? 0),
            auxiliaryTopRightWidth: Double(screen.auxiliaryTopRightArea?.width ?? 0)
        )
    )
}

@MainActor
private func appKitOriginalCompactHostingScreenResolver(
    selectedIdentifier: String?
) -> OriginalNSScreenMetricsInput {
    let mainScreen = NSScreen.main
    let screens = NSScreen.screens
    let snapshot = appKitOriginalCompactHostingScreenSnapshot(
        candidates: screens.map(appKitOriginalCompactHostingScreenCandidate),
        mainCandidate: mainScreen.map(appKitOriginalCompactHostingScreenCandidate)
    )
    return OriginalCompactHostingScreenSelection.resolve(
        candidates: snapshot.candidates,
        selectedIdentifier: selectedIdentifier,
        mainIdentifier: snapshot.mainIdentifier,
        fallback: OriginalNSScreenMetricsInput(
            safeAreaTopInset: 0,
            frameWidth: 0,
            auxiliaryTopLeftWidth: 0,
            auxiliaryTopRightWidth: 0
        )
    )
}

@MainActor
private final class MyVibeIslandAppKitPanelInteractionRouter {
    weak var notchController: MyVibeIslandAppKitNotchViewModelController?
    weak var switcherCoordinator: MyVibeIslandAppKitSwitcherCoordinator?

    func perform(_ command: PanelInteractionCommand) {
        if command == .outsideClick, let switcherCoordinator {
            switcherCoordinator.outsideInteraction()
            return
        }
        performPanel(command)
    }

    func performPanel(_ command: PanelInteractionCommand) {
        notchController?.applyInteractionCommand(command)
    }
}

@MainActor
private final class MyVibeIslandAppKitShortcutLifecycleBridge {
    weak var manager: MyVibeIslandAppKitShortcutManagerController?

    func start() {
        guard let manager else {
            SessionCompletionTraceLog.append(
                stage: "shortcut.lifecycle.start",
                sessionId: nil,
                metadata: ["manager": "missing"]
            )
            return
        }
        let plan = manager.start()
        SessionCompletionTraceLog.append(
            stage: "shortcut.lifecycle.start",
            sessionId: nil,
            metadata: [
                "manager": "bound",
                "action": plan.action.rawValue,
                "registeredIDs": plan.nextState.registeredHotKeyIds.joined(separator: ","),
            ]
        )
    }

    func stop() {
        _ = manager?.stop()
    }
}

@MainActor
public final class MyVibeIslandAppKitPlatformComposition {
    private let panelInteractionRouter: MyVibeIslandAppKitPanelInteractionRouter
    public let runtime: AppRuntime?
    public let localSessionJumpCoordinator: MyVibeIslandAppKitLocalSessionJumpCoordinator?
    public let switcherCoordinator: MyVibeIslandAppKitSwitcherCoordinator
    public let shortcutCoordinatorController: MyVibeIslandAppKitShortcutCoordinatorController
    public let shortcutManagerController: MyVibeIslandAppKitShortcutManagerController
    let switcherEventMonitor: MyVibeIslandAppKitSwitcherEventMonitor
    public let originalUnifiedHostingRenderer: MyVibeIslandAppKitOriginalUnifiedHostingRenderer
    public let statusItemController: MyVibeIslandAppKitStatusItemController
    public let statusItemMenuPresenter: MyVibeIslandAppKitStatusItemMenuPresenter
    public let platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor
    public let overlayController: MyVibeIslandAppKitOverlayController
    public let notchViewModelController: MyVibeIslandAppKitNotchViewModelController
    public let notificationPresentationController: MyVibeIslandAppKitNotificationPresentationController
    public let notificationCoordinatorController: MyVibeIslandAppKitNotificationCoordinatorController
    public let quietSceneMonitor: MyVibeIslandAppKitQuietSceneMonitor
    public let soundOutputDeviceMonitor: MyVibeIslandCoreAudioOutputDeviceMonitor?
    public let usageCoordinatorController: MyVibeIslandAppKitUsageCoordinatorController
    public let soundCoordinatorController: MyVibeIslandAppKitSoundCoordinatorController
    public let soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController
    public let diagnosticExportController: MyVibeIslandAppKitDiagnosticExportController
    public let updateCheckerController: MyVibeIslandAppKitUpdateCheckerController
    public let runtimeOwnerController: MyVibeIslandAppKitRuntimeOwnerController
    public let screenSelectionController: MyVibeIslandAppKitScreenSelectionController
    public let lifecycleController: MyVibeIslandAppKitLifecycleController

    isolated deinit {
        // Composition tests and app relaunch paths can dispose the owner
        // without traversing the normal lifecycle command sequence. Stop
        // every process-backed monitor at the ownership boundary so a stale
        // `log stream` cannot survive into the next runtime.
        quietSceneMonitor.stop()
        soundOutputDeviceMonitor?.stop()
        switcherEventMonitor.stop()
        runtime?.stop()
    }
    public let launchContext: AppLaunchContext
    private var screenParametersMonitor: MyVibeIslandAppKitScreenParametersMonitor?

    public static func production(
        runtime: AppRuntime = AppRuntime.productionRuntime(),
        defaults: UserDefaults = .standard,
        shortcutSettings: ShortcutSettings? = nil,
        makeCarbonHotKeyRuntime: @escaping (@escaping @MainActor (String) -> Void) -> MyVibeIslandAppKitCarbonHotKeyRuntime = {
            MyVibeIslandAppKitCarbonHotKeyRuntime(onHotKey: $0)
        },
        soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController? = nil,
        overlayController: MyVibeIslandAppKitOverlayController? = nil,
        notchPanelController: MyVibeIslandAppKitNotchPanelControlling? = nil,
        quietSceneMonitor: MyVibeIslandAppKitQuietSceneMonitor? = nil,
        automaticExpansionFocusProvider: (@MainActor ([AgentSession]) -> V3AutomaticExpansionFocus)? = nil,
        screenSelectionController: MyVibeIslandAppKitScreenSelectionController? = nil,
        originalCompactHostingScreenResolver: (@MainActor (String?) -> OriginalNSScreenMetricsInput)? = nil,
        onboardingWindowController: MyVibeIslandAppKitOnboardingWindowController? = nil,
        settingsSnapshotProvider: @escaping @MainActor () -> SettingsSnapshot = {
            SettingsStore(fileURL: SettingsStore.defaultFileURL()).loadSnapshot()
        },
        installBundledBridge: @escaping @MainActor () throws -> Void = {
            guard !VibeIslandStateRoot.isStateFixtureEnabled() else { return }
            _ = try MyVibeIslandBundledBridgeInstaller.production().install()
            _ = try MyVibeIslandBundledHookInstaller.production().install()
            _ = try CodexPermissionRequestTimeoutInstaller.production().install()
        },
        versionProvider: @escaping @MainActor () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        }
    ) -> MyVibeIslandAppKitPlatformComposition {
        let persistedSettings = settingsSnapshotProvider()
        let usageSettings = effectiveUsageSettings(
            persistedSettings.usage,
            legacyShowUsagePreference: defaults.object(forKey: "showUsage") as? Bool
        )
        let shortcutSettings = shortcutSettings ?? persistedSettings.shortcuts
        let productionSettingsStore = SettingsStore(fileURL: SettingsStore.defaultFileURL())
        SessionCompletionTraceLog.append(
            stage: "settings.snapshot.load",
            sessionId: nil,
            metadata: [
                "error": productionSettingsStore.lastError.map(String.init(describing:)) ?? "none",
                "enabled": String(shortcutSettings.keyboardShortcutsEnabled),
                "globalIDs": shortcutSettings.globalShortcuts.map(\.id).joined(separator: ","),
                "panelIDs": shortcutSettings.panelShortcuts.map(\.id).joined(separator: ","),
                "switcherIDs": shortcutSettings.switcherShortcuts.map(\.id).joined(separator: ","),
            ]
        )
        let firstLaunchStore = FirstLaunchPreferenceStore(defaults: defaults)
        let whatsNewStore = WhatsNewPreferenceStore(defaults: defaults)
        let screenPreferenceStore = ScreenSelectionPreferenceStore(defaults: defaults)
        let storedScreenPreferences = screenPreferenceStore.load()
        let storedWhatsNewState = whatsNewStore.load()
        let panelInteractionRouter = MyVibeIslandAppKitPanelInteractionRouter()
        let notchPanelController = notchPanelController
            ?? MyVibeIslandAppKitNotchPanelController<NSPanel>(
                performInteraction: panelInteractionRouter.perform
            )
        let soundManagerProvider: @MainActor () -> SoundManager = {
            SoundManager(
                snapshot: SoundPreferencesStore(defaults: defaults).loadManagerSnapshot()
            )
        }
        let soundOutputDeviceMonitor = MyVibeIslandCoreAudioOutputDeviceMonitor.production()
        let screenSelectionController = screenSelectionController
            ?? MyVibeIslandAppKitScreenSelectionController(
                snapshot: ScreenSelectionSnapshot(
                    mode: storedScreenPreferences.mode,
                    manualScreenIdentifier: storedScreenPreferences.selectedScreenIdentifier,
                    switchTipDismissed: storedScreenPreferences.switchTipDismissed
                ),
                applyTargetScreen: { target in
                    notchPanelController.applyTargetScreen(target.identifier)
                }
            )
        screenSelectionController.onSnapshotChange = { snapshot in
            screenPreferenceStore.save(ScreenSelectionPreferences(
                mode: snapshot.mode,
                selectedScreenIdentifier: snapshot.manualScreenIdentifier,
                switchTipDismissed: snapshot.switchTipDismissed
            ))
        }
        screenSelectionController.refreshCurrentScreens()
        let currentVersion = MyVibeIslandAppVersion.resolve(versionProvider())
        let onboardingController = onboardingWindowController ?? MyVibeIslandAppKitOnboardingWindowController.production()
        let onboardingSelectionHandler = onboardingController.onSelection
        onboardingController.onSelection = { selection in
            onboardingSelectionHandler(selection)
            let store = SoundPreferencesStore(defaults: defaults)
            let settings = store.loadManagerSettings()
            store.saveManagerSettings(SoundManagerSettings(
                selectedPackId: settings.selectedPackId,
                isEnabled: selection.playNotificationSounds,
                volume: settings.volume,
                quietHoursEnabled: settings.quietHoursEnabled,
                quietHoursStartMinutes: settings.quietHoursStartMinutes,
                quietHoursEndMinutes: settings.quietHoursEndMinutes
            ))
        }
        onboardingController.onFinish = {
            firstLaunchStore.completeOnboarding(version: FirstLaunchPreferenceStore.currentOnboardingVersion)
        }
        let firstLaunchContext = firstLaunchStore.launchContext(
            currentOnboardingVersion: FirstLaunchPreferenceStore.currentOnboardingVersion
        )
        let storedLaunchContext = AppLaunchContext(
            isFirstLaunch: firstLaunchContext.isFirstLaunch,
            hasPendingOnboarding: firstLaunchContext.hasPendingOnboarding,
            hasPendingUpdateNotes: storedWhatsNewState.pendingVersion != nil
        )
        let shortcutLifecycleBridge = MyVibeIslandAppKitShortcutLifecycleBridge()
        let lifecycleStepExecutor = MyVibeIslandAppKitLifecycleStepExecutor { step in
            switch step {
            case .loadSettings:
                firstLaunchStore.markLaunched()
                let state = whatsNewStore.load()
                let plan = WhatsNewStore().plan(
                    .recordLaunch(currentVersion: currentVersion, rawHTML: nil),
                    from: state
                )
                whatsNewStore.save(plan.nextState)
            case .showIsland:
                break
            case .persistSettingsAndSessions:
                screenPreferenceStore.save(ScreenSelectionPreferences(
                    mode: screenSelectionController.snapshot.mode,
                    selectedScreenIdentifier: screenSelectionController.snapshot.manualScreenIdentifier,
                    switchTipDismissed: screenSelectionController.snapshot.switchTipDismissed
                ))
            case .startRuntimeCoordinators:
                shortcutLifecycleBridge.start()
            case .unregisterShortcuts:
                shortcutLifecycleBridge.stop()
            default:
                break
            }
        }
        let localSessionJumpCoordinator = MyVibeIslandAppKitLocalSessionJumpCoordinator(runtime: runtime)
        let runtimeOwnerController = MyVibeIslandAppKitRuntimeOwnerController(
            startOwner: { owner in
                switch owner {
                case .bridgeServer:
                    try runtime.startBridge()
                case .sessionCoordinator:
                    runtime.startLocalSessionWatchers()
                case .integrationCoordinator:
                    try installBundledBridge()
                default:
                    break
                }
            },
            stopOwner: { owner in
                switch owner {
                case .bridgeServer:
                    runtime.stop()
                case .sessionCoordinator:
                    runtime.stopLocalSessionWatchers()
                default:
                    break
                }
            },
            unavailableOwners: [
                .notchViewModel: "notch view model is owned by AppKit composition",
                .overlayController: "overlay controller is owned by AppKit composition",
                .actionRouter: "action router is owned by AppRuntime",
                .terminalJumpRouter: "terminal jump router is owned by AppRuntime",
                .notificationCoordinator: "notification coordinator is owned by AppKit composition",
                .soundCoordinator: "sound coordinator is owned by AppKit composition",
                .usageCoordinator: "usage coordinator is owned by AppKit composition",
                .diagnosticsCoordinator: "diagnostics coordinator is owned by AppKit composition",
                .settingsStore: "settings store is owned by AppKit composition",
                .onboardingCoordinator: "onboarding coordinator is owned by AppKit composition",
                .appMenuController: "app menu controller is owned by AppKit composition",
                .dockIconController: "dock icon controller is owned by AppKit composition",
                .launchAtLoginService: "launch at login is owned by AppKit composition",
                .updateCoordinator: "updates are not configured in this noncommercial build",
                .screenSelectionCoordinator: "screen selection is owned by AppKit composition",
                .whatsNewStore: "What's New store is owned by AppKit composition"
            ]
        )
        let activeCliTTYProvider = ActiveCliTTYProvider()
        let resolvedAutomaticExpansionFocus = automaticExpansionFocusProvider ?? { sessions in
            V3AutomaticExpansionFocus(
                frontmostBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                activeTTYs: activeCliTTYProvider.activeTTYs(for: sessions)
            )
        }
        let resolvedV3SensoryPolicy: @MainActor (AgentSession) -> V3SensoryPolicy = { session in
            V3SensoryPolicyResolver(
                rules: V3SilenceRulesPreferenceStore(defaults: defaults).load()
            ).resolve(for: session)
        }
        let composition = MyVibeIslandAppKitPlatformComposition(
            runtime: runtime,
            localSessionJumpCoordinator: localSessionJumpCoordinator,
            lifecycleController: MyVibeIslandAppKitLifecycleController(
                lifecycleStepExecutor: lifecycleStepExecutor
            ),
            runtimeOwnerController: runtimeOwnerController,
            screenSelectionController: screenSelectionController,
            originalCompactHostingScreenResolver: originalCompactHostingScreenResolver,
            diagnosticExportController: MyVibeIslandAppKitDiagnosticExportController.production(
                runtime: runtime,
                defaults: defaults
            ),
            updatesConfigured: false,
            onboardingWindowController: onboardingController,
            notchPanelController: notchPanelController,
            overlayController: overlayController,
            initialState: NotchViewModelState(
                localPreferences: NotchLocalUIPreferences(
                    compactMode: defaults.string(forKey: "layoutMode") != "normal"
                ),
                autoExpandOnTaskComplete: persistedSettings.behaviour.autoExpandOnTaskComplete
            ),
            behaviourSettings: persistedSettings.behaviour,
            automaticExpansionFocus: resolvedAutomaticExpansionFocus,
            quietSceneMonitor: quietSceneMonitor,
            usageSettings: usageSettings,
            silenceRulesProvider: {
                SilenceRulesPreferenceStore(defaults: defaults).load()
            },
            v3SensoryPolicyProvider: resolvedV3SensoryPolicy,
            soundOutputDeviceMonitor: soundOutputDeviceMonitor,
            soundManager: soundManagerProvider(),
            soundManagerProvider: soundManagerProvider,
            soundPlaybackController: soundPlaybackController ?? MyVibeIslandAppKitSoundPlaybackController(
                executor: MyVibeIslandAppKitSoundExecutor.production()
            ),
            shortcutSettings: shortcutSettings,
            makeCarbonHotKeyRuntime: makeCarbonHotKeyRuntime,
            selectSession: localSessionJumpCoordinator.selectSession,
            jumpToSession: { _ = localSessionJumpCoordinator.jumpToSession($0) },
            submitActionResolution: { resolution in
                _ = localSessionJumpCoordinator.resolveAction(resolution)
            },
            launchContext: storedLaunchContext,
            persistScreenSelection: { snapshot in
                screenPreferenceStore.save(ScreenSelectionPreferences(
                    mode: snapshot.mode,
                    selectedScreenIdentifier: snapshot.manualScreenIdentifier,
                    switchTipDismissed: snapshot.switchTipDismissed
                ))
            }
        )
        let completionNotificationRouter = MyVibeIslandSessionCompletionNotificationRouter(
            childAgentNotificationTiming: persistedSettings.behaviour.childAgentNotificationTiming,
            completionDwellSeconds: persistedSettings.behaviour.transientRevealDwellSeconds
        )
        runtime.setIslandRuntimeDidChange { [weak composition] snapshot in
            Task { @MainActor in
                guard let composition else { return }
                composition.notchViewModelController.replaceIslandRuntimeSnapshot(snapshot)
                let workspaceBySessionId = Dictionary(
                    uniqueKeysWithValues: snapshot.sessions.map { ($0.id, $0.cwd) }
                )
                for notification in completionNotificationRouter.notifications(for: snapshot) {
                    var deliveredNotification = notification
                    if notification.category == .sessionCompleted,
                       let sessionId = notification.sessionId {
                        let sensoryPolicy = snapshot.sessions.first { $0.id == sessionId }
                            .map(resolvedV3SensoryPolicy) ?? .none
                        guard composition.notchViewModelController.allowsTaskCompletionNotification(
                            sessionId: sessionId,
                            quietSceneActive: composition.quietSceneMonitor.isQuietSceneActive,
                            sensoryPolicy: sensoryPolicy
                        ) else {
                            SessionCompletionTraceLog.append(
                                stage: "completion.notification_suppressed",
                                sessionId: sessionId,
                                metadata: [
                                    "reason": "v3_pre_notification_decision",
                                    "hidePanel": String(sensoryPolicy.hidePanel),
                                    "suppressExpand": String(sensoryPolicy.suppressExpand),
                                ]
                            )
                            continue
                        }
                        if sensoryPolicy.muteSound {
                            deliveredNotification = notification.replacingSoundCategory(nil)
                            SessionCompletionTraceLog.append(
                                stage: "completion.sound_suppressed",
                                sessionId: sessionId,
                                metadata: [
                                    "effect": notification.rootResponseEffect?.rawValue ?? "nil",
                                    "matchedRules": sensoryPolicy.matchedRuleIds.map(String.init).joined(separator: ",")
                                ]
                            )
                        }
                    }
                    _ = composition.notificationCoordinatorController.deliver(
                        deliveredNotification,
                        policyInput: NotificationPolicyInput(
                            category: notification.category,
                            sessionId: notification.sessionId,
                            agent: notification.agent,
                            workspace: notification.sessionId.flatMap { workspaceBySessionId[$0] },
                            dedupeKey: notification.dedupeKey
                        )
                    )
                }
            }
        }
        panelInteractionRouter.notchController = composition.notchViewModelController
        panelInteractionRouter.switcherCoordinator = composition.switcherCoordinator
        shortcutLifecycleBridge.manager = composition.shortcutManagerController
        let screenResolver = originalCompactHostingScreenResolver
            ?? appKitOriginalCompactHostingScreenResolver
        let screenParametersMonitor = MyVibeIslandAppKitScreenParametersMonitor { [weak composition] in
            guard let composition else { return }
            screenSelectionController.refreshCurrentScreens()
            let screen = screenResolver(screenSelectionController.snapshot.target?.identifier)
            guard screen.hasValidDisplayFrames else { return }

            let panelSize = OriginalIslandGeometryResolver.panelSize
            let placement = DisplayPlacementResolver().resolve(DisplayPlacementInput(
                screenFrame: screen.screenFrame,
                safeAreaTopInset: screen.safeAreaTopInset,
                closedSize: panelSize,
                expandedSize: panelSize
            ))
            notchPanelController.applyPlacement(placement)
            composition.notchViewModelController.synchronizePlacement(placement)
            _ = composition.originalUnifiedHostingRenderer.refreshScreen(screen)
            if let geometry = composition.originalUnifiedHostingRenderer.interactionGeometry {
                notchPanelController.applyInteractionGeometry(geometry)
            }
        }
        composition.screenParametersMonitor = screenParametersMonitor
        screenParametersMonitor.start()
        if usageSettings.isUsageDisplayEnabled {
            Task { @MainActor [weak composition] in
                _ = await composition?.usageCoordinatorController.presentationSnapshot(
                    refreshPlanNowSeconds: Int(Date().timeIntervalSince1970)
                )
            }
        }
        return composition
    }

    private static func effectiveUsageSettings(
        _ persistedSettings: UsageSettingsSnapshot,
        legacyShowUsagePreference: Bool?
    ) -> UsageSettingsSnapshot {
        guard persistedSettings.displayStyle == .hidden, legacyShowUsagePreference == true else {
            return persistedSettings
        }

        return UsageSettingsSnapshot(
            preferredProviderId: persistedSettings.preferredProviderId,
            displayStyle: .ringBadge,
            valueMode: persistedSettings.valueMode,
            thresholdPeeksEnabled: persistedSettings.thresholdPeeksEnabled,
            thresholdPercent: persistedSettings.thresholdPercent,
            usageNotificationsEnabled: persistedSettings.usageNotificationsEnabled,
            usageSoundEnabled: persistedSettings.usageSoundEnabled,
            labsProviderIds: persistedSettings.labsProviderIds
        )
    }

    public init(
        runtime: AppRuntime? = nil,
        localSessionJumpCoordinator: MyVibeIslandAppKitLocalSessionJumpCoordinator? = nil,
        statusItemController: MyVibeIslandAppKitStatusItemController = MyVibeIslandAppKitStatusItemController(),
        shellCommandDispatcher: MyVibeIslandAppKitShellCommandDispatcher? = nil,
        lifecycleController: MyVibeIslandAppKitLifecycleController = MyVibeIslandAppKitLifecycleController(),
        runtimeOwnerController: MyVibeIslandAppKitRuntimeOwnerController = MyVibeIslandAppKitRuntimeOwnerController(),
        systemCommandController: MyVibeIslandAppKitSystemCommandController? = nil,
        dockIconController: MyVibeIslandAppKitDockIconController = MyVibeIslandAppKitDockIconController(),
        launchAtLoginController: MyVibeIslandAppKitLaunchAtLoginController = MyVibeIslandAppKitLaunchAtLoginController(),
        screenSelectionController: MyVibeIslandAppKitScreenSelectionController? = nil,
        originalCompactHostingScreenResolver: (@MainActor (String?) -> OriginalNSScreenMetricsInput)? = nil,
        updateWindowController: MyVibeIslandAppKitUpdateWindowController = MyVibeIslandAppKitUpdateWindowController(),
        updateCheckerController: MyVibeIslandAppKitUpdateCheckerController? = nil,
        diagnosticExportController: MyVibeIslandAppKitDiagnosticExportController = MyVibeIslandAppKitDiagnosticExportController(),
        updatesConfigured: Bool = true,
        settingsWindowController: MyVibeIslandAppKitSettingsWindowController = MyVibeIslandAppKitSettingsWindowController(),
        onboardingWindowController: MyVibeIslandAppKitOnboardingWindowController = MyVibeIslandAppKitOnboardingWindowController(),
        routeController: MyVibeIslandAppKitRouteController? = nil,
        notchPanelController: MyVibeIslandAppKitNotchPanelControlling = MyVibeIslandAppKitNotchPanelController<NSPanel>(),
        overlayController: MyVibeIslandAppKitOverlayController? = nil,
        initialState: NotchViewModelState = NotchViewModelState(),
        behaviourSettings: BehaviourSettings = BehaviourSettings(),
        automaticExpansionFocus: @escaping @MainActor ([AgentSession]) -> V3AutomaticExpansionFocus = { _ in
            V3AutomaticExpansionFocus(frontmostBundleId: nil, activeTTYs: [])
        },
        notificationPresentationController: MyVibeIslandAppKitNotificationPresentationController? = nil,
        notificationCoordinatorController: MyVibeIslandAppKitNotificationCoordinatorController? = nil,
        quietSceneMonitor: MyVibeIslandAppKitQuietSceneMonitor? = nil,
        usageCoordinatorController: MyVibeIslandAppKitUsageCoordinatorController? = nil,
        usageSettings: UsageSettingsSnapshot = UsageSettingsSnapshot(),
        silenceRulesProvider: @escaping @MainActor () -> SilenceRulesSnapshot = { SilenceRulesSnapshot() },
        v3SensoryPolicyProvider: @escaping @MainActor (AgentSession) -> V3SensoryPolicy = { _ in .none },
        soundOutputDeviceMonitor: MyVibeIslandCoreAudioOutputDeviceMonitor? = nil,
        soundCoordinatorController: MyVibeIslandAppKitSoundCoordinatorController? = nil,
        soundManager: SoundManager = SoundManager(),
        soundManagerProvider: (@MainActor () -> SoundManager)? = nil,
        soundPlaybackController: MyVibeIslandAppKitSoundPlaybackController = MyVibeIslandAppKitSoundPlaybackController(),
        shortcutSettings: ShortcutSettings = ShortcutSettings(),
        makeCarbonHotKeyRuntime: @escaping (@escaping @MainActor (String) -> Void) -> MyVibeIslandAppKitCarbonHotKeyRuntime = {
            MyVibeIslandAppKitCarbonHotKeyRuntime(onHotKey: $0)
        },
        notificationSoundMinuteOfDay: @escaping @MainActor () -> Int = { 12 * 60 },
        selectSession: @escaping @MainActor (String) -> Void = { _ in },
        jumpToSession: @escaping @MainActor (String) -> Void = { _ in },
        resolveAction: @escaping @MainActor (String, String) -> Void = { _, _ in },
        answerQuestion: @escaping @MainActor (String, String) -> Void = { _, _ in },
        submitActionResolution: @escaping @MainActor (ActionResolution) -> Void = { _ in },
        dispatchMenuCommand: (@MainActor (AppCommand) -> Void)? = nil,
        launchContext: AppLaunchContext = AppLaunchContext(),
        persistScreenSelection: @escaping @MainActor (ScreenSelectionSnapshot) -> Void = { _ in }
    ) {
        self.runtime = runtime
        self.localSessionJumpCoordinator = localSessionJumpCoordinator
        let quietSceneMonitor = quietSceneMonitor ?? MyVibeIslandAppKitQuietSceneMonitor()
        let switcherPanelInteractionRouter = MyVibeIslandAppKitPanelInteractionRouter()
        self.panelInteractionRouter = switcherPanelInteractionRouter
        let soundManagerProvider = soundManagerProvider ?? { soundManager }
        let screenSelectionController = screenSelectionController ?? MyVibeIslandAppKitScreenSelectionController(
            applyTargetScreen: { target in
                notchPanelController.applyTargetScreen(target.identifier)
            }
        )
        let originalCompactHostingScreenResolver = originalCompactHostingScreenResolver
            ?? appKitOriginalCompactHostingScreenResolver
        let routeController = routeController ?? MyVibeIslandAppKitRouteController(
            settingsWindowController: settingsWindowController,
            onboardingWindowController: onboardingWindowController
        )
        let routeOverlayAction: @MainActor (OverlayRoutedAction) -> Void = { action in
            switch action {
            case .openSettings:
                if let shellCommandDispatcher {
                    _ = shellCommandDispatcher.dispatchOverlayAction(action)
                } else {
                    routeController.openSettings(nil)
                }
            case let .appCommand(command):
                if let shellCommandDispatcher {
                    _ = shellCommandDispatcher.dispatchOverlayAction(action)
                } else {
                    if let dispatchMenuCommand {
                        dispatchMenuCommand(command)
                    } else {
                        switch command {
                        case .openSettings:
                            routeController.openSettings(nil)
                        case .checkForUpdates:
                            updateWindowController.checkForUpdates()
                        case .exportDiagnostics:
                            diagnosticExportController.exportDiagnostics()
                        case .toggleDockIcon:
                            dockIconController.setVisible(!dockIconController.state.preferredDockVisible)
                        case .toggleLaunchAtLogin:
                            launchAtLoginController.setEnabled(!launchAtLoginController.state.desiredEnabled)
                        case let .selectScreenMode(mode):
                            screenSelectionController.selectMode(mode)
                            persistScreenSelection(screenSelectionController.snapshot)
                        case .quit:
                            routeController.quit()
                        }
                    }
                }
            case let .selectSession(sessionId):
                if let shellCommandDispatcher {
                    _ = shellCommandDispatcher.dispatchOverlayAction(action)
                } else {
                    selectSession(sessionId)
                }
            case let .jumpToSession(sessionId):
                if let shellCommandDispatcher {
                    _ = shellCommandDispatcher.dispatchOverlayAction(action)
                } else {
                    jumpToSession(sessionId)
                }
            case let .resolveAction(requestId, sessionId):
                if let shellCommandDispatcher {
                    _ = shellCommandDispatcher.dispatchOverlayAction(action)
                } else {
                    if let localSessionJumpCoordinator {
                        _ = localSessionJumpCoordinator.resolveAction(requestId: requestId, sessionId: sessionId)
                    } else {
                        resolveAction(requestId, sessionId)
                    }
                }
            case let .answerQuestion(requestId, sessionId):
                if let shellCommandDispatcher {
                    _ = shellCommandDispatcher.dispatchOverlayAction(action)
                } else {
                    if let localSessionJumpCoordinator {
                        _ = localSessionJumpCoordinator.resolveAnswer(requestId: requestId, sessionId: sessionId)
                    } else {
                        answerQuestion(requestId, sessionId)
                    }
                }
            case let .submitActionResolution(resolution):
                if let shellCommandDispatcher {
                    _ = shellCommandDispatcher.dispatchOverlayAction(action)
                } else {
                    submitActionResolution(resolution)
                }
            }
        }
        let switcherCoordinator = MyVibeIslandAppKitSwitcherCoordinator(
            jumpToSession: { sessionID in
                if let localSessionJumpCoordinator {
                    _ = localSessionJumpCoordinator.jumpToSession(sessionID)
                } else {
                    jumpToSession(sessionID)
                }
            },
            routePanelInteraction: switcherPanelInteractionRouter.performPanel
        )
        switcherPanelInteractionRouter.switcherCoordinator = switcherCoordinator
        let shortcutCoordinatorController = MyVibeIslandAppKitShortcutCoordinatorController(
            settings: shortcutSettings,
            onModifierRelease: switcherCoordinator.modifierReleased
        )
        let switcherEventMonitor = MyVibeIslandAppKitSwitcherEventMonitor(
            coordinator: switcherCoordinator,
            modifierReleased: shortcutCoordinatorController.handleModifierReleaseEvent,
            modifierFlags: { KeyboardShortcutManager.shared.modifierKey.eventModifierFlags },
            interactionFrame: { notchPanelController.activeInteractionFrame }
        )
        let routeShortcutAction: @MainActor (ShortcutAction) -> Void = { action in
            switch action {
            case .toggleIsland:
                if switcherCoordinator.state.isOpen {
                    switcherCoordinator.collapse()
                } else {
                    switcherCoordinator.openFromShortcut()
                    switcherPanelInteractionRouter.perform(.openSwitcher)
                }
            case .navigateSessions:
                if switcherCoordinator.state.isOpen {
                    switcherCoordinator.navigate(
                        .down,
                        reverse: KeyboardShortcutManager.shared.reverseSwitcherEnabled
                    )
                } else {
                    switcherCoordinator.openFromShortcut()
                    switcherPanelInteractionRouter.perform(.openSwitcher)
                }
            case .jumpToTerminal, .focusActiveSession:
                if switcherCoordinator.state.isOpen {
                    switcherCoordinator.submitHighlighted()
                } else if let activeSessionID = runtime?.sessionStoreIndexes().activeSessionId {
                    if let localSessionJumpCoordinator {
                        _ = localSessionJumpCoordinator.jumpToSession(activeSessionID)
                    } else {
                        jumpToSession(activeSessionID)
                    }
                }
            case .collapsePanel:
                switcherCoordinator.collapse()
            case .selectOption, .submitMultiSelectAnswer, .approvePermission, .denyPermission, .alwaysAllow:
                break
            }
        }
        var shortcutManagerController: MyVibeIslandAppKitShortcutManagerController?
        let carbonRuntime = makeCarbonHotKeyRuntime { hotKeyID in
            SessionCompletionTraceLog.append(
                stage: "shortcut.carbon.callback",
                sessionId: nil,
                metadata: ["hotKeyID": hotKeyID]
            )
            shortcutManagerController?.handleHotKey(hotKeyID)
        }
        let concreteShortcutManagerController = MyVibeIslandAppKitShortcutManagerController(
            settings: shortcutSettings,
            carbonController: MyVibeIslandAppKitCarbonHotKeyController(runtime: carbonRuntime),
            routeShortcutAction: routeShortcutAction
        )
        shortcutManagerController = concreteShortcutManagerController
        let originalUnifiedHostingRenderer = MyVibeIslandAppKitOriginalUnifiedHostingRenderer(
            onNavigateSwitcher: { switcherCoordinator.navigate($0) },
            onSubmitSwitcher: switcherCoordinator.submitHighlighted,
            onCollapseSwitcher: switcherCoordinator.collapse,
            onRequestFocus: {
                switcherPanelInteractionRouter.perform(.setKeyboardFocusNeeded(true))
            },
            onReleaseFocus: {
                switcherPanelInteractionRouter.perform(.setKeyboardFocusNeeded(false))
            },
            // V3's NotchWindowController owns expanded-hover state through
            // its AppKit pointer classifier. Root SwiftUI hover is visual
            // only and must not race the retained leave work item.
            onExpandedContentHoverChange: { _ in },
            onInteractionGeometryChange: { geometry in
                SessionCompletionTraceLog.append(
                    stage: "panel.geometry.consume",
                    sessionId: nil,
                    metadata: [
                        "expandedFrame": "x=\(geometry.expandedFrame.x),y=\(geometry.expandedFrame.y),w=\(geometry.expandedFrame.width),h=\(geometry.expandedFrame.height)",
                    ]
                )
                notchPanelController.applyInteractionGeometry(geometry)
                // V3 `NotchWindowController` resizes its NSPanel to the
                // maximum transparent host envelope. The smaller visible
                // surface remains an interaction-only rectangle.
                notchPanelController.applyFrame(geometry.hostingFrame)
            },
            onOpenSettings: { routeOverlayAction(.openSettings) },
            onContextMenuCommand: { command in
                routeOverlayAction(.appCommand(command))
            },
            onSelectSession: { localSessionJumpCoordinator?.selectSession($0) },
            onJumpToSession: { _ = localSessionJumpCoordinator?.jumpToSession($0) },
            onSubmitActionResolution: { resolution in
                localSessionJumpCoordinator?.resolveAction(resolution) ?? false
            }
        )
        switcherCoordinator.onStateChange = { [weak originalUnifiedHostingRenderer, weak switcherEventMonitor] state in
            originalUnifiedHostingRenderer?.replaceSwitcherState(state)
            if state.isOpen {
                _ = concreteShortcutManagerController.enterScope(.switcherPanel)
                switcherEventMonitor?.start()
            } else {
                _ = concreteShortcutManagerController.exitScope(.switcherPanel)
                switcherEventMonitor?.stop()
            }
        }
        let overlayController = overlayController ?? MyVibeIslandAppKitOverlayController(
            buildOriginalIslandSurfaceView: { renderList in
                if renderList.sections.rootContentStatus == .expanded {
                    _ = concreteShortcutManagerController.enterScope(.expandedPanel)
                } else {
                    _ = concreteShortcutManagerController.exitScope(.expandedPanel)
                }
                switcherCoordinator.syncAvailableSessions(
                    sessionIDs: renderList.sections.sessions.map(\.id),
                    focusedID: renderList.sections.focusedSessionId
                )
                let screen = originalCompactHostingScreenResolver(
                    screenSelectionController.snapshot.target?.identifier
                )
                let view = originalUnifiedHostingRenderer.render(renderList, screen: screen)
                if let interactionGeometry = originalUnifiedHostingRenderer.interactionGeometry {
                    notchPanelController.applyInteractionGeometry(interactionGeometry)
                } else {
                    notchPanelController.clearInteractionGeometry()
                }
                return view
            },
            buildIslandSurfaceView: { descriptor in
                MyVibeIslandAppKitIslandSurfaceViewFactory(
                    performAction: { resolution in
                        routeOverlayAction(.submitActionResolution(resolution))
                    }
                ).makeView(from: descriptor)
            },
            renderIslandSurfaceView: { view in
                notchPanelController.installContentView(view)
            },
            applyFrame: { frame in
                notchPanelController.applyFrame(frame)
            },
            showPanel: { _ in
                notchPanelController.show()
            },
            hidePanel: { _ in
                switcherEventMonitor.stop()
                notchPanelController.hide()
            },
            forwardInteractionAction: { action in
                notchPanelController.applyInteractionAction(action)
            },
            routeAction: routeOverlayAction
        )
        let notchViewModelController = MyVibeIslandAppKitNotchViewModelController(
            state: initialState,
            reducer: NotchViewModelReducer(
                overlayController: OverlayControllerModel(
                    panelController: OverlayPanelControllerModel(
                        interactionController: PanelInteractionController(
                            settings: behaviourSettings
                        )
                    )
                )
            ),
            overlayController: overlayController,
            autoHideWhenIdle: behaviourSettings.autoHideWhenIdle,
            setIdleHidden: { isHidden in
                notchPanelController.setIdleHidden(isHidden)
            },
            automaticExpansionFocus: automaticExpansionFocus
        )
        originalUnifiedHostingRenderer.setManualSessionExpansionHandler {
            [weak notchViewModelController] sessionID in
            notchViewModelController?.toggleManualSessionExpansion(sessionID)
        }
        let notificationPresentationController = notificationPresentationController ?? MyVibeIslandAppKitNotificationPresentationController(
            presentPeek: { notification in
                if notification.notification.category == .sessionCompleted
                    || notification.notification.category == .permissionRequested {
                    if notification.notification.category == .sessionCompleted {
                        let sensoryPolicy = notification.notification.sessionId.flatMap { sessionId in
                            notchViewModelController.state.sessions.first { $0.id == sessionId }
                        }.map(v3SensoryPolicyProvider) ?? .none
                        notchViewModelController.handleTaskCompletion(
                            sessionId: notification.notification.sessionId,
                            autoExpandOnTaskComplete: behaviourSettings.autoExpandOnTaskComplete,
                            quietSceneActive: quietSceneMonitor.isQuietSceneActive,
                            sensoryPolicy: sensoryPolicy
                        )
                    } else {
                        notchViewModelController.showCompletionRender(
                            sessionId: notification.notification.sessionId
                        )
                    }
                    return
                }
                guard let sessionID = notification.notification.sessionId else { return }
                let previews = notchViewModelController.state.sessionPreviews.filter {
                    $0.sessionId == sessionID
                }
                guard !previews.isEmpty else { return }
                notchViewModelController.showNotificationPeek(previews)
            },
            clearPeek: {
                guard notchViewModelController.state.overlayState.panelState.presentationState.displayState
                    == .notificationPeek else { return }
                notchViewModelController.clearNotificationPeek()
            },
            shouldClearPeek: {
                !notchViewModelController.state.overlayState.panelState.presentationState
                    .interactionState.isMouseInExpandedPanel
            },
            requestSound: { request in
                let playbackPlan = soundManagerProvider().planPlayback(SoundManagerPlaybackRequest(
                    category: request.category,
                    source: request.source,
                    minuteOfDay: notificationSoundMinuteOfDay()
                ))
                soundPlaybackController.apply(playbackPlan)
            }
        )
        let notificationCoordinatorController = notificationCoordinatorController ?? MyVibeIslandAppKitNotificationCoordinatorController(
            silenceRulesProvider: silenceRulesProvider,
            presentationController: notificationPresentationController
        )
        let usageCoordinatorController = usageCoordinatorController ?? MyVibeIslandAppKitUsageCoordinatorController(
            settings: usageSettings,
            publishPresentation: { snapshot in
                notchViewModelController.applyUsagePresentation(snapshot)
            }
        )
        let soundCoordinatorController = soundCoordinatorController ?? MyVibeIslandAppKitSoundCoordinatorController(
            planSound: { request in
                SoundCoordinator(soundManager: soundManagerProvider()).planSound(for: request)
            },
            playSound: soundPlaybackController.apply
        )
        let updateCheckerController = updateCheckerController ?? MyVibeIslandAppKitUpdateCheckerController(
            currentVersion: updateWindowController.snapshot.currentVersion,
            isConfigured: updatesConfigured,
            presentManualCheck: {
                updateWindowController.checkForUpdates()
            },
            presentUnavailable: {
                updateWindowController.fail("Updates are not configured in this build.")
            }
        )
        let systemCommandController = systemCommandController ?? MyVibeIslandAppKitSystemCommandController(
            setDockIconVisible: { isVisible in
                dockIconController.setVisible(isVisible)
            },
            setLaunchAtLoginEnabled: { isEnabled in
                launchAtLoginController.setEnabled(isEnabled)
            },
            checkForUpdates: {
                updateCheckerController.checkForUpdates()
            },
            exportDiagnostics: {
                diagnosticExportController.exportDiagnostics()
            }
        )
        let presenter = MyVibeIslandAppKitStatusItemMenuPresenter(
            dispatch: { command in
                if let shellCommandDispatcher {
                    _ = shellCommandDispatcher.dispatch(command)
                } else {
                    if case let .selectScreenMode(mode) = command {
                        screenSelectionController.selectMode(mode)
                        persistScreenSelection(screenSelectionController.snapshot)
                    }
                    dispatchMenuCommand?(command)
                }
            },
            installMenu: { menu in
                statusItemController.install(menu)
            }
        )
        self.statusItemController = statusItemController
        self.switcherCoordinator = switcherCoordinator
        self.shortcutCoordinatorController = shortcutCoordinatorController
        self.shortcutManagerController = concreteShortcutManagerController
        self.switcherEventMonitor = switcherEventMonitor
        self.originalUnifiedHostingRenderer = originalUnifiedHostingRenderer
        self.statusItemMenuPresenter = presenter
        self.overlayController = overlayController
        self.notchViewModelController = notchViewModelController
        switcherPanelInteractionRouter.notchController = notchViewModelController
        self.notificationPresentationController = notificationPresentationController
        self.notificationCoordinatorController = notificationCoordinatorController
        self.quietSceneMonitor = quietSceneMonitor
        quietSceneMonitor.start()
        self.soundOutputDeviceMonitor = soundOutputDeviceMonitor
        soundOutputDeviceMonitor?.start()
        self.usageCoordinatorController = usageCoordinatorController
        self.soundCoordinatorController = soundCoordinatorController
        self.soundPlaybackController = soundPlaybackController
        self.diagnosticExportController = diagnosticExportController
        self.updateCheckerController = updateCheckerController
        self.runtimeOwnerController = runtimeOwnerController
        self.screenSelectionController = screenSelectionController
        self.lifecycleController = lifecycleController
        self.launchContext = launchContext
        self.platformIntentExecutor = MyVibeIslandAppKitPlatformIntentExecutor(
            applyStatusItemMenu: { snapshot in
                _ = presenter.apply(snapshot)
            },
            applyLifecycleStep: { step in
                guard lifecycleController.apply(step) else {
                    throw NSError(domain: "MyVibeIslandAppKitLifecycle", code: 1)
                }
            },
            startRuntimeOwner: { owner in
                runtimeOwnerController.start(owner)
            },
            stopRuntimeOwner: { owner in
                runtimeOwnerController.stop(owner)
            },
            runtimeOwnerResult: { owner in
                runtimeOwnerController.result(for: owner)
            },
            createNotchPanel: {
                notchPanelController.createPanel()
            },
            installNotchEventMonitors: {
                notchPanelController.installMonitors()
            },
            removeNotchEventMonitors: {
                switcherEventMonitor.stop()
                notchPanelController.removeMonitors()
            },
            applyTargetScreen: { identifier in
                notchPanelController.applyTargetScreen(identifier)
            },
            applyNotchPlacement: { placement in
                notchPanelController.applyPlacement(placement)
                notchViewModelController.synchronizePlacement(placement)
            },
            showNotchPanel: {
                notchPanelController.show()
            },
            hideNotchPanel: {
                switcherEventMonitor.stop()
                notchPanelController.hide()
            },
            closeNotchPanel: {
                switcherEventMonitor.stop()
                notchPanelController.close()
            },
            showIsland: {
                routeController.showIsland()
            },
            openSettings: { link in
                routeController.openSettings(link)
            },
            showOnboarding: {
                routeController.showOnboarding()
            },
            setDockIconVisible: { isVisible in
                systemCommandController.setDockIconVisible(isVisible)
            },
            setLaunchAtLoginEnabled: { isEnabled in
                systemCommandController.setLaunchAtLoginEnabled(isEnabled)
            },
            checkForUpdates: {
                systemCommandController.checkForUpdates()
            },
            exportDiagnostics: {
                systemCommandController.exportDiagnostics()
            },
            quitApplication: {
                routeController.quit()
            },
            ignoreMenuCommand: { command in
                lifecycleController.ignore(command)
            },
            applyOverlayAction: { action in
                overlayController.apply(action)
            }
        )
    }

}
