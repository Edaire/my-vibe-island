import Foundation

/// V3's child presentation distinguishes team members from foreground and
/// background fan-out work. Codex ingress deliberately leaves this absent:
/// its thread-spawn record does not carry a proven equivalent field.
public enum SubagentSpawnShape: Codable, Equatable, Sendable {
    case teammate(inProcess: Bool)
    case foregroundFanout
    case backgroundFanout
}

public struct SubagentState: Codable, Equatable, Sendable {
    public let id: String
    public let source: String
    public let parentSessionId: String
    public let parentThreadId: String?
    public let threadId: String?
    public let kind: String?
    public let nickname: String?
    public let role: String?
    public let status: String?
    public let sourceDetailId: String?
    public let startedAt: Date?
    public let completedAt: Date?
    public let hasLifecycleSignal: Bool
    public let currentActivity: String?
    public let needsAttention: Bool
    public let runtimeProfileModel: String?
    public let runtimeProfileReasoningEffort: String?
    public let agentId: String?
    public let agentType: String?
    public let parentChildId: String?
    public let runtimeSessionId: String?
    public let processIncarnation: String?
    public let spawnShape: SubagentSpawnShape?
    public let teammateIdentity: String?

    private enum CodingKeys: String, CodingKey {
        case id, source, parentSessionId, parentThreadId, threadId, kind, nickname, role
        case status, sourceDetailId, startedAt, completedAt, hasLifecycleSignal
        case currentActivity, needsAttention, runtimeProfileModel
        case runtimeProfileReasoningEffort, agentId, agentType, parentChildId
        case runtimeSessionId, processIncarnation, spawnShape, teammateIdentity
    }

