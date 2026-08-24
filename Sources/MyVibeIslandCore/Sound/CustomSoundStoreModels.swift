import Foundation

public enum CustomSoundSourceMode: String, Codable, Equatable, Sendable {
    case copiedIntoLibrary
    case referencedInPlace
}

public enum CustomSoundFormat: String, Codable, Equatable, Sendable {
    case aiff
    case wav
    case mp3
    case m4a
    case unknown
}

public struct CustomSoundPlaybackSettings: Codable, Equatable, Sendable {
    public let volume: Double
    public let cooldownSeconds: Int
    public let trimStartMilliseconds: Int
    public let trimEndMilliseconds: Int
    public let shouldNormalize: Bool
    public let isEnabled: Bool

    public init(
        volume: Double = 1,
        cooldownSeconds: Int = 0,
        trimStartMilliseconds: Int = 0,
        trimEndMilliseconds: Int = 0,
        shouldNormalize: Bool = false,
        isEnabled: Bool = true
    ) {
        self.volume = min(max(volume, 0), 1)
        self.cooldownSeconds = max(cooldownSeconds, 0)
        let normalizedTrimStart = max(trimStartMilliseconds, 0)
        self.trimStartMilliseconds = normalizedTrimStart
        self.trimEndMilliseconds = max(trimEndMilliseconds, normalizedTrimStart)
        self.shouldNormalize = shouldNormalize
        self.isEnabled = isEnabled
    }
}

public enum CustomSoundFileValidationIssueKind: String, Codable, Equatable, Sendable {
    case missingFileId
    case missingDisplayName
    case missingStoredFileName
    case invalidDuration
}

public struct CustomSoundFileValidationIssue: Codable, Equatable, Sendable {
    public let kind: CustomSoundFileValidationIssueKind

    public init(kind: CustomSoundFileValidationIssueKind) {
        self.kind = kind
    }
}

public struct CustomSoundFileValidationReport: Codable, Equatable, Sendable {
    public let issues: [CustomSoundFileValidationIssue]

    public var isValid: Bool {
        issues.isEmpty
    }

    public init(issues: [CustomSoundFileValidationIssue]) {
        self.issues = issues
    }
}

public struct CustomSoundFileDiagnosticSummary: Codable, Equatable, Sendable {
    public let sourceMode: CustomSoundSourceMode
    public let format: CustomSoundFormat
    public let hasStoredFileReference: Bool
    public let hasDuration: Bool
    public let isPlaybackEnabled: Bool

    public init(
        sourceMode: CustomSoundSourceMode,
        format: CustomSoundFormat,
        hasStoredFileReference: Bool,
        hasDuration: Bool,
        isPlaybackEnabled: Bool
    ) {
        self.sourceMode = sourceMode
        self.format = format
        self.hasStoredFileReference = hasStoredFileReference
        self.hasDuration = hasDuration
        self.isPlaybackEnabled = isPlaybackEnabled
    }
}

public struct CustomSoundFile: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let storedFileName: String
    public let sourceMode: CustomSoundSourceMode
    public let format: CustomSoundFormat
    public let durationMilliseconds: Int?
    public let createdAtUnixSeconds: Int
    public let playbackSettings: CustomSoundPlaybackSettings

    public var validationReport: CustomSoundFileValidationReport {
        var issues: [CustomSoundFileValidationIssue] = []

        if id.isEmpty {
            issues.append(CustomSoundFileValidationIssue(kind: .missingFileId))
        }
        if displayName.isEmpty {
            issues.append(CustomSoundFileValidationIssue(kind: .missingDisplayName))
        }
        if storedFileName.isEmpty {
            issues.append(CustomSoundFileValidationIssue(kind: .missingStoredFileName))
        }
        if let durationMilliseconds, durationMilliseconds < 0 {
            issues.append(CustomSoundFileValidationIssue(kind: .invalidDuration))
        }

        return CustomSoundFileValidationReport(issues: issues)
    }

    public var diagnosticSummary: CustomSoundFileDiagnosticSummary {
        CustomSoundFileDiagnosticSummary(
            sourceMode: sourceMode,
            format: format,
            hasStoredFileReference: !storedFileName.isEmpty,
            hasDuration: durationMilliseconds != nil,
            isPlaybackEnabled: playbackSettings.isEnabled
        )
    }

    public init(
        id: String,
        displayName: String,
        storedFileName: String,
        sourceMode: CustomSoundSourceMode,
        format: CustomSoundFormat,
        durationMilliseconds: Int? = nil,
        createdAtUnixSeconds: Int,
        playbackSettings: CustomSoundPlaybackSettings = CustomSoundPlaybackSettings()
    ) {
        self.id = id
        self.displayName = displayName
        self.storedFileName = storedFileName
        self.sourceMode = sourceMode
        self.format = format
        self.durationMilliseconds = durationMilliseconds
        self.createdAtUnixSeconds = max(createdAtUnixSeconds, 0)
        self.playbackSettings = playbackSettings
    }
}

