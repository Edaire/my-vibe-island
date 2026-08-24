public struct OriginalCompactContentPlan: Equatable, Sendable {
    public enum DisplayClass: Equatable, Sendable {
        case physicalNotch
        case nonNotched
    }

    public struct SessionInput: Equatable, Sendable {
        public let status: OriginalPixelStatusCompact
        public let currentTool: String?
        public let toolInput: [String: BridgeJSONValue]?
        public let toolTarget: String?
        public let lastAssistantMessage: String?
        public let currentCommandPreview: String?
        public let activitySummary: String?
        public let tasks: [TaskItem]
        public let todos: [TodoItem]
        public let repoName: String?
        public let cwd: String?
        public let source: String?
        public let customTitle: String?
        public let desktopTitle: String?
        public let aiTitle: String?
        public let summary: String?
        public let firstUserMessage: String?
        public let lastUserMessage: String?

        public init(
            status: OriginalPixelStatusCompact,
            currentTool: String? = nil,
            toolInput: [String: BridgeJSONValue]? = nil,
            toolTarget: String? = nil,
            lastAssistantMessage: String? = nil,
            currentCommandPreview: String? = nil,
            activitySummary: String? = nil,
            tasks: [TaskItem] = [],
            todos: [TodoItem] = [],
            repoName: String? = nil,
            cwd: String? = nil,
            source: String? = nil,
            customTitle: String? = nil,
            desktopTitle: String? = nil,
            aiTitle: String? = nil,
            summary: String? = nil,
            firstUserMessage: String? = nil,
            lastUserMessage: String? = nil
        ) {
            self.status = status
            self.currentTool = currentTool
            self.toolInput = toolInput
            self.toolTarget = toolTarget
            self.lastAssistantMessage = lastAssistantMessage
            self.currentCommandPreview = currentCommandPreview
            self.activitySummary = activitySummary
            self.tasks = tasks
            self.todos = todos
            self.repoName = repoName
            self.cwd = cwd
            self.source = source
            self.customTitle = customTitle
            self.desktopTitle = desktopTitle
            self.aiTitle = aiTitle
            self.summary = summary
            self.firstUserMessage = firstUserMessage
            self.lastUserMessage = lastUserMessage
        }
    }

    public let status: OriginalPixelStatusCompact
    public let title: OriginalCompactTitlePlan?
    public let rightCount: OriginalCompactRightCount?
    public let activityLine: String?

    public init(
        status: OriginalPixelStatusCompact,
        title: OriginalCompactTitlePlan?,
        rightCount: OriginalCompactRightCount?,
        activityLine: String? = nil
    ) {
        self.status = status
        self.title = title
        self.rightCount = rightCount
        self.activityLine = activityLine
    }

    public static func resolve(
        displayClass: DisplayClass,
        sessions: [SessionInput]
    ) -> Self {
        let status = sessions.first?.status ?? .waitingForInput
        let rightCount = OriginalCompactRightCount.resolve(
            eligibleStatuses: sessions.map(\.status)
        )

        guard let first = sessions.first else {
            let title: OriginalCompactTitlePlan? = switch displayClass {
            case .physicalNotch:
                nil
            case .nonNotched:
                OriginalCompactTitlePlan(content: .verbatim("Vibe Island"))
            }
            return Self(status: status, title: title, rightCount: rightCount)
        }

        let resolvedTitle = switch displayClass {
        case .physicalNotch:
            OriginalCompactPhysicalTitlePlan.resolve(
                status: first.status,
                currentTool: first.currentTool,
                toolInput: effectiveToolInput(for: first),
                tasks: first.tasks,
                todos: first.todos,
                repoName: first.repoName,
                cwd: first.cwd,
                source: first.source
            )

        case .nonNotched:
            OriginalCompactNonNotchedTitlePlan.resolve(
                status: first.status,
                currentTool: first.currentTool,
                toolInput: effectiveToolInput(for: first),
                toolTarget: first.toolTarget,
                repoName: first.repoName,
                cwd: first.cwd,
                source: first.source,
                customTitle: first.customTitle,
                desktopTitle: first.desktopTitle,
                aiTitle: first.aiTitle,
                summary: first.summary,
                normalizedFirstUserMessage: first.firstUserMessage.flatMap(
                    OriginalCompactConversationMessageNormalizer.resolve
                ),
                normalizedLastUserMessage: first.lastUserMessage.flatMap(
                    OriginalCompactConversationMessageNormalizer.resolve
                )
            )
        }

        let title = if let command = first.currentCommandPreview,
                       let tool = first.currentTool {
            OriginalCompactTitlePlan(
                content: .verbatim("\(tool): \(command)"),
                transform: displayClass == .physicalNotch ? .physicalCompact : .none
            )
        } else {
            resolvedTitle
        }

        return Self(
            status: status,
            title: title,
            rightCount: rightCount,
            activityLine: normalized(first.currentCommandPreview)
                ?? normalized(first.activitySummary)
                ?? normalized(first.lastAssistantMessage)
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
        return normalized.isEmpty ? nil : normalized
    }

    private static func effectiveToolInput(
        for session: SessionInput
    ) -> [String: BridgeJSONValue]? {
        session.toolInput
            ?? session.currentCommandPreview.map { ["command": .string($0)] }
    }
}
