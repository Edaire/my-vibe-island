import Foundation
import MyVibeIslandShared

public struct SessionState: Equatable, Sendable {
    public let sessionId: String
    public private(set) var runtimeInstanceId: UUID
    public private(set) var lastActivityAt: Date
    public private(set) var hookIngressRevision: UInt64
    public private(set) var rawHookIngressCutoff: UInt64
    public private(set) var permissionIngressRevision: UInt64
    public private(set) var rawPermissionIngressCutoff: UInt64
    public private(set) var source: String
    public private(set) var cwd: String
    public private(set) var cliSessionId: String?
    public private(set) var activeTool: String?
    public private(set) var activitySummary: String?
    public private(set) var safeTitle: String?
    public private(set) var originalStatus: OriginalPixelStatusCompact
    public private(set) var toolInput: [String: BridgeJSONValue]?
    public private(set) var toolTarget: String?
    public private(set) var lastAssistantMessage: String?
    public private(set) var currentCommandPreview: String?
    public private(set) var updatedAt: Date?
    public private(set) var repoName: String?
    public private(set) var customTitle: String?
    public private(set) var desktopTitle: String?
    public private(set) var aiTitle: String?
    public private(set) var summary: String?
    public private(set) var firstUserMessage: String?
    public private(set) var lastUserMessage: String?
    public private(set) var codexRolloutPath: String?
    public private(set) var codexOrigin: String?
    public private(set) var codexSubagentKind: String?
    public private(set) var pendingRequestIds: [String]
    public private(set) var needsAttention: Bool
    public private(set) var reportedStatus: SessionStatus?
    public private(set) var hasUnreadCompletion: Bool
    public private(set) var tasks: [TaskItem]
    public private(set) var todos: [TodoItem]
    public private(set) var subagents: [SubagentState]
    public private(set) var teamGrouping: TeamGrouping?
    public private(set) var actionableRequests: [ActionableRequest]
    public private(set) var questionPrompt: String?
    public private(set) var isRestored: Bool
    public private(set) var jumpInput: JumpInput?
    public private(set) var resolvedJumpTarget: TerminalResolvedTarget?
    public private(set) var childTreeGeneration: UInt64
    public private(set) var childLifecycleRevision: UInt64
    public private(set) var childTreeHasAuthoritativeChildren: Bool

    /// Mirrors V3's root-response ownership check: explicit approval/question
    /// state or a nonempty SocketServer pending-permission bucket for this
    /// session. It is intentionally narrower than `needsAttention`.
    public var hasV3SameTreeAttention: Bool {
        switch originalStatus {
        case .waitingForApproval, .question:
            return true
        default:
            return !pendingRequestIds.isEmpty
        }
    }

