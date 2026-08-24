public struct SessionPresentation: Codable, Equatable, Sendable {
    public let sessionId: String
    public let sourceBadge: String
    public let statusBadge: String
    public let taskSummary: String
    public let todoSummary: String
    public let attentionRequired: Bool
    public let redactionLevel: RedactionLevel
    public let restored: Bool
}
