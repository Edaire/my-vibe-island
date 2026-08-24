import Foundation

public enum IntegrationSettingsHookStatus: String, Codable, Equatable, Sendable {
    case notInstalled
    case installed
    case needsRepair
    case unsupported
}

public enum IntegrationSettingsWatcherStatus: String, Codable, Equatable, Sendable {
    case unknown
    case healthy
    case warning
    case failed
}

public enum IntegrationSettingsLocalTrustStatus: String, Codable, Equatable, Sendable {
    case unknown
    case trusted
    case untrusted
    case notRequired
}

public enum IntegrationSettingsTerminalExtensionStatus: String, Codable, Equatable, Sendable {
    case unknown
    case notInstalled
    case installed
    case requiresRestart
    case unsupported
}

public enum IntegrationSettingsStatusSummary: String, Codable, Equatable, Sendable {
    case ready
    case needsRepair
    case needsRestart
    case failed
    case unsupported
    case unknown
}

public enum IntegrationRepairOperation: String, Codable, Equatable, Sendable {
    case install
    case uninstall
    case repair
    case removeCustomPath
    case addCustomPath
}

public enum IntegrationRepairOutcome: String, Codable, Equatable, Sendable {
    case succeeded
    case failed
    case skipped
}

public struct IntegrationRepairResult: Codable, Equatable, Sendable {
    public let integrationId: String
    public let operation: IntegrationRepairOperation
    public let outcome: IntegrationRepairOutcome
    public let message: String
    public let configPath: String?
    public let changedPaths: [String]
    public let hookStatusBefore: IntegrationSettingsHookStatus
    public let hookStatusAfter: IntegrationSettingsHookStatus
    public let requiresTerminalRestart: Bool
    public let diagnosticNotes: [String]

    public var isSuccessful: Bool {
        outcome == .succeeded
    }

    public var statusSummary: IntegrationSettingsStatusSummary {
        if outcome == .failed {
            return .failed
        }
        if requiresTerminalRestart {
            return .needsRestart
        }
        if hookStatusAfter == .needsRepair {
            return .needsRepair
        }
        if hookStatusAfter == .unsupported {
            return .unsupported
        }
        return outcome == .succeeded ? .ready : .unknown
    }

    public init(
        integrationId: String,
        operation: IntegrationRepairOperation,
        outcome: IntegrationRepairOutcome,
        message: String,
        configPath: String? = nil,
        changedPaths: [String] = [],
        hookStatusBefore: IntegrationSettingsHookStatus,
        hookStatusAfter: IntegrationSettingsHookStatus,
        requiresTerminalRestart: Bool = false,
        diagnosticNotes: [String] = []
    ) {
        self.integrationId = integrationId
        self.operation = operation
        self.outcome = outcome
        self.message = message
        self.configPath = configPath
        self.changedPaths = Array(Set(changedPaths)).sorted()
        self.hookStatusBefore = hookStatusBefore
        self.hookStatusAfter = hookStatusAfter
        self.requiresTerminalRestart = requiresTerminalRestart
        self.diagnosticNotes = diagnosticNotes
    }
}

public struct IntegrationSettingsRow: Codable, Equatable, Sendable {
    public let sourceId: String
    public let displayName: String
    public let supportLevel: AgentSupportLevel
    public let detectedVersion: String?
    public let configPath: String?
    public let hookStatus: IntegrationSettingsHookStatus
    public let watcherStatus: IntegrationSettingsWatcherStatus
    public let localTrustStatus: IntegrationSettingsLocalTrustStatus
    public let terminalExtensionStatus: IntegrationSettingsTerminalExtensionStatus
    public let repairResult: IntegrationRepairResult?
    public let lastCheckedAt: String?

    public var canRepair: Bool {
        hookStatus == .needsRepair
            || watcherStatus == .failed
            || terminalExtensionStatus == .requiresRestart
            || repairResult?.statusSummary == .failed
            || repairResult?.statusSummary == .needsRepair
            || repairResult?.statusSummary == .needsRestart
    }

    public var statusSummary: IntegrationSettingsStatusSummary {
        if terminalExtensionStatus == .requiresRestart || repairResult?.statusSummary == .needsRestart {
            return .needsRestart
        }
        if repairResult?.statusSummary == .failed || watcherStatus == .failed {
            return .failed
        }
        if hookStatus == .needsRepair {
            return .needsRepair
        }
        if hookStatus == .unsupported || terminalExtensionStatus == .unsupported || supportLevel == .planned {
            return .unsupported
        }
        if hookStatus == .installed && watcherStatus == .healthy {
            return .ready
        }
        return .unknown
    }

