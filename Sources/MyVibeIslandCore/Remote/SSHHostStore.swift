public struct SSHHostStore: Codable, Equatable, Sendable {
    public let hosts: [SSHHostStoreHost]
    public let runtimeState: SSHHostStoreRuntimeState

    public init(
        hosts: [SSHHostStoreHost] = [],
        runtimeState: SSHHostStoreRuntimeState = SSHHostStoreRuntimeState()
    ) {
        self.hosts = hosts
        self.runtimeState = runtimeState
    }
}

public struct SSHHostStoreHost: Codable, Equatable, Sendable {
    public let id: String
    public let hostAlias: String
    public let hostName: String
    public let user: String
    public let port: Int
    public let sshOptions: [String: String]
    public let tunnelKind: SSHTunnelKind
    public let tcpPort: Int?
    public let remoteSocketPath: String?
    public let localSocketPath: String?
    public let remoteUID: Int?
    public let localUID: Int?
    public let deployed: Bool
    public let lastDeployedAt: String?
    public let lastDeployError: String?
    public let lastConnectedAt: String?
    public let lastSetupVersion: String?
    public let trustStatus: String
    public let notes: String?
    public let hookVersion: String?
    public let hookUpdateAvailable: Bool

    public init(
        id: String,
        hostAlias: String,
        hostName: String,
        user: String,
        port: Int,
        sshOptions: [String: String] = [:],
        tunnelKind: SSHTunnelKind,
        tcpPort: Int? = nil,
        remoteSocketPath: String? = nil,
        localSocketPath: String? = nil,
        remoteUID: Int? = nil,
        localUID: Int? = nil,
        deployed: Bool,
        lastDeployedAt: String? = nil,
        lastDeployError: String? = nil,
        lastConnectedAt: String? = nil,
        lastSetupVersion: String? = nil,
        trustStatus: String,
        notes: String? = nil,
        hookVersion: String? = nil,
        hookUpdateAvailable: Bool = false
    ) {
        self.id = id
        self.hostAlias = hostAlias
        self.hostName = hostName
        self.user = user
        self.port = port
        self.sshOptions = sshOptions
        self.tunnelKind = tunnelKind
        self.tcpPort = tcpPort
        self.remoteSocketPath = remoteSocketPath
        self.localSocketPath = localSocketPath
        self.remoteUID = remoteUID
        self.localUID = localUID
        self.deployed = deployed
        self.lastDeployedAt = lastDeployedAt
        self.lastDeployError = lastDeployError
        self.lastConnectedAt = lastConnectedAt
        self.lastSetupVersion = lastSetupVersion
        self.trustStatus = trustStatus
        self.notes = notes
        self.hookVersion = hookVersion
        self.hookUpdateAvailable = hookUpdateAvailable
    }
}

public struct SSHHostStoreRuntimeState: Codable, Equatable, Sendable {
    public let tunnelProcesses: [String: SSHTunnelProcess]
    public let tunnelStatuses: [String: TunnelStatus]
    public let tunnelConnectedAt: [String: String]
    public let reconnectPolicies: [String: SSHReconnectPolicy]
    public let userDisconnectedHosts: [String]
    public let lastPreCleanForeignHosts: [String]
    public let outdatedHookHosts: [String]
    public let lastSchemaCheckAt: String?
    public let schemaCheckDebounceSeconds: Int?
    public let healthCheckFailures: [String: Int]
    public let tunnelGeneration: [String: Int]
    public let suspendedHealthCheckHosts: [String]
    public let pendingWakeCompensation: Bool

    public init(
        tunnelProcesses: [String: SSHTunnelProcess] = [:],
        tunnelStatuses: [String: TunnelStatus] = [:],
        tunnelConnectedAt: [String: String] = [:],
        reconnectPolicies: [String: SSHReconnectPolicy] = [:],
        userDisconnectedHosts: [String] = [],
        lastPreCleanForeignHosts: [String] = [],
        outdatedHookHosts: [String] = [],
        lastSchemaCheckAt: String? = nil,
        schemaCheckDebounceSeconds: Int? = nil,
        healthCheckFailures: [String: Int] = [:],
        tunnelGeneration: [String: Int] = [:],
        suspendedHealthCheckHosts: [String] = [],
        pendingWakeCompensation: Bool = false
    ) {
        self.tunnelProcesses = tunnelProcesses
        self.tunnelStatuses = tunnelStatuses
        self.tunnelConnectedAt = tunnelConnectedAt
        self.reconnectPolicies = reconnectPolicies
        self.userDisconnectedHosts = userDisconnectedHosts
        self.lastPreCleanForeignHosts = lastPreCleanForeignHosts
        self.outdatedHookHosts = outdatedHookHosts
        self.lastSchemaCheckAt = lastSchemaCheckAt
        self.schemaCheckDebounceSeconds = schemaCheckDebounceSeconds
        self.healthCheckFailures = healthCheckFailures
        self.tunnelGeneration = tunnelGeneration
        self.suspendedHealthCheckHosts = suspendedHealthCheckHosts
        self.pendingWakeCompensation = pendingWakeCompensation
    }
}
