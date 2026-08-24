import XCTest
@testable import MyVibeIslandCore

final class SoundSynthesizerStateModelsTests: XCTestCase {
    func testSoundSynthesizerPlansMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SoundSynthesizerPlanFixture.self,
            from: try FixtureLoader.data("sound/synthesizer-plans")
        )
        let synthesizer = SoundSynthesizer()
        let setupPlan = synthesizer.plan(.setup, from: SoundSynthesizerState())
        let enqueuePlan = synthesizer.plan(.enqueue(soundId: "permission.clean"), from: setupPlan.nextState)
        let volumePlan = synthesizer.plan(.updateVolume(0.25), from: enqueuePlan.nextState)
        let idlePlan = synthesizer.plan(
            .scheduleIdleShutdown(expectedGeneration: volumePlan.nextState.generation),
            from: volumePlan.nextState
        )
        let stalePlan = synthesizer.plan(
            .scheduleIdleShutdown(expectedGeneration: volumePlan.nextState.generation - 1),
            from: volumePlan.nextState
        )

        let actual = SoundSynthesizerPlanFixture(
            setup: setupPlan,
            enqueue: enqueuePlan,
            updateVolume: volumePlan,
            scheduleIdleShutdown: idlePlan,
            ignoreStaleGeneration: stalePlan
        )

        XCTAssertEqual(actual, expected)
    }

    func testSoundSynthesizerStateRoundTripsObservedLifecycleFields() throws {
        let state = SoundSynthesizerState(
            isSetup: true,
            outputVolume: 0.75,
            queuedSoundIds: ["permission.clean"],
            generation: 4,
            isIdleShutdownScheduled: true
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SoundSynthesizerState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.generation, 4)
    }

    func testSoundSynthesizerStateNormalizesVolumeAndGeneration() {
        let state = SoundSynthesizerState(outputVolume: 1.5, generation: -4)

        XCTAssertEqual(state.outputVolume, 1)
        XCTAssertEqual(state.generation, 0)
    }

    func testSoundSynthesizerPlansSetupEnqueueAndVolumeUpdate() {
        let synthesizer = SoundSynthesizer()
        let setupPlan = synthesizer.plan(.setup, from: SoundSynthesizerState())
        let enqueuePlan = synthesizer.plan(.enqueue(soundId: "permission.clean"), from: setupPlan.nextState)
        let volumePlan = synthesizer.plan(.updateVolume(0.25), from: enqueuePlan.nextState)

        XCTAssertEqual(setupPlan.action, .setup)
        XCTAssertTrue(setupPlan.nextState.isSetup)
        XCTAssertEqual(setupPlan.nextState.generation, 1)

        XCTAssertEqual(enqueuePlan.action, .enqueue)
        XCTAssertEqual(enqueuePlan.nextState.queuedSoundIds, ["permission.clean"])
        XCTAssertEqual(enqueuePlan.nextState.generation, 2)
        XCTAssertFalse(enqueuePlan.nextState.isIdleShutdownScheduled)

        XCTAssertEqual(volumePlan.action, .updateVolume)
        XCTAssertEqual(volumePlan.nextState.outputVolume, 0.25)
        XCTAssertEqual(volumePlan.nextState.generation, 3)
    }

    func testSoundSynthesizerPlansIdleShutdownAndIgnoresStaleGeneration() {
        let synthesizer = SoundSynthesizer()
        let state = SoundSynthesizerState(isSetup: true, generation: 3)

        let currentPlan = synthesizer.plan(.scheduleIdleShutdown(expectedGeneration: 3), from: state)
        let stalePlan = synthesizer.plan(.scheduleIdleShutdown(expectedGeneration: 2), from: state)

        XCTAssertEqual(currentPlan.action, .scheduleIdleShutdown)
        XCTAssertTrue(currentPlan.nextState.isIdleShutdownScheduled)
        XCTAssertEqual(currentPlan.nextState.generation, 3)

        XCTAssertEqual(stalePlan.action, .ignoreStaleGeneration)
        XCTAssertEqual(stalePlan.nextState, state)
    }

    private struct SoundSynthesizerPlanFixture: Codable, Equatable {
        let setup: SoundSynthesizerPlan
        let enqueue: SoundSynthesizerPlan
        let updateVolume: SoundSynthesizerPlan
        let scheduleIdleShutdown: SoundSynthesizerPlan
        let ignoreStaleGeneration: SoundSynthesizerPlan
    }
}
