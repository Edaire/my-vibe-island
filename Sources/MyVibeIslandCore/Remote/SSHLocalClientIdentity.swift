public struct SSHLocalClientIdentity: Codable, Equatable, Sendable {
    public let bundleIdentifier: String?
    public let pid: Int
    public let tty: String?
    public let resolution: String
    public let commandLineRedacted: String?
    public let hostAlias: String?
    public let remoteForwardSpec: String?

    public init(
        bundleIdentifier: String? = nil,
        pid: Int,
        tty: String? = nil,
        resolution: String,
        commandLineRedacted: String? = nil,
        hostAlias: String? = nil,
        remoteForwardSpec: String? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.pid = pid
        self.tty = tty
        self.resolution = resolution
        self.commandLineRedacted = commandLineRedacted
        self.hostAlias = hostAlias
        self.remoteForwardSpec = remoteForwardSpec
    }
}
