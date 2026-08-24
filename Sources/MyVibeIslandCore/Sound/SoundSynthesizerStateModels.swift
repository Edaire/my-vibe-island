import Foundation

public struct SoundSynthesizerState: Codable, Equatable, Sendable {
    public let isSetup: Bool
    public let outputVolume: Double
    public let queuedSoundIds: [String]
    public let generation: Int
    public let isIdleShutdownScheduled: Bool

    public init(
        isSetup: Bool = false,
        outputVolume: Double = 1,
        queuedSoundIds: [String] = [],
        generation: Int = 0,
        isIdleShutdownScheduled: Bool = false
    ) {
        self.isSetup = isSetup
        self.outputVolume = min(max(outputVolume, 0), 1)
        self.queuedSoundIds = queuedSoundIds
        self.generation = max(generation, 0)
        self.isIdleShutdownScheduled = isIdleShutdownScheduled
    }
}

public enum SoundSynthesizerCommand: Equatable, Sendable {
    case setup
    case enqueue(soundId: String)
    case updateVolume(Double)
    case scheduleIdleShutdown(expectedGeneration: Int)
}

public enum SoundSynthesizerPlanAction: String, Codable, Equatable, Sendable {
    case setup
    case enqueue
    case updateVolume
    case scheduleIdleShutdown
    case ignoreStaleGeneration
}

public struct SoundSynthesizerPlan: Codable, Equatable, Sendable {
    public let action: SoundSynthesizerPlanAction
    public let nextState: SoundSynthesizerState

    public init(action: SoundSynthesizerPlanAction, nextState: SoundSynthesizerState) {
        self.action = action
        self.nextState = nextState
    }
}

public struct SynthesizedSound: Equatable, Sendable {
    public let sampleRate: Double
    public let channels: Int
    public let samples: [Float]

    public init(sampleRate: Double, channels: Int = 1, samples: [Float]) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.samples = samples
    }
}

public struct SoundSynthesizer: Sendable {
    public let sampleRate: Double

    public init(sampleRate: Double = 48_000) {
        self.sampleRate = sampleRate
    }

    public func plan(
        _ command: SoundSynthesizerCommand,
        from state: SoundSynthesizerState
    ) -> SoundSynthesizerPlan {
        switch command {
        case .setup:
            return SoundSynthesizerPlan(
                action: .setup,
                nextState: SoundSynthesizerState(
                    isSetup: true,
                    outputVolume: state.outputVolume,
                    queuedSoundIds: state.queuedSoundIds,
                    generation: state.generation + 1,
                    isIdleShutdownScheduled: state.isIdleShutdownScheduled
                )
            )
        case let .enqueue(soundId):
            return SoundSynthesizerPlan(
                action: .enqueue,
                nextState: SoundSynthesizerState(
                    isSetup: state.isSetup,
                    outputVolume: state.outputVolume,
                    queuedSoundIds: state.queuedSoundIds + [soundId],
                    generation: state.generation + 1,
                    isIdleShutdownScheduled: false
                )
            )
        case let .updateVolume(volume):
            return SoundSynthesizerPlan(
                action: .updateVolume,
                nextState: SoundSynthesizerState(
                    isSetup: state.isSetup,
                    outputVolume: volume,
                    queuedSoundIds: state.queuedSoundIds,
                    generation: state.generation + 1,
                    isIdleShutdownScheduled: state.isIdleShutdownScheduled
                )
            )
        case let .scheduleIdleShutdown(expectedGeneration):
            if expectedGeneration != state.generation {
                return SoundSynthesizerPlan(action: .ignoreStaleGeneration, nextState: state)
            }

            return SoundSynthesizerPlan(
                action: .scheduleIdleShutdown,
                nextState: SoundSynthesizerState(
                    isSetup: state.isSetup,
                    outputVolume: state.outputVolume,
                    queuedSoundIds: state.queuedSoundIds,
                    generation: state.generation,
                    isIdleShutdownScheduled: true
                )
            )
        }
    }

