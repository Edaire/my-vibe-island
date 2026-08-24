public enum SSHReconnectPolicy: String, Codable, Equatable, Sendable {
    case manualOnly
    case promptBeforeReconnect
    case automaticForKnownHost
}
