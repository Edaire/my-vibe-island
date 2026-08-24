import Foundation
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSoundCoordinatorControllerTests: XCTestCase {
    @MainActor
    func testHandleUsesCurrentPlanProviderForEveryRequest() {
        let suiteName = "MyVibeIslandAppKitSoundCoordinatorControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SoundPreferencesStore(defaults: defaults)
        store.saveManagerSettings(SoundManagerSettings(isEnabled: true))
        let controller = MyVibeIslandAppKitSoundCoordinatorController(
            planSound: { request in
                SoundCoordinator(
                    soundManager: SoundManager(snapshot: store.loadManagerSnapshot())
                ).planSound(for: request)
            }
        )
        let request = SoundCoordinatorRequest(
            notificationInput: NotificationPolicyInput(
                category: .permissionRequested,
                agent: "codex"
            ),
            minuteOfDay: 12 * 60
        )

        XCTAssertEqual(controller.handle(request).playbackPlan?.action, .playBuiltin8bit)
        store.saveManagerSettings(SoundManagerSettings(isEnabled: false))
        XCTAssertEqual(controller.handle(request).playbackPlan?.action, .suppressSound)
    }
    @MainActor
    func testSoundCoordinatorControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SoundCoordinatorControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/sound-coordinator-controller-matrix")
        )

        let actual = SoundCoordinatorControllerMatrixFixture(rows: [
            row(id: "permission-plays-sound", category: .permissionRequested),
            row(id: "session-completed-plays-system-sound", category: .sessionCompleted)
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerPlaysSoundThroughInjectedClosureWhenPlanRequestsPlayback() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitSoundCoordinatorController(
            playSound: { playbackPlan in
                events.append("play:\(playbackPlan.soundId ?? "none"):\(playbackPlan.effectiveVolume)")
            },
            recordSkippedSound: { reason in
                events.append("skip:\(reason.rawValue)")
            }
        )

        let plan = controller.handle(SoundCoordinatorRequest(
            notificationInput: NotificationPolicyInput(category: .permissionRequested, agent: "codex"),
            minuteOfDay: 12 * 60
        ))

        XCTAssertEqual(plan.action, .playSound)
        XCTAssertEqual(plan.soundCategory, .permission)
        XCTAssertEqual(controller.lastPlan, plan)
        XCTAssertEqual(events, ["play:builtin8bit.permission:1.0"])
    }

    @MainActor
    func testControllerRecordsSilencedCompletionWithoutPlaying() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitSoundCoordinatorController(
            playSound: { playbackPlan in
                events.append("play:\(playbackPlan.soundId ?? "none")")
            },
            recordSkippedSound: { reason in
                events.append("skip:\(reason.rawValue)")
            }
        )

        let plan = controller.handle(SoundCoordinatorRequest(
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
        XCTAssertEqual(events, ["skip:notificationPolicyMuted"])
    }

    @MainActor
    func testControllerCanRoutePlaybackPlansThroughPlaybackBoundary() throws {
        var events: [String] = []
        let playbackController = MyVibeIslandAppKitSoundPlaybackController(
            playSound: { plan in
                events.append("play:\(plan.soundId ?? "none")")
            },
            recordSuppressedSound: { plan in
                events.append("suppress:\(plan.category.rawValue)")
            }
        )
        let controller = MyVibeIslandAppKitSoundCoordinatorController(
            playbackController: playbackController
        )

        let plan = controller.handle(SoundCoordinatorRequest(
            notificationInput: NotificationPolicyInput(category: .permissionRequested, agent: "codex"),
            minuteOfDay: 12 * 60
        ))

        XCTAssertEqual(playbackController.lastAction, .play(try XCTUnwrap(plan.playbackPlan)))
        XCTAssertEqual(events, ["play:builtin8bit.permission"])
    }

    @MainActor
    private func row(
        id: String,
        category: NotificationEventCategory
    ) -> SoundCoordinatorControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitSoundCoordinatorController(
            playSound: { events.append("play:\($0.soundId ?? "none"):\($0.effectiveVolume)") },
            recordSkippedSound: { events.append("skip:\($0.rawValue)") }
        )
        let plan = controller.handle(SoundCoordinatorRequest(
            notificationInput: NotificationPolicyInput(category: category, agent: "codex"),
            minuteOfDay: 12 * 60
        ))

        return SoundCoordinatorControllerMatrixRow(
            id: id,
            action: plan.action.rawValue,
            soundCategory: plan.soundCategory?.rawValue,
            soundId: plan.playbackPlan?.soundId,
            effectiveVolume: plan.playbackPlan?.effectiveVolume,
            skippedReason: plan.skippedReason?.rawValue,
            lastPlanAction: controller.lastPlan?.action.rawValue,
            events: events
        )
    }
}

private struct SoundCoordinatorControllerMatrixFixture: Codable, Equatable {
    let rows: [SoundCoordinatorControllerMatrixRow]
}

private struct SoundCoordinatorControllerMatrixRow: Codable, Equatable {
    let id: String
    let action: String
    let soundCategory: String?
    let soundId: String?
    let effectiveVolume: Double?
    let skippedReason: String?
    let lastPlanAction: String?
    let events: [String]
}
