import Foundation

public enum AgentEvent: Equatable, Sendable {
    case sessionStarted(source: String, sessionId: String, cwd: String)
    case sessionEnded(source: String, sessionId: String)
    case sessionActivityUpdated(source: String, sessionId: String, activity: SessionActivityUpdate)
    case permissionRequested(
        source: String,
        sessionId: String,
        requestId: String,
        toolName: String,
        details: ActionRequestDetails? = nil
    )
    case questionAsked(
        source: String,
        sessionId: String,
        requestId: String,
        toolName: String,
        details: ActionRequestDetails? = nil
    )
    case messageReceived(source: String, sessionId: String, message: String)
    case taskUpdated(source: String, sessionId: String, task: TaskItem)
    case todoUpdated(source: String, sessionId: String, todo: TodoItem)
    case teamGroupingUpdated(source: String, sessionId: String, grouping: TeamGrouping)
    case jumpTargetUpdated(source: String, sessionId: String, jumpInput: JumpInput)
    case subagentLifecycleUpdated(source: String, childSessionId: String, lifecycle: SubagentLifecycleUpdate)
    case actionResolved(resolution: ActionResolution)

    public init?(hookEvent: HookEvent) {
        switch hookEvent.rawEventName {
        case "SessionStart":
            self = .sessionStarted(
                source: hookEvent.source,
                sessionId: hookEvent.sessionId,
                cwd: hookEvent.cwd
            )
        case "SessionEnd":
            self = .sessionEnded(source: hookEvent.source, sessionId: hookEvent.sessionId)
        case "PermissionRequest":
            guard let requestId = hookEvent.requestId, !requestId.isEmpty else {
                return nil
            }
            if hookEvent.toolName == "AskUserQuestion"
                || !(hookEvent.actionRequestDetails?.questions.isEmpty ?? true) {
                self = .questionAsked(
                    source: hookEvent.source,
                    sessionId: hookEvent.sessionId,
                    requestId: requestId,
                    toolName: hookEvent.toolName ?? "Question",
                    details: hookEvent.actionRequestDetails
                )
            } else {
                self = .permissionRequested(
                    source: hookEvent.source,
                    sessionId: hookEvent.sessionId,
                    requestId: requestId,
                    toolName: hookEvent.toolName ?? "",
                    details: hookEvent.actionRequestDetails
                )
            }
        case "QuestionRequest":
            guard let requestId = hookEvent.requestId, !requestId.isEmpty else {
                return nil
            }

            self = .questionAsked(
                source: hookEvent.source,
                sessionId: hookEvent.sessionId,
                requestId: requestId,
                toolName: hookEvent.toolName ?? "",
                details: hookEvent.actionRequestDetails
            )
        case "UserPromptSubmit":
            self = .sessionActivityUpdated(
                source: hookEvent.source,
                sessionId: hookEvent.sessionId,
                activity: SessionActivityUpdate(
                    status: .active,
                    summary: hookEvent.message ?? "Codex is working.",
                    firstUserMessage: hookEvent.firstUserMessage ?? hookEvent.message,
                    lastUserMessage: hookEvent.message,
                    codexRolloutPath: hookEvent.codexRolloutPath,
                    // A transcript-derived first message is authoritative and
                    // may correct a hook-created state during startup. When no
                    // transcript is available, preserve the hook-only
                    // bootstrap semantics for later prompts.
                    startsNewTurn: true,
                    isBootstrapFirstUserMessage: hookEvent.firstUserMessage == nil,
                    cwd: hookEvent.cwd
                )
            )
        case "PreToolUse":
            let tool = hookEvent.toolName
            self = .sessionActivityUpdated(
                source: hookEvent.source,
                sessionId: hookEvent.sessionId,
                activity: SessionActivityUpdate(
                    status: .active,
                    summary: tool.map { "Codex is running \($0)." } ?? "Codex is working.",
                    originalStatus: .runningTool,
                    activeTool: tool,
                    codexRolloutPath: hookEvent.codexRolloutPath,
                    cwd: hookEvent.cwd
                )
            )
        case "PostToolUse", "PostToolUseFailure":
            self = .sessionActivityUpdated(
                source: hookEvent.source,
                sessionId: hookEvent.sessionId,
                activity: SessionActivityUpdate(
                    status: .active,
                    summary: hookEvent.message ?? "Codex is working.",
                    lastAssistantMessage: hookEvent.message,
                    codexRolloutPath: hookEvent.codexRolloutPath,
                    cwd: hookEvent.cwd
                )
            )
        case "Stop":
            self = .sessionActivityUpdated(
                source: hookEvent.source,
                sessionId: hookEvent.sessionId,
                activity: SessionActivityUpdate(
                    status: .completed,
                    summary: hookEvent.message ?? "Codex completed the turn.",
                    lastAssistantMessage: hookEvent.message,
                    codexRolloutPath: hookEvent.codexRolloutPath,
                    hasUnreadCompletion: hasVisibleCompletionBody(hookEvent.message),
                    cwd: hookEvent.cwd
                )
            )
        case "StopFailure":
            self = .sessionActivityUpdated(
                source: hookEvent.source,
                sessionId: hookEvent.sessionId,
                activity: SessionActivityUpdate(
                    status: .failed,
                    summary: hookEvent.message ?? "Codex failed to complete the turn.",
                    lastAssistantMessage: hookEvent.message,
                    codexRolloutPath: hookEvent.codexRolloutPath,
                    hasUnreadCompletion: hasVisibleCompletionBody(hookEvent.message),
                    cwd: hookEvent.cwd
                )
            )
        case "SubagentStop":
            // V3's Codex hook path is not an accepted SubagentInfo provider.
            // Child-card lifecycle is published only by the rollout watcher.
            return nil
        default:
            self = .messageReceived(
                source: hookEvent.source,
                sessionId: hookEvent.sessionId,
                message: hookEvent.message ?? hookEvent.rawEventName
            )
        }
    }
}

