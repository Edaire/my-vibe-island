public enum TodoStatus: String, Codable, Equatable, Sendable {
    case pending
    case active
    case completed
    case cancelled
    case unknown
}

public struct TodoItem: Codable, Equatable, Sendable {
    public let id: String
    public let content: String
    public let status: TodoStatus
    public let activeForm: String?

    public init(
        id: String,
        content: String,
        status: TodoStatus = .unknown,
        activeForm: String? = nil
    ) {
        self.id = id
        self.content = content
        self.status = status
        self.activeForm = activeForm
    }
}
