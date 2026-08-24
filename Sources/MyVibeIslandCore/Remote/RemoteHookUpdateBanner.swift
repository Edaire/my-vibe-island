public struct RemoteHookUpdateBanner: Codable, Equatable, Sendable {
    public let hostId: String
    public let hostAlias: String
    public let currentHookVersion: String?
    public let supportedHookVersion: String
    public let repairAction: SSHReconnectRepairAction
    public let redeployCommandPreview: String

    public init?(
        host: SSHHostStoreHost,
        supportedHookVersion: String
    ) {
        guard host.hookUpdateAvailable else {
            return nil
        }

        hostId = host.id
        hostAlias = host.hostAlias
        currentHookVersion = host.hookVersion ?? host.lastSetupVersion
        self.supportedHookVersion = supportedHookVersion
        repairAction = .redeployHelper
        redeployCommandPreview = "scp my-vibe-island-hooks \(host.hostAlias):~/.local/bin/my-vibe-island-hooks"
    }
}