    public init(
        id: String,
        source: String,
        parentSessionId: String,
        parentThreadId: String?,
        threadId: String?,
        kind: String?,
        nickname: String?,
        role: String?,
        status: String?,
        sourceDetailId: String?,
        startedAt: Date?,
        completedAt: Date?,
        hasLifecycleSignal: Bool,
        currentActivity: String?,
        needsAttention: Bool,
        runtimeProfileModel: String? = nil,
        runtimeProfileReasoningEffort: String? = nil,
        agentId: String? = nil,
        agentType: String? = nil,
        parentChildId: String? = nil,
        runtimeSessionId: String? = nil,
        processIncarnation: String? = nil,
        spawnShape: SubagentSpawnShape? = nil,
        teammateIdentity: String? = nil
    ) {
        self.id = id
        self.source = source
        self.parentSessionId = parentSessionId
        self.parentThreadId = parentThreadId
        self.threadId = threadId
        self.kind = kind
        self.nickname = nickname
        self.role = role
        self.status = status
        self.sourceDetailId = sourceDetailId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.hasLifecycleSignal = hasLifecycleSignal
        self.currentActivity = currentActivity
        self.needsAttention = needsAttention
        self.runtimeProfileModel = runtimeProfileModel
        self.runtimeProfileReasoningEffort = runtimeProfileReasoningEffort
        self.agentId = agentId
        self.agentType = agentType
        self.parentChildId = parentChildId
        self.runtimeSessionId = runtimeSessionId
        self.processIncarnation = processIncarnation
        self.spawnShape = spawnShape
        self.teammateIdentity = teammateIdentity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decodeIfPresent(String.self, forKey: .id) ?? "",
            source: container.decodeIfPresent(String.self, forKey: .source) ?? "",
            parentSessionId: container.decodeIfPresent(String.self, forKey: .parentSessionId) ?? "",
            parentThreadId: container.decodeIfPresent(String.self, forKey: .parentThreadId),
            threadId: container.decodeIfPresent(String.self, forKey: .threadId),
            kind: container.decodeIfPresent(String.self, forKey: .kind),
            nickname: container.decodeIfPresent(String.self, forKey: .nickname),
            role: container.decodeIfPresent(String.self, forKey: .role),
            status: container.decodeIfPresent(String.self, forKey: .status),
            sourceDetailId: container.decodeIfPresent(String.self, forKey: .sourceDetailId),
            startedAt: container.decodeIfPresent(Date.self, forKey: .startedAt),
            completedAt: container.decodeIfPresent(Date.self, forKey: .completedAt),
            hasLifecycleSignal: container.decodeIfPresent(Bool.self, forKey: .hasLifecycleSignal) ?? false,
            currentActivity: container.decodeIfPresent(String.self, forKey: .currentActivity),
            needsAttention: container.decodeIfPresent(Bool.self, forKey: .needsAttention) ?? false,
            runtimeProfileModel: container.decodeIfPresent(String.self, forKey: .runtimeProfileModel),
            runtimeProfileReasoningEffort: container.decodeIfPresent(String.self, forKey: .runtimeProfileReasoningEffort),
            agentId: container.decodeIfPresent(String.self, forKey: .agentId),
            agentType: container.decodeIfPresent(String.self, forKey: .agentType),
            parentChildId: container.decodeIfPresent(String.self, forKey: .parentChildId),
            runtimeSessionId: container.decodeIfPresent(String.self, forKey: .runtimeSessionId),
            processIncarnation: container.decodeIfPresent(String.self, forKey: .processIncarnation),
            spawnShape: container.decodeIfPresent(SubagentSpawnShape.self, forKey: .spawnShape),
            teammateIdentity: container.decodeIfPresent(String.self, forKey: .teammateIdentity)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        try container.encode(parentSessionId, forKey: .parentSessionId)
        try container.encodeIfPresent(parentThreadId, forKey: .parentThreadId)
        try container.encodeIfPresent(threadId, forKey: .threadId)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(sourceDetailId, forKey: .sourceDetailId)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(hasLifecycleSignal, forKey: .hasLifecycleSignal)
        try container.encodeIfPresent(currentActivity, forKey: .currentActivity)
        try container.encode(needsAttention, forKey: .needsAttention)
        try container.encodeIfPresent(runtimeProfileModel, forKey: .runtimeProfileModel)
        try container.encodeIfPresent(runtimeProfileReasoningEffort, forKey: .runtimeProfileReasoningEffort)
        try container.encodeIfPresent(agentId, forKey: .agentId)
        try container.encodeIfPresent(agentType, forKey: .agentType)
        try container.encodeIfPresent(parentChildId, forKey: .parentChildId)
        try container.encodeIfPresent(runtimeSessionId, forKey: .runtimeSessionId)
        try container.encodeIfPresent(processIncarnation, forKey: .processIncarnation)
        try container.encodeIfPresent(spawnShape, forKey: .spawnShape)
        try container.encodeIfPresent(teammateIdentity, forKey: .teammateIdentity)
    }

    // Retains the established public initializer ABI for already-built clients.
    public init(
        id: String,
        source: String,
        parentSessionId: String,
        parentThreadId: String? = nil,
        threadId: String? = nil,
        kind: String? = nil,
        nickname: String? = nil,
        role: String? = nil,
        status: String? = nil,
        sourceDetailId: String? = nil
    ) {
        self.init(
            id: id,
            source: source,
            parentSessionId: parentSessionId,
            parentThreadId: parentThreadId,
            threadId: threadId,
            kind: kind,
            nickname: nickname,
            role: role,
            status: status,
            sourceDetailId: sourceDetailId,
            startedAt: nil,
            completedAt: nil,
            hasLifecycleSignal: false,
            currentActivity: nil,
            needsAttention: false,
            runtimeProfileModel: nil,
            runtimeProfileReasoningEffort: nil,
            agentId: nil,
            agentType: nil,
            parentChildId: nil,
            runtimeSessionId: nil,
            processIncarnation: nil,
            spawnShape: nil,
            teammateIdentity: nil
        )
    }
}
