public struct SSHTunnelProcess: Codable, Equatable, Sendable {
    public let processId: Int
    public let hostId: String
    public let tunnelKind: SSHTunnelKind
    public let localSocketPath: String?
    public let remoteSocketPath: String?
    public let localPort: Int?
    public let remotePort: Int?
    public let startedAt: String
    public let lastStatus: TunnelStatus
    public let generation: Int
    public let controlPath: String?
    public let isPiggybackMode: Bool

    public init(
        processId: Int,
        hostId: String,
        tunnelKind: SSHTunnelKind,
        localSocketPath: String? = nil,
        remoteSocketPath: String? = nil,
        localPort: Int? = nil,
        remotePort: Int? = nil,
        startedAt: String,
        lastStatus: TunnelStatus,
        generation: Int,
        controlPath: String? = nil,
        isPiggybackMode: Bool = false
    ) {
        self.processId = processId
        self.hostId = hostId
        self.tunnelKind = tunnelKind
        self.localSocketPath = localSocketPath
        self.remoteSocketPath = remoteSocketPath
        self.localPort = localPort
        self.remotePort = remotePort
        self.startedAt = startedAt
        self.lastStatus = lastStatus
        self.generation = generation
        self.controlPath = controlPath
        self.isPiggybackMode = isPiggybackMode
    }
}
