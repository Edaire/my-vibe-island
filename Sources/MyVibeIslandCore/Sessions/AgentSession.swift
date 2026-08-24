import Foundation
import MyVibeIslandShared

public struct AgentSession: Codable, Equatable, Sendable {
    public let id: String
    public let source: String
    public let cwd: String
    public let cliSessionId: String?
    public let workspaceName: String?
    public let model: String?
    public let permissionMode: String?
    public let activeTool: String?
    public let activitySummary: String?
    public let safeTitle: String?
    public let originalStatus: OriginalPixelStatusCompact
    public let toolInput: [String: BridgeJSONValue]?
    public let toolTarget: String?
    public let lastAssistantMessage: String?
    public let currentCommandPreview: String?
    public let updatedAt: Date?
    public let lastActivityAt: Date?
    public let repoName: String?
    public let customTitle: String?
    public let desktopTitle: String?
    public let aiTitle: String?
    public let summary: String?
    public let firstUserMessage: String?
    public let lastUserMessage: String?
    public let codexRolloutPath: String?
    public let codexOrigin: String?
    public let codexSubagentKind: String?
    public let tasks: [TaskItem]
    public let todos: [TodoItem]
    public let subagents: [SubagentState]
    public let pendingRequestIds: [String]
    public let actionableRequests: [ActionableRequest]
    public let questionPrompt: String?
    public let isRestored: Bool
    public let isRemote: Bool
    public let hasUnreadCompletion: Bool
    public let jumpInput: JumpInput?
    public let resolvedJumpTarget: TerminalResolvedTarget?
    public let redactionLevel: RedactionLevel

