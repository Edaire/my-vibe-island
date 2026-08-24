public enum UpdatePhase: String, Codable, Equatable, Sendable {
    case idle
    case checking
    case available
    case downloading
    case extracting
    case readyToInstall
    case installing
    case upToDate
    case skipped
    case failed
}

public enum ReleaseNotesCategory: String, Codable, Equatable, Sendable {
    case feature
    case fix
    case security
    case other
}

public enum ReleaseNotesSeverity: String, Codable, Equatable, Sendable {
    case normal
    case important
    case critical
}

public struct ReleaseNotesSection: Codable, Equatable, Sendable {
    public let title: String
    public let summary: String
    public let items: [String]
    public let category: ReleaseNotesCategory
    public let severity: ReleaseNotesSeverity
    public let sourceURL: String?

    public init(
        title: String,
        summary: String,
        items: [String] = [],
        category: ReleaseNotesCategory = .feature,
        severity: ReleaseNotesSeverity = .normal,
        sourceURL: String? = nil
    ) {
        self.title = title
        self.summary = summary
        self.items = items
        self.category = category
        self.severity = severity
        self.sourceURL = sourceURL
    }
}

public struct UpdatePresentationSnapshot: Codable, Equatable, Sendable {
    public let currentVersion: String
    public let newVersion: String?
    public let previousVersion: String?
    public let phase: UpdatePhase
    public let isCritical: Bool
    public let isInformationOnly: Bool
    public let isMajorUpgrade: Bool
    public let isAlreadyDownloaded: Bool
    public let expectedContentLength: Int?
    public let downloadedLength: Int?
    public let skippedVersion: String?
    public let willInstallOnQuit: Bool
    public let isPostUpdateRestart: Bool
    public let releaseNotesSections: [ReleaseNotesSection]
    public let errorHint: String?

    public init(
        currentVersion: String,
        newVersion: String? = nil,
        previousVersion: String? = nil,
        phase: UpdatePhase = .idle,
        isCritical: Bool = false,
        isInformationOnly: Bool = false,
        isMajorUpgrade: Bool = false,
        isAlreadyDownloaded: Bool = false,
        expectedContentLength: Int? = nil,
        downloadedLength: Int? = nil,
        skippedVersion: String? = nil,
        willInstallOnQuit: Bool = false,
        isPostUpdateRestart: Bool = false,
        releaseNotesSections: [ReleaseNotesSection] = [],
        errorHint: String? = nil
    ) {
        self.currentVersion = currentVersion
        self.newVersion = newVersion
        self.previousVersion = previousVersion
        self.phase = phase
        self.isCritical = isCritical
        self.isInformationOnly = isInformationOnly
        self.isMajorUpgrade = isMajorUpgrade
        self.isAlreadyDownloaded = isAlreadyDownloaded
        self.expectedContentLength = expectedContentLength
        self.downloadedLength = downloadedLength
        self.skippedVersion = skippedVersion
        self.willInstallOnQuit = willInstallOnQuit
        self.isPostUpdateRestart = isPostUpdateRestart
        self.releaseNotesSections = releaseNotesSections
        self.errorHint = errorHint
    }
}

public enum UpdatePresentationAction: String, Codable, Equatable, Sendable {
    case none
    case checkAgain
    case downloadAndInstall
    case remindLater
    case skipVersion
    case installAndRelaunch
    case openUpdateWindow
}

public struct UpdateAvailablePill: Codable, Equatable, Sendable {
    public let visible: Bool
    public let label: String
    public let targetVersion: String?
    public let installReady: Bool
    public let action: UpdatePresentationAction

    public init(
        visible: Bool = false,
        label: String = "",
        targetVersion: String? = nil,
        installReady: Bool = false,
        action: UpdatePresentationAction = .none
    ) {
        self.visible = visible
        self.label = label
        self.targetVersion = targetVersion
        self.installReady = installReady
        self.action = action
    }
}

public struct UpdatePresentationViewModel: Equatable, Sendable {
    public let snapshot: UpdatePresentationSnapshot
    public let progressFraction: Double?
    public let primaryAction: UpdatePresentationAction
    public let secondaryActions: [UpdatePresentationAction]
    public let pill: UpdateAvailablePill

    public init(snapshot: UpdatePresentationSnapshot) {
        self.snapshot = snapshot
        progressFraction = Self.progressFraction(
            downloadedLength: snapshot.downloadedLength,
            expectedContentLength: snapshot.expectedContentLength
        )
        primaryAction = Self.primaryAction(for: snapshot)
        secondaryActions = Self.secondaryActions(for: snapshot)
        pill = Self.pill(for: snapshot)
    }

    private static func progressFraction(downloadedLength: Int?, expectedContentLength: Int?) -> Double? {
        guard let downloadedLength, let expectedContentLength, expectedContentLength > 0 else {
            return nil
        }
        return min(1.0, max(0.0, Double(downloadedLength) / Double(expectedContentLength)))
    }

    private static func primaryAction(for snapshot: UpdatePresentationSnapshot) -> UpdatePresentationAction {
        switch snapshot.phase {
        case .available:
            return snapshot.isAlreadyDownloaded ? .installAndRelaunch : .downloadAndInstall
        case .readyToInstall:
            return .installAndRelaunch
        case .failed:
            return .checkAgain
        case .idle, .checking, .downloading, .extracting, .installing, .upToDate, .skipped:
            return .none
        }
    }

    private static func secondaryActions(for snapshot: UpdatePresentationSnapshot) -> [UpdatePresentationAction] {
        switch snapshot.phase {
        case .available:
            return snapshot.isCritical ? [.remindLater] : [.remindLater, .skipVersion]
        case .readyToInstall:
            return [.remindLater]
        case .idle, .checking, .downloading, .extracting, .installing, .upToDate, .skipped, .failed:
            return []
        }
    }

