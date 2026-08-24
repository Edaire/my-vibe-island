import Foundation

public struct ActionRequestPreview: Codable, Equatable, Sendable {
    public let requestId: String
    public let sessionId: String
    public let source: String
    public let kind: ActionableRequestKind
    public let toolName: String
    public let prompt: String?
    public let command: String?
    public let reason: String?
    public let options: [ActionRequestOption]
    public let allowsMultipleSelection: Bool
    public let questions: [ActionRequestQuestion]
    public let canResolveLocally: Bool
    public let supportsPersistentApproval: Bool
    public let actionableRequestLifecycleTimestamp: Date?

    public init(request: ActionableRequest) {
        self.init(request: request, isLocallyOwned: nil)
    }

    public init(
        request: ActionableRequest,
        isLocallyOwned: Bool?,
        codexApprovalTarget: String? = UserDefaults.standard.string(forKey: "codexApprovalTarget")
    ) {
        requestId = request.requestId
        sessionId = request.sessionId
        source = request.source
        kind = request.kind
        toolName = request.toolName
        prompt = request.details?.prompt
        command = request.details?.command
        reason = request.details?.reason
        options = request.details?.options ?? []
        allowsMultipleSelection = request.details?.allowsMultipleSelection ?? false
        questions = request.details?.questions ?? []
        actionableRequestLifecycleTimestamp = request.actionableRequestLifecycleTimestamp
        let adapterSupportsLocalResolution = AgentAdapterRegistry.default.blockingTimeout(for: request) != nil
        let hasLocalOwnership = isLocallyOwned ?? adapterSupportsLocalResolution
        // The captured default Codex path keeps native allow/deny controls in
        // Island. The legacy `terminal` target remains a distinct handoff
        // presentation.
        let usesTerminalHandoff = request.source == "codex"
            && request.kind == .permission
            && CodexApprovalRoutingPolicy.presentation(target: codexApprovalTarget) == .terminalHandoff
        canResolveLocally = !usesTerminalHandoff
            && hasLocalOwnership
            && adapterSupportsLocalResolution
            && (request.kind == .permission || !options.isEmpty || !questions.isEmpty)
        supportsPersistentApproval = canResolveLocally
            && request.kind == .permission
            && request.source == "opencode"
    }
}

public struct V3SessionNotificationMetadata: Codable, Equatable, Sendable {
    public let childTreeGeneration: Int
    public let childLifecycleRevision: Int
    public let childTreeHasAuthoritativeChildren: Bool
    public let runningAuthoritativeChildCount: Int
    public let hasSameTreeAttention: Bool

    public init(
        childTreeGeneration: Int = 0,
        childLifecycleRevision: Int = 0,
        childTreeHasAuthoritativeChildren: Bool = false,
        runningAuthoritativeChildCount: Int = 0,
        hasSameTreeAttention: Bool = false
    ) {
        self.childTreeGeneration = childTreeGeneration
        self.childLifecycleRevision = childLifecycleRevision
        self.childTreeHasAuthoritativeChildren = childTreeHasAuthoritativeChildren
        self.runningAuthoritativeChildCount = runningAuthoritativeChildCount
        self.hasSameTreeAttention = hasSameTreeAttention
    }
}

public struct IslandRuntimeSnapshot: Codable, Equatable, Sendable {
    public let sessions: [AgentSession]
    public let sessionPreviews: [SessionCardPreview]
    public let actionRequestPreviews: [ActionRequestPreview]
    /// Runtime-only publication of SessionState fields recovered from V3.
    /// It is intentionally omitted from the legacy wire encoding.
    public let v3NotificationMetadata: [String: V3SessionNotificationMetadata]

    public init(
        sessions: [AgentSession] = [],
        sessionPreviews: [SessionCardPreview] = [],
        actionRequestPreviews: [ActionRequestPreview] = [],
        v3NotificationMetadata: [String: V3SessionNotificationMetadata] = [:]
    ) {
        self.sessions = sessions
        self.sessionPreviews = sessionPreviews
        self.actionRequestPreviews = actionRequestPreviews
        self.v3NotificationMetadata = v3NotificationMetadata
    }

    // Preserve the pre-metadata constructor symbol for already-built app and
    // test clients that link the core module incrementally.
    public init(
        sessions: [AgentSession],
        sessionPreviews: [SessionCardPreview],
        actionRequestPreviews: [ActionRequestPreview]
    ) {
        self.init(
            sessions: sessions,
            sessionPreviews: sessionPreviews,
            actionRequestPreviews: actionRequestPreviews,
            v3NotificationMetadata: [:]
        )
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sessions: try container.decodeIfPresent([AgentSession].self, forKey: .sessions) ?? [],
            sessionPreviews: try container.decode([SessionCardPreview].self, forKey: .sessionPreviews),
            actionRequestPreviews: try container.decode([ActionRequestPreview].self, forKey: .actionRequestPreviews),
            v3NotificationMetadata: [:]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case sessions
        case sessionPreviews
        case actionRequestPreviews
    }
}
