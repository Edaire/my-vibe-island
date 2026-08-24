public struct BlockingPolicy: Codable, Equatable, Sendable {
    public let source: String
    public let eventName: String
    public let expectsResponse: Bool
    public let timeoutSeconds: Int?
    public let timeoutBehavior: BlockingTimeoutBehavior
    public let directiveEncoderId: String?
    public let userVisible: Bool

    public init(
        source: String,
        eventName: String,
        expectsResponse: Bool,
        timeoutSeconds: Int? = nil,
        timeoutBehavior: BlockingTimeoutBehavior,
        directiveEncoderId: String? = nil,
        userVisible: Bool
    ) {
        self.source = source
        self.eventName = eventName
        self.expectsResponse = expectsResponse
        self.timeoutSeconds = timeoutSeconds
        self.timeoutBehavior = timeoutBehavior
        self.directiveEncoderId = directiveEncoderId
        self.userVisible = userVisible
    }
}

public enum BlockingTimeoutBehavior: String, Codable, Equatable, Sendable {
    case failOpen
    case explicitAllow
    case explicitDeny
    case drop
}
