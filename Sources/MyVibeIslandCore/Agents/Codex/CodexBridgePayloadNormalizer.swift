public enum CodexBridgePayloadNormalizer {
    public static func normalizedPayload(
        eventName: String?,
        input: [String: BridgeJSONValue]
    ) throws -> [String: BridgeJSONValue] {
        var payload = input
        payload["_source"] = .string("codex")
        if let eventName, !eventName.isEmpty {
            payload["hook_event_name"] = .string(eventName)
        }

        if let sessionId = string("session_id", in: payload) {
            let codexSessionId = sessionId.hasPrefix("codex-") ? sessionId : "codex-\(sessionId)"
            payload["session_id"] = .string(codexSessionId)
            payload["codex_thread_id"] = .string(codexSessionId)
        }

        copy("turn_id", to: "codex_turn_id", in: &payload)
        copy("transcript_path", to: "codex_transcript_path", in: &payload)
        copy("model", to: "codex_model", in: &payload)
        copy("permission_mode", to: "codex_permission_mode", in: &payload)
        copy("last_assistant_message", to: "codex_last_assistant_message", in: &payload)

        if let prompt = string("prompt", in: payload), prompt.count > 400 {
            payload["prompt"] = .string(String(prompt.prefix(400)))
        }

        return payload
    }

    private static func copy(
        _ sourceKey: String,
        to destinationKey: String,
        in payload: inout [String: BridgeJSONValue]
    ) {
        guard payload[destinationKey] == nil, let value = payload[sourceKey] else {
            return
        }
        payload[destinationKey] = value
    }

    private static func string(_ key: String, in payload: [String: BridgeJSONValue]) -> String? {
        guard case let .string(value) = payload[key], !value.isEmpty else {
            return nil
        }
        return value
    }
}
