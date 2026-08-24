public struct RemoteHookUninstallPlan: Codable, Equatable, Sendable {
    public let hostId: String
    public let managedHookKeysToRemove: [String]
    public let userAuthoredHookKeysToPreserve: [String]
    public let unknownHookKeysToPreserve: [String]
    public let configPathsToEdit: [String]
    public let filesToDelete: [String]
    public let stopTunnelProcessIds: [Int]
    public let preservesUserAuthoredHooks: Bool
    public let preservesUnrelatedRemoteFiles: Bool

    public init(
        hostId: String,
        probes: [HookOriginProbe],
        tunnelProcess: SSHTunnelProcess? = nil
    ) {
        self.hostId = hostId
        self.managedHookKeysToRemove = Self.keys(from: probes, origins: [.managed])
        self.userAuthoredHookKeysToPreserve = Self.keys(from: probes, origins: [.userAuthored])
        self.unknownHookKeysToPreserve = Self.keys(from: probes, origins: [.unknown, .disabled])
        self.configPathsToEdit = Self.configPaths(from: probes)
        self.filesToDelete = []
        self.stopTunnelProcessIds = Self.stopTunnelProcessIds(hostId: hostId, tunnelProcess: tunnelProcess)
        self.preservesUserAuthoredHooks = true
        self.preservesUnrelatedRemoteFiles = true
    }

    private static func keys(from probes: [HookOriginProbe], origins: Set<HookCommandOrigin>) -> [String] {
        probes
            .filter { origins.contains($0.origin) }
            .map(\.key)
            .sorted()
    }

    private static func configPaths(from probes: [HookOriginProbe]) -> [String] {
        Array(
            Set(
                probes
                    .filter { $0.origin == .managed }
                    .compactMap(\.sourceConfigPath)
            )
        )
        .sorted()
    }

    private static func stopTunnelProcessIds(hostId: String, tunnelProcess: SSHTunnelProcess?) -> [Int] {
        guard let tunnelProcess,
              tunnelProcess.hostId == hostId,
              !tunnelProcess.isPiggybackMode
        else {
            return []
        }

        return [tunnelProcess.processId]
    }
}
