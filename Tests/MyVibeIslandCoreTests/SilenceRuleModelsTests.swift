import XCTest
@testable import MyVibeIslandCore

final class SilenceRuleModelsTests: XCTestCase {
    func testSilenceRuleMatcherMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SilenceRuleMatcherMatrixFixture.self,
            from: try FixtureLoader.data("notifications/silence-rule-matcher-matrix")
        )
        let input = NotificationPolicyInput(
            category: .questionAsked,
            sessionId: "session-1",
            agent: "codex",
            workspace: "/Users/<user>/project",
            timeWindowKey: "weekday-morning"
        )
        let rules = [
            SilenceRule(
                id: "category-question",
                enabled: true,
                matcher: SilenceMatcher(scope: .category, target: "questionAsked"),
                action: SilenceAction(suppressesPeek: true, suppressesSound: false),
                createdAt: "2026-07-08T08:00:00Z"
            ),
            SilenceRule(
                id: "agent-codex",
                enabled: true,
                matcher: SilenceMatcher(scope: .agent, target: "codex"),
                action: SilenceAction(suppressesPeek: true, suppressesSound: true),
                createdAt: "2026-07-08T08:01:00Z"
            ),
            SilenceRule(
                id: "workspace-project",
                enabled: true,
                matcher: SilenceMatcher(scope: .workspace, target: "/Users/<user>/project"),
                action: SilenceAction(suppressesPeek: false, suppressesSound: true),
                createdAt: "2026-07-08T08:02:00Z"
            ),
            SilenceRule(
                id: "session-one",
                enabled: true,
                matcher: SilenceMatcher(scope: .session, target: "session-1"),
                action: SilenceAction(suppressesPeek: true, suppressesSound: true),
                createdAt: "2026-07-08T08:03:00Z"
            ),
            SilenceRule(
                id: "weekday-morning",
                enabled: true,
                matcher: SilenceMatcher(scope: .timeWindow, target: "weekday-morning"),
                action: SilenceAction(suppressesPeek: false, suppressesSound: true),
                expiresAt: "2026-07-08T12:00:00Z",
                createdAt: "2026-07-08T08:04:00Z"
            ),
            SilenceRule(
                id: "disabled-agent",
                enabled: false,
                matcher: SilenceMatcher(scope: .agent, target: "codex"),
                action: SilenceAction(suppressesPeek: true, suppressesSound: true),
                createdAt: "2026-07-08T08:05:00Z"
            ),
            SilenceRule(
                id: "agent-claude",
                enabled: true,
                matcher: SilenceMatcher(scope: .agent, target: "claude"),
                action: SilenceAction(suppressesPeek: true, suppressesSound: true),
                createdAt: "2026-07-08T08:06:00Z"
            ),
        ]

        let actual = SilenceRuleMatcherMatrixFixture(
            input: input,
            rows: rules.map { rule in
                SilenceRuleMatcherMatrixRow(
                    id: rule.id,
                    scope: rule.matcher.scope,
                    target: rule.matcher.target,
                    enabled: rule.enabled,
                    matcherMatches: rule.matcher.matches(input),
                    effectiveMatch: rule.enabled && rule.matcher.matches(input),
                    suppressesPeek: rule.action.suppressesPeek,
                    suppressesSound: rule.action.suppressesSound,
                    expiresAt: rule.expiresAt
                )
            }
        )

        XCTAssertEqual(actual, expected)
    }

    func testSilenceRuleRoundTripsMatcherAndAction() throws {
        let rule = SilenceRule(
            id: "rule-1",
            enabled: true,
            matcher: SilenceMatcher(scope: .agent, target: "codex"),
            action: SilenceAction(suppressesPeek: true, suppressesSound: false),
            expiresAt: "2026-07-08T09:00:00Z",
            createdAt: "2026-07-08T08:00:00Z"
        )

        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(SilenceRule.self, from: data)

        XCTAssertEqual(decoded, rule)
        XCTAssertEqual(decoded.matcher.scope, .agent)
        XCTAssertTrue(decoded.action.suppressesPeek)
    }

    func testSilenceMatcherMatchesCategoryAgentWorkspaceAndSession() {
        let input = NotificationPolicyInput(
            category: .questionAsked,
            sessionId: "session-1",
            agent: "codex",
            workspace: "/Users/<user>/project"
        )

        XCTAssertTrue(SilenceMatcher(scope: .category, target: "questionAsked").matches(input))
        XCTAssertTrue(SilenceMatcher(scope: .agent, target: "codex").matches(input))
        XCTAssertTrue(SilenceMatcher(scope: .workspace, target: "/Users/<user>/project").matches(input))
        XCTAssertTrue(SilenceMatcher(scope: .session, target: "session-1").matches(input))
        XCTAssertFalse(SilenceMatcher(scope: .agent, target: "claude").matches(input))
    }

    func testNotificationPolicyAppliesEnabledSilenceRulesWithoutResolvingBlockingEvent() {
        let policy = NotificationPolicy()
        let input = NotificationPolicyInput(
            category: .permissionRequested,
            agent: "codex",
            silenceRules: [
                SilenceRule(
                    id: "silence-codex",
                    enabled: true,
                    matcher: SilenceMatcher(scope: .agent, target: "codex"),
                    action: SilenceAction(suppressesPeek: true, suppressesSound: true),
                    createdAt: "2026-07-08T08:00:00Z"
                )
            ]
        )

        let decision = policy.decision(for: input)

        XCTAssertEqual(decision.route, .updateUnreadOnly)
        XCTAssertFalse(decision.shouldPlaySound)
        XCTAssertTrue(decision.shouldMarkUnread)
        XCTAssertEqual(decision.reason, .silenceRuleMatched)
    }

    private struct SilenceRuleMatcherMatrixFixture: Codable, Equatable {
        let input: NotificationPolicyInput
        let rows: [SilenceRuleMatcherMatrixRow]
    }

    private struct SilenceRuleMatcherMatrixRow: Codable, Equatable {
        let id: String
        let scope: SilenceRuleScope
        let target: String
        let enabled: Bool
        let matcherMatches: Bool
        let effectiveMatch: Bool
        let suppressesPeek: Bool
        let suppressesSound: Bool
        let expiresAt: String?
    }
}
