public enum SSHBlockReason: String, Codable, Equatable, Sendable {
    case appNotRunning
    case remoteSocketMissing
    case staleSocket
    case uidMismatch
    case helperMissing
    case hookConfigMissing
    case tunnelDisconnected
    case heartbeatTimeout
    case portConflict
    case foreignListener
    case liveSameUserTunnel
    case unsupportedSource
    case scpBlocked
    case hostUnreachable
    case authenticationFailed
    case commandFailed
    case unknown
}

public enum SSHReconnectRepairAction: String, Codable, Equatable, Sendable {
    case startApp
    case reconnectSSHRemoteForward
    case enableStreamLocalBindUnlinkOrRemoveSocket
    case setExplicitSocketMapping
    case redeployHelper
    case installManagedHooks
    case reconnectHostTunnel
    case chooseDifferentPort
    case manualInstallFallback
    case manualInstructionsOnly
    case inspectDiagnostics
}

public struct SSHReconnectHint: Codable, Equatable, Sendable {
    public let hostId: String
    public let blockReason: SSHBlockReason
    public let failureKind: SSHTunnelFailureKind
    public let repairAction: SSHReconnectRepairAction
    public let message: String
    public let nextReconnectAt: String?
    public let failureCount: Int
    public let reconnectAttempt: Int
    public let requiresManualSetup: Bool
    public let allowsReconnectAttempt: Bool

    public init(
        hostId: String,
        blockReason: SSHBlockReason,
        failureKind: SSHTunnelFailureKind,
        repairAction: SSHReconnectRepairAction,
        message: String,
        nextReconnectAt: String? = nil,
        failureCount: Int = 0,
        reconnectAttempt: Int = 0,
        requiresManualSetup: Bool,
        allowsReconnectAttempt: Bool
    ) {
        self.hostId = hostId
        self.blockReason = blockReason
        self.failureKind = failureKind
        self.repairAction = repairAction
        self.message = message
        self.nextReconnectAt = nextReconnectAt
        self.failureCount = failureCount
        self.reconnectAttempt = reconnectAttempt
        self.requiresManualSetup = requiresManualSetup
        self.allowsReconnectAttempt = allowsReconnectAttempt
    }

    public static func fromReachability(_ observer: SSHReachabilityObserver) -> SSHReconnectHint {
        let failureKind = observer.lastProbeResult.failureKind ?? .unknown
        return fromFailureKind(
            failureKind,
            hostId: observer.hostId,
            nextReconnectAt: observer.nextReconnectAt,
            failureCount: observer.failureCount,
            reconnectAttempt: observer.reconnectAttempt
        )
    }

    public static func fromPortConflict(_ conflict: SSHPortConflict) -> SSHReconnectHint {
        let failureKind: SSHTunnelFailureKind
        switch conflict.decision {
        case .foreignOccupied, .nonSSHDOccupied:
            failureKind = .foreignListener
        case .liveTunnelOccupied:
            failureKind = .portConflict
        case .sameUserStaleSSHDCleanupAllowed:
            failureKind = .staleListener
        case .free:
            failureKind = .unknown
        case .unknownFailClosed:
            failureKind = .portConflict
        }

        return fromFailureKind(failureKind, hostId: conflict.hostId)
    }

    public static func fromFailureKind(
        _ failureKind: SSHTunnelFailureKind,
        hostId: String,
        nextReconnectAt: String? = nil,
        failureCount: Int = 0,
        reconnectAttempt: Int = 0
    ) -> SSHReconnectHint {
        let mapped = mapping(for: failureKind)
        return SSHReconnectHint(
            hostId: hostId,
            blockReason: mapped.blockReason,
            failureKind: failureKind,
            repairAction: mapped.repairAction,
            message: mapped.message,
            nextReconnectAt: nextReconnectAt,
            failureCount: failureCount,
            reconnectAttempt: reconnectAttempt,
            requiresManualSetup: mapped.requiresManualSetup,
            allowsReconnectAttempt: mapped.allowsReconnectAttempt
        )
    }

    private static func mapping(
        for failureKind: SSHTunnelFailureKind
    ) -> (
        blockReason: SSHBlockReason,
        repairAction: SSHReconnectRepairAction,
        message: String,
        requiresManualSetup: Bool,
        allowsReconnectAttempt: Bool
    ) {
        switch failureKind {
        case .hostUnreachable:
            return (.hostUnreachable, .reconnectHostTunnel, "remote host is unreachable", false, true)
        case .authenticationFailed:
            return (.authenticationFailed, .inspectDiagnostics, "SSH authentication failed", true, false)
        case .deployMissing:
            return (.helperMissing, .redeployHelper, "remote helper is missing", true, false)
        case .hookOutdated:
            return (.hookConfigMissing, .installManagedHooks, "remote hook needs setup or repair", true, false)
        case .portConflict:
            return (.portConflict, .chooseDifferentPort, "remote port is already in use", true, false)
        case .staleListener:
            return (.staleSocket, .enableStreamLocalBindUnlinkOrRemoveSocket, "remote socket listener is stale", true, false)
        case .foreignListener:
            return (.foreignListener, .chooseDifferentPort, "remote listener belongs to another owner", true, false)
        case .heartbeatTimeout:
            return (.heartbeatTimeout, .reconnectHostTunnel, "remote heartbeat timed out", false, true)
        case .commandFailed:
            return (.commandFailed, .inspectDiagnostics, "remote command failed", true, false)
        case .unknown:
            return (.unknown, .inspectDiagnostics, "remote connection state is unknown", true, false)
        }
    }
}
