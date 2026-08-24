public enum AgentSupportLevel: String, Codable, Equatable, Sendable {
    case supported
    case experimental
    case detectedOnly
    case planned
    case unknown
}
