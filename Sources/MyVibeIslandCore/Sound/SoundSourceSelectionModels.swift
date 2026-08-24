import Foundation

public enum SoundSourceKind: String, Codable, Equatable, Sendable {
    case off
    case builtin8bit
    case appleSystem
    case custom
}

public struct SoundSourceSelection: Codable, Equatable, Sendable {
    public let category: NotificationSoundCategory
    public let sourceKind: SoundSourceKind
    public let sourceId: String?
    public let soundId: String?
    public let fallbackSourceId: String?
    public let isEnabled: Bool
    public let volume: Double
    public let cooldownSeconds: Int
    public let outputRouteBehavior: String

    public init(
        category: NotificationSoundCategory,
        sourceKind: SoundSourceKind,
        soundId: String?,
        isEnabled: Bool,
        volume: Double,
        cooldownSeconds: Int,
        outputRouteBehavior: String,
        sourceId: String? = nil,
        fallbackSourceId: String? = nil
    ) {
        self.category = category
        self.sourceKind = sourceKind
        self.sourceId = sourceId
        self.soundId = soundId
        self.fallbackSourceId = fallbackSourceId
        self.isEnabled = isEnabled
        self.volume = volume
        self.cooldownSeconds = cooldownSeconds
        self.outputRouteBehavior = outputRouteBehavior
    }
}

public struct SoundSourceStoreSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let selections: [SoundSourceSelection]

    public init(
        schemaVersion: String = SoundSourceStore.schemaVersion,
        selections: [SoundSourceSelection]
    ) {
        self.schemaVersion = schemaVersion
        self.selections = selections
    }
}

public struct SoundSourceStore: Sendable {
    public static let schemaVersion = "soundSourceSelections.v1"

    public let selections: [NotificationSoundCategory: SoundSourceSelection]
    public let defaults: [SoundSourceSelection]

    public init(
        selections: [NotificationSoundCategory: SoundSourceSelection] = [:],
        defaults: [SoundSourceSelection] = SoundSourceStore.defaultSelections
    ) {
        self.selections = selections
        self.defaults = defaults
    }

    public func resolve(category: NotificationSoundCategory) -> SoundSourceSelection {
        if let selection = selections[category] {
            return selection
        }

        return defaults.first { $0.category == category } ?? SoundSourceSelection(
            category: category,
            sourceKind: .off,
            soundId: nil,
            isEnabled: false,
            volume: 0,
            cooldownSeconds: 0,
            outputRouteBehavior: "default"
        )
    }

    public var persistedSnapshot: SoundSourceStoreSnapshot {
        SoundSourceStoreSnapshot(
            selections: NotificationSoundCategory.allCases.map { resolve(category: $0) }
        )
    }

    public static let defaultSelections: [SoundSourceSelection] = [
        SoundSourceSelection(
            category: .permission,
            sourceKind: .builtin8bit,
            soundId: "builtin8bit.permission",
            isEnabled: true,
            volume: 1,
            cooldownSeconds: 0,
            outputRouteBehavior: "default"
        ),
        SoundSourceSelection(
            category: .question,
            sourceKind: .builtin8bit,
            soundId: "builtin8bit.question",
            isEnabled: true,
            volume: 1,
            cooldownSeconds: 0,
            outputRouteBehavior: "default"
        ),
        SoundSourceSelection(
            category: .completion,
            sourceKind: .appleSystem,
            soundId: nil,
            isEnabled: true,
            volume: 1,
            cooldownSeconds: 0,
            outputRouteBehavior: "default"
        ),
        SoundSourceSelection(
            category: .failure,
            sourceKind: .builtin8bit,
            soundId: "builtin8bit.failure",
            isEnabled: true,
            volume: 1,
            cooldownSeconds: 0,
            outputRouteBehavior: "default"
        ),
        SoundSourceSelection(
            category: .warning,
            sourceKind: .off,
            soundId: nil,
            isEnabled: false,
            volume: 0,
            cooldownSeconds: 5,
            outputRouteBehavior: "default"
        ),
        SoundSourceSelection(
            category: .usage,
            sourceKind: .off,
            soundId: nil,
            isEnabled: false,
            volume: 0,
            cooldownSeconds: 5,
            outputRouteBehavior: "default"
        ),
        SoundSourceSelection(
            category: .remote,
            sourceKind: .off,
            soundId: nil,
            isEnabled: false,
            volume: 0,
            cooldownSeconds: 5,
            outputRouteBehavior: "default"
        ),
    ]
}
