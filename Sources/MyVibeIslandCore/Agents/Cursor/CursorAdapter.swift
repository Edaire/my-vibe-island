import Foundation

public struct CursorAdapter: AgentAdapter {
    public let sourceIds: Set<String> = ["cursor"]
    private static let acceptedEventNames: Set<String> = [
        "beforeSubmitPrompt",
        "beforeShellExecution",
        "beforeMCPExecution",
        "beforeReadFile",
        "afterFileEdit",
        "stop",
    ]

    public init() {}

    public func hookEvent(from envelope: BridgeEnvelope) throws -> HookEvent {
        guard
            let eventName = stringValue("hook_event_name", in: envelope.payload),
            let sessionId = stringValue("conversation_id", in: envelope.payload),
            let generationId = stringValue("generation_id", in: envelope.payload),
            let cwd = stringValue("cwd", in: envelope.payload) ?? firstString("workspace_roots", in: envelope.payload)
        else {
            throw AgentAdapterError.invalidHookPayload
        }
        guard Self.acceptedEventNames.contains(eventName) else {
            throw AgentAdapterError.invalidHookPayload
        }

        let normalizedEventName: String
        let toolName: String?
        switch eventName {
        case "beforeShellExecution":
            normalizedEventName = "PermissionRequest"
            toolName = "Shell"
        case "beforeMCPExecution":
            normalizedEventName = "PermissionRequest"
            toolName = stringValue("tool_name", in: envelope.payload)
                ?? stringValue("server", in: envelope.payload)
                ?? "MCP"
        case "beforeSubmitPrompt":
            normalizedEventName = "SessionStart"
            toolName = nil
        case "stop":
            normalizedEventName = "Stop"
            toolName = nil
        default:
            normalizedEventName = eventName
            toolName = stringValue("tool_name", in: envelope.payload)
        }

        return HookEvent(
            rawEventName: normalizedEventName,
            source: envelope.source,
            sessionId: sessionId,
            requestId: normalizedEventName == "PermissionRequest" ? nonEmpty(envelope.requestId) ?? generationId : nil,
            cwd: cwd,
            model: stringValue("model", in: envelope.payload),
            toolName: toolName,
            message: stringValue("command", in: envelope.payload)
                ?? stringValue("prompt", in: envelope.payload)
                ?? stringValue("content", in: envelope.payload)
                ?? stringValue("status", in: envelope.payload),
            actionRequestDetails: ActionRequestDetails.safeDetails(from: envelope.payload),
            environment: envelope.environment
        )
    }

    public func directive(for request: ActionableRequest, resolution: ActionResolution) -> SourceDirective {
        guard request.kind == .permission else {
            return .none
        }

        switch resolution.kind {
        case .approve:
            return .json(.object([
                "continue": .bool(true),
                "permission": .string("allow"),
            ]))
        case .deny:
            return .json(.object([
                "continue": .bool(true),
                "permission": .string("deny"),
                "agentMessage": .string("User denied the permission request"),
            ]))
        case .approveAlways, .answer, .dismiss:
            return .none
        }
    }

    public func blockingTimeout(for request: ActionableRequest) -> TimeInterval? {
        request.kind == .permission ? 300 : nil
    }

    private func firstString(_ key: String, in payload: [String: BridgeJSONValue]) -> String? {
        guard case let .array(values) = payload[key] else {
            return nil
        }

        for value in values {
            if case let .string(string) = value, !string.isEmpty {
                return string
            }
        }
        return nil
    }
}
