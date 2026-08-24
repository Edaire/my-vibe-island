import MyVibeIslandCore

public enum MyVibeIslandAppKitSoundPlaybackAction: Equatable {
    case play(SoundManagerPlaybackPlan)
    case suppress(SoundManagerPlaybackPlan)
}

@MainActor
public final class MyVibeIslandAppKitSoundPlaybackController {
    public private(set) var lastAction: MyVibeIslandAppKitSoundPlaybackAction?
    public let usesConcreteExecutor: Bool

    private let playSound: @MainActor (SoundManagerPlaybackPlan) -> Void
    private let recordSuppressedSound: @MainActor (SoundManagerPlaybackPlan) -> Void

    public init(
        playSound: @escaping @MainActor (SoundManagerPlaybackPlan) -> Void = { _ in },
        recordSuppressedSound: @escaping @MainActor (SoundManagerPlaybackPlan) -> Void = { _ in },
        usesConcreteExecutor: Bool = false
    ) {
        self.playSound = playSound
        self.recordSuppressedSound = recordSuppressedSound
        self.usesConcreteExecutor = usesConcreteExecutor
    }

    public convenience init(executor: MyVibeIslandAppKitSoundExecutor) {
        self.init(
            playSound: { plan in _ = executor.execute(plan) },
            usesConcreteExecutor: true
        )
    }

    public func apply(_ plan: SoundManagerPlaybackPlan) {
        switch plan.action {
        case .playBuiltin8bit, .playAppleSystem, .playCustomSound, .fallbackToSystemSound:
            lastAction = .play(plan)
            playSound(plan)
        case .suppressSound:
            lastAction = .suppress(plan)
            recordSuppressedSound(plan)
        }
    }
}
