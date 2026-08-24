public enum SSHHeartbeatStatus: String, Codable, Equatable, Sendable {
    case notStarted
    case healthy
    case networkUnsatisfied
    case timeout
    case commandFailed
    case suspended
}

public struct SSHHeartbeatSnapshot: Codable, Equatable, Sendable {
    public let hostId: String
    public let status: SSHHeartbeatStatus
    public let heartbeatIntervalSeconds: Int
    public let heartbeatTimeoutSeconds: Int
    public let heartbeatTimerActive: Bool
    public let didFireEarlyHeartbeat: Bool
    public let lastHeartbeatAt: String?
    public let failureCount: Int
    public let failureKind: SSHTunnelFailureKind?
    public let shouldShowReconnectWarning: Bool

    public init(observer: SSHReachabilityObserver, isSuspended: Bool) {
        hostId = observer.hostId
        status = Self.status(for: observer.lastProbeResult, isSuspended: isSuspended)
        heartbeatIntervalSeconds = observer.heartbeatIntervalSeconds
        heartbeatTimeoutSeconds = observer.heartbeatTimeoutSeconds
        heartbeatTimerActive = observer.heartbeatTimerActive
        didFireEarlyHeartbeat = observer.didFireEarlyHeartbeat
        lastHeartbeatAt = observer.lastSuccessAt
        failureCount = observer.failureCount
        failureKind = isSuspended ? nil : observer.lastProbeResult.failureKind
        shouldShowReconnectWarning = Self.shouldShowReconnectWarning(
            status: status,
            failureCount: observer.failureCount,
            isSuspended: isSuspended
        )
    }

    private static func status(
        for probeResult: SSHReachabilityProbeResult,
        isSuspended: Bool
    ) -> SSHHeartbeatStatus {
        if isSuspended {
            return .suspended
        }

        switch probeResult {
        case .notStarted:
            return .notStarted
        case .succeeded:
            return .healthy
        case .networkUnsatisfied:
            return .networkUnsatisfied
        case .heartbeatTimeout:
            return .timeout
        case .commandFailed:
            return .commandFailed
        }
    }

    private static func shouldShowReconnectWarning(
        status: SSHHeartbeatStatus,
        failureCount: Int,
        isSuspended: Bool
    ) -> Bool {
        guard !isSuspended, failureCount > 0 else {
            return false
        }

        switch status {
        case .networkUnsatisfied, .timeout, .commandFailed:
            return true
        case .notStarted, .healthy, .suspended:
            return false
        }
    }
}
