public struct SSHRemoteHost: Codable, Equatable, Sendable {
    public let hostId: String
    public let displayName: String
    public let connectionState: String
    public let activeRemoteSessions: [String]
    public let lastHeartbeatAt: String?
    public let lastError: String?
    public let tunnelStatus: TunnelStatus
    public let deployStatus: String
    public let hookVersion: String?
    public let reconnectAttempt: Int

    public init(
        hostId: String,
        displayName: String,
        connectionState: String,
        activeRemoteSessions: [String] = [],
        lastHeartbeatAt: String? = nil,
        lastError: String? = nil,
        tunnelStatus: TunnelStatus,
        deployStatus: String,
        hookVersion: String? = nil,
        reconnectAttempt: Int = 0
    ) {
        self.hostId = hostId
        self.displayName = displayName
        self.connectionState = connectionState
        self.activeRemoteSessions = activeRemoteSessions
        self.lastHeartbeatAt = lastHeartbeatAt
        self.lastError = lastError
        self.tunnelStatus = tunnelStatus
        self.deployStatus = deployStatus
        self.hookVersion = hookVersion
        self.reconnectAttempt = reconnectAttempt
    }
}
