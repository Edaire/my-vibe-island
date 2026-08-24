public struct RemoteSettingsSnapshot: Codable, Equatable, Sendable {
    public let isEnabled: Bool
    public let hosts: [SSHHostStoreHost]
    public let selectedHostId: String?
    public let reachabilityObservers: [String: SSHReachabilityObserver]
    public let tunnelProcesses: [String: SSHTunnelProcess]
    public let tunnelStatuses: [String: TunnelStatus]
    public let deployResults: [String: SSHDeployResult]
    public let commandOutputs: [String: SSHCommandOutputBuffer]
    public let portConflicts: [String: SSHPortConflict]
    public let dockerSetups: [String: DockerSidecarSetup]
    public let manualInstallGuides: [String: ManualRemoteInstallGuide]
    public let forwardedSocketProbeResults: [String: RemoteForwardedSocketProbeResult]
    public let reconnectPolicies: [String: SSHReconnectPolicy]
    public let userDisconnectedHosts: [String]
    public let healthCheckFailures: [String: Int]
    public let suspendedHealthCheckHosts: [String]
    public let reconnectFailureThreshold: Int
    public let supportedRemoteHookVersion: String
    public let allowAutomaticReconnectOnJump: Bool

    public var selectedHost: SSHHostStoreHost? {
        if let selectedHostId, let host = hosts.first(where: { $0.id == selectedHostId }) {
            return host
        }
        return hosts.first
    }

    public var selectedTunnelProcess: SSHTunnelProcess? {
        selectedHost.flatMap { tunnelProcesses[$0.id] }
    }

    public var selectedTunnelStatus: TunnelStatus {
        guard let host = selectedHost else {
            return .disconnected
        }
        return tunnelStatuses[host.id] ?? selectedTunnelProcess?.lastStatus ?? .disconnected
    }

    public var selectedReachabilityObserver: SSHReachabilityObserver? {
        selectedHost.flatMap { reachabilityObservers[$0.id] }
    }

    public var selectedPortConflict: SSHPortConflict? {
        selectedHost.flatMap { portConflicts[$0.id] }
    }

    public var selectedDeployResult: SSHDeployResult? {
        selectedHost.flatMap { deployResults[$0.id] }
    }

    public var selectedCommandOutput: SSHCommandOutputBuffer? {
        selectedHost.flatMap { commandOutputs[$0.id] }
    }

    public var selectedDockerSetup: DockerSidecarSetup? {
        selectedHost.flatMap { dockerSetups[$0.id] }
    }

    public var selectedManualInstallGuide: ManualRemoteInstallGuide? {
        selectedHost.flatMap { manualInstallGuides[$0.id] }
    }

    public var selectedRepairCommandPanel: RemoteRepairCommandPanel? {
        selectedHost.map(RemoteRepairCommandPanel.init(host:))
    }

    public var selectedForwardedSocketHealth: RemoteForwardedSocketHealth? {
        selectedHost.map {
            RemoteForwardedSocketHealth(
                host: $0,
                tunnelStatus: selectedTunnelStatus,
                probeResult: forwardedSocketProbeResults[$0.id] ?? .notChecked
            )
        }
    }

    public var selectedHeartbeatSnapshot: SSHHeartbeatSnapshot? {
        selectedReachabilityObserver.map {
            SSHHeartbeatSnapshot(
                observer: $0,
                isSuspended: suspendedHealthCheckHosts.contains($0.hostId)
            )
        }
    }

    public var selectedDiagnosticsSnapshot: RemoteDiagnosticsSnapshot? {
        selectedHost.map {
            RemoteDiagnosticsSnapshot(
                host: $0,
                deployResult: selectedDeployResult,
                commandOutput: selectedCommandOutput,
                portConflict: selectedPortConflict,
                reachabilityObserver: selectedReachabilityObserver,
                tunnelStatus: selectedTunnelStatus
            )
        }
    }

    public var selectedReconnectPolicy: SSHReconnectPolicy {
        guard let host = selectedHost else {
            return .manualOnly
        }
        return reconnectPolicies[host.id] ?? .manualOnly
    }

    public var selectedReconnectDecision: SSHReconnectDecision {
        guard let host = selectedHost else {
            return SSHReconnectDecision(
                hostId: "",
                policy: .manualOnly,
                healthCheckFailureCount: 0,
                failureThreshold: reconnectFailureThreshold,
                userDisconnected: false,
                tunnelStatus: .disconnected,
                failureKind: .unknown
            )
        }

        return SSHReconnectDecision(
            hostId: host.id,
            policy: selectedReconnectPolicy,
            healthCheckFailureCount: healthCheckFailures[host.id] ?? 0,
            failureThreshold: reconnectFailureThreshold,
            userDisconnected: userDisconnectedHosts.contains(host.id),
            tunnelStatus: selectedTunnelStatus,
            failureKind: selectedReachabilityObserver?.lastProbeResult.failureKind ?? .unknown
        )
    }

    public var selectedHookUpdateBanner: RemoteHookUpdateBanner? {
        selectedHost.flatMap {
            RemoteHookUpdateBanner(host: $0, supportedHookVersion: supportedRemoteHookVersion)
        }
    }

    public var showsHookUpdateBanner: Bool {
        selectedHookUpdateBanner != nil
    }

    public var showsPortConflictBanner: Bool {
        selectedPortConflict?.decision != .free && selectedPortConflict != nil
    }

    public var showsDockerSidecarCommands: Bool {
        selectedDockerSetup != nil
    }

    public var showsManualInstallCommands: Bool {
        selectedManualInstallGuide != nil
    }

    public var canAttemptExactJump: Bool {
        isEnabled && selectedTunnelProcess != nil && selectedTunnelStatus == .connected
    }

    public var allowsAutomaticReconnectOnJump: Bool {
        allowAutomaticReconnectOnJump
    }

    public init(
        isEnabled: Bool,
        hosts: [SSHHostStoreHost],
        selectedHostId: String? = nil,
        reachabilityObservers: [String: SSHReachabilityObserver] = [:],
        tunnelProcesses: [String: SSHTunnelProcess] = [:],
        tunnelStatuses: [String: TunnelStatus] = [:],
        deployResults: [String: SSHDeployResult] = [:],
        commandOutputs: [String: SSHCommandOutputBuffer] = [:],
        portConflicts: [String: SSHPortConflict] = [:],
        dockerSetups: [String: DockerSidecarSetup] = [:],
        manualInstallGuides: [String: ManualRemoteInstallGuide] = [:],
        forwardedSocketProbeResults: [String: RemoteForwardedSocketProbeResult] = [:],
        reconnectPolicies: [String: SSHReconnectPolicy] = [:],
        userDisconnectedHosts: [String] = [],
        healthCheckFailures: [String: Int] = [:],
        suspendedHealthCheckHosts: [String] = [],
        reconnectFailureThreshold: Int = 3,
        supportedRemoteHookVersion: String = "unknown",
        allowAutomaticReconnectOnJump: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.hosts = hosts.sorted { left, right in
            if left.hostAlias == right.hostAlias {
                return left.id < right.id
            }
            return left.hostAlias < right.hostAlias
        }
        self.selectedHostId = selectedHostId
        self.reachabilityObservers = reachabilityObservers
        self.tunnelProcesses = tunnelProcesses
        self.tunnelStatuses = tunnelStatuses
        self.deployResults = deployResults
        self.commandOutputs = commandOutputs
        self.portConflicts = portConflicts
        self.dockerSetups = dockerSetups
        self.manualInstallGuides = manualInstallGuides
        self.forwardedSocketProbeResults = forwardedSocketProbeResults
        self.reconnectPolicies = reconnectPolicies
        self.userDisconnectedHosts = userDisconnectedHosts
        self.healthCheckFailures = healthCheckFailures
        self.suspendedHealthCheckHosts = suspendedHealthCheckHosts
        self.reconnectFailureThreshold = reconnectFailureThreshold
        self.supportedRemoteHookVersion = supportedRemoteHookVersion
        self.allowAutomaticReconnectOnJump = allowAutomaticReconnectOnJump
    }
}

