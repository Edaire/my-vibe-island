import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSoundExecutorTests: XCTestCase {
    @MainActor
    func testCompletionSystemPlanUsesBundledDownloadedMP3() {
        var urls: [URL] = []
        let executor = MyVibeIslandAppKitSoundExecutor(
            playCustomSound: { url, _ in
                urls.append(url)
                return true
            },
            playSystemSound: { _, _ in XCTFail("Bundled completion MP3 should be used") }
        )

        XCTAssertTrue(executor.execute(SoundManagerPlaybackPlan(
            action: .playAppleSystem,
            category: .completion,
            sourceKind: .appleSystem,
            effectiveVolume: 1
        )))

        XCTAssertEqual(urls.map(\.lastPathComponent), ["3424.mp3"])
    }

    @MainActor
    func testBuiltinPlanSynthesizesRecoveredCategoryAndAppliesVolume() {
        var outputs: [(SynthesizedSound, Float)] = []
        let executor = MyVibeIslandAppKitSoundExecutor(
            playPCM: { outputs.append(($0, $1)) },
            playSystemSound: { _, _ in XCTFail("Unexpected system sound") }
        )
        let plan = SoundManagerPlaybackPlan(
            action: .playBuiltin8bit,
            category: .completion,
            sourceKind: .builtin8bit,
            effectiveVolume: 0.65
        )

        XCTAssertTrue(executor.execute(plan))
        XCTAssertEqual(outputs.count, 1)
        XCTAssertEqual(outputs[0].0, SoundSynthesizer().synthesize(category: .taskComplete))
        XCTAssertEqual(outputs[0].1, 0.65, accuracy: 0.0001)
    }

    @MainActor
    func testSuppressionAndCooldownDoNotEmitAudio() {
        var now: TimeInterval = 10
        var outputCount = 0
        let executor = MyVibeIslandAppKitSoundExecutor(
            now: { now },
            playPCM: { _, _ in outputCount += 1 },
            playSystemSound: { _, _ in outputCount += 1 }
        )
        let playable = SoundManagerPlaybackPlan(
            action: .playBuiltin8bit,
            category: .permission,
            sourceKind: .builtin8bit,
            effectiveVolume: 1,
            cooldownSeconds: 5
        )

        XCTAssertFalse(executor.execute(SoundManagerPlaybackPlan(
            action: .suppressSound,
            category: .permission,
            suppressedReason: .quietHours
        )))
        XCTAssertTrue(executor.execute(playable))
        now = 12
        XCTAssertFalse(executor.execute(playable))
        now = 15
        XCTAssertTrue(executor.execute(playable))
        XCTAssertEqual(outputCount, 2)
    }

    @MainActor
    func testAppleAndMissingCustomPlansUseSystemOutput() {
        var sounds: [(String, Float)] = []
        let executor = MyVibeIslandAppKitSoundExecutor(
            playPCM: { _, _ in XCTFail("Unexpected PCM") },
            playSystemSound: { sounds.append(($0, $1)) }
        )

        XCTAssertTrue(executor.execute(SoundManagerPlaybackPlan(
            action: .playAppleSystem,
            category: .question,
            sourceKind: .appleSystem,
            soundId: "Ping",
            effectiveVolume: 0.4
        )))
        XCTAssertTrue(executor.execute(SoundManagerPlaybackPlan(
            action: .fallbackToSystemSound,
            category: .failure,
            sourceKind: .custom,
            effectiveVolume: 0.7,
            suppressedReason: .missingCustomSound
        )))

        XCTAssertEqual(sounds.map(\.0), ["Ping", "Basso"])
        XCTAssertEqual(sounds.map(\.1), [0.4, 0.7])
    }

    @MainActor
    func testCustomPlanResolvesAndUsesCustomAudioOutput() throws {
        let url = URL(fileURLWithPath: "/tmp/custom.wav")
        var customOutputs: [(URL, Float)] = []
        let executor = MyVibeIslandAppKitSoundExecutor(
            resolveCustomSound: { $0 == "custom-1" ? url : nil },
            playCustomSound: { customOutputs.append(($0, $1)); return true },
            playPCM: { _, _ in XCTFail("Unexpected PCM") },
            playSystemSound: { _, _ in XCTFail("Unexpected system sound") }
        )

        XCTAssertTrue(executor.execute(SoundManagerPlaybackPlan(
            action: .playCustomSound,
            category: .completion,
            sourceKind: .custom,
            soundId: "custom-1",
            effectiveVolume: 0.55
        )))

        XCTAssertEqual(customOutputs.count, 1)
        XCTAssertEqual(customOutputs.first?.0, url)
        XCTAssertEqual(try XCTUnwrap(customOutputs.first?.1), 0.55, accuracy: 0.0001)
    }
}
