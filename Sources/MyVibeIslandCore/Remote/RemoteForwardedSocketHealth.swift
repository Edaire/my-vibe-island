public enum RemoteForwardedSocketTransportKind: String, Codable, Equatable, Sendable {
    case uds
    case tcp
}

public enum RemoteForwardedSocketProbeResult: String, Codable, Equatable, Sendable {
    case notChecked
    case succeeded
    case localSocketMissing
    case remoteSocketMissing
    case uidMismatch
    case tunnelDisconnected
    case unknownFailure
}

public enum RemoteForwardedSocketStatus: String, Codable, Equatable, Sendable {
    case unknown
    case healthy
    case missingLocalSocket
    case missingRemoteSocket
    case uidMismatch
    case tunnelDisconnected
    case failed
}

public struct RemoteForwardedSocketHealth: Codable, Equatable, Sendable {
    public let hostId: String
    public let transportKind: RemoteForwardedSocketTransportKind
    public let remoteEndpoint: String
    public let localEndpoint: String
    public let hasUIDMismatch: Bool
    public let tunnelStatus: TunnelStatus?
    public let probeResult: RemoteForwardedSocketProbeResult
    public let status: RemoteForwardedSocketStatus
    public let reconnectHint: SSHReconnectHint?

    public init(
        host: SSHHostStoreHost,
        tunnelStatus: TunnelStatus? = nil,
        probeResult: RemoteForwardedSocketProbeResult = .notChecked
    ) {
        self.hostId = host.id
        self.transportKind = RemoteForwardedSocketTransportKind(host.tunnelKind)
        self.remoteEndpoint = Self.remoteEndpoint(for: host)
        self.localEndpoint = Self.localEndpoint(for: host)
        self.hasUIDMismatch = Self.hasUIDMismatch(remoteUID: host.remoteUID, localUID: host.localUID)
        self.tunnelStatus = tunnelStatus
        self.probeResult = probeResult
        self.status = Self.status(tunnelStatus: tunnelStatus, probeResult: probeResult)
        self.reconnectHint = Self.reconnectHint(hostId: host.id, status: self.status)
    }

    private static func hasUIDMismatch(remoteUID: Int?, localUID: Int?) -> Bool {
        guard let remoteUID, let localUID else {
            return false
        }
        return remoteUID != localUID
    }

    private static func remoteEndpoint(for host: SSHHostStoreHost) -> String {
        switch host.tunnelKind {
        case .uds:
            return host.remoteSocketPath ?? ""
        case .tcp:
            return "tcp:\(host.tcpPort ?? 0)"
        }
    }

    private static func localEndpoint(for host: SSHHostStoreHost) -> String {
        switch host.tunnelKind {
        case .uds:
            return host.localSocketPath ?? ""
        case .tcp:
            return "127.0.0.1:\(host.tcpPort ?? 0)"
        }
    }

    private static func status(
        tunnelStatus: TunnelStatus?,
        probeResult: RemoteForwardedSocketProbeResult
    ) -> RemoteForwardedSocketStatus {
        if tunnelStatus == .disconnected || tunnelStatus == .notDeployed {
            return .tunnelDisconnected
        }

        switch probeResult {
        case .notChecked:
            return .unknown
        case .succeeded:
            return .healthy
        case .localSocketMissing:
            return .missingLocalSocket
        case .remoteSocketMissing:
            return .missingRemoteSocket
        case .uidMismatch:
            return .uidMismatch
        case .tunnelDisconnected:
            return .tunnelDisconnected
        case .unknownFailure:
            return .failed
        }
    }

    private static func reconnectHint(hostId: String, status: RemoteForwardedSocketStatus) -> SSHReconnectHint? {
        switch status {
        case .missingRemoteSocket:
            return SSHReconnectHint(
                hostId: hostId,
                blockReason: .remoteSocketMissing,
                failureKind: .unknown,
                repairAction: .reconnectSSHRemoteForward,
                message: "remote socket is missing",
                requiresManualSetup: false,
                allowsReconnectAttempt: true
            )
        case .tunnelDisconnected:
            return SSHReconnectHint(
                hostId: hostId,
                blockReason: .tunnelDisconnected,
                failureKind: .unknown,
                repairAction: .reconnectHostTunnel,
                message: "remote tunnel is disconnected",
                requiresManualSetup: false,
                allowsReconnectAttempt: true
            )
        case .uidMismatch:
            return SSHReconnectHint(
                hostId: hostId,
                blockReason: .uidMismatch,
                failureKind: .unknown,
                repairAction: .setExplicitSocketMapping,
                message: "remote and local socket owners do not match",
                requiresManualSetup: true,
                allowsReconnectAttempt: false
            )
        case .missingLocalSocket:
            return SSHReconnectHint(
                hostId: hostId,
                blockReason: .staleSocket,
                failureKind: .unknown,
                repairAction: .enableStreamLocalBindUnlinkOrRemoveSocket,
                message: "local socket is missing",
                requiresManualSetup: true,
                allowsReconnectAttempt: false
            )
        case .unknown, .healthy, .failed:
            return nil
        }
    }
}

private extension RemoteForwardedSocketTransportKind {
    init(_ tunnelKind: SSHTunnelKind) {
        switch tunnelKind {
        case .uds:
            self = .uds
        case .tcp:
            self = .tcp
        }
    }
}