    public init(
        sessionId: String,
        source: String,
        cwd: String,
        cliSessionId: String? = nil,
        activeTool: String? = nil,
        activitySummary: String? = nil,
        safeTitle: String? = nil,
        originalStatus: OriginalPixelStatusCompact = .waitingForInput,
        toolInput: [String: BridgeJSONValue]? = nil,
        toolTarget: String? = nil,
        lastAssistantMessage: String? = nil,
        currentCommandPreview: String? = nil,
        updatedAt: Date? = nil,
        lastActivityAt: Date? = nil,
        repoName: String? = nil,
        customTitle: String? = nil,
        desktopTitle: String? = nil,
        aiTitle: String? = nil,
        summary: String? = nil,
        firstUserMessage: String? = nil,
        lastUserMessage: String? = nil,
        codexRolloutPath: String? = nil,
        codexOrigin: String? = nil,
        codexSubagentKind: String? = nil,
        pendingRequestIds: [String] = [],
        needsAttention: Bool = false,
        reportedStatus: SessionStatus? = nil,
        hasUnreadCompletion: Bool = false,
        tasks: [TaskItem] = [],
        todos: [TodoItem] = [],
        subagents: [SubagentState] = [],
        teamGrouping: TeamGrouping? = nil,
        actionableRequests: [ActionableRequest] = [],
        questionPrompt: String? = nil,
        isRestored: Bool = false,
        jumpInput: JumpInput? = nil,
        resolvedJumpTarget: TerminalResolvedTarget? = nil,
        childTreeGeneration: UInt64 = 0,
        childLifecycleRevision: UInt64 = 0,
        childTreeHasAuthoritativeChildren: Bool = false
    ) {
        self.sessionId = sessionId
        self.runtimeInstanceId = UUID()
        self.lastActivityAt = lastActivityAt ?? updatedAt ?? Date()
        self.hookIngressRevision = 0
        self.rawHookIngressCutoff = 0
        self.permissionIngressRevision = 0
        self.rawPermissionIngressCutoff = 0
        self.source = source
        self.cwd = cwd
        self.cliSessionId = cliSessionId
        self.activeTool = activeTool
        self.activitySummary = activitySummary
        self.safeTitle = safeTitle
        self.originalStatus = originalStatus
        self.toolInput = toolInput
        self.toolTarget = toolTarget
        self.lastAssistantMessage = lastAssistantMessage
        self.currentCommandPreview = currentCommandPreview
        self.updatedAt = updatedAt
        self.repoName = repoName
        self.customTitle = customTitle
        self.desktopTitle = desktopTitle
        self.aiTitle = aiTitle
        self.summary = summary
        self.firstUserMessage = firstUserMessage
        self.lastUserMessage = lastUserMessage
        self.codexRolloutPath = codexRolloutPath
        self.codexOrigin = codexOrigin
        self.codexSubagentKind = codexSubagentKind
        self.pendingRequestIds = pendingRequestIds
        self.needsAttention = needsAttention
        self.reportedStatus = reportedStatus
        self.hasUnreadCompletion = hasUnreadCompletion
        self.tasks = tasks
        self.todos = todos
        self.subagents = subagents
        self.teamGrouping = teamGrouping
        self.actionableRequests = actionableRequests
        self.questionPrompt = questionPrompt
        self.isRestored = isRestored
        self.jumpInput = jumpInput
        self.resolvedJumpTarget = resolvedJumpTarget
        self.childTreeGeneration = childTreeGeneration
        self.childLifecycleRevision = childLifecycleRevision
        self.childTreeHasAuthoritativeChildren = childTreeHasAuthoritativeChildren
    }

    // Preserve the pre-V3-field constructor symbol for already-built app
    // test clients and helper modules.
    public init(
        sessionId: String,
        source: String,
        cwd: String,
        cliSessionId: String? = nil,
        activeTool: String? = nil,
        activitySummary: String? = nil,
        safeTitle: String? = nil,
        originalStatus: OriginalPixelStatusCompact = .waitingForInput,
        toolInput: [String: BridgeJSONValue]? = nil,
        toolTarget: String? = nil,
        lastAssistantMessage: String? = nil,
        currentCommandPreview: String? = nil,
        updatedAt: Date? = nil,
        repoName: String? = nil,
        customTitle: String? = nil,
        desktopTitle: String? = nil,
        aiTitle: String? = nil,
        summary: String? = nil,
        firstUserMessage: String? = nil,
        lastUserMessage: String? = nil,
        codexRolloutPath: String? = nil,
        pendingRequestIds: [String] = [],
        needsAttention: Bool = false,
        reportedStatus: SessionStatus? = nil,
        hasUnreadCompletion: Bool = false,
        tasks: [TaskItem] = [],
        todos: [TodoItem] = [],
        subagents: [SubagentState] = [],
        teamGrouping: TeamGrouping? = nil,
        actionableRequests: [ActionableRequest] = [],
        questionPrompt: String? = nil,
        isRestored: Bool = false,
        jumpInput: JumpInput? = nil,
        resolvedJumpTarget: TerminalResolvedTarget? = nil
    ) {
        self.init(
            sessionId: sessionId,
            source: source,
            cwd: cwd,
            cliSessionId: cliSessionId,
            activeTool: activeTool,
            activitySummary: activitySummary,
            safeTitle: safeTitle,
            originalStatus: originalStatus,
            toolInput: toolInput,
            toolTarget: toolTarget,
            lastAssistantMessage: lastAssistantMessage,
            currentCommandPreview: currentCommandPreview,
            updatedAt: updatedAt,
            repoName: repoName,
            customTitle: customTitle,
            desktopTitle: desktopTitle,
            aiTitle: aiTitle,
            summary: summary,
            firstUserMessage: firstUserMessage,
            lastUserMessage: lastUserMessage,
            codexRolloutPath: codexRolloutPath,
            pendingRequestIds: pendingRequestIds,
            needsAttention: needsAttention,
            reportedStatus: reportedStatus,
            hasUnreadCompletion: hasUnreadCompletion,
            tasks: tasks,
            todos: todos,
            subagents: subagents,
            teamGrouping: teamGrouping,
            actionableRequests: actionableRequests,
            questionPrompt: questionPrompt,
            isRestored: isRestored,
            jumpInput: jumpInput,
            resolvedJumpTarget: resolvedJumpTarget,
            childTreeGeneration: 0,
            childLifecycleRevision: 0,
            childTreeHasAuthoritativeChildren: false
        )
    }

