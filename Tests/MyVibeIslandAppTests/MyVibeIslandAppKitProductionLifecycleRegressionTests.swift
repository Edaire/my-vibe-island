import AppKit
import MyVibeIslandCore
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitProductionLifecycleRegressionTests: XCTestCase {
    @MainActor
    func testStoredLaunchContextAndScreenReachApplicationAndRunnerLaunchPlan() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ProductionLifecycleRegression.\(UUID().uuidString)"))
        FirstLaunchPreferenceStore(defaults: defaults).completeOnboarding(version: 3)
        FirstLaunchPreferenceStore(defaults: defaults).markLaunched()
        ScreenSelectionPreferenceStore(defaults: defaults).save(ScreenSelectionPreferences(
            mode: .manualDisplay,
            selectedScreenIdentifier: "external",
            switchTipDismissed: true
        ))
        let target = ScreenTarget(identifier: "external", displayName: "External", isBuiltIn: false, isMain: false)
        let application = MyVibeIslandApplication.production(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
            safeAreaTopInset: 0,
            target: target,
            defaults: defaults
        )

        let launchPlan = application.prepareLaunch()
        let runnerPlan = MyVibeIslandAppKitRunner(application: application).prepareRun()

        XCTAssertEqual(launchPlan.launchPlan.request.context, AppLaunchContext())
        XCTAssertEqual(launchPlan.launchPlan.request.target.identifier, "external")
        XCTAssertEqual(launchPlan.launchPlan.request.menuSnapshot.selectedScreenMode, .manualDisplay)
        XCTAssertEqual(runnerPlan.delegate.bridge.application.prepareLaunch().launchPlan.request.context, AppLaunchContext())
    }

    @MainActor
    func testProductionLifecyclePersistsResolvedLastLaunchedVersion() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ProductionLifecycleRegression.\(UUID().uuidString)"))
        let composition = MyVibeIslandAppKitPlatformComposition.production(defaults: defaults)

        _ = composition.platformIntentExecutor.execute([.lifecycle(.loadSettings)])

        XCTAssertEqual(
            WhatsNewPreferenceStore(defaults: defaults).load().lastLaunchedVersion,
            MyVibeIslandAppVersion.resolve(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        )
        XCTAssertNotEqual(WhatsNewPreferenceStore(defaults: defaults).load().lastLaunchedVersion, "0.0.0")
    }

    @MainActor
    func testProductionOnboardingWritesVersionThreeOnlyFromStartVibing() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ProductionLifecycleRegression.\(UUID().uuidString)"))
        let onboarding = MyVibeIslandAppKitOnboardingWindowController(
            screenFrame: { NSRect(x: 0, y: 0, width: 1440, height: 900) }
        )
        defer { onboarding.close() }
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            defaults: defaults,
            onboardingWindowController: onboarding
        )

        _ = composition.platformIntentExecutor.execute([.showIsland])
        XCTAssertEqual(FirstLaunchPreferenceStore(defaults: defaults).load(), FirstLaunchPreferences())

        _ = composition.platformIntentExecutor.execute([.showOnboarding])
        XCTAssertEqual(FirstLaunchPreferenceStore(defaults: defaults).load(), FirstLaunchPreferences())
        onboarding.completeFullscreen()
        XCTAssertEqual(FirstLaunchPreferenceStore(defaults: defaults).load(), FirstLaunchPreferences())
        onboarding.completeCard()
        XCTAssertEqual(FirstLaunchPreferenceStore(defaults: defaults).load(), FirstLaunchPreferences())
        let ready = try XCTUnwrap(onboarding.readyWindow)
        let readyView = try XCTUnwrap(
            ready.contentView as? NSHostingView<MyVibeIslandAppKitProductionReadyView>
        )
        readyView.rootView.finish()
        readyView.rootView.finish()

        XCTAssertEqual(FirstLaunchPreferenceStore(defaults: defaults).load(), FirstLaunchPreferences(
            hasLaunchedBefore: false,
            hasCompletedOnboarding: true,
            onboardingVersion: 3
        ))
    }

    @MainActor
    func testProductionApplicationResolvesEveryScreenModeBeforeUsingLaunchTarget() throws {
        let screens = [
            ScreenDescriptor(identifier: "main", displayName: "Main", isBuiltIn: true, hasNotch: true, isMain: true),
            ScreenDescriptor(identifier: "external", displayName: "External", isBuiltIn: false, hasNotch: false, isMain: false)
        ]
        let target = ScreenTarget(identifier: "main", displayName: "Main", isBuiltIn: true, isMain: true)
        let cases: [(AppScreenSelectionMode, String)] = [
            (.builtInNotchDisplay, "main"),
            (.mainDisplay, "main"),
            (.followKeyboardFocus, "main"),
            (.manualDisplay, "external")
        ]

        for (mode, expectedIdentifier) in cases {
            let defaults = try XCTUnwrap(UserDefaults(suiteName: "ProductionLifecycleRegression.\(UUID().uuidString)"))
            ScreenSelectionPreferenceStore(defaults: defaults).save(ScreenSelectionPreferences(
                mode: mode,
                selectedScreenIdentifier: "external"
            ))
            let application = MyVibeIslandApplication.production(
                screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
                safeAreaTopInset: 0,
                target: target,
                defaults: defaults,
                availableScreens: screens
            )

            XCTAssertEqual(application.prepareLaunch().launchPlan.request.target.identifier, expectedIdentifier)
        }
    }

    @MainActor
    func testSchemaVersionDrivesOnboardingWhileAppVersionPersistsWhatsNew() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ProductionLifecycleRegression.\(UUID().uuidString)"))
        let firstLaunch = FirstLaunchPreferenceStore(defaults: defaults)
        firstLaunch.markLaunched()
        firstLaunch.completeOnboarding(version: 2)
        let application = MyVibeIslandApplication.production(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
            safeAreaTopInset: 0,
            target: ScreenTarget(identifier: "main", displayName: "Main", isBuiltIn: true, isMain: true),
            defaults: defaults,
            versionProvider: { "3.2.0" }
        )

        XCTAssertTrue(application.prepareLaunch().launchPlan.request.context.hasPendingOnboarding)

        let composition = MyVibeIslandAppKitPlatformComposition.production(
            defaults: defaults,
            versionProvider: { "3.2.0" }
        )
        _ = composition.platformIntentExecutor.execute([.lifecycle(.loadSettings)])
        XCTAssertEqual(WhatsNewPreferenceStore(defaults: defaults).load().lastLaunchedVersion, "3.2.0")
    }

    @MainActor
    func testFutureAppVersionDoesNotReplayCompletedSchemaThreeOnboarding() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ProductionLifecycleRegression.\(UUID().uuidString)"))
        let firstLaunch = FirstLaunchPreferenceStore(defaults: defaults)
        firstLaunch.markLaunched()
        firstLaunch.completeOnboarding(version: 3)

        let application = MyVibeIslandApplication.production(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
            safeAreaTopInset: 0,
            target: ScreenTarget(identifier: "main", displayName: "Main", isBuiltIn: true, isMain: true),
            defaults: defaults,
            versionProvider: { "4.7.0" }
        )
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            defaults: defaults,
            versionProvider: { "4.7.0" }
        )

        XCTAssertFalse(application.prepareLaunch().launchPlan.request.context.hasPendingOnboarding)
        XCTAssertFalse(composition.launchContext.hasPendingOnboarding)
    }

    @MainActor
    func testLifecycleFailureIsVisibleAndExcludedFromExecutedPlatformIntents() {
        let executor = MyVibeIslandAppKitLifecycleStepExecutor { step in
            if step == .startBridge { throw NSError(domain: "test", code: 1) }
        }
        let lifecycle = MyVibeIslandAppKitLifecycleController(lifecycleStepExecutor: executor)
        let platform = MyVibeIslandAppKitPlatformIntentExecutor(
            applyLifecycleStep: { step in
                guard lifecycle.apply(step) else {
                    throw NSError(domain: "lifecycle", code: 1)
                }
            }
        )

        let result = platform.execute([.lifecycle(.startBridge)])

        XCTAssertTrue(result.executedIntents.isEmpty)
        XCTAssertEqual(result.failedIntents.count, 1)
        XCTAssertEqual(result.failedIntents.first?.intent, .lifecycle(.startBridge))
    }

    @MainActor
    func testScreenDisplayAndTipChangesPersistImmediately() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ProductionLifecycleRegression.\(UUID().uuidString)"))
        let screens = [
            ScreenDescriptor(identifier: "main", displayName: "Main", isBuiltIn: true, hasNotch: true, isMain: true),
            ScreenDescriptor(identifier: "external", displayName: "External", isBuiltIn: false, hasNotch: false, isMain: false)
        ]
        let selection = MyVibeIslandAppKitScreenSelectionController(currentScreens: { screens })
        let composition = MyVibeIslandAppKitPlatformComposition.production(
            defaults: defaults,
            screenSelectionController: selection
        )

        _ = composition.screenSelectionController.selectDisplay("external")
        _ = composition.screenSelectionController.dismissSwitchTip()

        XCTAssertEqual(ScreenSelectionPreferenceStore(defaults: defaults).load(), ScreenSelectionPreferences(
            mode: .manualDisplay,
            selectedScreenIdentifier: "external",
            switchTipDismissed: true
        ))
    }
}