public struct CustomSoundLibraryManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let soundIds: [String]
    public let lastUpdatedUnixSeconds: Int
    public let migrationVersion: Int

    public init(
        schemaVersion: Int = 1,
        soundIds: [String] = [],
        lastUpdatedUnixSeconds: Int = 0,
        migrationVersion: Int = 1
    ) {
        self.schemaVersion = max(schemaVersion, 1)
        self.soundIds = soundIds
        self.lastUpdatedUnixSeconds = max(lastUpdatedUnixSeconds, 0)
        self.migrationVersion = max(migrationVersion, 0)
    }
}

public struct CustomSoundStoreSnapshot: Codable, Equatable, Sendable {
    public let files: [CustomSoundFile]
    public let assignments: [NotificationSoundCategory: String]
    public let lastImportError: String?
    public let hasLoaded: Bool
    public let isStarted: Bool
    public let libraryDirectory: String?
    public let manifest: CustomSoundLibraryManifest

    public init(
        files: [CustomSoundFile] = [],
        assignments: [NotificationSoundCategory: String] = [:],
        lastImportError: String? = nil,
        hasLoaded: Bool = false,
        isStarted: Bool = false,
        libraryDirectory: String? = nil,
        manifest: CustomSoundLibraryManifest = CustomSoundLibraryManifest()
    ) {
        self.files = files
        self.assignments = assignments
        self.lastImportError = lastImportError
        self.hasLoaded = hasLoaded
        self.isStarted = isStarted
        self.libraryDirectory = libraryDirectory
        self.manifest = manifest
    }
}

public enum CustomSoundStoreValidationIssueKind: String, Codable, Equatable, Sendable {
    case duplicateFileId
    case invalidFile
    case missingAssignedFile
    case manifestReferencesMissingFile
}

public struct CustomSoundStoreValidationIssue: Codable, Equatable, Sendable {
    public let kind: CustomSoundStoreValidationIssueKind
    public let fileId: String?
    public let category: NotificationSoundCategory?

    public init(
        kind: CustomSoundStoreValidationIssueKind,
        fileId: String? = nil,
        category: NotificationSoundCategory? = nil
    ) {
        self.kind = kind
        self.fileId = fileId
        self.category = category
    }
}

public struct CustomSoundStoreValidationReport: Codable, Equatable, Sendable {
    public let issues: [CustomSoundStoreValidationIssue]

    public var isValid: Bool {
        issues.isEmpty
    }

    public init(issues: [CustomSoundStoreValidationIssue]) {
        self.issues = issues
    }
}

public struct CustomSoundStoreDiagnosticSummary: Codable, Equatable, Sendable {
    public let fileCount: Int
    public let assignmentCount: Int
    public let hasLastImportError: Bool
    public let hasLibraryDirectory: Bool
    public let hasLoaded: Bool
    public let isStarted: Bool

    public init(
        fileCount: Int,
        assignmentCount: Int,
        hasLastImportError: Bool,
        hasLibraryDirectory: Bool,
        hasLoaded: Bool,
        isStarted: Bool
    ) {
        self.fileCount = fileCount
        self.assignmentCount = assignmentCount
        self.hasLastImportError = hasLastImportError
        self.hasLibraryDirectory = hasLibraryDirectory
        self.hasLoaded = hasLoaded
        self.isStarted = isStarted
    }
}

public struct CustomSoundStore: Sendable {
    public let snapshot: CustomSoundStoreSnapshot

    public var validationReport: CustomSoundStoreValidationReport {
        var issues: [CustomSoundStoreValidationIssue] = []
        var seenFileIds = Set<String>()
        var duplicateFileIds = Set<String>()

        for file in snapshot.files {
            if seenFileIds.contains(file.id), !duplicateFileIds.contains(file.id) {
                issues.append(CustomSoundStoreValidationIssue(kind: .duplicateFileId, fileId: file.id))
                duplicateFileIds.insert(file.id)
            }
            seenFileIds.insert(file.id)
        }

        for file in snapshot.files where !file.validationReport.isValid {
            issues.append(CustomSoundStoreValidationIssue(kind: .invalidFile, fileId: file.id))
        }

        for (category, fileId) in snapshot.assignments.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where file(id: fileId) == nil {
            issues.append(CustomSoundStoreValidationIssue(
                kind: .missingAssignedFile,
                fileId: fileId,
                category: category
            ))
        }

        for fileId in snapshot.manifest.soundIds where file(id: fileId) == nil {
            issues.append(CustomSoundStoreValidationIssue(kind: .manifestReferencesMissingFile, fileId: fileId))
        }

        return CustomSoundStoreValidationReport(issues: issues)
    }

    public var diagnosticSummary: CustomSoundStoreDiagnosticSummary {
        CustomSoundStoreDiagnosticSummary(
            fileCount: snapshot.files.count,
            assignmentCount: snapshot.assignments.count,
            hasLastImportError: snapshot.lastImportError != nil,
            hasLibraryDirectory: snapshot.libraryDirectory != nil,
            hasLoaded: snapshot.hasLoaded,
            isStarted: snapshot.isStarted
        )
    }

    public init(snapshot: CustomSoundStoreSnapshot = CustomSoundStoreSnapshot()) {
        self.snapshot = snapshot
    }

    public func file(id: String) -> CustomSoundFile? {
        snapshot.files.first { $0.id == id }
    }

    public func assignedFile(for category: NotificationSoundCategory) -> CustomSoundFile? {
        guard let fileId = snapshot.assignments[category] else {
            return nil
        }
        return file(id: fileId)
    }
}