    public init(agentSession: AgentSession) {
        self.init(
            sessionId: agentSession.id,
            source: agentSession.source,
            cwd: agentSession.cwd,
            cliSessionId: agentSession.cliSessionId,
            activeTool: agentSession.activeTool,
            activitySummary: agentSession.activitySummary,
            safeTitle: agentSession.safeTitle,
            originalStatus: Self.restoredStatus(for: agentSession),
            toolInput: agentSession.toolInput,
            toolTarget: agentSession.toolTarget,
            lastAssistantMessage: agentSession.lastAssistantMessage,
            currentCommandPreview: agentSession.currentCommandPreview,
            updatedAt: agentSession.updatedAt,
            lastActivityAt: agentSession.lastActivityAt,
            repoName: agentSession.repoName,
            customTitle: agentSession.customTitle,
            desktopTitle: agentSession.desktopTitle,
            aiTitle: agentSession.aiTitle,
            summary: agentSession.summary,
            firstUserMessage: Self.visibleUserText(agentSession.firstUserMessage),
            lastUserMessage: Self.visibleUserText(agentSession.lastUserMessage),
            codexRolloutPath: agentSession.codexRolloutPath,
            codexOrigin: agentSession.codexOrigin,
            codexSubagentKind: agentSession.codexSubagentKind,
            // Original bridge keeps pending approvals in its in-memory socket
            // server and expires them by TTL. A restarted app cannot own the
            // hook response fd, so persisted request state is never actionable.
            pendingRequestIds: [],
            needsAttention: false,
            hasUnreadCompletion: agentSession.hasUnreadCompletion,
            tasks: agentSession.tasks,
            todos: agentSession.todos,
            subagents: agentSession.subagents,
            actionableRequests: [],
            questionPrompt: nil,
            isRestored: true,
            jumpInput: agentSession.jumpInput,
            resolvedJumpTarget: agentSession.resolvedJumpTarget
        )
    }

