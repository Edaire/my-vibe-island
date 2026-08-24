public struct CodexSubagentSource: Codable, Equatable, Sendable {
    public let sourceId: String
    public let wrapperKind: String?
    public let subagentKind: String?
    public let sourceThreadSpawn: CodexSubagentThread?
    public let detailThreadSpawn: CodexSubagentThread?
    public let detailOther: String?
    public let parentThreadId: String?
    public let subagentDetailId: String?
    public let rawEventId: String?
    public let sessionId: String?
    public let observedAt: String?
    public let confidence: Double

    public init(
        sourceId: String,
        wrapperKind: String? = nil,
        subagentKind: String? = nil,
        sourceThreadSpawn: CodexSubagentThread? = nil,
        detailThreadSpawn: CodexSubagentThread? = nil,
        detailOther: String? = nil,
        parentThreadId: String? = nil,
        subagentDetailId: String? = nil,
        rawEventId: String? = nil,
        sessionId: String? = nil,
        observedAt: String? = nil,
        confidence: Double = 0.5
    ) {
        self.sourceId = sourceId
        self.wrapperKind = wrapperKind
        self.subagentKind = subagentKind
        self.sourceThreadSpawn = sourceThreadSpawn
        self.detailThreadSpawn = detailThreadSpawn
        self.detailOther = detailOther
        self.parentThreadId = parentThreadId
        self.subagentDetailId = subagentDetailId
        self.rawEventId = rawEventId
        self.sessionId = sessionId
        self.observedAt = observedAt
        self.confidence = min(max(confidence, 0.0), 1.0)
    }

    public var wrapperKey: String? {
        guard !sourceId.isEmpty, let rawEventId, !rawEventId.isEmpty else {
            return nil
        }

        return "\(sourceId):\(rawEventId)"
    }

    public var canCreateTopLevelSession: Bool {
        sessionId?.isEmpty == false
    }
}
