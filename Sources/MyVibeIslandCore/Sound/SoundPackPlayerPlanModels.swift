import Foundation

public struct SoundPackPlaybackRequest: Codable, Equatable, Sendable {
    public let category: NotificationSoundCategory
    public let soundId: String?

    public init(category: NotificationSoundCategory, soundId: String? = nil) {
        self.category = category
        self.soundId = soundId
    }
}

public enum SoundPackPlaybackOutcome: String, Codable, Equatable, Sendable {
    case play
    case fail
}

public enum SoundPackPlaybackFailureKind: String, Codable, Equatable, Sendable {
    case missingSelectedPack
    case missingCategorySound
    case missingRequestedSound
    case invalidAssetReference
}

public struct SoundPackPlaybackPlan: Codable, Equatable, Sendable {
    public let outcome: SoundPackPlaybackOutcome
    public let packId: String?
    public let entry: SoundPackSoundEntry?
    public let failureKind: SoundPackPlaybackFailureKind?

    public init(
        outcome: SoundPackPlaybackOutcome,
        packId: String? = nil,
        entry: SoundPackSoundEntry? = nil,
        failureKind: SoundPackPlaybackFailureKind? = nil
    ) {
        self.outcome = outcome
        self.packId = packId
        self.entry = entry
        self.failureKind = failureKind
    }
}

public struct SoundPackPlayer: Sendable {
    public init() {}

    public func planPlayback(
        request: SoundPackPlaybackRequest,
        store: SoundPackStore
    ) -> SoundPackPlaybackPlan {
        guard let manifest = store.selectedManifest else {
            return SoundPackPlaybackPlan(outcome: .fail, failureKind: .missingSelectedPack)
        }

        let categoryEntries = manifest.sounds(for: request.category)
        guard !categoryEntries.isEmpty else {
            return SoundPackPlaybackPlan(
                outcome: .fail,
                packId: manifest.id,
                failureKind: .missingCategorySound
            )
        }

        let entry: SoundPackSoundEntry?
        if let soundId = request.soundId {
            entry = categoryEntries.first { $0.id == soundId }
            if entry == nil {
                return SoundPackPlaybackPlan(
                    outcome: .fail,
                    packId: manifest.id,
                    failureKind: .missingRequestedSound
                )
            }
        } else {
            entry = categoryEntries.first
        }

        guard let entry else {
            return SoundPackPlaybackPlan(
                outcome: .fail,
                packId: manifest.id,
                failureKind: .missingCategorySound
            )
        }

        if entry.file.isEmpty {
            return SoundPackPlaybackPlan(
                outcome: .fail,
                packId: manifest.id,
                entry: entry,
                failureKind: .invalidAssetReference
            )
        }

        return SoundPackPlaybackPlan(
            outcome: .play,
            packId: manifest.id,
            entry: entry
        )
    }
}
