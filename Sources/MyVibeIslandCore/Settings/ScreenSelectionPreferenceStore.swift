import Foundation
import CoreFoundation

public struct ScreenSelectionPreferences: Equatable, Sendable {
    public let mode: AppScreenSelectionMode
    public let selectedScreenIdentifier: String?
    public let switchTipDismissed: Bool

    public init(
        mode: AppScreenSelectionMode = .builtInNotchDisplay,
        selectedScreenIdentifier: String? = nil,
        switchTipDismissed: Bool = false
    ) {
        self.mode = mode
        self.selectedScreenIdentifier = selectedScreenIdentifier
        self.switchTipDismissed = switchTipDismissed
    }
}

public final class ScreenSelectionPreferenceStore: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ScreenSelectionPreferences {
        let mode = defaults.string(forKey: Self.modeKey)
            .flatMap(AppScreenSelectionMode.init(rawValue:))
            ?? .builtInNotchDisplay
        let identifier = defaults.object(forKey: Self.identifierKey) as? String
        let tipDismissed: Bool
        if let value = defaults.object(forKey: Self.tipDismissedKey) as AnyObject?,
           CFGetTypeID(value) == CFBooleanGetTypeID() {
            tipDismissed = (value as! NSNumber).boolValue
        } else {
            tipDismissed = false
        }
        return ScreenSelectionPreferences(
            mode: mode,
            selectedScreenIdentifier: identifier,
            switchTipDismissed: tipDismissed
        )
    }

    public func save(_ preferences: ScreenSelectionPreferences) {
        defaults.set(preferences.mode.rawValue, forKey: Self.modeKey)
        if let identifier = preferences.selectedScreenIdentifier {
            defaults.set(identifier, forKey: Self.identifierKey)
        } else {
            defaults.removeObject(forKey: Self.identifierKey)
        }
        defaults.set(preferences.switchTipDismissed, forKey: Self.tipDismissedKey)
    }

    private static let modeKey = "screenSelection.mode"
    private static let identifierKey = "screenSelection.selectedScreenIdentifier"
    private static let tipDismissedKey = "screenSelection.switchTipDismissed"
}
