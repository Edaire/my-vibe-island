import Foundation

public struct SoundPackAuthor: Codable, Equatable, Sendable {
    public let name: String
    public let github: String?

    public init(name: String, github: String? = nil) {
        self.name = name
        self.github = github
    }
}

public enum SoundPackLoudness: String, Codable, Equatable, Sendable {
    case quiet
    case normal
    case loud
}

public struct SoundPackSoundEntry: Codable, Equatable, Sendable {
    public let id: String
    public let category: NotificationSoundCategory
    public let file: String
    public let label: String
    public let durationMs: Int?
    public let loudness: SoundPackLoudness?

    public init(
        id: String,
        category: NotificationSoundCategory,
        file: String,
        label: String,
        durationMs: Int? = nil,
        loudness: SoundPackLoudness? = nil
    ) {
        self.id = id
        self.category = category
        self.file = file
        self.label = label
        self.durationMs = durationMs
        self.loudness = loudness
    }
}

public struct SoundPackCategoryEntry: Codable, Equatable, Sendable {
    public let category: NotificationSoundCategory
    public let sounds: [SoundPackSoundEntry]

    public init(category: NotificationSoundCategory, sounds: [SoundPackSoundEntry]) {
        self.category = category
        self.sounds = sounds
    }
}

public enum SoundPackManifestValidationIssueKind: String, Codable, Equatable, Sendable {
    case missingPackId
    case missingPackName
    case missingDisplayName
    case missingVersion
    case missingAuthorName
    case emptyCategories
    case soundCategoryNotListed
    case missingSoundId
    case missingSoundFile
    case missingSoundLabel
    case invalidDuration
}

public struct SoundPackManifestValidationIssue: Codable, Equatable, Sendable {
    public let kind: SoundPackManifestValidationIssueKind
    public let soundId: String?

    public init(kind: SoundPackManifestValidationIssueKind, soundId: String? = nil) {
        self.kind = kind
        self.soundId = soundId
    }
}

public struct SoundPackManifestValidationReport: Codable, Equatable, Sendable {
    public let issues: [SoundPackManifestValidationIssue]

    public var isValid: Bool {
        issues.isEmpty
    }

    public init(issues: [SoundPackManifestValidationIssue]) {
        self.issues = issues
    }
}

public struct SoundPackManifest: Codable, Equatable, Sendable {
    public let cespVersion: Int
    public let id: String
    public let name: String
    public let displayName: String
    public let version: String
    public let author: SoundPackAuthor
    public let contentRights: String?
    public let categories: [NotificationSoundCategory]
    public let sounds: [SoundPackSoundEntry]

    public var categoryEntries: [SoundPackCategoryEntry] {
        categories.map { category in
            SoundPackCategoryEntry(category: category, sounds: sounds(for: category))
        }
    }

    public var validationReport: SoundPackManifestValidationReport {
        var issues: [SoundPackManifestValidationIssue] = []

        if id.isEmpty {
            issues.append(SoundPackManifestValidationIssue(kind: .missingPackId))
        }
        if name.isEmpty {
            issues.append(SoundPackManifestValidationIssue(kind: .missingPackName))
        }
        if displayName.isEmpty {
            issues.append(SoundPackManifestValidationIssue(kind: .missingDisplayName))
        }
        if version.isEmpty {
            issues.append(SoundPackManifestValidationIssue(kind: .missingVersion))
        }
        if author.name.isEmpty {
            issues.append(SoundPackManifestValidationIssue(kind: .missingAuthorName))
        }
        if categories.isEmpty {
            issues.append(SoundPackManifestValidationIssue(kind: .emptyCategories))
        }

        for sound in sounds {
            if !categories.contains(sound.category) {
                issues.append(SoundPackManifestValidationIssue(kind: .soundCategoryNotListed, soundId: sound.id))
            }
            if sound.id.isEmpty {
                issues.append(SoundPackManifestValidationIssue(kind: .missingSoundId))
            }
            if sound.file.isEmpty {
                issues.append(SoundPackManifestValidationIssue(kind: .missingSoundFile, soundId: sound.id))
            }
            if sound.label.isEmpty {
                issues.append(SoundPackManifestValidationIssue(kind: .missingSoundLabel, soundId: sound.id))
            }
            if let durationMs = sound.durationMs, durationMs < 0 {
                issues.append(SoundPackManifestValidationIssue(kind: .invalidDuration, soundId: sound.id))
            }
        }

        return SoundPackManifestValidationReport(issues: issues)
    }

    public init(
        cespVersion: Int,
        id: String,
        name: String,
        displayName: String,
        version: String,
        author: SoundPackAuthor,
        contentRights: String? = nil,
        categories: [NotificationSoundCategory],
        sounds: [SoundPackSoundEntry]
    ) {
        self.cespVersion = cespVersion
        self.id = id
        self.name = name
        self.displayName = displayName
        self.version = version
        self.author = author
        self.contentRights = contentRights
        self.categories = categories
        self.sounds = sounds
    }

    public func sounds(for category: NotificationSoundCategory) -> [SoundPackSoundEntry] {
        sounds.filter { $0.category == category }
    }

    private enum CodingKeys: String, CodingKey {
        case cespVersion = "cesp_version"
        case id
        case name
        case displayName = "display_name"
        case version
        case author
        case contentRights
        case categories
        case sounds
    }
}
