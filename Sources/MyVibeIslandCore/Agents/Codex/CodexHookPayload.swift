public struct CodexHookPayload: Equatable, Sendable {
    public let hookEventName: String
    public let sessionId: String
    public let cwd: String
    public let model: String?
    public let permissionMode: String?
    public let toolName: String?
    public let toolUseId: String?
    public let turnId: String?
    public let transcriptPath: String?
    public let prompt: String?
    public let lastAssistantMessage: String?
    public let genericRequestId: String?
    public let subagentParentThreadId: String?
    public let subagentKind: String?
    public let subagentNickname: String?
    public let subagentRole: String?
    public let childModel: String?
    public let childReasoningEffort: String?
    public let agentId: String?
    public let agentType: String?
    public let childParentId: String?
    public let childRuntimeSessionId: String?
    public let childProcessIncarnation: String?

    public init(payload: [String: BridgeJSONValue]) throws {
        guard
            let hookEventName = Self.string("hook_event_name", in: payload),
            let sessionId = Self.string("session_id", in: payload),
            let cwd = Self.string("cwd", in: payload)
        else {
            throw AgentAdapterError.invalidHookPayload
        }

        self.hookEventName = hookEventName
        self.sessionId = sessionId
        self.cwd = cwd
        model = Self.string("model", in: payload) ?? Self.string("codex_model", in: payload)
        permissionMode = Self.string("permission_mode", in: payload)
        toolName = Self.string("tool_name", in: payload)
        toolUseId = Self.string("tool_use_id", in: payload)
        turnId = Self.string("turn_id", in: payload)
        transcriptPath = Self.string("transcript_path", in: payload)
            ?? Self.string("codex_transcript_path", in: payload)
        prompt = Self.string("prompt", in: payload)
        lastAssistantMessage = Self.string("last_assistant_message", in: payload)
            ?? Self.string("codex_last_assistant_message", in: payload)
        genericRequestId = Self.string("requestId", in: payload)
        subagentParentThreadId = Self.string("subagent_parent_thread_id", in: payload)
            ?? Self.string("subagentParentThreadId", in: payload)
        subagentKind = Self.string("subagent_kind", in: payload)
            ?? Self.string("subagentKind", in: payload)
        subagentNickname = Self.string("subagent_nickname", in: payload)
            ?? Self.string("subagentNickname", in: payload)
        subagentRole = Self.string("subagent_role", in: payload)
            ?? Self.string("subagentRole", in: payload)
        childModel = Self.string("child_model", in: payload)
            ?? Self.string("childModel", in: payload)
        childReasoningEffort = Self.string("child_reasoning_effort", in: payload)
            ?? Self.string("childReasoningEffort", in: payload)
        agentId = Self.string("agent_id", in: payload)
            ?? Self.string("agentId", in: payload)
        agentType = Self.string("agent_type", in: payload)
            ?? Self.string("agentType", in: payload)
        childParentId = Self.string("_child_parent_id", in: payload)
            ?? Self.string("childParentID", in: payload)
        childRuntimeSessionId = Self.string("_child_runtime_session_id", in: payload)
            ?? Self.string("childRuntimeSessionID", in: payload)
        childProcessIncarnation = Self.string("_child_process_incarnation", in: payload)
            ?? Self.string("childProcessIncarnation", in: payload)
    }

    private static func string(_ key: String, in payload: [String: BridgeJSONValue]) -> String? {
        guard case let .string(value) = payload[key], !value.isEmpty else {
            return nil
        }

        return value
    }
}
