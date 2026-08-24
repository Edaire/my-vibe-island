public enum TeamGroupingSource: String, Codable, Equatable, Sendable {
    case providerSupplied
    case workspaceDerived
    case userPinned
}

public struct TeamGrouping: Codable, Equatable, Sendable {
    public let groupId: String
    public let displayName: String?
    public let rootSessionId: String
    public let memberSessionIds: [String]
    public let source: TeamGroupingSource
    public let confidence: Double
    public let createdAt: String?
    public let updatedAt: String?
    public let childToParent: [String: String]
    public let parentToChildren: [String: [String]]

    public init(
        groupId: String? = nil,
        displayName: String? = nil,
        rootSessionId: String,
        memberSessionIds: [String] = [],
        source: TeamGroupingSource = .workspaceDerived,
        confidence: Double = 0.5,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        childToParent: [String: String] = [:],
        parentToChildren: [String: [String]] = [:]
    ) {
        self.groupId = groupId ?? rootSessionId
        self.displayName = displayName
        self.rootSessionId = rootSessionId
        var normalizedChildToParent = childToParent
        var normalizedParentToChildren: [String: [String]] = [:]
        var normalizedMemberSessionIds = Set(memberSessionIds)
        normalizedMemberSessionIds.insert(rootSessionId)

        for (parent, children) in parentToChildren {
            let uniqueChildren = Array(Set(children)).sorted()
            normalizedParentToChildren[parent] = uniqueChildren
            normalizedMemberSessionIds.insert(parent)
            for child in uniqueChildren {
                normalizedChildToParent[child] = parent
                normalizedMemberSessionIds.insert(child)
            }
        }

        for (child, parent) in normalizedChildToParent {
            normalizedMemberSessionIds.insert(child)
            normalizedMemberSessionIds.insert(parent)
            var children = normalizedParentToChildren[parent] ?? []
            if !children.contains(child) {
                children.append(child)
                children.sort()
            }
            normalizedParentToChildren[parent] = children
        }

        self.memberSessionIds = Array(normalizedMemberSessionIds).sorted()
        self.source = source
        self.confidence = min(max(confidence, 0.0), 1.0)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.childToParent = normalizedChildToParent
        self.parentToChildren = normalizedParentToChildren
    }
}
