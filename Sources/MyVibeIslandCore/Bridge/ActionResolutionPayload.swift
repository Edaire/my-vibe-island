public enum ActionResolutionPayloadError: Error, Equatable, Sendable {
    case invalidPayload
}

public struct ActionResolutionPayload: Equatable, Sendable {
    public let resolution: ActionResolution

    public init(payload: [String: BridgeJSONValue]) throws {
        guard
            case let .string(requestId) = payload["requestId"],
            !requestId.isEmpty,
            case let .string(sessionId) = payload["sessionId"],
            !sessionId.isEmpty,
            case let .string(action) = payload["action"],
            let kind = ActionResolutionKind(rawValue: action)
        else {
            throw ActionResolutionPayloadError.invalidPayload
        }

        let selection: String?
        if case let .string(answer) = payload["answer"], !answer.isEmpty {
            selection = answer
        } else {
            selection = nil
        }
        let answers: [String: String]?
        if case let .object(values) = payload["answers"] {
            let normalized = values.compactMapValues { value -> String? in
                guard case let .string(answer) = value, !answer.isEmpty else {
                    return nil
                }
                return answer
            }
            answers = normalized.isEmpty ? nil : normalized
        } else {
            answers = nil
        }

        resolution = ActionResolution(
            requestId: requestId,
            sessionId: sessionId,
            kind: kind,
            selection: selection,
            answers: answers
        )
    }
}