    public func synthesize(
        category: SoundCategory,
        questionVariant: Bool = false
    ) -> SynthesizedSound {
        var samples = [Float](repeating: 0, count: Int(duration(for: category, questionVariant: questionVariant) * sampleRate))

        switch category {
        case .sessionStart:
            square(&samples, start: 0.02, duration: 0.10, frequency: 523.25, amplitude: 0.22)
            square(&samples, start: 0.10, duration: 0.20, frequency: 659.25, amplitude: 0.20)
            square(&samples, start: 0.20, duration: 0.20, frequency: 783.99, amplitude: 0.25)
            sine(&samples, start: 0.40, duration: 0.06, frequency: 261.63, amplitude: 0.20)
        case .taskAcknowledge:
            square(&samples, duration: 0.055, frequency: 987.76, amplitude: 0.20, attack: 0.004, release: 0.008)
            square(&samples, start: 0.06, duration: 0.12, frequency: 1_318.51, amplitude: 0.24, attack: 0.008, release: 0.018)
        case .taskComplete:
            square(&samples, start: 0.02, duration: 0.07, frequency: 659.25, amplitude: 0.20)
            square(&samples, start: 0.08, duration: 0.16, frequency: 783.99, amplitude: 0.25)
            square(&samples, start: 0.25, duration: 0.55, frequency: 1_046.50, amplitude: 0.22)
            sine(&samples, start: 0.80, duration: 0.10, frequency: 523.25, amplitude: 0.20, release: 0.04)
        case .taskError:
            square(&samples, start: 0.015, duration: 0.12, frequency: 130.81, amplitude: 0.20)
            square(&samples, start: 0.13, duration: 0.20, frequency: 87.305, amplitude: 0.40)
            noise(&samples, start: 0.10, duration: 0.30, amplitude: 0.12, seed: 3)
        case .inputRequired:
            if questionVariant {
                chirp(&samples, start: 0.008, duration: 0.30, from: 523.25, ratio: 1.259_914, amplitude: 0.20)
                square(&samples, start: 0.20, duration: 0.10, frequency: 783.99, amplitude: 0.18)
            } else {
                square(&samples, start: 0.02, duration: 0.10, frequency: 523.25, amplitude: 0.20)
                square(&samples, start: 0.16, duration: 0.12, frequency: 698.46, amplitude: 0.22)
                square(&samples, start: 0.28, duration: 0.16, frequency: 880, amplitude: 0.21)
                sine(&samples, start: 0.38, duration: 0.16, frequency: 174.61, amplitude: 0.16, release: 0.03)
            }
        case .resourceLimit:
            sine(&samples, start: 0.003, duration: 0.06, frequency: 440, amplitude: 0.45, release: 0.01)
            sine(&samples, start: 0.07, duration: 0.28, frequency: 220, amplitude: 0.30, release: 0.06)
        case .userSpam:
            chirp(&samples, start: 0.008, duration: 0.15, from: 1_046.50, ratio: 0.25, amplitude: 0.20)
            square(&samples, start: 0.18, duration: 0.08, frequency: 329.63, amplitude: 0.15)
            square(&samples, start: 0.26, duration: 0.06, frequency: 196, amplitude: 0.10)
        case .idleReminder:
            sine(&samples, start: 0.01, duration: 0.09, frequency: 880, amplitude: 0.22)
            sine(&samples, start: 0.10, duration: 0.09, frequency: 1_046.50, amplitude: 0.28)
            sine(&samples, start: 0.22, duration: 0.08, frequency: 220, amplitude: 0.25, release: 0.025)
        case .usageWarning:
            square(&samples, start: 0.015, duration: 0.09, frequency: 392, amplitude: 0.18)
            square(&samples, start: 0.11, duration: 0.13, frequency: 396.704, amplitude: 0.10)
            square(&samples, start: 0.28, duration: 0.11, frequency: 329.63, amplitude: 0.20)
            square(&samples, start: 0.39, duration: 0.13, frequency: 333.586, amplitude: 0.11)
            sine(&samples, start: 0.52, duration: 0.13, frequency: 196, amplitude: 0.20, release: 0.04)
        case .usageReset:
            square(&samples, start: 0.018, duration: 0.07, frequency: 523.25, amplitude: 0.18)
            square(&samples, start: 0.08, duration: 0.08, frequency: 659.25, amplitude: 0.19)
            square(&samples, start: 0.16, duration: 0.08, frequency: 783.99, amplitude: 0.20)
            square(&samples, start: 0.24, duration: 0.10, frequency: 1_046.50, amplitude: 0.22)
            square(&samples, start: 0.35, duration: 0.10, frequency: 1_318.51, amplitude: 0.24)
            sine(&samples, start: 0.40, duration: 0.20, frequency: 261.63, amplitude: 0.18)
            sine(&samples, start: 0.40, duration: 0.20, frequency: 130.815, amplitude: 0.10)
        }

        for index in samples.indices {
            samples[index] = min(max(samples[index] * 1.5, -1), 1)
        }
        return SynthesizedSound(sampleRate: sampleRate, samples: samples)
    }