    public init(
        id: String,
        source: String,
        cwd: String,
        cliSessionId: String? = nil,
        workspaceName: String? = nil,
        model: String? = nil,
        permissionMode: String? = nil,
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
        tasks: [TaskItem] = [],
        todos: [TodoItem] = [],
        subagents: [SubagentState] = [],
        pendingRequestIds: [String] = [],
        actionableRequests: [ActionableRequest] = [],
        questionPrompt: String? = nil,
        isRestored: Bool = false,
        isRemote: Bool = false,
        hasUnreadCompletion: Bool = false,
        jumpInput: JumpInput? = nil,
        resolvedJumpTarget: TerminalResolvedTarget? = nil,
        redactionLevel: RedactionLevel = .metadataOnly
    ) {
        self.id = id
        self.source = source
        self.cwd = cwd
        self.cliSessionId = cliSessionId
        self.workspaceName = workspaceName
        self.model = model
        self.permissionMode = permissionMode
        self.activeTool = activeTool
        self.activitySummary = activitySummary
        self.safeTitle = safeTitle
        self.originalStatus = originalStatus
        self.toolInput = toolInput
        self.toolTarget = toolTarget
        self.lastAssistantMessage = lastAssistantMessage
        self.currentCommandPreview = currentCommandPreview
        self.updatedAt = updatedAt
        self.lastActivityAt = lastActivityAt ?? updatedAt
        self.repoName = repoName
        self.customTitle = customTitle
        self.desktopTitle = desktopTitle
        self.aiTitle = aiTitle
        self.summary = summary
        self.firstUserMessage = firstUserMessage.flatMap(SyntheticUserText.unwrappedUserQuery)
        self.lastUserMessage = lastUserMessage.flatMap(SyntheticUserText.unwrappedUserQuery)
        self.codexRolloutPath = codexRolloutPath
        self.codexOrigin = codexOrigin
        self.codexSubagentKind = codexSubagentKind
        self.tasks = tasks
        self.todos = todos
        self.subagents = subagents
        self.pendingRequestIds = pendingRequestIds
        self.actionableRequests = actionableRequests
        self.questionPrompt = questionPrompt
        self.isRestored = isRestored
        self.isRemote = isRemote
        self.hasUnreadCompletion = hasUnreadCompletion
        self.jumpInput = jumpInput
        self.resolvedJumpTarget = resolvedJumpTarget
        self.redactionLevel = redactionLevel
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            source: try container.decode(String.self, forKey: .source),
            cwd: try container.decode(String.self, forKey: .cwd),
            cliSessionId: try container.decodeIfPresent(String.self, forKey: .cliSessionId),
            workspaceName: try container.decodeIfPresent(String.self, forKey: .workspaceName),
            model: try container.decodeIfPresent(String.self, forKey: .model),
            permissionMode: try container.decodeIfPresent(String.self, forKey: .permissionMode),
            activeTool: try container.decodeIfPresent(String.self, forKey: .activeTool),
            activitySummary: try container.decodeIfPresent(String.self, forKey: .activitySummary),
            safeTitle: try container.decodeIfPresent(String.self, forKey: .safeTitle),
            originalStatus: try container.decodeIfPresent(OriginalPixelStatusCompact.self, forKey: .originalStatus) ?? .waitingForInput,
            toolInput: try container.decodeIfPresent([String: BridgeJSONValue].self, forKey: .toolInput),
            toolTarget: try container.decodeIfPresent(String.self, forKey: .toolTarget),
            lastAssistantMessage: try container.decodeIfPresent(String.self, forKey: .lastAssistantMessage),
            currentCommandPreview: try container.decodeIfPresent(String.self, forKey: .currentCommandPreview),
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt),
            lastActivityAt: try container.decodeIfPresent(Date.self, forKey: .lastActivityAt),
            repoName: try container.decodeIfPresent(String.self, forKey: .repoName),
            customTitle: try container.decodeIfPresent(String.self, forKey: .customTitle),
            desktopTitle: try container.decodeIfPresent(String.self, forKey: .desktopTitle),
            aiTitle: try container.decodeIfPresent(String.self, forKey: .aiTitle),
            summary: try container.decodeIfPresent(String.self, forKey: .summary),
            firstUserMessage: try container.decodeIfPresent(String.self, forKey: .firstUserMessage),
            lastUserMessage: try container.decodeIfPresent(String.self, forKey: .lastUserMessage),
            codexRolloutPath: try container.decodeIfPresent(String.self, forKey: .codexRolloutPath),
            codexOrigin: try container.decodeIfPresent(String.self, forKey: .codexOrigin),
            codexSubagentKind: try container.decodeIfPresent(String.self, forKey: .codexSubagentKind),
            tasks: try container.decodeIfPresent([TaskItem].self, forKey: .tasks) ?? [],
            todos: try container.decodeIfPresent([TodoItem].self, forKey: .todos) ?? [],
            subagents: try container.decodeIfPresent([SubagentState].self, forKey: .subagents) ?? [],
            pendingRequestIds: try container.decodeIfPresent([String].self, forKey: .pendingRequestIds) ?? [],
            actionableRequests: try container.decodeIfPresent([ActionableRequest].self, forKey: .actionableRequests) ?? [],
            questionPrompt: try container.decodeIfPresent(String.self, forKey: .questionPrompt),
            isRestored: try container.decodeIfPresent(Bool.self, forKey: .isRestored) ?? false,
            isRemote: try container.decodeIfPresent(Bool.self, forKey: .isRemote) ?? false,
            hasUnreadCompletion: try container.decodeIfPresent(Bool.self, forKey: .hasUnreadCompletion) ?? false,
            jumpInput: try container.decodeIfPresent(JumpInput.self, forKey: .jumpInput),
            resolvedJumpTarget: try container.decodeIfPresent(TerminalResolvedTarget.self, forKey: .resolvedJumpTarget),
            redactionLevel: try container.decodeIfPresent(RedactionLevel.self, forKey: .redactionLevel) ?? .metadataOnly
        )
    }

    // Preserve the pre-origin metadata constructor for already-built app
    // test clients and helper modules.
    public init(
        id: String,
        source: String,
        cwd: String,
        cliSessionId: String? = nil,
        workspaceName: String? = nil,
        model: String? = nil,
        permissionMode: String? = nil,
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
        tasks: [TaskItem] = [],
        todos: [TodoItem] = [],
        subagents: [SubagentState] = [],
        pendingRequestIds: [String] = [],
        actionableRequests: [ActionableRequest] = [],
        questionPrompt: String? = nil,
        isRestored: Bool = false,
        isRemote: Bool = false,
        hasUnreadCompletion: Bool = false,
        jumpInput: JumpInput? = nil,
        resolvedJumpTarget: TerminalResolvedTarget? = nil,
        redactionLevel: RedactionLevel = .metadataOnly
    ) {
        self.init(
            id: id,
            source: source,
            cwd: cwd,
            cliSessionId: cliSessionId,
            workspaceName: workspaceName,
            model: model,
            permissionMode: permissionMode,
            activeTool: activeTool,
            activitySummary: activitySummary,
            safeTitle: safeTitle,
            originalStatus: originalStatus,
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
            codexOrigin: nil,
            codexSubagentKind: nil,
            tasks: tasks,
            todos: todos,
            subagents: subagents,
            pendingRequestIds: pendingRequestIds,
            actionableRequests: actionableRequests,
            questionPrompt: questionPrompt,
            isRestored: isRestored,
            isRemote: isRemote,
            hasUnreadCompletion: hasUnreadCompletion,
            jumpInput: jumpInput,
            resolvedJumpTarget: resolvedJumpTarget,
            redactionLevel: redactionLevel
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case source
        case cwd
        case cliSessionId
        case workspaceName
        case model
        case permissionMode
        case activeTool
        case activitySummary
        case safeTitle
        case originalStatus
        case toolInput
        case toolTarget
        case lastAssistantMessage
        case currentCommandPreview
        case updatedAt
        case lastActivityAt
        case repoName
        case customTitle
        case desktopTitle
        case aiTitle
        case summary
        case firstUserMessage
        case lastUserMessage
        case codexRolloutPath
        case codexOrigin
        case codexSubagentKind
        case tasks
        case todos
        case subagents
        case pendingRequestIds
        case actionableRequests
        case questionPrompt
        case isRestored
        case isRemote
        case hasUnreadCompletion
        case jumpInput
        case resolvedJumpTarget
        case redactionLevel
    }
}
