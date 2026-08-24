public enum WatchEventPayloadError: Error, Equatable, Sendable {
    case invalidPayload
}

public struct WatchEventPayload: Equatable, Sendable {
    public let sessionId: String
    public let eventKind: String
    public let tasks: [TaskItem]
    public let todos: [TodoItem]

    public init(payload: [String: BridgeJSONValue]) throws {
        guard
            let sessionId = Self.string("sessionId", in: payload),
            let eventKind = Self.string("eventKind", in: payload)
        else {
            throw WatchEventPayloadError.invalidPayload
        }

        let contentPayload = Self.contentPayload(from: payload)
        self.sessionId = sessionId
        self.eventKind = eventKind
        tasks = NormalizedSessionContentPayload.tasks(from: contentPayload)
        todos = NormalizedSessionContentPayload.todos(from: contentPayload)
    }

    public func agentEvents(source: String) -> [AgentEvent] {
        tasks.map {
            .taskUpdated(source: source, sessionId: sessionId, task: $0)
        } + todos.map {
            .todoUpdated(source: source, sessionId: sessionId, todo: $0)
        }
    }

    private static func contentPayload(from payload: [String: BridgeJSONValue]) -> [String: BridgeJSONValue] {
        if case let .object(metadata) = payload["metadata"] {
            return metadata
        }

        return payload
    }

    private static func string(_ key: String, in payload: [String: BridgeJSONValue]) -> String? {
        guard case let .string(value) = payload[key], !value.isEmpty else {
            return nil
        }

        return value
    }
}
