import Foundation

/// Reads V3's separately persisted silence-rule payload. This store is kept
/// separate from the legacy local notification rules because V3 custom rules
/// compile to a combined display policy rather than an arbitrary action.
public final class V3SilenceRulesPreferenceStore: @unchecked Sendable {
    public enum Key {
        public static let snapshot = "silenceRulesV1"
    }

    private struct PersistedRules: Codable {
        let version: Int
        let disabledBuiltInIds: [UUID]
        var customRules: [PersistedCustomRule]

        init(
            version: Int,
            disabledBuiltInIds: [UUID],
            customRules: [PersistedCustomRule]
        ) {
            self.version = version
            self.disabledBuiltInIds = disabledBuiltInIds
            self.customRules = customRules
        }
    }

    private struct PersistedCustomRule: Codable {
        let id: UUID
        let enabled: Bool
        let field: V3SilenceMatchField
        let matchType: V3SilenceMatchType
        let pattern: String
        let caseSensitive: Bool
        let createdAt: Date
    }

    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [V3SilenceRule] {
        guard let data = defaults.data(forKey: Key.snapshot),
              let persisted = try? decoder.decode(PersistedRules.self, from: data),
              persisted.version == 1 else {
            return []
        }

        return persisted.customRules.map { rule in
            V3SilenceRule(
                id: rule.id,
                isEnabled: rule.enabled,
                matchers: [V3SilenceMatcher(
                    field: rule.field,
                    matchType: rule.matchType,
                    pattern: rule.pattern,
                    caseSensitive: rule.caseSensitive
                )],
                action: V3SilenceAction(
                    hidePanel: true,
                    muteSound: true,
                    suppressExpand: true,
                    autoDismissOnStop: false
                )
            )
        }
    }

    public func addCustomRule(
        field: V3SilenceMatchField,
        matchType: V3SilenceMatchType,
        pattern: String,
        now: Date = Date()
    ) {
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPattern.isEmpty else { return }

        var persisted = loadPersistedRules()
        guard !persisted.customRules.contains(where: {
            $0.field == field && $0.matchType == matchType && $0.pattern == trimmedPattern
        }) else { return }

        persisted.customRules.append(PersistedCustomRule(
            id: UUID(),
            enabled: true,
            field: field,
            matchType: matchType,
            pattern: trimmedPattern,
            caseSensitive: false,
            createdAt: now
        ))
        defaults.set(try? encoder.encode(persisted), forKey: Key.snapshot)
    }

    private func loadPersistedRules() -> PersistedRules {
        guard let data = defaults.data(forKey: Key.snapshot),
              let persisted = try? decoder.decode(PersistedRules.self, from: data),
              persisted.version == 1 else {
            return PersistedRules(version: 1, disabledBuiltInIds: [], customRules: [])
        }
        return persisted
    }
}