    public init(
        sourceId: String,
        displayName: String,
        supportLevel: AgentSupportLevel,
        detectedVersion: String? = nil,
        configPath: String? = nil,
        hookStatus: IntegrationSettingsHookStatus = .notInstalled,
        watcherStatus: IntegrationSettingsWatcherStatus = .unknown,
        localTrustStatus: IntegrationSettingsLocalTrustStatus = .unknown,
        terminalExtensionStatus: IntegrationSettingsTerminalExtensionStatus = .unknown,
        repairResult: IntegrationRepairResult? = nil,
        lastCheckedAt: String? = nil
    ) {
        self.sourceId = sourceId
        self.displayName = displayName
        self.supportLevel = supportLevel
        self.detectedVersion = detectedVersion
        self.configPath = configPath
        self.hookStatus = hookStatus
        self.watcherStatus = watcherStatus
        self.localTrustStatus = localTrustStatus
        self.terminalExtensionStatus = terminalExtensionStatus
        self.repairResult = repairResult
        self.lastCheckedAt = lastCheckedAt
    }
}

public enum CustomConfigPathKind: String, Codable, Equatable, Sendable {
    case global
    case project
    case fork
}

public enum CustomConfigPathDuplicateStatus: Codable, Equatable, Sendable {
    case unique
    case duplicateOf(String)
}

public struct CustomConfigPath: Codable, Equatable, Sendable {
    public let id: String
    public let sourceId: String
    public let rawPath: String
    public let displayPath: String
    public let kind: CustomConfigPathKind
    public let exists: Bool
    public let duplicateStatus: CustomConfigPathDuplicateStatus
    public let lastCheckedAt: String?

    public var canSave: Bool {
        exists && duplicateStatus == .unique
    }

    public init(
        id: String,
        sourceId: String,
        rawPath: String,
        displayPath: String? = nil,
        kind: CustomConfigPathKind,
        exists: Bool,
        duplicateStatus: CustomConfigPathDuplicateStatus = .unique,
        lastCheckedAt: String? = nil
    ) {
        self.id = id
        self.sourceId = sourceId
        self.rawPath = rawPath
        self.displayPath = displayPath ?? Self.defaultDisplayPath(rawPath)
        self.kind = kind
        self.exists = exists
        self.duplicateStatus = duplicateStatus
        self.lastCheckedAt = lastCheckedAt
    }

    private static func defaultDisplayPath(_ rawPath: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if rawPath == home {
            return "~"
        }
        if rawPath.hasPrefix(home + "/") {
            return "~" + rawPath.dropFirst(home.count)
        }
        return rawPath
    }
}

public struct IntegrationSettingsSnapshot: Codable, Equatable, Sendable {
    public let rows: [IntegrationSettingsRow]
    public let customPaths: [CustomConfigPath]
    public let lastCheckedAt: String?

    public init(
        rows: [IntegrationSettingsRow],
        customPaths: [CustomConfigPath] = [],
        lastCheckedAt: String? = nil
    ) {
        self.rows = rows.sorted { lhs, rhs in
            if lhs.sourceId == rhs.sourceId {
                return lhs.displayName < rhs.displayName
            }
            return lhs.sourceId < rhs.sourceId
        }
        self.customPaths = customPaths.sorted { lhs, rhs in
            if lhs.sourceId == rhs.sourceId {
                return lhs.id < rhs.id
            }
            return lhs.sourceId < rhs.sourceId
        }
        self.lastCheckedAt = lastCheckedAt
    }
}

public struct IntegrationSettingsModel: Sendable {
    public init() {}

    public func snapshot(
        from state: IntegrationCoordinatorState,
        customPaths: [CustomConfigPath] = []
    ) -> IntegrationSettingsSnapshot {
        IntegrationSettingsSnapshot(
            rows: state.rows.map { row in
                Self.row(from: row, stateLastCheckedAt: state.lastCheckedAt)
            },
            customPaths: customPaths,
            lastCheckedAt: state.lastCheckedAt
        )
    }

    private static func row(
        from row: IntegrationStatusRow,
        stateLastCheckedAt: String?
    ) -> IntegrationSettingsRow {
        IntegrationSettingsRow(
            sourceId: row.sourceId,
            displayName: row.displayName,
            supportLevel: row.supportLevel,
            hookStatus: hookStatus(from: row.installState),
            watcherStatus: watcherStatus(from: row.healthState),
            localTrustStatus: .unknown,
            terminalExtensionStatus: .unknown,
            lastCheckedAt: stateLastCheckedAt
        )
    }

    private static func hookStatus(from installState: IntegrationInstallState) -> IntegrationSettingsHookStatus {
        switch installState {
        case .notInstalled:
            return .notInstalled
        case .installed:
            return .installed
        case .needsRepair:
            return .needsRepair
        case .unsupported:
            return .unsupported
        }
    }

    private static func watcherStatus(from healthState: IntegrationHealthState) -> IntegrationSettingsWatcherStatus {
        switch healthState {
        case .unknown:
            return .unknown
        case .healthy:
            return .healthy
        case .warning:
            return .warning
        case .failed:
            return .failed
        }
    }
}
