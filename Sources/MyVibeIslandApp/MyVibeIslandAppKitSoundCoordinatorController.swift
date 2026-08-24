import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSoundCoordinatorController {
    public private(set) var lastPlan: SoundCoordinatorPlan?

    private let planSound: @MainActor (SoundCoordinatorRequest) -> SoundCoordinatorPlan
    private let playSound: @MainActor (SoundManagerPlaybackPlan) -> Void
    private let recordSkippedSound: @MainActor (SoundCoordinatorSkippedReason) -> Void

    public init(
        coordinator: SoundCoordinator = SoundCoordinator(),
        playSound: @escaping @MainActor (SoundManagerPlaybackPlan) -> Void = { _ in },
        recordSkippedSound: @escaping @MainActor (SoundCoordinatorSkippedReason) -> Void = { _ in }
    ) {
        planSound = coordinator.planSound
        self.playSound = playSound
        self.recordSkippedSound = recordSkippedSound
    }

    public init(
        planSound: @escaping @MainActor (SoundCoordinatorRequest) -> SoundCoordinatorPlan,
        playSound: @escaping @MainActor (SoundManagerPlaybackPlan) -> Void = { _ in },
        recordSkippedSound: @escaping @MainActor (SoundCoordinatorSkippedReason) -> Void = { _ in }
    ) {
        self.planSound = planSound
        self.playSound = playSound
        self.recordSkippedSound = recordSkippedSound
    }

    public convenience init(
        coordinator: SoundCoordinator = SoundCoordinator(),
        playbackController: MyVibeIslandAppKitSoundPlaybackController
    ) {
        self.init(
            coordinator: coordinator,
            playSound: { plan in
                playbackController.apply(plan)
            },
            recordSkippedSound: { _ in }
        )
    }

    @discardableResult
    public func handle(_ request: SoundCoordinatorRequest) -> SoundCoordinatorPlan {
        let plan = planSound(request)
        lastPlan = plan

        switch plan.action {
        case .playSound:
            if let playbackPlan = plan.playbackPlan {
                playSound(playbackPlan)
            }
        case .skipSound:
            if let reason = plan.skippedReason {
                recordSkippedSound(reason)
            }
        }

        return plan
    }
}
