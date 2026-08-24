import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSoundPlaybackControllerTests: XCTestCase {
    @MainActor
    func testSoundPlaybackControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SoundPlaybackControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/sound-playback-controller-matrix")
        )

        let actual = SoundPlaybackControllerMatrixFixture(rows: [
            row(
                id: "play-builtin-sound",
                plan: SoundManagerPlaybackPlan(
                    action: .playBuiltin8bit,
                    category: .permission,
                    sourceKind: .builtin8bit,
                    soundId: "builtin8bit.permission",
                    effectiveVolume: 0.8
                )
            ),
            row(
                id: "suppress-quiet-hours",
                plan: SoundManagerPlaybackPlan(
                    action: .suppressSound,
                    category: .question,
                    suppressedReason: .quietHours
                )
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerPublishesPlayablePlanThroughInjectedClosure() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitSoundPlaybackController(
            playSound: { plan in
                events.append("play:\(plan.action.rawValue):\(plan.soundId ?? "none")")
            },
            recordSuppressedSound: { plan in
                events.append("suppress:\(plan.suppressedReason?.rawValue ?? "none")")
            }
        )
        let plan = SoundManagerPlaybackPlan(
            action: .playBuiltin8bit,
            category: .permission,
            sourceKind: .builtin8bit,
            soundId: "builtin8bit.permission",
            effectiveVolume: 0.8
        )

        controller.apply(plan)

        XCTAssertEqual(controller.lastAction, .play(plan))
        XCTAssertEqual(events, ["play:playBuiltin8bit:builtin8bit.permission"])
    }

    @MainActor
    func testControllerPublishesSuppressedPlanWithoutPlaying() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitSoundPlaybackController(
            playSound: { _ in
                events.append("play")
            },
            recordSuppressedSound: { plan in
                events.append("suppress:\(plan.suppressedReason?.rawValue ?? "none")")
            }
        )
        let plan = SoundManagerPlaybackPlan(
            action: .suppressSound,
            category: .question,
            suppressedReason: .quietHours
        )

        controller.apply(plan)

        XCTAssertEqual(controller.lastAction, .suppress(plan))
        XCTAssertEqual(events, ["suppress:quietHours"])
    }

    @MainActor
    private func row(
        id: String,
        plan: SoundManagerPlaybackPlan
    ) -> SoundPlaybackControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitSoundPlaybackController(
            playSound: { events.append("play:\($0.action.rawValue):\($0.soundId ?? "none")") },
            recordSuppressedSound: { events.append("suppress:\($0.suppressedReason?.rawValue ?? "none")") }
        )
        controller.apply(plan)

        let lastAction: String?
        switch controller.lastAction {
        case .play: lastAction = "play"
        case .suppress: lastAction = "suppress"
        case nil: lastAction = nil
        }

        return SoundPlaybackControllerMatrixRow(
            id: id,
            planAction: plan.action.rawValue,
            category: plan.category.rawValue,
            soundId: plan.soundId,
            effectiveVolume: plan.effectiveVolume,
            suppressedReason: plan.suppressedReason?.rawValue,
            lastAction: lastAction,
            events: events
        )
    }
}

private struct SoundPlaybackControllerMatrixFixture: Codable, Equatable {
    let rows: [SoundPlaybackControllerMatrixRow]
}

private struct SoundPlaybackControllerMatrixRow: Codable, Equatable {
    let id: String
    let planAction: String
    let category: String
    let soundId: String?
    let effectiveVolume: Double
    let suppressedReason: String?
    let lastAction: String?
    let events: [String]
}
