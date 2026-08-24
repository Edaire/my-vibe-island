import AppKit
import CoreGraphics
import MyVibeIslandCore

func productionPrimaryScreen<Screen>(
    orderedScreens: [Screen],
    mainScreen: Screen?
) -> Screen? {
    orderedScreens.first ?? mainScreen
}

@MainActor
private func appKitProductionScreenTarget(_ screen: NSScreen) -> ScreenTarget {
    let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    return ScreenTarget(
        identifier: displayID.map(String.init) ?? screen.localizedName,
        displayName: screen.localizedName,
        isBuiltIn: displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false,
        isMain: screen == NSScreen.main
    )
}

public struct MyVibeIslandApplication: Sendable {
    public let launchBootstrap: AppShellLaunchBootstrap
    public let platformLaunchPlanner: AppShellPlatformLaunchPlanner

    public init(
        launchBootstrap: AppShellLaunchBootstrap = AppShellLaunchBootstrap(),
        platformLaunchPlanner: AppShellPlatformLaunchPlanner = AppShellPlatformLaunchPlanner()
    ) {
        self.launchBootstrap = launchBootstrap
        self.platformLaunchPlanner = platformLaunchPlanner
    }

    public func prepareLaunch() -> AppShellPlatformLaunchPlan {
        platformLaunchPlanner.makePlan(from: launchBootstrap.buildLaunchPlan())
    }

    public static func production(
        screenFrame: DisplayFrame,
        safeAreaTopInset: Double,
        defaults: UserDefaults = .standard,
        availableScreens: [ScreenDescriptor] = [],
        versionProvider: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        }
    ) -> MyVibeIslandApplication {
        production(
            screenFrame: screenFrame,
            safeAreaTopInset: safeAreaTopInset,
            target: AppShellLaunchConfiguration().target,
            defaults: defaults,
            availableScreens: availableScreens,
            versionProvider: versionProvider
        )
    }

    public static func production(
        screenFrame: DisplayFrame,
        safeAreaTopInset: Double,
        target: ScreenTarget,
        defaults: UserDefaults = .standard,
        availableScreens: [ScreenDescriptor] = [],
        versionProvider: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        }
    ) -> MyVibeIslandApplication {
        let launchContext = productionLaunchContext(defaults: defaults)
        let preferences = ScreenSelectionPreferenceStore(defaults: defaults).load()
        let resolvedTarget = productionTarget(
            fallback: target,
            preferences: preferences,
            availableScreens: availableScreens
        ) ?? target
        return MyVibeIslandApplication(
            launchBootstrap: AppShellLaunchBootstrap(
                configuration: AppShellLaunchConfiguration(
                    launchContext: launchContext,
                    target: resolvedTarget,
                    placementInput: appKitProductionPlacementInput(
                        screenFrame: screenFrame,
                        safeAreaTopInset: safeAreaTopInset
                    ),
                    menuSnapshot: AppMenuSnapshot(
                        enabledCommands: AppShellLaunchConfiguration().menuSnapshot.enabledCommands,
                        selectedScreenMode: preferences.mode
                    )
                )
            )
        )
    }

    @MainActor
    public static func production(
        defaults: UserDefaults = .standard,
        versionProvider: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        }
    ) -> MyVibeIslandApplication {
        let preferences = ScreenSelectionPreferenceStore(defaults: defaults).load()
        let screenDescriptors = NSScreen.screens.map(appKitProductionScreenDescriptor)
        let fallbackTarget = ScreenTarget(
                identifier: preferences.selectedScreenIdentifier ?? "main",
                displayName: preferences.selectedScreenIdentifier ?? "Built-in Display",
                isBuiltIn: preferences.mode == .builtInNotchDisplay,
                isMain: preferences.mode == .mainDisplay
        )
        let resolvedTarget = productionTarget(
            fallback: fallbackTarget,
            preferences: preferences,
            availableScreens: screenDescriptors
        ) ?? fallbackTarget
        let target = resolvedTarget
        let targetScreen = NSScreen.screens.first {
            appKitProductionScreenTarget($0).identifier == target.identifier
        } ?? productionPrimaryScreen(orderedScreens: NSScreen.screens, mainScreen: NSScreen.main)
        let placementInput = targetScreen.map(appKitProductionPlacementInput(for:))
        return MyVibeIslandApplication(
            launchBootstrap: AppShellLaunchBootstrap(
                configuration: AppShellLaunchConfiguration(
                    launchContext: productionLaunchContext(defaults: defaults),
                    target: target,
                    placementInput: placementInput ?? AppShellLaunchConfiguration().placementInput,
                    menuSnapshot: AppMenuSnapshot(
                        enabledCommands: AppShellLaunchConfiguration().menuSnapshot.enabledCommands,
                        selectedScreenMode: preferences.mode
                    )
                )
            )
        )
    }

    @MainActor
    public static func production() -> MyVibeIslandApplication {
        guard let screen = productionPrimaryScreen(
            orderedScreens: productionOrderedScreens(defaults: .standard),
            mainScreen: NSScreen.main
        ) else {
            return MyVibeIslandApplication()
        }
        return production(
            screenFrame: DisplayFrame(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y,
                width: screen.frame.width,
                height: screen.frame.height
            ),
            safeAreaTopInset: screen.safeAreaInsets.top,
            target: appKitProductionScreenTarget(screen),
            defaults: .standard,
            availableScreens: NSScreen.screens.map(appKitProductionScreenDescriptor)
        )
    }
}

