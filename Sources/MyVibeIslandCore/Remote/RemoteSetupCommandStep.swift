public enum RemoteSetupCommandStepKind: String, Codable, Equatable, Sendable {
    case sidecar
    case transport
    case remoteCommand
    case verification
}

public struct RemoteSetupCommandStep: Codable, Equatable, Sendable {
    public let kind: RemoteSetupCommandStepKind
    public let body: String
    public let note: String
    public let requiresUserRun: Bool

    public init(
        kind: RemoteSetupCommandStepKind,
        body: String,
        note: String,
        requiresUserRun: Bool = true
    ) {
        self.kind = kind
        self.body = body
        self.note = note
        self.requiresUserRun = requiresUserRun
    }
}

public struct RemoteSetupInstallPlan: Codable, Equatable, Sendable {
    public let steps: [RemoteSetupCommandStep]
    public let canExecuteAutomatically: Bool

    public init(
        steps: [RemoteSetupCommandStep],
        canExecuteAutomatically: Bool = false
    ) {
        self.steps = steps
        self.canExecuteAutomatically = canExecuteAutomatically
    }
}
