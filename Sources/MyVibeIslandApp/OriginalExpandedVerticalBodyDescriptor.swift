import MyVibeIslandCore

struct OriginalExpandedVerticalBodyDescriptor: Equatable {
    let status: OriginalPixelStatusCompact
    let displayTitle: String
    let taskSummary: String?
    let todoSummary: String?
    let childAgentSummary: String?
    let latestPrompt: String?
    let activityToolLabel: String?
    let activityContent: String?
    let activityLine: String?
    let activityLineIsCommand: Bool
    let assistantMessage: String?
    let questionPrompt: String?
    let passiveQuestionDetails: ActionRequestDetails?
    let approvalSummary: String?
    let taskItems: [TaskItem]
    let todoItems: [TodoItem]
    let childAgentItems: [SubagentState]
    let hasUnreadCompletion: Bool

    let rendersIdentityTag = false
    let rendersAge = false
    let rendersContextMenu = false
    let rendersUsageHeader = false
    let rendersEmptyState = false

    static func resolve(row: OriginalExpandedSessionRow) -> Self {
        let frameOneTitle = nonEmpty(row.session.firstUserMessage)
            ?? row.preview.displayTitle
        return Self(
            status: row.status,
            displayTitle: frameOneTitle,
            taskSummary: nonEmpty(row.taskSummary),
            todoSummary: nonEmpty(row.todoSummary),
            childAgentSummary: nonEmpty(row.childAgentSummary),
            latestPrompt: nonEmpty(row.session.lastUserMessage) ?? nonEmpty(row.session.firstUserMessage),
            activityToolLabel: activityToolLabel(row.session),
            activityContent: activityContent(row.session, status: row.status),
            activityLine: activityLine(row.session, status: row.status),
            activityLineIsCommand: nonEmpty(row.session.currentCommandPreview) != nil,
            assistantMessage: nonEmpty(row.session.lastAssistantMessage),
            questionPrompt: nonEmpty(row.session.questionPrompt) ?? requestPrompt(kind: .question, row: row),
            passiveQuestionDetails: passiveQuestionDetails(row: row),
            approvalSummary: approvalSummary(row: row),
            taskItems: row.session.tasks,
            todoItems: row.session.todos,
            childAgentItems: row.session.subagents,
            hasUnreadCompletion: row.session.hasUnreadCompletion
        )
    }

    private static func activityToolLabel(_ session: AgentSession) -> String? {
        guard let tool = nonEmpty(session.activeTool) else {
            guard nonEmpty(session.currentCommandPreview) != nil,
                  session.source.caseInsensitiveCompare("codex") == .orderedSame else {
                return nil
            }
            return "Bash"
        }
        switch tool.lowercased() {
        case "exec_command", "local_shell", "bash", "shell":
            return "Bash"
        default:
            return tool
        }
    }

    private static func activityContent(
        _ session: AgentSession,
        status: OriginalPixelStatusCompact
    ) -> String? {
        guard status != .ended else { return nil }
        return nonEmpty(session.currentCommandPreview)
            ?? nonEmpty(session.lastAssistantMessage)
            ?? visibleActivitySummary(session.activitySummary)
    }

    private static func activityLine(
        _ session: AgentSession,
        status: OriginalPixelStatusCompact
    ) -> String? {
        if status == .ended, nonEmpty(session.lastAssistantMessage) != nil {
            return nil
        }
        return nonEmpty(session.currentCommandPreview)
            ?? nonEmpty(session.lastAssistantMessage)
            ?? visibleActivitySummary(session.activitySummary)
    }

    // Completion notifications reuse the same session content source as the
    // expanded card, but prefer the completed assistant response itself.
    static func completionBody(for session: AgentSession) -> String? {
        nonEmpty(session.lastAssistantMessage)
            ?? nonEmpty(session.currentCommandPreview)
            ?? visibleActivitySummary(session.activitySummary)
    }

    private static func requestPrompt(
        kind: ActionableRequestKind,
        row: OriginalExpandedSessionRow
    ) -> String? {
        row.session.actionableRequests
            .first(where: { $0.kind == kind })?
            .details?.prompt
            .flatMap(nonEmpty)
    }

    private static func passiveQuestionDetails(row: OriginalExpandedSessionRow) -> ActionRequestDetails? {
        guard row.session.actionableRequests.isEmpty,
              row.session.activeTool == "AskUserQuestion",
              let toolInput = row.session.toolInput else {
            return nil
        }
        return ActionRequestDetails.safeDetails(from: toolInput)
    }

    private static func approvalSummary(row: OriginalExpandedSessionRow) -> String? {
        guard let request = row.session.actionableRequests.first(where: { $0.kind == .permission }) else {
            return row.session.pendingRequestIds.isEmpty ? nil : "Approval required"
        }
        if let prompt = request.details?.prompt.flatMap(nonEmpty) {
            return prompt
        }
        return nonEmpty(request.toolName).map { "\($0) approval required" } ?? "Approval required"
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, value.contains(where: { !$0.isWhitespace }) else { return nil }
        return value
    }

    static func visibleActivitySummary(_ value: String?) -> String? {
        guard let value = nonEmpty(value) else { return nil }
        let placeholders = [
            "Codex is working.",
            "Codex is running a tool.",
            "Codex is idle.",
            "Codex completed the turn.",
            "Codex failed to complete the turn.",
            "Codex needs attention."
        ]
        return placeholders.contains(value) ? nil : value
    }
}
