import Foundation

public struct SilenceBuiltInRuleGroup: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let rules: [SilenceRule]

    public init(
        id: String,
        name: String,
        rules: [SilenceRule]
    ) {
        self.id = id
        self.name = name
        self.rules = rules
    }
}

public struct SilenceRulesSnapshot: Codable, Equatable, Sendable {
    public let disabledBuiltInIds: [String]
    public let customRules: [SilenceRule]
    public let builtInGroups: [SilenceBuiltInRuleGroup]

    public var effectiveRules: [SilenceRule] {
        let enabledBuiltInRules = builtInGroups
            .filter { !disabledBuiltInIds.contains($0.id) }
            .flatMap(\.rules)
        return enabledBuiltInRules + customRules
    }

    public init(
        disabledBuiltInIds: [String] = [],
        customRules: [SilenceRule] = [],
        builtInGroups: [SilenceBuiltInRuleGroup] = []
    ) {
        self.disabledBuiltInIds = disabledBuiltInIds
        self.customRules = customRules
        self.builtInGroups = builtInGroups
    }
}

public struct SilenceRulesSavePlan: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let disabledBuiltInIds: [String]
    public let customRules: [SilenceRule]

    public init(
        schemaVersion: Int,
        disabledBuiltInIds: [String],
        customRules: [SilenceRule]
    ) {
        self.schemaVersion = schemaVersion
        self.disabledBuiltInIds = disabledBuiltInIds
        self.customRules = customRules
    }
}

public struct SilenceRulesStore: Sendable {
    public init() {}

    public func planSave(_ snapshot: SilenceRulesSnapshot) -> SilenceRulesSavePlan {
        SilenceRulesSavePlan(
            schemaVersion: 1,
            disabledBuiltInIds: snapshot.disabledBuiltInIds,
            customRules: snapshot.customRules
        )
    }
}
