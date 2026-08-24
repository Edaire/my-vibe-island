public enum TaskStatus: String, Codable, Equatable, Sendable {
    case pending
    case active
    case blocked
    case completed
    case failed
    case unknown
}

public struct TaskItem: Codable, Equatable, Sendable {
    public let id: String
    public let subject: String
    public let description: String?
    public let status: TaskStatus
    public let activeForm: String?
    public let blockedBy: String?
    public let owner: String?

    public init(
        id: String,
        subject: String,
        description: String? = nil,
        status: TaskStatus = .unknown,
        activeForm: String? = nil,
        blockedBy: String? = nil,
        owner: String? = nil
    ) {
        self.id = id
        self.subject = subject
        self.description = description
        self.status = status
        self.activeForm = activeForm
        self.blockedBy = blockedBy
        self.owner = owner
    }
}
