public struct SocketServerTCPListener: Codable, Equatable, Sendable {
    public let host: String
    public let port: Int
    public let isListening: Bool

    public init(host: String, port: Int, isListening: Bool) {
        self.host = host
        self.port = port
        self.isListening = isListening
    }
}

public struct SocketServerSnapshot: Codable, Equatable, Sendable {
    public let unixServerFD: Int?
    public let tcpServerFD: Int?
    public let tcpListener: SocketServerTCPListener?
    public let sshRemoteConnections: [RemoteBridgeConnection]
    public let activeLocalClientCount: Int

    public var diagnosticSummary: SocketServerDiagnosticSummary {
        SocketServerDiagnosticSummary(snapshot: self)
    }

    public init(
        unixServerFD: Int? = nil,
        tcpServerFD: Int? = nil,
        tcpListener: SocketServerTCPListener? = nil,
        sshRemoteConnections: [RemoteBridgeConnection] = [],
        activeLocalClientCount: Int = 0
    ) {
        self.unixServerFD = unixServerFD
        self.tcpServerFD = tcpServerFD
        self.tcpListener = tcpListener
        self.sshRemoteConnections = sshRemoteConnections
        self.activeLocalClientCount = max(0, activeLocalClientCount)
    }
}

public struct SocketServerDiagnosticSummary: Codable, Equatable, Sendable {
    public let hasUnixServer: Bool
    public let hasTCPServer: Bool
    public let isTCPListenerActive: Bool
    public let remoteConnectionCount: Int
    public let activeLocalClientCount: Int
    public let totalConnectionCount: Int

    public init(snapshot: SocketServerSnapshot) {
        hasUnixServer = snapshot.unixServerFD != nil
        hasTCPServer = snapshot.tcpServerFD != nil
        isTCPListenerActive = snapshot.tcpListener?.isListening == true
        remoteConnectionCount = snapshot.sshRemoteConnections.count
        activeLocalClientCount = snapshot.activeLocalClientCount
        totalConnectionCount = activeLocalClientCount + remoteConnectionCount
    }
}
