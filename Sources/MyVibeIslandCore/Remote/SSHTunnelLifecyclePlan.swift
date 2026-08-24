public enum SSHTunnelLifecycleOperation: String, Codable, Equatable, Sendable {
    case connect
    case disconnect
    case reconnect
}

public enum SSHTunnelLifecycleActionKind: String, Codable, Equatable, Sendable {
    case startTunnel
    case stopHostOwnedTunnel
}

public struct SSHTunnelLifecycleAction: Codable, Equatable, Sendable {
    public let kind: SSHTunnelLifecycleActionKind
    public let processId: Int?
    public let commandPreview: String?
    public let remoteForwardPreview: String?

    public init(
        kind: SSHTunnelLifecycleActionKind,
        processId: Int? = nil,
        commandPreview: String? = nil,
        remoteForwardPreview: String? = nil
    ) {
        self.kind = kind
        self.processId = processId
        self.commandPreview = commandPreview
        self.remoteForwardPreview = remoteForwardPreview
    }
}

public struct SSHTunnelLifecyclePlan: Codable, Equatable, Sendable {
    public let hostId: String
    public let tunnelKind: SSHTunnelKind
    public let operation: SSHTunnelLifecycleOperation
    public let currentGeneration: Int
    public let nextGeneration: Int
    public let nextStatus: TunnelStatus
    public let actions: [SSHTunnelLifecycleAction]

    public init(
        host: SSHHostStoreHost,
        operation: SSHTunnelLifecycleOperation,
        currentProcess: SSHTunnelProcess? = nil,
        currentGeneration: Int
    ) {
        self.hostId = host.id
        self.tunnelKind = host.tunnelKind
        self.operation = operation
        self.currentGeneration = currentGeneration
        self.nextGeneration = Self.nextGeneration(operation: operation, currentGeneration: currentGeneration)
        self.nextStatus = Self.nextStatus(for: operation)
        self.actions = Self.actions(host: host, operation: operation, currentProcess: currentProcess)
    }

    private static func nextGeneration(
        operation: SSHTunnelLifecycleOperation,
        currentGeneration: Int
    ) -> Int {
        switch operation {
        case .connect, .reconnect:
            return currentGeneration + 1
        case .disconnect:
            return currentGeneration
        }
    }

    private static func nextStatus(for operation: SSHTunnelLifecycleOperation) -> TunnelStatus {
        switch operation {
        case .connect:
            return .connecting
        case .disconnect:
            return .disconnected
        case .reconnect:
            return .reconnecting
        }
    }

    private static func actions(
        host: SSHHostStoreHost,
        operation: SSHTunnelLifecycleOperation,
        currentProcess: SSHTunnelProcess?
    ) -> [SSHTunnelLifecycleAction] {
        switch operation {
        case .connect:
            return [startAction(for: host)]
        case .disconnect:
            return stopAction(hostId: host.id, currentProcess: currentProcess).map { [$0] } ?? []
        case .reconnect:
            var actions = stopAction(hostId: host.id, currentProcess: currentProcess).map { [$0] } ?? []
            actions.append(startAction(for: host))
            return actions
        }
    }

    private static func stopAction(
        hostId: String,
        currentProcess: SSHTunnelProcess?
    ) -> SSHTunnelLifecycleAction? {
        guard let currentProcess,
              currentProcess.hostId == hostId,
              !currentProcess.isPiggybackMode
        else {
            return nil
        }

        return SSHTunnelLifecycleAction(kind: .stopHostOwnedTunnel, processId: currentProcess.processId)
    }

    private static func startAction(for host: SSHHostStoreHost) -> SSHTunnelLifecycleAction {
        SSHTunnelLifecycleAction(
            kind: .startTunnel,
            commandPreview: "ssh -N \(host.hostAlias)",
            remoteForwardPreview: remoteForwardPreview(for: host)
        )
    }

    private static func remoteForwardPreview(for host: SSHHostStoreHost) -> String? {
        switch host.tunnelKind {
        case .uds:
            guard let remoteSocketPath = nonEmpty(host.remoteSocketPath),
                  let localSocketPath = nonEmpty(host.localSocketPath)
            else {
                return nil
            }
            return "RemoteForward \(remoteSocketPath) \(localSocketPath)"
        case .tcp:
            guard let tcpPort = host.tcpPort else {
                return nil
            }
            return "RemoteForward \(tcpPort) 127.0.0.1:\(tcpPort)"
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
