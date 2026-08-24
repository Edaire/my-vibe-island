public enum SessionStatus: String, Codable, Equatable, Sendable {
    case active
    case waiting
    case completed
    case failed
    case idle
}

public enum RedactionLevel: String, Codable, Equatable, Sendable {
    case metadataOnly
    case redacted
}

public struct WaitingActionSummary: Codable, Equatable, Sendable {
    public let pendingRequestCount: Int
    public let firstPendingRequestId: String?
    public let needsAttention: Bool

    public init(pendingRequestIds: [String], needsAttention: Bool) {
        self.pendingRequestCount = pendingRequestIds.count
        self.firstPendingRequestId = pendingRequestIds.first
        self.needsAttention = needsAttention
    }
}

public struct SessionSnapshot: Codable, Equatable, Sendable {
    public let sessionId: String
    public let source: String
    public let status: SessionStatus
    public let cwdDisplay: String
    public let activeTaskCount: Int
    public let todoCount: Int
    public let waitingActionSummary: WaitingActionSummary
    public let redactionLevel: RedactionLevel
    public let isRestored: Bool
    public let jumpInput: JumpInput?
    public let resolvedJumpTarget: TerminalResolvedTarget?

    public init(
        sessionId: String,
        source: String,
        status: SessionStatus,
        cwdDisplay: String,
        activeTaskCount: Int,
        todoCount: Int,
        waitingActionSummary: WaitingActionSummary,
        redactionLevel: RedactionLevel,
        isRestored: Bool,
        jumpInput: JumpInput? = nil,
        resolvedJumpTarget: TerminalResolvedTarget? = nil
    ) {
        self.sessionId = sessionId
        self.source = source
        self.status = status
        self.cwdDisplay = cwdDisplay
        self.activeTaskCount = activeTaskCount
        self.todoCount = todoCount
        self.waitingActionSummary = waitingActionSummary
        self.redactionLevel = redactionLevel
        self.isRestored = isRestored
        self.jumpInput = jumpInput
        self.resolvedJumpTarget = resolvedJumpTarget
    }
}
