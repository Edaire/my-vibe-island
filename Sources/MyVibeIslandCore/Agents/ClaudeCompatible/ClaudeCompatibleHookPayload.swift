public struct ClaudeCompatibleHookPayload: Equatable, Sendable {
    public let hookEventName: String
    public let sessionId: String
    public let cwd: String
    public let transcriptPath: String?
    public let permissionMode: String?
    public let model: String?
    public let toolName: String?
    public let toolUseId: String?
    public let genericRequestId: String?
    public let prompt: String?
    public let message: String?
    public let lastAssistantMessage: String?

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
        transcriptPath = Self.string("transcript_path", in: payload)
        permissionMode = Self.string("permission_mode", in: payload)
        model = Self.string("model", in: payload)
        toolName = Self.string("tool_name", in: payload)
        toolUseId = Self.string("tool_use_id", in: payload)
        genericRequestId = Self.string("requestId", in: payload)
        prompt = Self.string("prompt", in: payload)
        message = Self.string("message", in: payload)
        lastAssistantMessage = Self.string("last_assistant_message", in: payload)
    }

    private static func string(_ key: String, in payload: [String: BridgeJSONValue]) -> String? {
        guard case let .string(value) = payload[key], !value.isEmpty else {
            return nil
        }

        return value
    }
}
