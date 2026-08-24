import Foundation

public enum ActionableRequestKind: String, Codable, Equatable, Sendable {
    case permission
    case question
}

public struct ActionableRequest: Codable, Equatable, Sendable {
    public let requestId: String
    public let sessionId: String
    public let source: String
    public let kind: ActionableRequestKind
    public let toolName: String
    public let details: ActionRequestDetails?
    public let actionableRequestLifecycleTimestamp: Date?

    public init(
        requestId: String,
        sessionId: String,
        source: String,
        kind: ActionableRequestKind,
        toolName: String,
        details: ActionRequestDetails? = nil,
        actionableRequestLifecycleTimestamp: Date? = nil
    ) {
        self.requestId = requestId
        self.sessionId = sessionId
        self.source = source
        self.kind = kind
        self.toolName = toolName
        self.details = details
        self.actionableRequestLifecycleTimestamp = actionableRequestLifecycleTimestamp
    }
}

public struct RuntimeActionableRequest: Equatable, Sendable {
    public let request: ActionableRequest
    public let storedSelection: String?

    public init(request: ActionableRequest, storedSelection: String? = nil) {
        self.request = request
        self.storedSelection = storedSelection
    }
}

public enum ActionResolutionKind: String, Codable, Equatable, Sendable {
    case approve
    case approveAlways
    case deny
    case answer
    case dismiss
}

public struct ActionResolution: Codable, Equatable, Sendable {
    public let requestId: String
    public let sessionId: String
    public let kind: ActionResolutionKind
    public let selection: String?
    public let answers: [String: String]?

    public init(
        requestId: String,
        sessionId: String,
        kind: ActionResolutionKind,
        selection: String? = nil,
        answers: [String: String]? = nil
    ) {
        self.requestId = requestId
        self.sessionId = sessionId
        self.kind = kind
        self.selection = selection
        self.answers = answers
    }

    public init(
        requestId: String,
        sessionId: String,
        kind: ActionResolutionKind,
        selection: String?
    ) {
        self.init(
            requestId: requestId,
            sessionId: sessionId,
            kind: kind,
            selection: selection,
            answers: nil
        )
    }
}