public struct SubagentLifecycleUpdate: Equatable, Sendable {
    public enum Status: String, Equatable, Sendable {
        case running
        case completed
    }

    public let parentThreadId: String?
    public let kind: String?
    public let nickname: String?
    public let role: String?
    public let runtimeProfileModel: String?
    public let runtimeProfileReasoningEffort: String?
    public let agentId: String?
    public let agentType: String?
    public let parentChildId: String?
    public let runtimeSessionId: String?
    public let processIncarnation: String?
    public let status: Status
    public let observedAt: Date?
    public let currentActivity: String?
    public let needsAttention: Bool

    public init(
        parentThreadId: String? = nil,
        kind: String? = nil,
        nickname: String? = nil,
        role: String? = nil,
        runtimeProfileModel: String? = nil,
        runtimeProfileReasoningEffort: String? = nil,
        agentId: String? = nil,
        agentType: String? = nil,
        parentChildId: String? = nil,
        runtimeSessionId: String? = nil,
        processIncarnation: String? = nil,
        status: Status,
        observedAt: Date? = nil,
        currentActivity: String? = nil,
        needsAttention: Bool = false
    ) {
        self.parentThreadId = parentThreadId
        self.kind = kind
        self.nickname = nickname
        self.role = role
        self.runtimeProfileModel = runtimeProfileModel
        self.runtimeProfileReasoningEffort = runtimeProfileReasoningEffort
        self.agentId = agentId
        self.agentType = agentType
        self.parentChildId = parentChildId
        self.runtimeSessionId = runtimeSessionId
        self.processIncarnation = processIncarnation
        self.status = status
        self.observedAt = observedAt
        self.currentActivity = currentActivity
        self.needsAttention = needsAttention
    }
}

