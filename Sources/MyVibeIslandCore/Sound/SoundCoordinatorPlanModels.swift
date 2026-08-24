import Foundation

public struct SoundCoordinatorRequest: Codable, Equatable, Sendable {
    public let notificationInput: NotificationPolicyInput
    public let minuteOfDay: Int

    public init(
        notificationInput: NotificationPolicyInput,
        minuteOfDay: Int
    ) {
        self.notificationInput = notificationInput
        self.minuteOfDay = min(max(minuteOfDay, 0), 1_439)
    }
}

public enum SoundCoordinatorAction: String, Codable, Equatable, Sendable {
    case playSound
    case skipSound
}

public enum SoundCoordinatorSkippedReason: String, Codable, Equatable, Sendable {
    case notificationPolicyMuted
    case unmappedEventCategory
}

public struct SoundCoordinatorPlan: Codable, Equatable, Sendable {
    public let action: SoundCoordinatorAction
    public let notificationDecision: NotificationPolicyDecision
    public let soundCategory: NotificationSoundCategory?
    public let playbackPlan: SoundManagerPlaybackPlan?
    public let skippedReason: SoundCoordinatorSkippedReason?

    public init(
        action: SoundCoordinatorAction,
        notificationDecision: NotificationPolicyDecision,
        soundCategory: NotificationSoundCategory? = nil,
        playbackPlan: SoundManagerPlaybackPlan? = nil,
        skippedReason: SoundCoordinatorSkippedReason? = nil
    ) {
        self.action = action
        self.notificationDecision = notificationDecision
        self.soundCategory = soundCategory
        self.playbackPlan = playbackPlan
        self.skippedReason = skippedReason
    }
}

public struct SoundCoordinator: Sendable {
    public let soundManager: SoundManager
    private let notificationPolicy: NotificationPolicy

    public init(
        soundManager: SoundManager = SoundManager(),
        notificationPolicy: NotificationPolicy = NotificationPolicy()
    ) {
        self.soundManager = soundManager
        self.notificationPolicy = notificationPolicy
    }

    public func planSound(for request: SoundCoordinatorRequest) -> SoundCoordinatorPlan {
        let notificationDecision = notificationPolicy.decision(for: request.notificationInput)
        guard notificationDecision.shouldPlaySound else {
            return SoundCoordinatorPlan(
                action: .skipSound,
                notificationDecision: notificationDecision,
                skippedReason: .notificationPolicyMuted
            )
        }

        guard let soundCategory = Self.soundCategory(for: request.notificationInput.category) else {
            return SoundCoordinatorPlan(
                action: .skipSound,
                notificationDecision: notificationDecision,
                skippedReason: .unmappedEventCategory
            )
        }

        let playbackPlan = soundManager.planPlayback(SoundManagerPlaybackRequest(
            category: soundCategory,
            source: request.notificationInput.agent,
            minuteOfDay: request.minuteOfDay
        ))

        return SoundCoordinatorPlan(
            action: .playSound,
            notificationDecision: notificationDecision,
            soundCategory: soundCategory,
            playbackPlan: playbackPlan
        )
    }

    public static func soundCategory(for category: NotificationEventCategory) -> NotificationSoundCategory? {
        switch category {
        case .permissionRequested:
            return .permission
        case .questionAsked:
            return .question
        case .sessionCompleted:
            return .completion
        case .sessionFailed:
            return .failure
        case .usageThreshold, .usageLimit, .usageReset:
            return .usage
        case .remoteDisconnected:
            return .remote
        case .agentWarning, .integrationRepairNeeded:
            return .warning
        case .activityUpdate:
            return nil
        }
    }
}
