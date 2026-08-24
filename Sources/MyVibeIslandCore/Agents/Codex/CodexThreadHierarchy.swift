public struct CodexThreadHierarchyNode: Codable, Equatable, Sendable {
    public let id: String
    public let parentThreadId: String?
    public let threadId: String?
    public let kind: String?
    public let firstSeenAt: String
    public let lastSeenAt: String?
    public let diagnosticReason: String?

    public init(
        id: String,
        parentThreadId: String? = nil,
        threadId: String? = nil,
        kind: String? = nil,
        firstSeenAt: String,
        lastSeenAt: String? = nil,
        diagnosticReason: String? = nil
    ) {
        self.id = id
        self.parentThreadId = parentThreadId
        self.threadId = threadId
        self.kind = kind
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.diagnosticReason = diagnosticReason
    }

    public var isDetached: Bool {
        parentThreadId?.isEmpty ?? true
    }

    public func markingDetachedIfNeeded() -> CodexThreadHierarchyNode {
        guard isDetached, diagnosticReason == nil else {
            return self
        }

        return CodexThreadHierarchyNode(
            id: id,
            parentThreadId: parentThreadId,
            threadId: threadId,
            kind: kind,
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastSeenAt,
            diagnosticReason: "missingParentThreadId"
        )
    }

    public func updating(with newer: CodexThreadHierarchyNode) -> CodexThreadHierarchyNode {
        CodexThreadHierarchyNode(
            id: id,
            parentThreadId: newer.parentThreadId ?? parentThreadId,
            threadId: newer.threadId ?? threadId,
            kind: newer.kind ?? kind,
            firstSeenAt: firstSeenAt < newer.firstSeenAt ? firstSeenAt : newer.firstSeenAt,
            lastSeenAt: newer.lastSeenAt ?? lastSeenAt,
            diagnosticReason: newer.diagnosticReason ?? diagnosticReason
        ).markingDetachedIfNeeded()
    }
}

public struct CodexThreadHierarchy: Codable, Equatable, Sendable {
    public let rootSessionId: String
    public let rootThreadId: String?
    public let childNodes: [CodexThreadHierarchyNode]
    public let activeChildId: String?
    public let completedChildIds: [String]
    public let failedChildIds: [String]
    public let detachedChildIds: [String]

    public init(
        rootSessionId: String,
        rootThreadId: String? = nil,
        childNodes: [CodexThreadHierarchyNode] = [],
        activeChildId: String? = nil,
        completedChildIds: [String] = [],
        failedChildIds: [String] = [],
        detachedChildIds: [String] = []
    ) {
        self.rootSessionId = rootSessionId
        self.rootThreadId = rootThreadId
        self.childNodes = Self.normalizedNodes(childNodes)
        self.activeChildId = activeChildId
        self.completedChildIds = Array(Set(completedChildIds)).sorted()
        self.failedChildIds = Array(Set(failedChildIds)).sorted()

        let inferredDetachedIds = self.childNodes
            .filter(\.isDetached)
            .map(\.id)
        self.detachedChildIds = Array(Set(detachedChildIds + inferredDetachedIds)).sorted()
    }

    private static func normalizedNodes(
        _ nodes: [CodexThreadHierarchyNode]
    ) -> [CodexThreadHierarchyNode] {
        var byId: [String: CodexThreadHierarchyNode] = [:]

        for node in nodes {
            let normalized = node.markingDetachedIfNeeded()
            if let existing = byId[normalized.id] {
                byId[normalized.id] = existing.updating(with: normalized)
            } else {
                byId[normalized.id] = normalized
            }
        }

        return byId.values.sorted { lhs, rhs in
            if lhs.firstSeenAt == rhs.firstSeenAt {
                return lhs.id < rhs.id
            }
            return lhs.firstSeenAt < rhs.firstSeenAt
        }
    }
}
