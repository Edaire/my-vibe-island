public enum RemoteBridgeTransportKind: String, Codable, Equatable, Sendable {
    case forwardedUnixSocket
    case udsTunnel
    case tcpTunnel
}

public struct RemoteBridgeConnection: Codable, Equatable, Sendable {
    public let connectionId: String
    public let hostId: String
    public let transportKind: RemoteBridgeTransportKind
    public let connectedAt: String
    public let lastMessageAt: String?
    public let localTunnelProcessId: Int?
    public let remoteEnvironmentToken: String?
    public let heartbeatIntervalSeconds: Int?
    public let heartbeatTimeout: Int?
    public let didFireEarlyHeartbeat: Bool

    public init(
        connectionId: String,
        hostId: String,
        transportKind: RemoteBridgeTransportKind,
        connectedAt: String,
        lastMessageAt: String? = nil,
        localTunnelProcessId: Int? = nil,
        remoteEnvironmentToken: String? = nil,
        heartbeatIntervalSeconds: Int? = nil,
        heartbeatTimeout: Int? = nil,
        didFireEarlyHeartbeat: Bool = false
    ) {
        self.connectionId = connectionId
        self.hostId = hostId
        self.transportKind = transportKind
        self.connectedAt = connectedAt
        self.lastMessageAt = lastMessageAt
        self.localTunnelProcessId = localTunnelProcessId
        self.remoteEnvironmentToken = remoteEnvironmentToken
        self.heartbeatIntervalSeconds = heartbeatIntervalSeconds
        self.heartbeatTimeout = heartbeatTimeout
        self.didFireEarlyHeartbeat = didFireEarlyHeartbeat
    }
}