    public mutating func apply(
        _ event: AgentEvent,
        actionableRequestLifecycleTimestamp: Date? = nil
    ) {
        let requestLifecycleTimestamp = actionableRequestLifecycleTimestamp ?? Date()
        switch event {
        case let .sessionActivityUpdated(_, _, activity):
            isRestored = false
            // A confirmed terminal state is authoritative: a completed or
            // failed turn cannot retain an actionable request after native
            // Terminal approval has finished.
            if activity.status == .completed || activity.status == .failed {
                let pendingRequestCount = pendingRequestIds.count
                let actionableRequestCount = actionableRequests.count
                pendingRequestIds.removeAll()
                actionableRequests.removeAll()
                if pendingRequestCount > 0 || actionableRequestCount > 0 {
                    SessionCompletionTraceLog.append(
                        stage: "approval.terminal_completion_cleared",
                        sessionId: sessionId,
                        metadata: [
                            "status": activity.status.rawValue,
                            "pendingRequestCount": String(pendingRequestCount),
                            "actionableRequestCount": String(actionableRequestCount),
                        ]
                    )
                }
            }
            cliSessionId = activity.cliSessionId ?? cliSessionId
            safeTitle = activity.safeTitle ?? safeTitle
            activeTool = activity.activeTool
            toolInput = activity.toolInput
            questionPrompt = Self.questionPrompt(from: activity.toolInput)
            toolTarget = activity.toolTarget
            lastAssistantMessage = activity.lastAssistantMessage ?? lastAssistantMessage
            currentCommandPreview = activity.currentCommandPreview
            let activityDate = activity.updatedAt ?? Date()
            updatedAt = activityDate
            lastActivityAt = activityDate
            activitySummary = activity.summary
            if let firstUserMessage = Self.visibleUserText(activity.firstUserMessage) {
                if activity.isBootstrapFirstUserMessage {
                    if self.firstUserMessage == nil {
                        self.firstUserMessage = firstUserMessage
                    }
                } else {
                    self.firstUserMessage = firstUserMessage
                }
            }
            if let lastUserMessage = Self.visibleUserText(activity.lastUserMessage) {
                self.lastUserMessage = lastUserMessage
            }
            codexRolloutPath = activity.codexRolloutPath ?? codexRolloutPath
            codexOrigin = activity.codexOrigin ?? codexOrigin
            codexSubagentKind = activity.codexSubagentKind ?? codexSubagentKind
            reportedStatus = activity.status
            let hasPendingAction = !pendingRequestIds.isEmpty || !actionableRequests.isEmpty
            needsAttention = activity.needsAttention || hasPendingAction
            if hasPendingAction || activity.startsNewTurn {
                hasUnreadCompletion = false
            } else if activity.hasUnreadCompletion {
                hasUnreadCompletion = true
            }
            if actionableRequests.contains(where: { $0.kind == .question }) {
                originalStatus = .question
            } else if actionableRequests.contains(where: { $0.kind == .permission }) {
                originalStatus = .waitingForApproval
            } else {
                originalStatus = activity.originalStatus ?? originalStatus(for: activity.status)
            }
        case let .permissionRequested(source, sessionId, requestId, toolName, details):
            isRestored = false
            if !pendingRequestIds.contains(requestId) {
                pendingRequestIds.append(requestId)
            }
            upsert(
                ActionableRequest(
                    requestId: requestId,
                    sessionId: sessionId,
                    source: source,
                    kind: .permission,
                    toolName: toolName,
                    details: details,
                    actionableRequestLifecycleTimestamp: requestLifecycleTimestamp
                ),
                into: &actionableRequests
            )
            needsAttention = true
            originalStatus = .waitingForApproval
        case let .questionAsked(source, sessionId, requestId, toolName, details):
            isRestored = false
            if !pendingRequestIds.contains(requestId) {
                pendingRequestIds.append(requestId)
            }
            upsert(
                ActionableRequest(
                    requestId: requestId,
                    sessionId: sessionId,
                    source: source,
                    kind: .question,
                    toolName: toolName,
                    details: details,
                    actionableRequestLifecycleTimestamp: requestLifecycleTimestamp
                ),
                into: &actionableRequests
            )
            needsAttention = true
            originalStatus = .question
        case let .taskUpdated(_, _, task):
            isRestored = false
            upsert(task, into: &tasks)
        case let .todoUpdated(_, _, todo):
            isRestored = false
            upsert(todo, into: &todos)
        case let .teamGroupingUpdated(_, _, grouping):
            isRestored = false
            teamGrouping = grouping
        case let .jumpTargetUpdated(_, _, jumpInput):
            isRestored = false
            let resolver = TerminalResolver()
            let candidate = resolver.resolve(jumpInput, provenance: .hookEnvironment)
            resolvedJumpTarget = resolver.prefer(stored: resolvedJumpTarget, candidate: candidate)
            self.jumpInput = resolvedJumpTarget?.input ?? jumpInput
        case .subagentLifecycleUpdated:
            break
        case let .actionResolved(resolution):
            _ = applyResolution(resolution)
        case .sessionStarted, .sessionEnded, .messageReceived:
            break
        }
    }

