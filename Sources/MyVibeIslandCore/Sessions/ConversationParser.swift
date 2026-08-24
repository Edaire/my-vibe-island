public enum ConversationReadScope: String, Codable, Equatable, Sendable {
    case metadataOnly
}

public struct ConversationParseRequest: Equatable, Sendable {
    public let source: String
    public let sessionId: String
    public let metadata: [String: BridgeJSONValue]
    public let readScope: ConversationReadScope

    public init(
        source: String,
        sessionId: String,
        metadata: [String: BridgeJSONValue],
        readScope: ConversationReadScope = .metadataOnly
    ) {
        self.source = source
        self.sessionId = sessionId
        self.metadata = metadata
        self.readScope = readScope
    }
}

public struct ConversationParseSnapshot: Equatable, Sendable {
    public let source: String
    public let sessionId: String
    public let title: String?
    public let statusSummary: String?
    public let tasks: [TaskItem]
    public let todos: [TodoItem]
    public let redactionLevel: RedactionLevel

    public init(
        source: String,
        sessionId: String,
        title: String? = nil,
        statusSummary: String? = nil,
        tasks: [TaskItem] = [],
        todos: [TodoItem] = [],
        redactionLevel: RedactionLevel = .metadataOnly
    ) {
        self.source = source
        self.sessionId = sessionId
        self.title = title
        self.statusSummary = statusSummary
        self.tasks = tasks
        self.todos = todos
        self.redactionLevel = redactionLevel
    }
}

public enum ConversationParseFailureKind: String, Codable, Equatable, Sendable {
    case invalidIdentity
}

public struct ConversationParseFailure: Equatable, Sendable {
    public let kind: ConversationParseFailureKind
    public let redactedMessage: String
    public let redactionLevel: RedactionLevel

    public init(
        kind: ConversationParseFailureKind,
        redactedMessage: String,
        redactionLevel: RedactionLevel = .metadataOnly
    ) {
        self.kind = kind
        self.redactedMessage = redactedMessage
        self.redactionLevel = redactionLevel
    }
}

public enum ConversationParseResult: Equatable, Sendable {
    case parsed(ConversationParseSnapshot)
    case failed(ConversationParseFailure)
}

public struct ConversationParser: Sendable {
    public init() {}

    public func parse(_ request: ConversationParseRequest) -> ConversationParseResult {
        guard !request.source.isEmpty, !request.sessionId.isEmpty else {
            return .failed(ConversationParseFailure(
                kind: .invalidIdentity,
                redactedMessage: "invalid conversation metadata"
            ))
        }

        return .parsed(ConversationParseSnapshot(
            source: request.source,
            sessionId: request.sessionId,
            title: string("title", in: request.metadata),
            statusSummary: string("statusSummary", in: request.metadata),
            tasks: NormalizedSessionContentPayload.tasks(from: request.metadata),
            todos: NormalizedSessionContentPayload.todos(from: request.metadata),
            redactionLevel: .metadataOnly
        ))
    }

    private func string(_ key: String, in metadata: [String: BridgeJSONValue]) -> String? {
        guard case let .string(value) = metadata[key], !value.isEmpty else {
            return nil
        }

        return value
    }
}