private func hasVisibleCompletionBody(_ message: String?) -> Bool {
    guard let message else { return false }
    return !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

public struct SessionActivityUpdate: Equatable, Sendable {
    public let status: SessionStatus
    public let summary: String?
    public let originalStatus: OriginalPixelStatusCompact?
    public let safeTitle: String?
    public let cliSessionId: String?
    public let activeTool: String?
    public let toolInput: [String: BridgeJSONValue]?
    public let toolTarget: String?
    public let lastAssistantMessage: String?
    public let currentCommandPreview: String?
    public let updatedAt: Date?
    public let firstUserMessage: String?
    public let lastUserMessage: String?
    public let codexRolloutPath: String?
    public let codexOrigin: String?
    public let codexSubagentKind: String?
    public let needsAttention: Bool
    public let hasUnreadCompletion: Bool
    /// Only an explicit new user turn consumes the previous unread completion.
    public let startsNewTurn: Bool
    public let isCompletionFallback: Bool
    public let isBootstrapFirstUserMessage: Bool
    public let cwd: String?

    public init(
        status: SessionStatus,
        summary: String?,
        originalStatus: OriginalPixelStatusCompact? = nil,
        safeTitle: String? = nil,
        cliSessionId: String? = nil,
        activeTool: String? = nil,
        toolInput: [String: BridgeJSONValue]? = nil,
        toolTarget: String? = nil,
        lastAssistantMessage: String? = nil,
        currentCommandPreview: String? = nil,
        updatedAt: Date? = nil,
        firstUserMessage: String? = nil,
        lastUserMessage: String? = nil,
        codexRolloutPath: String? = nil,
        codexOrigin: String? = nil,
        codexSubagentKind: String? = nil,
        needsAttention: Bool = false,
        hasUnreadCompletion: Bool = false,
        startsNewTurn: Bool = false,
        isCompletionFallback: Bool = false,
        isBootstrapFirstUserMessage: Bool = false,
        cwd: String? = nil
    ) {
        self.status = status
        self.summary = summary
        self.originalStatus = originalStatus
        self.safeTitle = safeTitle
        self.cliSessionId = cliSessionId
        self.activeTool = activeTool
        self.toolInput = toolInput
        self.toolTarget = toolTarget
        self.lastAssistantMessage = lastAssistantMessage
        self.currentCommandPreview = currentCommandPreview
        self.updatedAt = updatedAt
        self.firstUserMessage = firstUserMessage
        self.lastUserMessage = lastUserMessage
        self.codexRolloutPath = codexRolloutPath
        self.codexOrigin = codexOrigin
        self.codexSubagentKind = codexSubagentKind
        self.needsAttention = needsAttention
        self.hasUnreadCompletion = hasUnreadCompletion
        self.startsNewTurn = startsNewTurn
        self.isCompletionFallback = isCompletionFallback
        self.isBootstrapFirstUserMessage = isBootstrapFirstUserMessage
        self.cwd = cwd
    }
}

public extension HookEvent {
    func agentEvents() -> [AgentEvent] {
        var events: [AgentEvent] = []

        if let primaryEvent = AgentEvent(hookEvent: self) {
            events.append(primaryEvent)
        }

        // Terminal lifecycle events must not recreate a top-level session from
        // child-scoped metadata after their primary event is reduced.
        if rawEventName == "SessionEnd" || rawEventName == "SubagentStop" {
            return events
        }

        events.append(contentsOf: tasks.map {
            .taskUpdated(source: source, sessionId: sessionId, task: $0)
        })
        events.append(contentsOf: todos.map {
            .todoUpdated(source: source, sessionId: sessionId, todo: $0)
        })
        if let environment {
            events.append(.jumpTargetUpdated(
                source: source,
                sessionId: sessionId,
                jumpInput: JumpInput.fromHookEnvironment(
                    sessionId: sessionId,
                    source: source,
                    environment: environment
                )
            ))
        }

        return events
    }
}
