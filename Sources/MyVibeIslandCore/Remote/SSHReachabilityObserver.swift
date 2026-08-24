public struct SSHReachabilityObserver: Codable, Equatable, Sendable {
    public static let idaAlias = "SSHNetworkReachabilityObserver"

    public let hostId: String
    public let heartbeatIntervalSeconds: Int
    public let heartbeatTimeoutSeconds: Int
    public let heartbeatTimerActive: Bool
    public let didFireEarlyHeartbeat: Bool
    public let lastProbeResult: SSHReachabilityProbeResult
    public let lastSuccessAt: String?
    public let failureCount: Int
    public let reconnectAttempt: Int
    public let currentReachability: SSHReachabilityState
    public let nextReconnectAt: String?
    public let userDisconnected: Bool

    public init(
        hostId: String,
        heartbeatIntervalSeconds: Int,
        heartbeatTimeoutSeconds: Int,
        heartbeatTimerActive: Bool = false,
        didFireEarlyHeartbeat: Bool = false,
        lastProbeResult: SSHReachabilityProbeResult = .notStarted,
        lastSuccessAt: String? = nil,
        failureCount: Int = 0,
        reconnectAttempt: Int = 0,
        currentReachability: SSHReachabilityState = .unknown,
        nextReconnectAt: String? = nil,
        userDisconnected: Bool = false
    ) {
        self.hostId = hostId
        self.heartbeatIntervalSeconds = heartbeatIntervalSeconds
        self.heartbeatTimeoutSeconds = heartbeatTimeoutSeconds
        self.heartbeatTimerActive = heartbeatTimerActive
        self.didFireEarlyHeartbeat = didFireEarlyHeartbeat
        self.lastProbeResult = lastProbeResult
        self.lastSuccessAt = lastSuccessAt
        self.failureCount = failureCount
        self.reconnectAttempt = reconnectAttempt
        self.currentReachability = currentReachability
        self.nextReconnectAt = nextReconnectAt
        self.userDisconnected = userDisconnected
    }
}

public enum SSHReachabilityState: String, Codable, Equatable, Sendable {
    case unknown
    case satisfied
    case unsatisfied
}

public enum SSHReachabilityProbeResult: String, Codable, Equatable, Sendable {
    case notStarted
    case succeeded
    case networkUnsatisfied
    case heartbeatTimeout
    case commandFailed

    public var failureKind: SSHTunnelFailureKind? {
        switch self {
        case .notStarted, .succeeded:
            nil
        case .networkUnsatisfied:
            .hostUnreachable
        case .heartbeatTimeout:
            .heartbeatTimeout
        case .commandFailed:
            .commandFailed
        }
    }
}
