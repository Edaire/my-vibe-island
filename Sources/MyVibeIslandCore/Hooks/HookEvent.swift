public struct HookEvent: Codable, Equatable, Sendable {
    public let rawEventName: String
    public let source: String
    public let sessionId: String
    public let requestId: String?
    public let cwd: String
    public let model: String?
    public let permissionMode: String?
    public let toolName: String?
    public let message: String?
    public let firstUserMessage: String?
    public let codexRolloutPath: String?
    public let actionRequestDetails: ActionRequestDetails?
    public let environment: HookEnvironment?
    public let tasks: [TaskItem]
    public let todos: [TodoItem]
    public let subagentParentThreadId: String?
    public let subagentKind: String?
    public let subagentNickname: String?
    public let subagentRole: String?
    public let childModel: String?
    public let childReasoningEffort: String?
    public let agentId: String?
    public let agentType: String?
    public let childParentId: String?
    public let childRuntimeSessionId: String?
    public let childProcessIncarnation: String?

    public init(
        rawEventName: String,
        source: String,
        sessionId: String,
        requestId: String? = nil,
        cwd: String,
        model: String? = nil,
        permissionMode: String? = nil,
        toolName: String? = nil,
        message: String? = nil,
        firstUserMessage: String? = nil,
        codexRolloutPath: String? = nil,
        actionRequestDetails: ActionRequestDetails? = nil,
        environment: HookEnvironment? = nil,
        tasks: [TaskItem] = [],
        todos: [TodoItem] = [],
        subagentParentThreadId: String? = nil,
        subagentKind: String? = nil,
        subagentNickname: String? = nil,
        subagentRole: String? = nil,
        childModel: String? = nil,
        childReasoningEffort: String? = nil,
        agentId: String? = nil,
        agentType: String? = nil,
        childParentId: String? = nil,
        childRuntimeSessionId: String? = nil,
        childProcessIncarnation: String? = nil
    ) {
        self.rawEventName = rawEventName
        self.source = source
        self.sessionId = sessionId
        self.requestId = requestId
        self.cwd = cwd
        self.model = model
        self.permissionMode = permissionMode
        self.toolName = toolName
        self.message = message
        self.firstUserMessage = firstUserMessage
        self.codexRolloutPath = codexRolloutPath
        self.actionRequestDetails = actionRequestDetails
        self.environment = environment
        self.tasks = tasks
        self.todos = todos
        self.subagentParentThreadId = subagentParentThreadId
        self.subagentKind = subagentKind
        self.subagentNickname = subagentNickname
        self.subagentRole = subagentRole
        self.childModel = childModel
        self.childReasoningEffort = childReasoningEffort
        self.agentId = agentId
        self.agentType = agentType
        self.childParentId = childParentId
        self.childRuntimeSessionId = childRuntimeSessionId
        self.childProcessIncarnation = childProcessIncarnation
    }
}
