import XCTest
@testable import MyVibeIslandCore

final class SoundSynthesizerTests: XCTestCase {
    func testAllCategoriesProduceDeterministicDistinctClampedMonoBuffers() {
        let synthesizer = SoundSynthesizer()
        let sounds = SoundCategory.allCases.map { synthesizer.synthesize(category: $0) }

        XCTAssertTrue(sounds.allSatisfy { $0.sampleRate == 48_000 })
        XCTAssertTrue(sounds.allSatisfy { $0.channels == 1 })
        XCTAssertTrue(sounds.allSatisfy { !$0.samples.isEmpty })
        XCTAssertTrue(sounds.flatMap(\.samples).allSatisfy { $0.isFinite && (-1 ... 1).contains($0) })
        XCTAssertEqual(Set(sounds.map { $0.samples.count }).count, 7)
        XCTAssertEqual(Set(sounds.map { fingerprint($0.samples) }).count, SoundCategory.allCases.count)
        for category in SoundCategory.allCases {
            XCTAssertEqual(
                synthesizer.synthesize(category: category),
                synthesizer.synthesize(category: category)
            )
        }
    }

    func testTaskAcknowledgeMatchesRecoveredDurationAndPulseRegions() {
        let sound = SoundSynthesizer().synthesize(category: .taskAcknowledge)

        XCTAssertEqual(sound.samples.count, 10_560)
        XCTAssertEqual(sound.samples[0], 0, accuracy: 0.0001)
        XCTAssertGreaterThan(peak(sound.samples, seconds: 0.004 ... 0.05), 0.25)
        XCTAssertGreaterThan(peak(sound.samples, seconds: 0.07 ... 0.16), 0.3)
        XCTAssertLessThan(peak(sound.samples, seconds: 0.205 ... 0.219), 0.15)
    }

    func testInputRequiredQuestionVariantDiffersFromStandard() {
        let synthesizer = SoundSynthesizer()

        XCTAssertNotEqual(
            synthesizer.synthesize(category: .inputRequired),
            synthesizer.synthesize(category: .inputRequired, questionVariant: true)
        )
    }

    private func peak(_ samples: [Float], seconds: ClosedRange<Double>) -> Float {
        let lower = max(0, Int(seconds.lowerBound * 48_000))
        let upper = min(samples.count, Int(seconds.upperBound * 48_000))
        return samples[lower ..< upper].map { abs($0) }.max() ?? 0
    }

    private func fingerprint(_ samples: [Float]) -> Int {
        samples.enumerated().reduce(into: 17) { result, item in
            guard item.offset.isMultiple(of: 97) else { return }
            result = result &* 31 &+ Int(item.element * 10_000)
        }
    }
}
