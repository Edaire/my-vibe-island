import XCTest
@testable import MyVibeIslandCore

final class SilenceRulesStoreModelsTests: XCTestCase {
    func testSilenceRulesStoreSnapshotMatchesFixture() throws {
        let expected = try JSONDecoder().decode(
            SilenceRulesStoreFixture.self,
            from: try FixtureLoader.data("notifications/silence-rules-store")
        )
        let snapshot = SilenceRulesSnapshot(
            disabledBuiltInIds: ["quiet-activity"],
            customRules: [
                SilenceRule(
                    id: "custom-codex-permission",
                    enabled: true,
                    matcher: SilenceMatcher(scope: .agent, target: "codex"),
                    action: SilenceAction(suppressesPeek: true, suppressesSound: true),
                    createdAt: "2026-07-08T08:00:00Z"
                ),
                SilenceRule(
                    id: "custom-project-sound",
                    enabled: true,
                    matcher: SilenceMatcher(scope: .workspace, target: "/Users/<user>/project"),
                    action: SilenceAction(suppressesPeek: false, suppressesSound: true),
                    expiresAt: "2026-07-08T12:00:00Z",
                    createdAt: "2026-07-08T08:05:00Z"
                ),
            ],
            builtInGroups: [
                SilenceBuiltInRuleGroup(
                    id: "quiet-activity",
                    name: "Activity updates",
                    rules: [
                        SilenceRule(
                            id: "built-in-activity",
                            enabled: true,
                            matcher: SilenceMatcher(scope: .category, target: "activityUpdate"),
                            action: SilenceAction(suppressesPeek: true, suppressesSound: true),
                            createdAt: "built-in"
                        ),
                    ]
                ),
                SilenceBuiltInRuleGroup(
                    id: "quiet-usage",
                    name: "Usage notices",
                    rules: [
                        SilenceRule(
                            id: "built-in-usage-threshold",
                            enabled: true,
                            matcher: SilenceMatcher(scope: .category, target: "usageThreshold"),
                            action: SilenceAction(suppressesPeek: false, suppressesSound: true),
                            createdAt: "built-in"
                        ),
                    ]
                ),
            ]
        )

        let actual = SilenceRulesStoreFixture(
            snapshot: snapshot,
            effectiveRuleIds: snapshot.effectiveRules.map(\.id),
            savePlan: SilenceRulesStore().planSave(snapshot)
        )

        XCTAssertEqual(actual, expected)
    }

    func testBuiltInRuleGroupProvidesDefaultRulesUnlessDisabled() {
        let group = SilenceBuiltInRuleGroup(
            id: "activity",
            name: "Activity updates",
            rules: [
                SilenceRule(
                    id: "activity-updates",
                    enabled: true,
                    matcher: SilenceMatcher(scope: .category, target: "activityUpdate"),
                    action: SilenceAction(suppressesPeek: true, suppressesSound: true),
                    createdAt: "built-in"
                )
            ]
        )

        let enabled = SilenceRulesSnapshot(
            disabledBuiltInIds: [],
            customRules: [],
            builtInGroups: [group]
        )
        XCTAssertEqual(enabled.effectiveRules.map(\.id), ["activity-updates"])

        let disabled = SilenceRulesSnapshot(
            disabledBuiltInIds: ["activity"],
            customRules: [],
            builtInGroups: [group]
        )
        XCTAssertTrue(disabled.effectiveRules.isEmpty)
    }

    func testSilenceRulesStorePlansPersistenceWithoutWriting() throws {
        let snapshot = SilenceRulesSnapshot(
            disabledBuiltInIds: ["activity"],
            customRules: [
                SilenceRule(
                    id: "custom-codex",
                    enabled: true,
                    matcher: SilenceMatcher(scope: .agent, target: "codex"),
                    action: SilenceAction(suppressesPeek: true, suppressesSound: false),
                    createdAt: "2026-07-08T08:00:00Z"
                )
            ]
        )

        let plan = SilenceRulesStore().planSave(snapshot)
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(SilenceRulesSavePlan.self, from: data)

        XCTAssertEqual(decoded, plan)
        XCTAssertEqual(plan.schemaVersion, 1)
        XCTAssertEqual(plan.disabledBuiltInIds, ["activity"])
        XCTAssertEqual(plan.customRules.map(\.id), ["custom-codex"])
    }

    private struct SilenceRulesStoreFixture: Codable, Equatable {
        let snapshot: SilenceRulesSnapshot
        let effectiveRuleIds: [String]
        let savePlan: SilenceRulesSavePlan
    }
}
