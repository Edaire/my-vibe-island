import Foundation

public final class SoundPreferencesStore: @unchecked Sendable {
    public enum Key {
        public static let isEnabled = "soundEnabled"
        public static let volume = "soundVolume"
        public static let selectedPack = "soundSelectedPack"
        public static let quietHoursEnabled = "soundQuietHoursEnabled"
        public static let quietHoursStartMinutes = "soundQuietHoursStartMinutes"
        public static let quietHoursEndMinutes = "soundQuietHoursEndMinutes"
        public static let filterAutoDetect = "soundFilterAutoDetect"
        public static let filterRules = "soundFilterRules"
        public static let sourceSelections = "soundSourceSelections.v1"
    }

    private let preferences: LocalPreferenceStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        preferences = LocalPreferenceStore(defaults: defaults)
    }

    public func loadManagerSettings() -> SoundManagerSettings {
        SoundManagerSettings(
            selectedPackId: preferences.string(forKey: Key.selectedPack),
            isEnabled: preferences.bool(forKey: Key.isEnabled, default: true),
            volume: preferences.double(forKey: Key.volume, default: 1.0),
            quietHoursEnabled: preferences.bool(forKey: Key.quietHoursEnabled, default: false),
            quietHoursStartMinutes: preferences.integer(forKey: Key.quietHoursStartMinutes, default: 22 * 60),
            quietHoursEndMinutes: preferences.integer(forKey: Key.quietHoursEndMinutes, default: 8 * 60)
        )
    }

    public func saveManagerSettings(_ settings: SoundManagerSettings) {
        preferences.set(settings.isEnabled, forKey: Key.isEnabled)
        preferences.set(settings.volume, forKey: Key.volume)
        preferences.set(settings.selectedPackId, forKey: Key.selectedPack)
        preferences.set(settings.quietHoursEnabled, forKey: Key.quietHoursEnabled)
        preferences.set(settings.quietHoursStartMinutes, forKey: Key.quietHoursStartMinutes)
        preferences.set(settings.quietHoursEndMinutes, forKey: Key.quietHoursEndMinutes)
    }

    public func loadFilter() -> SoundFilter {
        let rules = preferences.data(forKey: Key.filterRules)
            .flatMap { try? decoder.decode([SoundFilterRule].self, from: $0) } ?? []
        return SoundFilter(
            autoDetectProbes: preferences.bool(forKey: Key.filterAutoDetect, default: false),
            rules: rules
        )
    }

    public func saveFilter(_ filter: SoundFilter) {
        preferences.set(filter.autoDetectProbes, forKey: Key.filterAutoDetect)
        preferences.set(try? encoder.encode(filter.rules), forKey: Key.filterRules)
    }

    public func loadSourceSelections() -> SoundSourceStoreSnapshot {
        preferences.data(forKey: Key.sourceSelections)
            .flatMap { try? decoder.decode(SoundSourceStoreSnapshot.self, from: $0) }
            ?? SoundSourceStore(selections: [:]).persistedSnapshot
    }

    public func saveSourceSelections(_ snapshot: SoundSourceStoreSnapshot) {
        preferences.set(try? encoder.encode(snapshot), forKey: Key.sourceSelections)
    }

    public func loadManagerSnapshot() -> SoundManagerSnapshot {
        let selections = loadSourceSelections().selections.reduce(
            into: [NotificationSoundCategory: SoundSourceSelection]()
        ) { result, selection in
            result[selection.category] = selection
        }
        return SoundManagerSnapshot(
            settings: loadManagerSettings(),
            filter: loadFilter(),
            sourceSelections: selections
        )
    }
}
