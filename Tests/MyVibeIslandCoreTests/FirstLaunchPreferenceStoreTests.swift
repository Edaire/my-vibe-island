import MyVibeIslandCore
import XCTest

final class FirstLaunchPreferenceStoreTests: XCTestCase {
    func testPreferencesRoundTripAndBuildLaunchContext() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "FirstLaunchPreferenceStoreTests.\(UUID().uuidString)"))
        let store = FirstLaunchPreferenceStore(defaults: defaults)

        XCTAssertEqual(store.load(), FirstLaunchPreferences())
        XCTAssertTrue(store.launchContext(currentOnboardingVersion: 3).isFirstLaunch)

        store.markLaunched()
        store.completeOnboarding(version: 3)

        XCTAssertEqual(
            store.load(),
            FirstLaunchPreferences(
                hasLaunchedBefore: true,
                hasCompletedOnboarding: true,
                onboardingVersion: 3
            )
        )
        XCTAssertEqual(store.launchContext(currentOnboardingVersion: 3), AppLaunchContext())
    }

    func testCorruptValuesFallBackSafely() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "FirstLaunchPreferenceStoreTests.\(UUID().uuidString)"))
        defaults.set("yes", forKey: "hasLaunchedBefore")
        defaults.set(NSNumber(value: -4), forKey: "onboardingVersion")
        defaults.set("true", forKey: "hasCompletedOnboarding")
        let store = FirstLaunchPreferenceStore(defaults: defaults)

        XCTAssertEqual(store.load(), FirstLaunchPreferences())
    }

    func testBooleanAndIntegerNSNumberTypesAreNotInterchangeable() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "FirstLaunchPreferenceStoreTests.\(UUID().uuidString)"))
        defaults.set(NSNumber(value: 1), forKey: "hasLaunchedBefore")
        defaults.set(NSNumber(value: 1), forKey: "hasCompletedOnboarding")
        defaults.set(NSNumber(value: true), forKey: "onboardingVersion")

        XCTAssertEqual(FirstLaunchPreferenceStore(defaults: defaults).load(), FirstLaunchPreferences())
    }

    func testVersionResolverUsesExplicitFallback() {
        XCTAssertEqual(MyVibeIslandAppVersion.resolve(nil), "1.0.0")
        XCTAssertEqual(MyVibeIslandAppVersion.resolve("  "), "1.0.0")
        XCTAssertEqual(MyVibeIslandAppVersion.resolve("0.0.0"), "1.0.0")
        XCTAssertEqual(MyVibeIslandAppVersion.resolve("invalid"), "1.0.0")
        XCTAssertEqual(MyVibeIslandAppVersion.resolve("2.4.1"), "2.4.1")
    }

    func testLaunchContextReopensOnboardingWhenTheSchemaVersionAdvances() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "FirstLaunchPreferenceStoreTests.\(UUID().uuidString)"))
        let store = FirstLaunchPreferenceStore(defaults: defaults)
        store.markLaunched()
        store.completeOnboarding(version: 2)

        XCTAssertFalse(store.launchContext(currentOnboardingVersion: 2).hasPendingOnboarding)
        XCTAssertTrue(store.launchContext(currentOnboardingVersion: 3).hasPendingOnboarding)

        store.completeOnboarding(version: 3)

        XCTAssertFalse(store.launchContext(currentOnboardingVersion: 3).hasPendingOnboarding)
    }

    func testInt8NSNumberIsNotAcceptedAsBoolean() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "FirstLaunchPreferenceStoreTests.\(UUID().uuidString)"))
        defaults.set(NSNumber(value: Int8(1)), forKey: "hasLaunchedBefore")
        defaults.set(NSNumber(value: Int8(1)), forKey: "hasCompletedOnboarding")

        XCTAssertEqual(FirstLaunchPreferenceStore(defaults: defaults).load(), FirstLaunchPreferences())
    }
}
