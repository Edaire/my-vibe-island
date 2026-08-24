public enum SSHTunnelFailureKind: String, Codable, Equatable, Sendable {
    case hostUnreachable
    case authenticationFailed
    case deployMissing
    case hookOutdated
    case portConflict
    case staleListener
    case foreignListener
    case heartbeatTimeout
    case commandFailed
    case unknown
}
