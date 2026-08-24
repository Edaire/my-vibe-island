import Foundation
import XCTest
@testable import MyVibeIslandCore

final class SilenceRulesPreferenceStoreTests: XCTestCase {
    func testCustomRulesAndDisabledBuiltInRuleIdsRoundTripAsJSON() throws {
        let defaults = try defaults()
        let store = SilenceRulesPreferenceStore(defaults: defaults)
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
            ]
        )

        store.save(snapshot)

        let data = try XCTUnwrap(defaults.data(forKey: "silenceRules.v1"))
        XCTAssertEqual(
            try JSONDecoder().decode(SilenceRulesSavePlan.self, from: data),
            SilenceRulesStore().planSave(snapshot)
        )
        XCTAssertEqual(store.load(), snapshot)
    }

    func testCorruptJSONFallsBackToEmptySnapshot() throws {
        let defaults = try defaults()
        defaults.set(Data("not-json".utf8), forKey: "silenceRules.v1")

        XCTAssertEqual(
            SilenceRulesPreferenceStore(defaults: defaults).load(),
            SilenceRulesSnapshot()
        )
    }

    private func defaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "SilenceRulesPreferenceStoreTests.\(UUID().uuidString)"))
    }
}
