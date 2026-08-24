public enum AntigravityWatcherVisibility: String, Codable, Equatable, Sendable {
    case hidden
    case labsOnly
}

public struct AntigravityWatcherRow: Codable, Equatable, Sendable {
    public let id: String
    public let workspaceId: String?
    public let transcriptPath: String?
    public let isActive: Bool

    public init(
        id: String,
        workspaceId: String? = nil,
        transcriptPath: String? = nil,
        isActive: Bool = false
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.transcriptPath = transcriptPath
        self.isActive = isActive
    }
}

public struct AntigravityWatcherState: Codable, Equatable, Sendable {
    public let watchers: [AntigravityWatcherRow]
    public let pendingParentMap: [String: String]
    public let visibility: AntigravityWatcherVisibility

    public var diagnosticSummary: AntigravityWatcherDiagnosticSummary {
        AntigravityWatcherDiagnosticSummary(state: self)
    }

    public init(
        watchers: [AntigravityWatcherRow] = [],
        pendingParentMap: [String: String] = [:],
        visibility: AntigravityWatcherVisibility = .hidden
    ) {
        self.watchers = watchers.sorted { lhs, rhs in
            lhs.id < rhs.id
        }
        self.pendingParentMap = pendingParentMap
        self.visibility = visibility
    }
}

public struct AntigravityWatcherDiagnosticSummary: Codable, Equatable, Sendable {
    public let watcherCount: Int
    public let activeWatcherCount: Int
    public let pendingParentLinkCount: Int
    public let visibility: AntigravityWatcherVisibility
    public let isRuntimeVisible: Bool

    public init(state: AntigravityWatcherState) {
        watcherCount = state.watchers.count
        activeWatcherCount = state.watchers.filter(\.isActive).count
        pendingParentLinkCount = state.pendingParentMap.count
        visibility = state.visibility
        isRuntimeVisible = state.visibility == .labsOnly
    }
}
