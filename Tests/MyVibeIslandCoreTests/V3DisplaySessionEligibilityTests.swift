import XCTest
@testable import MyVibeIslandCore

final class V3DisplaySessionEligibilityTests: XCTestCase {
    func testResolverMergesEveryMatchedRuleActionAndKeepsMatchOrder() {
        let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let session = AgentSession(
            id: "display-session",
            source: "codex",
            cwd: "/repo",
            activeTool: "Bash",
            firstUserMessage: "Investigate this issue"
        )
        let rules = [
            V3SilenceRule(
                id: first,
                isEnabled: true,
                matchers: [.init(field: .firstUserPrompt, matchType: .contains, pattern: "Investigate")],
                action: .init(hidePanel: true, muteSound: false, suppressExpand: false, autoDismissOnStop: false)
            ),
            V3SilenceRule(
                id: second,
                isEnabled: true,
                matchers: [.init(field: .toolName, matchType: .equals, pattern: "Bash")],
                action: .init(hidePanel: false, muteSound: true, suppressExpand: true, autoDismissOnStop: true)
            ),
        ]

        XCTAssertEqual(
            V3SensoryPolicyResolver(rules: rules).resolve(for: session),
            V3SensoryPolicy(
                hidePanel: true,
                muteSound: true,
                suppressExpand: true,
                autoDismissOnStop: true,
                matchedRuleIds: [first, second]
            )
        )
    }

    func testEligibilityCarriesSessionPolicyAndEventShellWithoutTurningItIntoAListFilter() {
        let session = AgentSession(id: "visible", source: "codex", cwd: "/repo")
        let policy = V3SensoryPolicy(
            hidePanel: true,
            muteSound: false,
            suppressExpand: true,
            autoDismissOnStop: false,
            matchedRuleIds: []
        )

        let eligibility = V3DisplaySessionEligibility(
            session: session,
            policy: policy,
            usedEventShell: true
        )

        XCTAssertEqual(eligibility.session, session)
        XCTAssertEqual(eligibility.policy, policy)
        XCTAssertTrue(eligibility.usedEventShell)
        XCTAssertTrue(eligibility.isHidden)
    }

    func testDisabledRuleDoesNotContributeToPolicy() {
        let session = AgentSession(id: "session", source: "codex", cwd: "/repo")
        let rule = V3SilenceRule(
            id: UUID(),
            isEnabled: false,
            matchers: [.init(field: .cli, matchType: .equals, pattern: "codex")],
            action: .init(hidePanel: true, muteSound: true, suppressExpand: true, autoDismissOnStop: true)
        )

        XCTAssertEqual(
            V3SensoryPolicyResolver(rules: [rule]).resolve(for: session),
            .none
        )
    }
}
