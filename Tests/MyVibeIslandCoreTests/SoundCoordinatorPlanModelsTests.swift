import XCTest
@testable import MyVibeIslandCore

final class SoundCoordinatorPlanModelsTests: XCTestCase {
    func testSoundCoordinatorPlansMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SoundCoordinatorPlanFixture.self,
            from: try FixtureLoader.data("sound/coordinator-plans")
        )
        let coordinator = SoundCoordinator(soundManager: SoundManager())

        let actual = SoundCoordinatorPlanFixture(
            permissionPlay: coordinator.planSound(for: SoundCoordinatorRequest(
                notificationInput: NotificationPolicyInput(category: .permissionRequested, agent: "codex"),
                minuteOfDay: 12 * 60
            )),
            completionMuted: coordinator.planSound(for: SoundCoordinatorRequest(
                notificationInput: NotificationPolicyInput(category: .sessionCompleted, agent: "codex"),
                minuteOfDay: 12 * 60
            )),
            silenceRuleMuted: coordinator.planSound(for: SoundCoordinatorRequest(
                notificationInput: NotificationPolicyInput(
                    category: .permissionRequested,
                    agent: "codex",
                    silenceRules: [
                        SilenceRule(
                            id: "silence-codex",
                            enabled: true,
                            matcher: SilenceMatcher(scope: .agent, target: "codex"),
                            action: SilenceAction(suppressesPeek: false, suppressesSound: true),
                            createdAt: "2026-07-08T08:00:00Z"
                        ),
                    ]
                ),
                minuteOfDay: 12 * 60
            ))
        )

        XCTAssertEqual(actual, expected)
    }

    func testSoundCoordinatorPlanRoundTripsDecisionAndPlaybackPlan() throws {
        let plan = SoundCoordinatorPlan(
            action: .playSound,
            notificationDecision: NotificationPolicyDecision(
                route: .showPeek,
                shouldPlaySound: true,
                shouldMarkUnread: true,
                reason: .defaultPolicy
            ),
            soundCategory: .permission,
            playbackPlan: SoundManagerPlaybackPlan(
                action: .playBuiltin8bit,
                category: .permission,
                sourceKind: .builtin8bit,
                soundId: "builtin8bit.permission",
                effectiveVolume: 1,
                cooldownSeconds: 0
            ),
            skippedReason: nil
        )

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(SoundCoordinatorPlan.self, from: data)

        XCTAssertEqual(decoded, plan)
        XCTAssertEqual(decoded.soundCategory, .permission)
    }

    func testSoundCoordinatorMapsNotificationEventToSoundManagerPlayback() {
        let coordinator = SoundCoordinator(soundManager: SoundManager())
        let plan = coordinator.planSound(for: SoundCoordinatorRequest(
            notificationInput: NotificationPolicyInput(category: .permissionRequested, agent: "codex"),
            minuteOfDay: 12 * 60
        ))

        XCTAssertEqual(plan.action, .playSound)
        XCTAssertEqual(plan.soundCategory, .permission)
        XCTAssertEqual(plan.playbackPlan?.action, .playBuiltin8bit)
        XCTAssertEqual(plan.playbackPlan?.soundId, "builtin8bit.permission")
    }

    func testSoundCoordinatorSkipsWhenSilenceRuleDoesNotPlaySound() {
        let coordinator = SoundCoordinator(soundManager: SoundManager())
        let plan = coordinator.planSound(for: SoundCoordinatorRequest(
            notificationInput: NotificationPolicyInput(
                category: .sessionCompleted,
                agent: "codex",
                silenceRules: [
                    SilenceRule(
                        id: "silence-completion",
                        enabled: true,
                        matcher: SilenceMatcher(scope: .agent, target: "codex"),
                        action: SilenceAction(suppressesPeek: false, suppressesSound: true),
                        createdAt: "2026-07-08T08:00:00Z"
                    )
                ]
            ),
            minuteOfDay: 12 * 60
        ))

        XCTAssertEqual(plan.action, .skipSound)
        XCTAssertEqual(plan.skippedReason, .notificationPolicyMuted)
        XCTAssertNil(plan.playbackPlan)
    }

    func testSoundCoordinatorHonorsSilenceRulesWithoutResolvingBlockingEvent() {
        let coordinator = SoundCoordinator(soundManager: SoundManager())
        let plan = coordinator.planSound(for: SoundCoordinatorRequest(
            notificationInput: NotificationPolicyInput(
                category: .permissionRequested,
                agent: "codex",
                silenceRules: [
                    SilenceRule(
                        id: "silence-codex",
                        enabled: true,
                        matcher: SilenceMatcher(scope: .agent, target: "codex"),
                        action: SilenceAction(suppressesPeek: false, suppressesSound: true),
                        createdAt: "2026-07-08T08:00:00Z"
                    ),
                ]
            ),
            minuteOfDay: 12 * 60
        ))

        XCTAssertEqual(plan.action, .skipSound)
        XCTAssertEqual(plan.notificationDecision.reason, .silenceRuleMatched)
        XCTAssertEqual(plan.skippedReason, .notificationPolicyMuted)
    }

    private struct SoundCoordinatorPlanFixture: Codable, Equatable {
        let permissionPlay: SoundCoordinatorPlan
        let completionMuted: SoundCoordinatorPlan
        let silenceRuleMuted: SoundCoordinatorPlan
    }
}