    private static func pill(for snapshot: UpdatePresentationSnapshot) -> UpdateAvailablePill {
        guard let version = snapshot.newVersion else {
            return UpdateAvailablePill()
        }

        switch snapshot.phase {
        case .available, .downloading, .extracting:
            return UpdateAvailablePill(
                visible: true,
                label: "Update \(version)",
                targetVersion: version,
                installReady: false,
                action: .openUpdateWindow
            )
        case .readyToInstall:
            return UpdateAvailablePill(
                visible: true,
                label: "Update \(version)",
                targetVersion: version,
                installReady: true,
                action: .installAndRelaunch
            )
        case .idle, .checking, .installing, .upToDate, .skipped, .failed:
            return UpdateAvailablePill()
        }
    }
}

public enum UpdatePresentationCommand: Equatable, Sendable {
    case startManualCheck
    case foundUpdate(
        version: String,
        critical: Bool,
        informationOnly: Bool,
        majorUpgrade: Bool,
        alreadyDownloaded: Bool,
        notes: [ReleaseNotesSection]
    )
    case updateDownloadProgress(downloadedLength: Int, expectedContentLength: Int)
    case readyToInstall
    case skipVersion
    case remindLater
    case fail(String)
}

public enum UpdatePresentedAction: String, Codable, Equatable, Sendable {
    case none
    case showUpdateWindow
    case dismissUpdateWindow
}

public struct UpdatePresentationPlan: Equatable, Sendable {
    public let nextSnapshot: UpdatePresentationSnapshot
    public let presentedAction: UpdatePresentedAction

    public init(
        nextSnapshot: UpdatePresentationSnapshot,
        presentedAction: UpdatePresentedAction = .none
    ) {
        self.nextSnapshot = nextSnapshot
        self.presentedAction = presentedAction
    }
}

public struct UpdatePresentationCoordinator: Sendable {
    public init() {}

    public func plan(
        _ command: UpdatePresentationCommand,
        from snapshot: UpdatePresentationSnapshot
    ) -> UpdatePresentationPlan {
        switch command {
        case .startManualCheck:
            return UpdatePresentationPlan(
                nextSnapshot: copy(snapshot, phase: .checking, errorHint: nil)
            )

        case let .foundUpdate(version, critical, informationOnly, majorUpgrade, alreadyDownloaded, notes):
            return UpdatePresentationPlan(
                nextSnapshot: UpdatePresentationSnapshot(
                    currentVersion: snapshot.currentVersion,
                    newVersion: version,
                    previousVersion: snapshot.previousVersion,
                    phase: alreadyDownloaded ? .readyToInstall : .available,
                    isCritical: critical,
                    isInformationOnly: informationOnly,
                    isMajorUpgrade: majorUpgrade,
                    isAlreadyDownloaded: alreadyDownloaded,
                    skippedVersion: nil,
                    willInstallOnQuit: snapshot.willInstallOnQuit,
                    isPostUpdateRestart: snapshot.isPostUpdateRestart,
                    releaseNotesSections: notes
                ),
                presentedAction: .showUpdateWindow
            )

        case let .updateDownloadProgress(downloadedLength, expectedContentLength):
            return UpdatePresentationPlan(
                nextSnapshot: copy(
                    snapshot,
                    phase: .downloading,
                    expectedContentLength: max(0, expectedContentLength),
                    downloadedLength: max(0, downloadedLength)
                )
            )

        case .readyToInstall:
            return UpdatePresentationPlan(
                nextSnapshot: copy(snapshot, phase: .readyToInstall, isAlreadyDownloaded: true)
            )

        case .skipVersion:
            return UpdatePresentationPlan(
                nextSnapshot: copy(snapshot, phase: .skipped, skippedVersion: snapshot.newVersion),
                presentedAction: .dismissUpdateWindow
            )

        case .remindLater:
            return UpdatePresentationPlan(
                nextSnapshot: copy(snapshot, phase: .idle, skippedVersion: nil),
                presentedAction: .dismissUpdateWindow
            )

        case let .fail(errorHint):
            return UpdatePresentationPlan(
                nextSnapshot: copy(snapshot, phase: .failed, errorHint: errorHint)
            )
        }
    }

    private func copy(
        _ snapshot: UpdatePresentationSnapshot,
        phase: UpdatePhase,
        isAlreadyDownloaded: Bool? = nil,
        expectedContentLength: Int? = nil,
        downloadedLength: Int? = nil,
        skippedVersion: String? = nil,
        errorHint: String? = nil
    ) -> UpdatePresentationSnapshot {
        UpdatePresentationSnapshot(
            currentVersion: snapshot.currentVersion,
            newVersion: snapshot.newVersion,
            previousVersion: snapshot.previousVersion,
            phase: phase,
            isCritical: snapshot.isCritical,
            isInformationOnly: snapshot.isInformationOnly,
            isMajorUpgrade: snapshot.isMajorUpgrade,
            isAlreadyDownloaded: isAlreadyDownloaded ?? snapshot.isAlreadyDownloaded,
            expectedContentLength: expectedContentLength ?? snapshot.expectedContentLength,
            downloadedLength: downloadedLength ?? snapshot.downloadedLength,
            skippedVersion: skippedVersion,
            willInstallOnQuit: snapshot.willInstallOnQuit,
            isPostUpdateRestart: snapshot.isPostUpdateRestart,
            releaseNotesSections: snapshot.releaseNotesSections,
            errorHint: errorHint
        )
    }
}
