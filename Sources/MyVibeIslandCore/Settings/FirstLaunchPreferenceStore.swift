import Foundation
import CoreFoundation

public struct FirstLaunchPreferences: Equatable, Sendable {
    public let hasLaunchedBefore: Bool
    public let hasCompletedOnboarding: Bool
    public let onboardingVersion: Int

    public init(
        hasLaunchedBefore: Bool = false,
        hasCompletedOnboarding: Bool = false,
        onboardingVersion: Int = 0
    ) {
        self.hasLaunchedBefore = hasLaunchedBefore
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.onboardingVersion = max(0, onboardingVersion)
    }
}

public enum MyVibeIslandAppVersion {
    public static let fallback = "1.0.0"

    public static func resolve(_ value: String?) -> String {
        guard let value else { return fallback }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        let components = trimmed.split(separator: ".")
        guard components.count >= 2,
              components.prefix(3).allSatisfy({ Int($0) != nil }),
              components.prefix(3).contains(where: { Int($0) != 0 })
        else {
            return fallback
        }
        return trimmed
    }

}

public final class FirstLaunchPreferenceStore: @unchecked Sendable {
    public static let currentOnboardingVersion = 3

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> FirstLaunchPreferences {
        FirstLaunchPreferences(
            hasLaunchedBefore: boolValue(forKey: Self.hasLaunchedBeforeKey) ?? false,
            hasCompletedOnboarding: boolValue(forKey: Self.hasCompletedOnboardingKey) ?? false,
            onboardingVersion: validVersion(integerValue(forKey: Self.onboardingVersionKey))
        )
    }

    public func launchContext(
        currentOnboardingVersion: Int = FirstLaunchPreferenceStore.currentOnboardingVersion
    ) -> AppLaunchContext {
        let preferences = load()
        return AppLaunchContext(
            isFirstLaunch: !preferences.hasLaunchedBefore,
            hasPendingOnboarding: !preferences.hasCompletedOnboarding
                || preferences.onboardingVersion < max(0, currentOnboardingVersion),
            hasPendingUpdateNotes: false
        )
    }

    public func markLaunched() {
        defaults.set(true, forKey: Self.hasLaunchedBeforeKey)
    }

    public func completeOnboarding(version: Int = 1) {
        defaults.set(true, forKey: Self.hasCompletedOnboardingKey)
        defaults.set(max(0, version), forKey: Self.onboardingVersionKey)
    }

    private func validVersion(_ value: Int?) -> Int {
        guard let value, value >= 0 else { return 0 }
        return value
    }

    private func boolValue(forKey key: String) -> Bool? {
        guard let value = defaults.object(forKey: key) as AnyObject?,
              CFGetTypeID(value) == CFBooleanGetTypeID()
        else {
            return nil
        }
        return (value as! NSNumber).boolValue
    }

    private func integerValue(forKey key: String) -> Int? {
        guard let value = defaults.object(forKey: key) as? NSNumber,
              Self.integerTypeCodes.contains(String(cString: value.objCType))
        else {
            return nil
        }
        return value.intValue
    }

    private static let integerTypeCodes: Set<String> = ["s", "S", "i", "I", "l", "L", "q", "Q"]

    private static let hasLaunchedBeforeKey = "hasLaunchedBefore"
    private static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private static let onboardingVersionKey = "onboardingVersion"
}
