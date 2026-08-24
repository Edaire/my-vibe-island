import Foundation

public struct ClaudeCompatibleAdapter: AgentAdapter {
    public let sourceIds: Set<String> = ["claude", "qwen", "qoder", "factory", "codebuddy", "kimi", "hermes"]
    private let genericAdapter: GenericHookAdapter

    public init(genericAdapter: GenericHookAdapter = GenericHookAdapter()) {
        self.genericAdapter = genericAdapter
    }

    public func hookEvent(from envelope: BridgeEnvelope) throws -> HookEvent {
        guard envelope.payload["hook_event_name"] != nil else {
            if envelope.source == "kimi" {
                throw AgentAdapterError.invalidHookPayload
            }
            return try genericAdapter.hookEvent(from: envelope)
        }

        let payload = try ClaudeCompatibleHookPayload(payload: envelope.payload)
        if envelope.source == "kimi", payload.hookEventName != "SessionStart" {
            throw AgentAdapterError.invalidHookPayload
        }
        let requestId = nonEmpty(envelope.requestId) ?? payload.toolUseId ?? payload.genericRequestId

        if Self.requiresStableRequestId(payload.hookEventName), requestId == nil {
            throw AgentAdapterError.invalidHookPayload
        }

        return HookEvent(
            rawEventName: payload.hookEventName,
            source: envelope.source,
            sessionId: payload.sessionId,
            requestId: requestId,
            cwd: payload.cwd,
            model: payload.model,
            permissionMode: payload.permissionMode,
            toolName: payload.toolName,
            message: payload.message ?? payload.lastAssistantMessage ?? payload.prompt,
            actionRequestDetails: ActionRequestDetails.safeDetails(
                from: envelope.payload,
                fallbackPrompt: payload.message ?? payload.prompt
            ),
            environment: envelope.environment,
            tasks: NormalizedSessionContentPayload.tasks(from: envelope.payload),
            todos: NormalizedSessionContentPayload.todos(from: envelope.payload)
        )
    }

    public func directive(for request: ActionableRequest, resolution: ActionResolution) -> SourceDirective {
        guard request.source != "kimi", request.kind == .permission else {
            return .none
        }

        switch resolution.kind {
        case .approve:
            return permissionDirective(decision: [
                "behavior": .string("allow"),
                "updatedInput": .object([:]),
                "updatedPermissions": .array([]),
            ])
        case .deny:
            return permissionDirective(decision: [
                "behavior": .string("deny"),
                "message": .string("User denied the permission request"),
                "interrupt": .bool(false),
            ])
        case .approveAlways, .answer, .dismiss:
            return .none
        }
    }

    public func blockingTimeout(for request: ActionableRequest) -> TimeInterval? {
        request.source != "kimi" && request.kind == .permission ? 86_400 : nil
    }

    private static func requiresStableRequestId(_ eventName: String) -> Bool {
        eventName == "PermissionRequest" || eventName == "PreToolUse"
    }

    private func permissionDirective(decision: [String: BridgeJSONValue]) -> SourceDirective {
        .json(.object([
            "continue": .bool(true),
            "suppressOutput": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object(decision),
            ]),
        ]))
    }
}
