public struct ManualRemoteInstallGuide: Codable, Equatable, Sendable {
    public let platform: String
    public let localBinaryPath: String
    public let remoteDestination: String
    public let transportInstructions: [String]
    public let remoteCommands: [String]
    public let deployVerificationCommand: String

    public init(
        platform: String,
        localBinaryPath: String,
        remoteDestination: String,
        transportInstructions: [String],
        remoteCommands: [String],
        deployVerificationCommand: String
    ) {
        self.platform = platform
        self.localBinaryPath = localBinaryPath
        self.remoteDestination = remoteDestination
        self.transportInstructions = transportInstructions
        self.remoteCommands = remoteCommands
        self.deployVerificationCommand = deployVerificationCommand
    }

    public var instructionsAreCopyable: Bool {
        true
    }

    public var installPlan: RemoteSetupInstallPlan {
        RemoteSetupInstallPlan(
            steps: transportSteps + remoteCommandSteps + verificationStep
        )
    }

    private var transportSteps: [RemoteSetupCommandStep] {
        transportInstructions.map { instruction in
            RemoteSetupCommandStep(
                kind: .transport,
                body: instruction,
                note: "transport \(platform) helper from \(localBinaryPath)"
            )
        }
    }

    private var remoteCommandSteps: [RemoteSetupCommandStep] {
        remoteCommands.map { command in
            RemoteSetupCommandStep(
                kind: .remoteCommand,
                body: command,
                note: "run on remote host"
            )
        }
    }

    private var verificationStep: [RemoteSetupCommandStep] {
        [
            RemoteSetupCommandStep(
                kind: .verification,
                body: deployVerificationCommand,
                note: "verify \(remoteDestination)"
            )
        ]
    }
}
