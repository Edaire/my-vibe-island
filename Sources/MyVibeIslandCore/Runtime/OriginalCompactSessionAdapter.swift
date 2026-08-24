public enum OriginalCompactSessionAdapter {
    public static func resolve(_ session: AgentSession) -> OriginalCompactContentPlan.SessionInput {
        OriginalCompactContentPlan.SessionInput(
            status: session.originalStatus,
            currentTool: session.activeTool,
            toolInput: session.toolInput,
            toolTarget: session.toolTarget,
            lastAssistantMessage: session.lastAssistantMessage,
            currentCommandPreview: session.currentCommandPreview,
            activitySummary: session.activitySummary,
            tasks: session.tasks,
            todos: session.todos,
            repoName: session.repoName,
            cwd: session.cwd,
            source: session.source,
            customTitle: session.customTitle ?? session.safeTitle,
            desktopTitle: session.desktopTitle,
            aiTitle: session.aiTitle,
            summary: session.summary ?? session.activitySummary,
            firstUserMessage: session.firstUserMessage,
            lastUserMessage: session.lastUserMessage
        )
    }
}
