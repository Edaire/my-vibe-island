public struct AgentDescriptor: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let supportLevel: AgentSupportLevel
    public let defaultEventSources: [String]

    public init(
        id: String,
        displayName: String,
        supportLevel: AgentSupportLevel,
        defaultEventSources: [String]
    ) {
        self.id = id
        self.displayName = displayName
        self.supportLevel = supportLevel
        self.defaultEventSources = defaultEventSources
    }
}
