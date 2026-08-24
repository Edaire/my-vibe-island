import XCTest
@testable import MyVibeIslandCore

final class NotificationPolicyModelsTests: XCTestCase {
    func testNotificationPolicyDecisionsMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            NotificationPolicyDecisionFixture.self,
            from: try FixtureLoader.data("notifications/policy-decisions")
        )
        let policy = NotificationPolicy()

        let actual = NotificationPolicyDecisionFixture(
            permissionDefault: policy.decision(for: NotificationPolicyInput(category: .permissionRequested)),
            completionDefault: policy.decision(for: NotificationPolicyInput(category: .sessionCompleted)),
            activityDefault: policy.decision(for: NotificationPolicyInput(category: .activityUpdate)),
            usageLimitDefault: policy.decision(for: NotificationPolicyInput(category: .usageLimit)),
            recentlyRevealed: policy.decision(for: NotificationPolicyInput(
                category: .integrationRepairNeeded,
                dedupeKey: "integrationRepair:codex:hash",
                recentRevealKeys: ["integrationRepair:codex:hash"]
            )),
            silencePeekAndSound: policy.decision(for: NotificationPolicyInput(
                category: .permissionRequested,
                agent: "codex",
                silenceRules: [
                    SilenceRule(
                        id: "silence-codex",
                        enabled: true,
                        matcher: SilenceMatcher(scope: .agent, target: "codex"),
                        action: SilenceAction(suppressesPeek: true, suppressesSound: true),
                        createdAt: "2026-07-08T08:00:00Z"
                    ),
                ]
            )),
            silenceSoundOnly: policy.decision(for: NotificationPolicyInput(
                category: .questionAsked,
                workspace: "/Users/<user>/project",
                silenceRules: [
                    SilenceRule(
                        id: "silence-workspace-sound",
                        enabled: true,
                        matcher: SilenceMatcher(scope: .workspace, target: "/Users/<user>/project"),
                        action: SilenceAction(suppressesPeek: false, suppressesSound: true),
                        createdAt: "2026-07-08T08:00:00Z"
                    ),
                ]
            ))
        )

        XCTAssertEqual(actual, expected)
    }

    func testPeekNotificationRoundTripsCoreFields() throws {
        let peek = PeekNotification(
            id: "peek-1",
            category: .questionAsked,
            sessionId: "session-1",
            agent: "codex",
            title: "Question",
            body: "Agent needs input",
            severity: .blocking,
            primaryAction: .answer,
            secondaryAction: .dismiss,
            createdAt: "2026-07-08T08:00:00Z",
            expiresAt: "2026-07-08T08:01:00Z",
            dwellSeconds: 8,
            dedupeKey: "question:session-1",
            soundCategory: .question,
            source: "runtime"
        )

        let data = try JSONEncoder().encode(peek)
        let decoded = try JSONDecoder().decode(PeekNotification.self, from: data)

        XCTAssertEqual(decoded, peek)
        XCTAssertEqual(decoded.primaryAction, .answer)
        XCTAssertEqual(decoded.soundCategory, .question)
        XCTAssertNil(decoded.rootResponseEffect)
    }

    func testPeekNotificationRoundTripsRootResponseEffect() throws {
        let peek = PeekNotification(
            id: "completion-1",
            category: .sessionCompleted,
            title: "Done",
            body: "Finished",
            severity: .info,
            createdAt: "2026-08-19T00:00:00Z",
            dwellSeconds: 8,
            soundCategory: .completion,
            source: "codex",
            rootResponseEffect: .revealFinal
        )

        let decoded = try JSONDecoder().decode(
            PeekNotification.self,
            from: try JSONEncoder().encode(peek)
        )

        XCTAssertEqual(decoded.rootResponseEffect, .revealFinal)
    }

    func testReplacingSoundCategoryPreservesRootResponseAndPresentationFields() {
        let notification = PeekNotification(
            id: "completion-1",
            category: .sessionCompleted,
            sessionId: "session-1",
            title: "Done",
            body: "Finished",
            severity: .info,
            createdAt: "now",
            dwellSeconds: 8,
            dedupeKey: "completion-1",
            soundCategory: .completion,
            source: "codex",
            rootResponseEffect: .revealProgress
        )

        let silent = notification.replacingSoundCategory(nil)

        XCTAssertNil(silent.soundCategory)
        XCTAssertEqual(silent.rootResponseEffect, .revealProgress)
        XCTAssertEqual(silent.title, notification.title)
        XCTAssertEqual(silent.body, notification.body)
        XCTAssertEqual(silent.dedupeKey, notification.dedupeKey)
    }

    func testNotchPeekNotificationBuildsRowWithoutRawBodyWhenCompact() {
        let peek = PeekNotification(
            id: "peek-1",
            category: .permissionRequested,
            sessionId: "session-1",
            agent: "codex",
            title: "Permission",
            body: "Agent wants to run a command",
            severity: .blocking,
            primaryAction: .approve,
            secondaryAction: .deny,
            createdAt: "2026-07-08T08:00:00Z",
            dwellSeconds: 8,
            soundCategory: .permission,
            source: "runtime"
        )

        let notch = NotchPeekNotification(notification: peek, presentation: .compact)
        let row = PeekNotificationRow(notification: notch)

        XCTAssertEqual(notch.presentation, .compact)
        XCTAssertEqual(row.id, "peek-1")
        XCTAssertEqual(row.title, "Permission")
        XCTAssertNil(row.body)
        XCTAssertEqual(row.focusedField, .primaryAction)
    }

    func testPeekNotificationRowKeepsBodyForExpandedPresentation() {
        let peek = PeekNotification(
            id: "peek-2",
            category: .questionAsked,
            title: "Question",
            body: "Choose an option",
            severity: .blocking,
            primaryAction: .answer,
            createdAt: "2026-07-08T08:00:00Z",
            dwellSeconds: 10,
            source: "runtime"
        )

        let row = PeekNotificationRow(notification: NotchPeekNotification(
            notification: peek,
            presentation: .expanded,
            focusedField: .body
        ))

        XCTAssertEqual(row.body, "Choose an option")
        XCTAssertEqual(row.focusedField, .body)
    }

    func testNotificationPolicyRoutesDefaultBlockingCompletionAndActivityEvents() {
        let policy = NotificationPolicy()

        let permission = policy.decision(for: NotificationPolicyInput(category: .permissionRequested))
        XCTAssertEqual(permission.route, .showPeek)
        XCTAssertTrue(permission.shouldPlaySound)
        XCTAssertTrue(permission.shouldMarkUnread)

        let completion = policy.decision(for: NotificationPolicyInput(category: .sessionCompleted))
        XCTAssertEqual(completion.route, .showPeek)
        XCTAssertTrue(completion.shouldPlaySound)
        XCTAssertTrue(completion.shouldMarkUnread)

        let activity = policy.decision(for: NotificationPolicyInput(category: .activityUpdate))
        XCTAssertEqual(activity.route, .suppressEntirely)
        XCTAssertFalse(activity.shouldPlaySound)
        XCTAssertFalse(activity.shouldMarkUnread)
    }

    func testNotificationPolicySuppressesRepeatedRevealKeysForPeekOnly() {
        let policy = NotificationPolicy()
        let input = NotificationPolicyInput(
            category: .integrationRepairNeeded,
            dedupeKey: "integrationRepair:codex:hash",
            recentRevealKeys: ["integrationRepair:codex:hash"]
        )

        let decision = policy.decision(for: input)

        XCTAssertEqual(decision.route, .suppressEntirely)
        XCTAssertFalse(decision.shouldPlaySound)
        XCTAssertFalse(decision.shouldMarkUnread)
        XCTAssertEqual(decision.reason, .recentlyRevealed)
    }

    private struct NotificationPolicyDecisionFixture: Codable, Equatable {
        let permissionDefault: NotificationPolicyDecision
        let completionDefault: NotificationPolicyDecision
        let activityDefault: NotificationPolicyDecision
        let usageLimitDefault: NotificationPolicyDecision
        let recentlyRevealed: NotificationPolicyDecision
        let silencePeekAndSound: NotificationPolicyDecision
        let silenceSoundOnly: NotificationPolicyDecision
    }
}