    private static func visibleUserText(_ value: String?) -> String? {
        value.flatMap(SyntheticUserText.unwrappedUserQuery)
    }

    public mutating func markLive(source: String? = nil, cwd: String? = nil) {
        isRestored = false
        if let source { self.source = source }
        if let cwd { self.cwd = cwd }
    }

    /// Mirrors the V3 child watcher boundary. The revision advances for every
    /// accepted lifecycle update. A new generation is opened only when a
    /// running authoritative child arrives while no authoritative child is
    /// currently running.
    public mutating func recordAcceptedChildLifecycle(_ lifecycle: SubagentLifecycleUpdate) {
        let hadRunningAuthoritativeChild = subagents.contains {
            $0.hasLifecycleSignal && $0.status != SubagentLifecycleUpdate.Status.completed.rawValue
        }
        childLifecycleRevision &+= 1
        if lifecycle.status == .running && !hadRunningAuthoritativeChild {
            childTreeGeneration &+= 1
            childTreeHasAuthoritativeChildren = true
        }
    }

    public mutating func beginRuntime(source: String, cwd: String, at date: Date) {
        runtimeInstanceId = UUID()
        lastActivityAt = date
        hookIngressRevision &+= 1
        rawHookIngressCutoff = hookIngressRevision
        self.source = source
        self.cwd = cwd
        isRestored = false
    }

    public mutating func recordLifecycleIngress(
        isPermission: Bool,
        at date: Date
    ) {
        lastActivityAt = updatedAt ?? date
        hookIngressRevision &+= 1
        rawHookIngressCutoff = hookIngressRevision
        if isPermission {
            permissionIngressRevision &+= 1
            rawPermissionIngressCutoff = permissionIngressRevision
        }
    }

    public func sessionEndIntent() -> SessionEndIntent {
        SessionEndIntent(
            sessionId: sessionId,
            runtimeInstanceId: runtimeInstanceId,
            lastActivityAt: lastActivityAt,
            status: snapshot().status,
            hookIngressRevision: hookIngressRevision,
            rawHookIngressCutoff: rawHookIngressCutoff,
            permissionIngressRevision: permissionIngressRevision,
            rawPermissionIngressCutoff: rawPermissionIngressCutoff
        )
    }

    public func matches(_ intent: SessionEndIntent) -> Bool {
        intent.sessionId == sessionId
            && intent.runtimeInstanceId == runtimeInstanceId
            && intent.lastActivityAt == lastActivityAt
            && intent.status == snapshot().status
            && intent.hookIngressRevision == hookIngressRevision
            && intent.rawHookIngressCutoff == rawHookIngressCutoff
            && intent.permissionIngressRevision == permissionIngressRevision
            && intent.rawPermissionIngressCutoff == rawPermissionIngressCutoff
    }

