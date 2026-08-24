public enum TunnelStatus: String, Codable, Equatable, Sendable {
    case notDeployed
    case disconnected
    case connecting
    case connected
    case connectedAgo
    case reconnecting
    case error
}