    private func duration(for category: SoundCategory, questionVariant: Bool) -> Double {
        switch category {
        case .sessionStart, .taskError, .resourceLimit: 0.5
        case .taskAcknowledge: 0.22
        case .taskComplete: 1.1
        case .inputRequired: questionVariant ? 0.4 : 0.6
        case .userSpam, .idleReminder: 0.35
        case .usageWarning: 0.7
        case .usageReset: 0.65
        }
    }

    private func square(
        _ samples: inout [Float],
        start: Double = 0,
        duration: Double,
        frequency: Double,
        amplitude: Float,
        attack: Double = 0.005,
        release: Double = 0.02
    ) {
        mix(&samples, start: start, duration: duration, attack: attack, release: release) { time in
            fmod(time * frequency, 1) < 0.5 ? amplitude : -amplitude
        }
    }

    private func sine(
        _ samples: inout [Float],
        start: Double,
        duration: Double,
        frequency: Double,
        amplitude: Float,
        attack: Double = 0.005,
        release: Double = 0.02
    ) {
        mix(&samples, start: start, duration: duration, attack: attack, release: release) { time in
            Float(sin(2 * Double.pi * frequency * time)) * amplitude
        }
    }

    private func chirp(
        _ samples: inout [Float],
        start: Double,
        duration: Double,
        from frequency: Double,
        ratio: Double,
        amplitude: Float
    ) {
        mix(&samples, start: start, duration: duration, attack: 0.008, release: 0.06) { time in
            let progress = min(max(time / duration, 0), 1)
            let current = frequency * pow(ratio, progress)
            return Float(sin(2 * Double.pi * current * time)) * amplitude
        }
    }

    private func noise(
        _ samples: inout [Float],
        start: Double,
        duration: Double,
        amplitude: Float,
        seed: UInt64
    ) {
        var state = seed
        mix(&samples, start: start, duration: duration, attack: 0.005, release: 0.06) { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let unit = Float((state >> 40) & 0xFFFFFF) / Float(0xFFFFFF)
            return (unit * 2 - 1) * amplitude
        }
    }

    private func mix(
        _ samples: inout [Float],
        start: Double,
        duration: Double,
        attack: Double,
        release: Double,
        signal: (Double) -> Float
    ) {
        let startIndex = max(0, Int(start * sampleRate))
        let count = max(0, Int(duration * sampleRate))
        let endIndex = min(samples.count, startIndex + count)
        guard startIndex < endIndex else { return }

        for index in startIndex ..< endIndex {
            let localTime = Double(index - startIndex) / sampleRate
            let remaining = duration - localTime
            let attackGain = attack > 0 ? min(localTime / attack, 1) : 1
            let releaseGain = release > 0 ? min(remaining / release, 1) : 1
            samples[index] += signal(localTime) * Float(max(0, min(attackGain, releaseGain)))
        }
    }
}
