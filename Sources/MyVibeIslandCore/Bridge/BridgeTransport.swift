public struct BridgeTransport: Codable, Equatable, Sendable {
    public let kind: BridgeTransportKind
    public let endpoint: String
    public let provenance: BridgeTransportProvenance
    public let remoteHostId: String?
    public let isPublicListener: Bool

    public init(
        kind: BridgeTransportKind,
        endpoint: String,
        provenance: BridgeTransportProvenance,
        remoteHostId: String? = nil,
        isPublicListener: Bool = false
    ) {
        self.kind = kind
        self.endpoint = endpoint
        self.provenance = provenance
        self.remoteHostId = remoteHostId
        self.isPublicListener = isPublicListener
    }
}

public enum BridgeTransportKind: String, Codable, Equatable, Sendable {
    case unixDomainSocket
    case inMemory
    case remoteTCP
    case remoteSSHForward
}

public enum BridgeTransportProvenance: String, Codable, Equatable, Sendable {
    case localDesktop
    case testHarness
    case remoteForwardedSocket
}
