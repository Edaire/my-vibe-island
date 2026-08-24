import XCTest
@testable import MyVibeIslandCore

final class V3SilenceRulesPreferenceStoreTests: XCTestCase {
    func testLoadsOriginalCustomRuleAsCombinedSensoryPolicyAction() throws {
        let defaults = try defaults()
        let payload = """
        {
          "customRules": [{
            "id": "7A9D7260-9C3D-4F89-A494-C0A9EB4CB10F",
            "enabled": true,
            "field": "firstUserPrompt",
            "matchType": "contains",
            "pattern": "__v3_policy_probe__",
            "caseSensitive": true,
            "createdAt": 0
          }],
          "disabledBuiltInIds": [],
          "version": 1
        }
        """
        defaults.set(
            try XCTUnwrap(payload.data(using: .utf8)),
            forKey: V3SilenceRulesPreferenceStore.Key.snapshot
        )

        let rules = V3SilenceRulesPreferenceStore(defaults: defaults).load()

        XCTAssertEqual(rules.count, 1)
        let rule = try XCTUnwrap(rules.first)
        XCTAssertEqual(rule.id.uuidString, "7A9D7260-9C3D-4F89-A494-C0A9EB4CB10F")
        XCTAssertTrue(rule.isEnabled)
        XCTAssertEqual(
            rule.matchers,
            [V3SilenceMatcher(
                field: .firstUserPrompt,
                matchType: .contains,
                pattern: "__v3_policy_probe__",
                caseSensitive: true
            )]
        )
        XCTAssertEqual(
            rule.action,
            V3SilenceAction(
                hidePanel: true,
                muteSound: true,
                suppressExpand: true,
                autoDismissOnStop: false
            )
        )
    }

    func testIgnoresUnsupportedPersistedVersion() throws {
        let defaults = try defaults()
        defaults.set(
            try JSONSerialization.data(withJSONObject: [
                "customRules": [],
                "disabledBuiltInIds": [],
                "version": 2,
            ]),
            forKey: V3SilenceRulesPreferenceStore.Key.snapshot
        )

        XCTAssertEqual(V3SilenceRulesPreferenceStore(defaults: defaults).load(), [])
    }

    func testAddsDirectoryRuleAndPersistsIt() throws {
        let defaults = try defaults()
        let store = V3SilenceRulesPreferenceStore(defaults: defaults)
        let timestamp = Date(timeIntervalSince1970: 1_725_000_000)

        store.addCustomRule(
            field: .cwd,
            matchType: .contains,
            pattern: "  /Users/admin/code/project  ",
            now: timestamp
        )

        let rules = store.load()
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].matchers, [V3SilenceMatcher(
            field: .cwd,
            matchType: .contains,
            pattern: "/Users/admin/code/project"
        )])
        XCTAssertTrue(rules[0].action.hidePanel)
        XCTAssertTrue(rules[0].action.muteSound)
        XCTAssertTrue(rules[0].action.suppressExpand)
    }

    func testDoesNotDuplicateEquivalentContextMenuRule() throws {
        let defaults = try defaults()
        let store = V3SilenceRulesPreferenceStore(defaults: defaults)

        store.addCustomRule(field: .firstUserPrompt, matchType: .prefix, pattern: "Build it")
        store.addCustomRule(field: .firstUserPrompt, matchType: .prefix, pattern: " Build it ")

        XCTAssertEqual(store.load().count, 1)
    }

    func testDirectoryAndPromptContextMenuRulesRemainIndependent() throws {
        let defaults = try defaults()
        let store = V3SilenceRulesPreferenceStore(defaults: defaults)

        store.addCustomRule(field: .cwd, matchType: .contains, pattern: "/tmp/work")
        store.addCustomRule(field: .firstUserPrompt, matchType: .prefix, pattern: "/tmp/work")

        let matchers = try XCTUnwrap(store.load().flatMap(\.matchers))
        XCTAssertEqual(matchers, [
            V3SilenceMatcher(field: .cwd, matchType: .contains, pattern: "/tmp/work"),
            V3SilenceMatcher(field: .firstUserPrompt, matchType: .prefix, pattern: "/tmp/work"),
        ])
    }

    private func defaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "V3SilenceRulesPreferenceStoreTests.\(UUID().uuidString)"))
    }
}