private func productionLaunchContext(defaults: UserDefaults) -> AppLaunchContext {
    let firstLaunch = FirstLaunchPreferenceStore(defaults: defaults)
    let whatsNew = WhatsNewPreferenceStore(defaults: defaults).load()
    let context = firstLaunch.launchContext(
        currentOnboardingVersion: FirstLaunchPreferenceStore.currentOnboardingVersion
    )
    return AppLaunchContext(
        isFirstLaunch: context.isFirstLaunch,
        hasPendingOnboarding: context.hasPendingOnboarding,
        hasPendingUpdateNotes: whatsNew.pendingVersion != nil
    )
}

@MainActor
private func productionOrderedScreens(defaults: UserDefaults) -> [NSScreen] {
    let preferences = ScreenSelectionPreferenceStore(defaults: defaults).load()
    let descriptors = NSScreen.screens.map(appKitProductionScreenDescriptor)
    guard let target = productionTarget(
        fallback: nil,
        preferences: preferences,
        availableScreens: descriptors
    ) else {
        return NSScreen.screens
    }
    let selected = NSScreen.screens.first { appKitProductionScreenTarget($0).identifier == target.identifier }
    return selected.map { [$0] } ?? NSScreen.screens
}

private func productionTarget(
    fallback: ScreenTarget?,
    preferences: ScreenSelectionPreferences,
    availableScreens: [ScreenDescriptor]
) -> ScreenTarget? {
    guard !availableScreens.isEmpty else { return fallback }
    let plan = ScreenSelectionCoordinator().plan(
        .refreshScreens(availableScreens),
        from: ScreenSelectionSnapshot(
            mode: preferences.mode,
            manualScreenIdentifier: preferences.mode == .manualDisplay
                ? preferences.selectedScreenIdentifier
                : nil,
            switchTipDismissed: preferences.switchTipDismissed
        )
    )
    return plan.nextSnapshot.target ?? fallback
}

@MainActor
private func appKitProductionScreenDescriptor(_ screen: NSScreen) -> ScreenDescriptor {
    let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    return ScreenDescriptor(
        identifier: displayID.map(String.init) ?? screen.localizedName,
        displayName: screen.localizedName,
        isBuiltIn: displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false,
        hasNotch: screen.safeAreaInsets.top > 0,
        isMain: screen == NSScreen.main
    )
}

func appKitProductionPlacementInput(
    screenFrame: DisplayFrame,
    safeAreaTopInset: Double
) -> DisplayPlacementInput {
    DisplayPlacementInput(
        screenFrame: screenFrame,
        safeAreaTopInset: safeAreaTopInset,
        closedSize: OriginalIslandGeometryResolver.panelSize,
        expandedSize: OriginalIslandGeometryResolver.panelSize
    )
}

@MainActor
private func appKitProductionPlacementInput(for screen: NSScreen) -> DisplayPlacementInput {
    appKitProductionPlacementInput(
        screenFrame: DisplayFrame(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y,
            width: screen.frame.width,
            height: screen.frame.height
        ),
        safeAreaTopInset: screen.safeAreaInsets.top
    )
}
