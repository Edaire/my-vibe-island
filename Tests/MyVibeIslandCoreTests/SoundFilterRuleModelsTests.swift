import XCTest
@testable import MyVibeIslandCore

final class SoundFilterRuleModelsTests: XCTestCase {
    func testSoundFilterDecisionsMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SoundFilterDecisionFixture.self,
            from: try FixtureLoader.data("sound/filter-decisions")
        )
        let filter = SoundFilter(rules: [
            SoundFilterRule(
                id: "allow-usage",
                type: .category,
                action: .allowSound,
                isEnabled: true,
                priority: 5,
                category: .usage,
                reason: "Allow usage"
            ),
            SoundFilterRule(
                id: "disabled-suppress-usage",
                type: .category,
                action: .suppressSound,
                isEnabled: false,
                priority: 100,
                category: .usage,
                reason: "Disabled"
            ),
            SoundFilterRule(
                id: "suppress-codex-usage",
                type: .source,
                action: .suppressSound,
                isEnabled: true,
                priority: 50,
                category: .usage,
                source: "codex",
                reason: "Codex usage is already visible"
            ),
            SoundFilterRule(
                id: "suppress-waiting-blocked",
                type: .lifecycle,
                action: .suppressSound,
                isEnabled: true,
                priority: 40,
                category: .permission,
                lifecycleEvent: .waiting,
                subagentState: .blocked,
                reason: "Blocked permission request is already visible"
            ),
        ])

        let actual = SoundFilterDecisionFixture(
            highPrioritySourceSuppress: filter.decision(for: SoundFilterInput(
                category: .usage,
                source: "codex"
            )),
            lowerPriorityCategoryAllow: filter.decision(for: SoundFilterInput(
                category: .usage,
                source: "opencode"
            )),
            lifecycleSubagentSuppress: filter.decision(for: SoundFilterInput(
                category: .permission,
                source: "codex",
                lifecycleEvent: .waiting,
                subagentState: .blocked
            )),
            noRuleAllow: filter.decision(for: SoundFilterInput(
                category: .remote,
                source: "codex"
            ))
        )

        XCTAssertEqual(actual, expected)
    }

    func testSoundFilterRuleRoundTripsCoreFields() throws {
        let rule = SoundFilterRule(
            id: "rule-usage-codex",
            type: .category,
            action: .suppressSound,
            isEnabled: true,
            priority: 20,
            category: .usage,
            source: "codex",
            lifecycleEvent: .waiting,
            subagentState: .blocked,
            cooldownSeconds: 30,
            reason: "Usage prompt is already visible"
        )

        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(SoundFilterRule.self, from: data)

        XCTAssertEqual(decoded, rule)
        XCTAssertEqual(decoded.type, .category)
        XCTAssertEqual(decoded.action, .suppressSound)
    }

    func testPendingFilterStateRoundTrips() throws {
        let lifecycle: [SoundFilterPendingLifecycleEvent] = [.started, .waiting, .completed, .failed]
        let subagents: [SoundFilterPendingSubagentState] = [.idle, .active, .blocked, .completed]

        let lifecycleData = try JSONEncoder().encode(lifecycle)
        let subagentData = try JSONEncoder().encode(subagents)

        XCTAssertEqual(try JSONDecoder().decode([SoundFilterPendingLifecycleEvent].self, from: lifecycleData), lifecycle)
        XCTAssertEqual(try JSONDecoder().decode([SoundFilterPendingSubagentState].self, from: subagentData), subagents)
    }

    func testSoundFilterUsesFirstEnabledMatchingRuleByPriority() {
        let lowerPriorityAllow = SoundFilterRule(
            id: "allow-usage",
            type: .category,
            action: .allowSound,
            isEnabled: true,
            priority: 5,
            category: .usage,
            reason: "Allow usage"
        )
        let disabledSuppress = SoundFilterRule(
            id: "disabled-suppress-usage",
            type: .category,
            action: .suppressSound,
            isEnabled: false,
            priority: 100,
            category: .usage,
            reason: "Disabled"
        )
        let higherPrioritySuppress = SoundFilterRule(
            id: "suppress-codex-usage",
            type: .source,
            action: .suppressSound,
            isEnabled: true,
            priority: 50,
            category: .usage,
            source: "codex",
            reason: "Codex usage is already visible"
        )
        let filter = SoundFilter(rules: [lowerPriorityAllow, disabledSuppress, higherPrioritySuppress])

        let decision = filter.decision(for: SoundFilterInput(category: .usage, source: "codex"))

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.category, .usage)
        XCTAssertEqual(decision.matchedRuleId, "suppress-codex-usage")
        XCTAssertEqual(decision.reason, "Codex usage is already visible")
    }

    func testSoundFilterAllowsWhenNoRuleMatches() {
        let filter = SoundFilter(rules: [
            SoundFilterRule(
                id: "remote-only",
                type: .category,
                action: .suppressSound,
                isEnabled: true,
                priority: 10,
                category: .remote,
                reason: "Remote only"
            )
        ])

        let decision = filter.decision(for: SoundFilterInput(category: .permission, source: "codex"))

        XCTAssertTrue(decision.isAllowed)
        XCTAssertEqual(decision.category, .permission)
        XCTAssertNil(decision.matchedRuleId)
        XCTAssertNil(decision.reason)
    }

    private struct SoundFilterDecisionFixture: Codable, Equatable {
        let highPrioritySourceSuppress: SoundFilterDecision
        let lowerPriorityCategoryAllow: SoundFilterDecision
        let lifecycleSubagentSuppress: SoundFilterDecision
        let noRuleAllow: SoundFilterDecision
    }
}