    public mutating func updateJumpTarget(
        _ jumpInput: JumpInput,
        provenance: TerminalResolutionProvenance,
        strength: TerminalTargetStrength
    ) {
        isRestored = false
        let resolver = TerminalResolver()
        let resolved = resolver.resolve(jumpInput, provenance: provenance)
        let candidate = TerminalResolvedTarget(
            input: resolved.input,
            provenance: resolved.provenance,
            strength: strength,
            plannedHandlerId: resolved.plannedHandlerId,
            plannedPrecision: resolved.plannedPrecision,
            capabilityDescriptor: resolved.capabilityDescriptor,
            diagnosticSummary: resolved.diagnosticSummary
        )
        resolvedJumpTarget = resolver.prefer(stored: resolvedJumpTarget, candidate: candidate)
        self.jumpInput = resolvedJumpTarget?.input ?? jumpInput
    }

    public func replacingJumpInput(
        _ jumpInput: JumpInput,
        provenance: TerminalResolutionProvenance = .processObservation
    ) -> SessionState {
        var copy = self
        let target = TerminalResolver().resolve(jumpInput, provenance: provenance)
        copy.jumpInput = target.input
        copy.resolvedJumpTarget = target
        return copy
    }

    @discardableResult
    public mutating func applyResolution(_ resolution: ActionResolution) -> Bool {
        guard resolution.sessionId == sessionId else {
            return false
        }
        guard pendingRequestIds.contains(resolution.requestId) || actionableRequests.contains(where: { $0.requestId == resolution.requestId }) else {
            return false
        }

        pendingRequestIds.removeAll { $0 == resolution.requestId }
        actionableRequests.removeAll { $0.requestId == resolution.requestId }
        needsAttention = !pendingRequestIds.isEmpty || !actionableRequests.isEmpty
        if !needsAttention {
            // A terminal-routed approval handoff has released its request.  Persisting
            // the previous waiting status would turn the released session back into a
            // blocking card when session-terminals.json is read on the next refresh.
            if let reportedStatus {
                originalStatus = originalStatus(for: reportedStatus)
            } else {
                originalStatus = .unknown
            }
        }
        isRestored = false
        return true
    }

    public func snapshot() -> SessionSnapshot {
        let waitingActionSummary = WaitingActionSummary(
            pendingRequestIds: pendingRequestIds,
            needsAttention: needsAttention
        )
        let activeTaskCount = tasks.filter { $0.status == .active }.count

        return SessionSnapshot(
            sessionId: sessionId,
            source: source,
            status: status(activeTaskCount: activeTaskCount),
            cwdDisplay: cwdDisplay,
            activeTaskCount: activeTaskCount,
            todoCount: todos.count,
            waitingActionSummary: waitingActionSummary,
            redactionLevel: .metadataOnly,
            isRestored: isRestored,
            jumpInput: jumpInput,
            resolvedJumpTarget: resolvedJumpTarget
        )
    }

    public func presentation() -> SessionPresentation {
        let snapshot = snapshot()
        return SessionPresentation(
            sessionId: sessionId,
            sourceBadge: source,
            statusBadge: snapshot.status.rawValue,
            taskSummary: "\(snapshot.activeTaskCount)/\(tasks.count) active tasks",
            todoSummary: "\(todos.count) todos",
            attentionRequired: snapshot.waitingActionSummary.needsAttention || snapshot.waitingActionSummary.pendingRequestCount > 0,
            redactionLevel: snapshot.redactionLevel,
            restored: isRestored
        )
    }

