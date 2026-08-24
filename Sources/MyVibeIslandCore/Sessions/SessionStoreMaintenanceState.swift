public struct SessionParseRequest: Codable, Equatable, Sendable {
    public let id: String
    public let sessionId: String?
    public let rootPath: String?

    public init(id: String, sessionId: String? = nil, rootPath: String? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.rootPath = rootPath
    }
}

public struct SessionStoreMaintenanceState: Codable, Equatable, Sendable {
    public let hasConfiguredGhosttyEnv: Bool
    public let hasConfiguredCmuxSocket: Bool
    public let pendingParseRequests: [SessionParseRequest]
    public let parseDebounceTask: EventSchedulerTask?
    public let parseDebounceDelayMillis: Int
    public let metadataWriteTask: EventSchedulerTask?
    public let refreshingSessionIds: [String]
    public let refreshingCodexTitleSessionIds: [String]

    public var diagnosticSummary: SessionStoreMaintenanceSummary {
        SessionStoreMaintenanceSummary(state: self)
    }

    public init(
        hasConfiguredGhosttyEnv: Bool = false,
        hasConfiguredCmuxSocket: Bool = false,
        pendingParseRequests: [SessionParseRequest] = [],
        parseDebounceTask: EventSchedulerTask? = nil,
        parseDebounceDelayMillis: Int = 0,
        metadataWriteTask: EventSchedulerTask? = nil,
        refreshingSessionIds: [String] = [],
        refreshingCodexTitleSessionIds: [String] = []
    ) {
        self.hasConfiguredGhosttyEnv = hasConfiguredGhosttyEnv
        self.hasConfiguredCmuxSocket = hasConfiguredCmuxSocket
        self.pendingParseRequests = pendingParseRequests.sortedById()
        self.parseDebounceTask = parseDebounceTask
        self.parseDebounceDelayMillis = max(0, parseDebounceDelayMillis)
        self.metadataWriteTask = metadataWriteTask
        self.refreshingSessionIds = refreshingSessionIds.uniqueSorted()
        self.refreshingCodexTitleSessionIds = refreshingCodexTitleSessionIds.uniqueSorted()
    }
}

public struct SessionStoreMaintenanceSummary: Codable, Equatable, Sendable {
    public let hasConfiguredGhosttyEnv: Bool
    public let hasConfiguredCmuxSocket: Bool
    public let pendingParseRequestCount: Int
    public let hasParseDebounceTask: Bool
    public let parseDebounceDelayMillis: Int
    public let hasMetadataWriteTask: Bool
    public let refreshingSessionCount: Int
    public let refreshingCodexTitleSessionCount: Int

    public init(state: SessionStoreMaintenanceState) {
        hasConfiguredGhosttyEnv = state.hasConfiguredGhosttyEnv
        hasConfiguredCmuxSocket = state.hasConfiguredCmuxSocket
        pendingParseRequestCount = state.pendingParseRequests.count
        hasParseDebounceTask = state.parseDebounceTask != nil
        parseDebounceDelayMillis = state.parseDebounceDelayMillis
        hasMetadataWriteTask = state.metadataWriteTask != nil
        refreshingSessionCount = state.refreshingSessionIds.count
        refreshingCodexTitleSessionCount = state.refreshingCodexTitleSessionIds.count
    }
}

private extension Array where Element == SessionParseRequest {
    func sortedById() -> [SessionParseRequest] {
        sorted { lhs, rhs in
            lhs.id < rhs.id
        }
    }
}

private extension Array where Element == String {
    func uniqueSorted() -> [String] {
        Array(Set(self)).sorted()
    }
}
