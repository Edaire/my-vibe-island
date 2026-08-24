import Foundation

public struct GeminiAdapter: AgentAdapter {
    public let sourceIds: Set<String> = ["gemini"]

    public init() {}

    public func hookEvent(from envelope: BridgeEnvelope) throws -> HookEvent {
        guard
            let eventName = stringValue("hook_event_name", in: envelope.payload),
            let sessionId = stringValue("session_id", in: envelope.payload),
            let cwd = stringValue("cwd", in: envelope.payload)
        else {
            throw AgentAdapterError.invalidHookPayload
        }

        let normalizedEventName: String
        switch eventName {
        case "SessionStart":
            normalizedEventName = "SessionStart"
        case "SessionEnd", "AfterAgent":
            normalizedEventName = "Stop"
        default:
            normalizedEventName = eventName
        }

        return HookEvent(
            rawEventName: normalizedEventName,
            source: envelope.source,
            sessionId: sessionId,
            requestId: nil,
            cwd: cwd,
            message: stringValue("prompt_response", in: envelope.payload)
                ?? stringValue("message", in: envelope.payload)
                ?? stringValue("prompt", in: envelope.payload),
            actionRequestDetails: ActionRequestDetails.safeDetails(from: envelope.payload),
            environment: envelope.environment
        )
    }
}
