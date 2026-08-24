public struct TerminalSessionMapEntry: Codable, Equatable, Sendable {
    public let source: String?
    public let status: String?
    public let currentTool: String?
    public let toolTarget: String?
    public let cwd: String?
    public let firstUserMessage: String?
    public let lastUserMessage: String?
    public let lastAssistantMessage: String?
    public let lastAssistantMessageFull: String?
    public let hasUnreadCompletion: Bool?
    public let codexRolloutPath: String?
    public let lastActivityAt: Double?
    public let bundleIdentifier: String?
    public let bundleIdentifiers: [String]?
    public let admissionRejection: String?
    public let gitIdentityStatus: String?
    public let repoName: String?
    public let worktreeName: String?
    public let gitBranch: String?
    public let termProgram: String?
    public let tty: String?
    public let isInTmux: Bool?
    public let tmuxPane: String?
    public let tmuxSocketPath: String?
    public let ottySocket: String?
    public let ottyPaneId: String?
    public let termSessionId: String?
    public let codexNotifyThreadId: String?

    public init(
        source: String? = nil,
        status: String? = nil,
        currentTool: String? = nil,
        toolTarget: String? = nil,
        cwd: String? = nil,
        firstUserMessage: String? = nil,
        lastUserMessage: String? = nil,
        lastAssistantMessage: String? = nil,
        lastAssistantMessageFull: String? = nil,
        hasUnreadCompletion: Bool? = nil,
        codexRolloutPath: String? = nil,
        lastActivityAt: Double? = nil,
        bundleIdentifier: String? = nil,
        bundleIdentifiers: [String]? = nil,
        admissionRejection: String? = nil,
        gitIdentityStatus: String? = nil,
        repoName: String? = nil,
        worktreeName: String? = nil,
        gitBranch: String? = nil,
        termProgram: String? = nil,
        tty: String? = nil,
        isInTmux: Bool? = nil,
        tmuxPane: String? = nil,
        tmuxSocketPath: String? = nil,
        ottySocket: String? = nil,
        ottyPaneId: String? = nil,
        termSessionId: String? = nil,
        codexNotifyThreadId: String? = nil
    ) {
        self.source = source
        self.status = status
        self.currentTool = currentTool
        self.toolTarget = toolTarget
        self.cwd = cwd
        self.firstUserMessage = firstUserMessage
        self.lastUserMessage = lastUserMessage
        self.lastAssistantMessage = lastAssistantMessage
        self.lastAssistantMessageFull = lastAssistantMessageFull
        self.hasUnreadCompletion = hasUnreadCompletion
        self.codexRolloutPath = codexRolloutPath
        self.lastActivityAt = lastActivityAt
        self.bundleIdentifier = bundleIdentifier
        self.bundleIdentifiers = bundleIdentifiers
        self.admissionRejection = admissionRejection
        self.gitIdentityStatus = gitIdentityStatus
        self.repoName = repoName
        self.worktreeName = worktreeName
        self.gitBranch = gitBranch
        self.termProgram = termProgram
        self.tty = tty
        self.isInTmux = isInTmux
        self.tmuxPane = tmuxPane
        self.tmuxSocketPath = tmuxSocketPath
        self.ottySocket = ottySocket
        self.ottyPaneId = ottyPaneId
        self.termSessionId = termSessionId
        self.codexNotifyThreadId = codexNotifyThreadId
    }
}
