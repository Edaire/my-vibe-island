public struct CodexSubagentThread: Codable, Equatable, Sendable {
    public let parentThreadId: String?
    public let agentNickname: String?
    public let agentRole: String?
    public let childThreadId: String?
    public let spawnKind: String?
    public let sourceWrapperId: String?
    public let observedAt: String?
    public let confidence: Double

    public init(
        parentThreadId: String? = nil,
        agentNickname: String? = nil,
        agentRole: String? = nil,
        childThreadId: String? = nil,
        spawnKind: String? = nil,
        sourceWrapperId: String? = nil,
        observedAt: String? = nil,
        confidence: Double = 0.5
    ) {
        self.parentThreadId = parentThreadId
        self.agentNickname = agentNickname
        self.agentRole = agentRole
        self.childThreadId = childThreadId
        self.spawnKind = spawnKind
        self.sourceWrapperId = sourceWrapperId
        self.observedAt = observedAt
        self.confidence = min(max(confidence, 0.0), 1.0)
    }

    public var identityKey: String {
        if let childThreadId, !childThreadId.isEmpty {
            return childThreadId
        }

        return "weak:" + weakIdentityParts
            .map { "\($0.kind)=\($0.value)" }
            .joined(separator: "|")
    }

    public var identityIsWeak: Bool {
        childThreadId?.isEmpty ?? true
    }

    private var weakIdentityParts: [(kind: String, value: String)] {
        [
            ("agentNickname", agentNickname),
            ("agentRole", agentRole),
            ("parentThreadId", parentThreadId),
            ("spawnKind", spawnKind)
        ].compactMap { kind, value in
            guard let value, !value.isEmpty else {
                return nil
            }

            return (kind, value)
        }
    }
}
