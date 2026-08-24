public struct SSHDeployResult: Codable, Equatable, Sendable {
    public let success: Bool
    public let message: String
    public let stderr: String?
    public let durationMs: Int?
    public let usedGoBinary: Bool
    public let hostId: String?
    public let step: String?
    public let remotePath: String?
    public let configPath: String?
    public let repairCommand: String?
    public let deployed: Bool
    public let lastDeployedAt: String?
    public let lastDeployError: String?

    public init(
        success: Bool,
        message: String,
        stderr: String? = nil,
        durationMs: Int? = nil,
        usedGoBinary: Bool = false,
        hostId: String? = nil,
        step: String? = nil,
        remotePath: String? = nil,
        configPath: String? = nil,
        repairCommand: String? = nil,
        deployed: Bool,
        lastDeployedAt: String? = nil,
        lastDeployError: String? = nil
    ) {
        self.success = success
        self.message = message
        self.stderr = stderr
        self.durationMs = durationMs
        self.usedGoBinary = usedGoBinary
        self.hostId = hostId
        self.step = step
        self.remotePath = remotePath
        self.configPath = configPath
        self.repairCommand = repairCommand
        self.deployed = deployed
        self.lastDeployedAt = lastDeployedAt
        self.lastDeployError = lastDeployError
    }
}
