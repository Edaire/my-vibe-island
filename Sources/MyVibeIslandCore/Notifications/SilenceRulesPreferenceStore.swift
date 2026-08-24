import Foundation

public final class SilenceRulesPreferenceStore: @unchecked Sendable {
    public enum Key {
        public static let snapshot = "silenceRules.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SilenceRulesSnapshot {
        guard let data = defaults.data(forKey: Key.snapshot),
              let plan = try? decoder.decode(SilenceRulesSavePlan.self, from: data),
              plan.schemaVersion == 1 else {
            return SilenceRulesSnapshot()
        }

        return SilenceRulesSnapshot(
            disabledBuiltInIds: plan.disabledBuiltInIds,
            customRules: plan.customRules
        )
    }

    public func save(_ snapshot: SilenceRulesSnapshot) {
        let plan = SilenceRulesStore().planSave(snapshot)
        defaults.set(try? encoder.encode(plan), forKey: Key.snapshot)
    }
}
