public enum JumpPrecision: String, Codable, Equatable, Sendable {
    case exactPane
    case exactWindow
    case workspace
    case application
    case remoteHint
    case unsupported
}

public enum JumpFailureReason: String, Codable, Equatable, Sendable {
    case unsupportedHost
    case missingTarget
    case remoteRequiresReconnect
    case tmuxNoAttachedClient
}

public struct JumpResult: Codable, Equatable, Sendable {
    public let precision: JumpPrecision
    public let succeeded: Bool
    public let handlerId: String
    public let attemptedMechanism: String
    public let failureReason: JumpFailureReason?
    public let repairAction: String?
    public let diagnosticSummary: String

    public init(
        precision: JumpPrecision,
        succeeded: Bool,
        handlerId: String,
        attemptedMechanism: String,
        failureReason: JumpFailureReason? = nil,
        repairAction: String? = nil,
        diagnosticSummary: String
    ) {
        self.precision = precision
        self.succeeded = succeeded
        self.handlerId = handlerId
        self.attemptedMechanism = attemptedMechanism
        self.failureReason = failureReason
        self.repairAction = repairAction
        self.diagnosticSummary = diagnosticSummary
    }
}
