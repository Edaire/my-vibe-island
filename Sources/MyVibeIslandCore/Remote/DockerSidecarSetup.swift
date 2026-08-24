public struct DockerSidecarSetup: Codable, Equatable, Sendable {
    public let hostId: String
    public let containerPlatform: String
    public let sidecarCommand: String
    public let persistenceHint: String?
    public let rerunHint: String?

    public init(
        hostId: String,
        containerPlatform: String,
        sidecarCommand: String,
        persistenceHint: String? = nil,
        rerunHint: String? = nil
    ) {
        self.hostId = hostId
        self.containerPlatform = containerPlatform
        self.sidecarCommand = sidecarCommand
        self.persistenceHint = persistenceHint
        self.rerunHint = rerunHint
    }

    public var requiresUserRunCommand: Bool {
        true
    }

    public var canExecuteAutomatically: Bool {
        false
    }

    public var commandSteps: [RemoteSetupCommandStep] {
        [
            RemoteSetupCommandStep(
                kind: .sidecar,
                body: sidecarCommand,
                note: "\(containerPlatform) sidecar for \(hostId)"
            )
        ]
    }
}
