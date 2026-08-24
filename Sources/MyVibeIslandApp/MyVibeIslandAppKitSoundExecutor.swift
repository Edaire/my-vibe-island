import AppKit
import AVFoundation
import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSoundExecutor {
    private let synthesizer: SoundSynthesizer
    private let now: () -> TimeInterval
    private let resolveCustomSound: (String) -> URL?
    private let playCustomSound: (URL, Float) -> Bool
    private let playPCM: (SynthesizedSound, Float) -> Void
    private let playSystemSound: (String, Float) -> Void
    private var lastPlayedAt: [NotificationSoundCategory: TimeInterval] = [:]

    public init(
        synthesizer: SoundSynthesizer = SoundSynthesizer(),
        now: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate },
        resolveCustomSound: @escaping (String) -> URL? = { _ in nil },
        playCustomSound: @escaping (URL, Float) -> Bool = { _, _ in false },
        playPCM: @escaping (SynthesizedSound, Float) -> Void = { _, _ in },
        playSystemSound: @escaping (String, Float) -> Void = { _, _ in }
    ) {
        self.synthesizer = synthesizer
        self.now = now
        self.resolveCustomSound = resolveCustomSound
        self.playCustomSound = playCustomSound
        self.playPCM = playPCM
        self.playSystemSound = playSystemSound
    }

    @discardableResult
    public func execute(_ plan: SoundManagerPlaybackPlan) -> Bool {
        guard plan.action != .suppressSound else {
            recordExecution(plan, result: "suppressed")
            return false
        }
        guard isOutsideCooldown(plan) else {
            recordExecution(plan, result: "cooldown")
            return false
        }

        let volume = Float(plan.effectiveVolume)
        switch plan.action {
        case .playBuiltin8bit:
            playPCM(
                synthesizer.synthesize(
                    category: SoundCategory(notificationCategory: plan.category),
                    questionVariant: plan.category == .question
                ),
                volume
            )
        case .playAppleSystem:
            if plan.category == .completion {
                let playedBundledSound = Bundle.module.url(
                    forResource: "3424",
                    withExtension: "mp3"
                ).map { playCustomSound($0, volume) } ?? false
                if !playedBundledSound {
                    playSystemSound(Self.defaultSystemSound(for: plan.category), volume)
                }
            } else {
                playSystemSound(plan.soundId ?? Self.defaultSystemSound(for: plan.category), volume)
            }
        case .playCustomSound:
            guard let soundId = plan.soundId,
                  let url = resolveCustomSound(soundId),
                  playCustomSound(url, volume) else {
                playSystemSound(Self.defaultSystemSound(for: plan.category), volume)
                break
            }
        case .fallbackToSystemSound:
            playSystemSound(Self.defaultSystemSound(for: plan.category), volume)
        case .suppressSound:
            recordExecution(plan, result: "suppressed")
            return false
        }

        lastPlayedAt[plan.category] = now()
        recordExecution(plan, result: "played")
        return true
    }

    private func recordExecution(_ plan: SoundManagerPlaybackPlan, result: String) {
        SessionCompletionTraceLog.append(
            stage: "sound.execute",
            sessionId: nil,
            metadata: [
                "result": result,
                "action": plan.action.rawValue,
                "category": plan.category.rawValue,
                "sourceKind": plan.sourceKind?.rawValue ?? "-",
                "soundId": plan.soundId ?? "-",
                "cooldownSeconds": String(plan.cooldownSeconds),
            ]
        )
    }

    public static func production() -> MyVibeIslandAppKitSoundExecutor {
        let pcmOutput = MyVibeIslandAVAudioOutput()
        let systemOutput = MyVibeIslandSystemSoundOutput()
        let customOutput = MyVibeIslandCustomSoundOutput()
        let library = CustomSoundLibraryStore(
            libraryDirectory: FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("My Vibe Island/Custom Sounds", isDirectory: true)
        )
        return MyVibeIslandAppKitSoundExecutor(
            resolveCustomSound: { soundId in
                guard let snapshot = try? library.loadSnapshot(),
                      let file = snapshot.files.first(where: { $0.id == soundId }) else {
                    return nil
                }
                return try? library.fileURL(forStoredFileName: file.storedFileName)
            },
            playCustomSound: customOutput.play,
            playPCM: { pcmOutput.play($0, volume: $1) },
            playSystemSound: { systemOutput.play(named: $0, volume: $1) }
        )
    }

    private func isOutsideCooldown(_ plan: SoundManagerPlaybackPlan) -> Bool {
        guard plan.cooldownSeconds > 0, let previous = lastPlayedAt[plan.category] else {
            return true
        }
        return now() - previous >= TimeInterval(plan.cooldownSeconds)
    }

    private static func defaultSystemSound(for category: NotificationSoundCategory) -> String {
        switch category {
        case .permission: "Ping"
        case .question: "Pop"
        case .completion: "Glass"
        case .failure: "Basso"
        case .warning: "Funk"
        case .usage: "Purr"
        case .remote: "Hero"
        }
    }
}

@MainActor
private final class MyVibeIslandCustomSoundOutput {
    private var current: AVAudioPlayer?

    func play(url: URL, volume: Float) -> Bool {
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return false }
        current?.stop()
        current = player
        player.volume = volume
        player.prepareToPlay()
        return player.play()
    }
}

@MainActor
private final class MyVibeIslandAVAudioOutput {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isConnected = false

    func play(_ sound: SynthesizedSound, volume: Float) {
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sound.sampleRate,
            channels: AVAudioChannelCount(sound.channels)
        ), let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(sound.samples.count)
        ), let channel = buffer.floatChannelData?.pointee else {
            return
        }

        buffer.frameLength = AVAudioFrameCount(sound.samples.count)
        sound.samples.withUnsafeBufferPointer { source in
            guard let baseAddress = source.baseAddress else { return }
            channel.update(from: baseAddress, count: sound.samples.count)
        }

        if !isConnected {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            isConnected = true
        }
        if !engine.isRunning {
            try? engine.start()
        }
        player.volume = volume
        player.scheduleBuffer(buffer)
        if !player.isPlaying {
            player.play()
        }
    }
}

@MainActor
private final class MyVibeIslandSystemSoundOutput {
    private var current: NSSound?

    func play(named name: String, volume: Float) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        current?.stop()
        current = sound
        sound.volume = volume
        sound.play()
    }
}