public struct RemoteSettingsModel: Sendable {
    public init() {}

    public func snapshot(
        isEnabled: Bool,
        hostStore: SSHHostStore,
        selectedHostId: String? = nil,
        reachabilityObservers: [String: SSHReachabilityObserver] = [:],
        deployResults: [String: SSHDeployResult] = [:],
        commandOutputs: [String: SSHCommandOutputBuffer] = [:],
        portConflicts: [String: SSHPortConflict] = [:],
        dockerSetups: [String: DockerSidecarSetup] = [:],
        manualInstallGuides: [String: ManualRemoteInstallGuide] = [:],
        forwardedSocketProbeResults: [String: RemoteForwardedSocketProbeResult] = [:],
        allowAutomaticReconnectOnJump: Bool = false
    ) -> RemoteSettingsSnapshot {
        RemoteSettingsSnapshot(
            isEnabled: isEnabled,
            hosts: hostStore.hosts,
            selectedHostId: selectedHostId,
            reachabilityObservers: reachabilityObservers,
            tunnelProcesses: hostStore.runtimeState.tunnelProcesses,
            tunnelStatuses: hostStore.runtimeState.tunnelStatuses,
            deployResults: deployResults,
            commandOutputs: commandOutputs,
            portConflicts: portConflicts,
            dockerSetups: dockerSetups,
            manualInstallGuides: manualInstallGuides,
            forwardedSocketProbeResults: forwardedSocketProbeResults,
            reconnectPolicies: hostStore.runtimeState.reconnectPolicies,
            userDisconnectedHosts: hostStore.runtimeState.userDisconnectedHosts,
            healthCheckFailures: hostStore.runtimeState.healthCheckFailures,
            suspendedHealthCheckHosts: hostStore.runtimeState.suspendedHealthCheckHosts,
            allowAutomaticReconnectOnJump: allowAutomaticReconnectOnJump
        )
    }
}