    public func agentSession(includeEphemeralActionState: Bool = true) -> AgentSession {
        let persistedApprovalStatus: OriginalPixelStatusCompact =
            originalStatus == .waitingForApproval || originalStatus == .question
                ? .unknown
                : originalStatus
        return AgentSession(
            id: sessionId,
            source: source,
            cwd: cwd,
            cliSessionId: cliSessionId,
            activeTool: activeTool,
            activitySummary: activitySummary,
            safeTitle: safeTitle,
            originalStatus: includeEphemeralActionState ? originalStatus : persistedApprovalStatus,
            toolInput: toolInput,
            toolTarget: toolTarget,
            lastAssistantMessage: lastAssistantMessage,
            currentCommandPreview: currentCommandPreview,
            updatedAt: updatedAt,
            lastActivityAt: lastActivityAt,
            repoName: repoName,
            customTitle: customTitle,
            desktopTitle: desktopTitle,
            aiTitle: aiTitle,
            summary: summary,
            firstUserMessage: firstUserMessage,
            lastUserMessage: lastUserMessage,
            codexRolloutPath: codexRolloutPath,
            codexOrigin: codexOrigin,
            codexSubagentKind: codexSubagentKind,
            tasks: tasks,
            todos: todos,
            subagents: subagents,
            pendingRequestIds: includeEphemeralActionState ? pendingRequestIds : [],
            actionableRequests: includeEphemeralActionState ? actionableRequests : [],
            questionPrompt: includeEphemeralActionState ? questionPrompt : nil,
            isRestored: isRestored,
            hasUnreadCompletion: hasUnreadCompletion,
            jumpInput: jumpInput,
            resolvedJumpTarget: resolvedJumpTarget,
            redactionLevel: .metadataOnly
        )
    }

    private static func questionPrompt(from toolInput: [String: BridgeJSONValue]?) -> String? {
        guard let toolInput else { return nil }
        if case let .string(prompt) = toolInput["question"], !prompt.isEmpty {
            return prompt
        }
        return ActionRequestDetails.safeDetails(from: toolInput)?.questions.first?.prompt
            ?? ActionRequestDetails.safeDetails(from: toolInput)?.prompt
    }

    private static func restoredStatus(for session: AgentSession) -> OriginalPixelStatusCompact {
        let containsEphemeralAction = !session.pendingRequestIds.isEmpty
            || !session.actionableRequests.isEmpty
            || session.questionPrompt != nil
            || session.originalStatus == .waitingForApproval
            || session.originalStatus == .question
        return containsEphemeralAction ? .unknown : session.originalStatus
    }

    private func upsert(_ task: TaskItem, into tasks: inout [TaskItem]) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
    }

    private func upsert(_ todo: TodoItem, into todos: inout [TodoItem]) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index] = todo
        } else {
            todos.append(todo)
        }
    }

    public mutating func upsertSubagent(_ subagent: SubagentState) {
        if let index = subagents.firstIndex(where: { $0.id == subagent.id }) {
            subagents[index] = subagent
        } else {
            subagents.append(subagent)
        }
    }

    private func upsert(_ request: ActionableRequest, into requests: inout [ActionableRequest]) {
        if let index = requests.firstIndex(where: { $0.requestId == request.requestId }) {
            let lifecycleTimestamp = requests[index].actionableRequestLifecycleTimestamp
                ?? request.actionableRequestLifecycleTimestamp
            requests[index] = ActionableRequest(
                requestId: request.requestId,
                sessionId: request.sessionId,
                source: request.source,
                kind: request.kind,
                toolName: request.toolName,
                details: request.details,
                actionableRequestLifecycleTimestamp: lifecycleTimestamp
            )
        } else {
            requests.append(request)
        }
    }

    private var cwdDisplay: String {
        if cwd.isEmpty || cwd == "/" {
            return cwd
        }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }

    private func status(activeTaskCount: Int) -> SessionStatus {
        if !pendingRequestIds.isEmpty || needsAttention {
            return .waiting
        }
        if let reportedStatus {
            return reportedStatus
        }
        if activeTaskCount > 0 {
            return .active
        }
        if tasks.contains(where: { $0.status == .failed }) {
            return .failed
        }
        if !tasks.isEmpty && tasks.allSatisfy({ $0.status == .completed }) {
            return .completed
        }
        return .idle
    }

    private func originalStatus(for status: SessionStatus) -> OriginalPixelStatusCompact {
        switch status {
        case .active:
            .processing
        case .waiting:
            .waitingForApproval
        case .completed, .failed:
            .ended
        case .idle:
            .waitingForInput
        }
    }
}
