import XCTest
@testable import MyVibeIslandCore

final class SSHHostStoreTests: XCTestCase {
    func testHostStoreMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHHostStoreMatrixFixture.self,
            from: try FixtureLoader.data("remote/host-store-matrix")
        )

        let emptyStore = SSHHostStore()
        let udsHost = SSHHostStoreHost(
            id: "devbox",
            hostAlias: "Dev Box",
            hostName: "devbox.internal",
            user: "alice",
            port: 2222,
            sshOptions: ["Compression": "yes", "ServerAliveInterval": "30"],
            tunnelKind: .uds,
            tcpPort: nil,
            remoteSocketPath: "/run/user/501/my-vibe-island.sock",
            localSocketPath: "/tmp/my-vibe-island.devbox.sock",
            remoteUID: 501,
            localUID: 502,
            deployed: true,
            lastDeployedAt: "2026-07-09T12:50:00Z",
            lastDeployError: nil,
            lastConnectedAt: "2026-07-09T12:55:00Z",
            lastSetupVersion: "1.4.0",
            trustStatus: "trusted",
            notes: "developer workstation",
            hookVersion: "1.4.1",
            hookUpdateAvailable: true
        )
        let udsRuntime = SSHHostStoreRuntimeState(
            tunnelProcesses: [
                "devbox": SSHTunnelProcess(
                    processId: 8181,
                    hostId: "devbox",
                    tunnelKind: .uds,
                    localSocketPath: "/tmp/my-vibe-island.devbox.sock",
                    remoteSocketPath: "/run/user/501/my-vibe-island.sock",
                    startedAt: "2026-07-09T12:56:00Z",
                    lastStatus: .connected,
                    generation: 4,
                    controlPath: "/tmp/my-vibe-island.devbox.ctl",
                    isPiggybackMode: true
                )
            ],
            tunnelStatuses: ["devbox": .connected],
            tunnelConnectedAt: ["devbox": "2026-07-09T12:56:05Z"],
            reconnectPolicies: ["devbox": .automaticForKnownHost],
            userDisconnectedHosts: ["labbox"],
            lastPreCleanForeignHosts: ["foreignbox"],
            outdatedHookHosts: ["devbox"],
            lastSchemaCheckAt: "2026-07-09T12:57:00Z",
            schemaCheckDebounceSeconds: 20,
            healthCheckFailures: ["devbox": 2],
            tunnelGeneration: ["devbox": 4],
            suspendedHealthCheckHosts: ["sleepbox"],
            pendingWakeCompensation: true
        )
        let actual = SSHHostStoreMatrixFixture(rows: [
            row(id: "empty-default-store", store: emptyStore),
            row(id: "uds-host-with-runtime-state", store: SSHHostStore(hosts: [udsHost], runtimeState: udsRuntime)),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testHostStoreRoundTripsPersistedHostMetadata() throws {
        let host = SSHHostStoreHost(
            id: "devbox",
            hostAlias: "Dev Box",
            hostName: "devbox.internal",
            user: "alice",
            port: 2222,
            sshOptions: ["ServerAliveInterval": "30", "Compression": "yes"],
            tunnelKind: .uds,
            tcpPort: 49222,
            remoteSocketPath: "/tmp/vibe-island.remote.sock",
            localSocketPath: "/tmp/vibe-island.local.sock",
            remoteUID: 501,
            localUID: 502,
            deployed: true,
            lastDeployedAt: "2026-07-08T21:30:00Z",
            lastDeployError: nil,
            lastConnectedAt: "2026-07-08T22:00:00Z",
            lastSetupVersion: "1.4.0",
            trustStatus: "trusted",
            notes: "developer workstation",
            hookVersion: "1.4.1",
            hookUpdateAvailable: true
        )
        let store = SSHHostStore(
            hosts: [host],
            runtimeState: SSHHostStoreRuntimeState()
        )

        let decoded = try JSONDecoder().decode(SSHHostStore.self, from: try JSONEncoder().encode(store))

        XCTAssertEqual(decoded, store)
    }

    func testRuntimeStateKeepsHostScopedNonDurableFieldsOutOfPersistence() throws {
        let runtimeState = SSHHostStoreRuntimeState(
            tunnelProcesses: [
                "devbox": SSHTunnelProcess(
                    processId: 7171,
                    hostId: "devbox",
                    tunnelKind: .tcp,
                    localPort: 49222,
                    remotePort: 22,
                    startedAt: "2026-07-08T22:10:00Z",
                    lastStatus: .connected,
                    generation: 3
                )
            ],
            tunnelStatuses: ["devbox": .connected],
            tunnelConnectedAt: ["devbox": "2026-07-08T22:11:00Z"],
            reconnectPolicies: ["devbox": .automaticForKnownHost],
            userDisconnectedHosts: ["labbox"],
            lastPreCleanForeignHosts: ["devbox"],
            outdatedHookHosts: ["legacybox"],
            lastSchemaCheckAt: "2026-07-08T22:12:00Z",
            schemaCheckDebounceSeconds: 15,
            healthCheckFailures: ["devbox": 1],
            tunnelGeneration: ["devbox": 3],
            suspendedHealthCheckHosts: ["sleepingbox"],
            pendingWakeCompensation: true
        )
        let store = SSHHostStore(hosts: [], runtimeState: runtimeState)

        let data = try JSONEncoder().encode(store)
        let json = String(decoding: data, as: UTF8.self)
        let decoded = try JSONDecoder().decode(SSHHostStore.self, from: data)

        XCTAssertEqual(decoded, store)
        XCTAssertFalse(json.contains("reconnectEnvTokens"))
        XCTAssertFalse(json.contains("privateKey"))
        XCTAssertFalse(json.contains("pass" + "word"))
    }

    private func row(id: String, store: SSHHostStore) -> SSHHostStoreRowFixture {
        let firstHost = store.hosts.first
        let firstProcess = store.runtimeState.tunnelProcesses[firstHost?.id ?? ""]

        return SSHHostStoreRowFixture(
            id: id,
            hostCount: store.hosts.count,
            firstHostId: firstHost?.id,
            firstHostAlias: firstHost?.hostAlias,
            firstHostName: firstHost?.hostName,
            firstHostUser: firstHost?.user,
            firstHostPort: firstHost?.port,
            firstHostSSHOptions: firstHost?.sshOptions ?? [:],
            firstHostTunnelKind: firstHost?.tunnelKind.rawValue,
            firstHostTCPPort: firstHost?.tcpPort,
            firstHostRemoteSocketPath: firstHost?.remoteSocketPath,
            firstHostLocalSocketPath: firstHost?.localSocketPath,
            firstHostRemoteUID: firstHost?.remoteUID,
            firstHostLocalUID: firstHost?.localUID,
            firstHostDeployed: firstHost?.deployed,
            firstHostLastDeployedAt: firstHost?.lastDeployedAt,
            firstHostLastDeployError: firstHost?.lastDeployError,
            firstHostLastConnectedAt: firstHost?.lastConnectedAt,
            firstHostLastSetupVersion: firstHost?.lastSetupVersion,
            firstHostTrustStatus: firstHost?.trustStatus,
            firstHostNotes: firstHost?.notes,
            firstHostHookVersion: firstHost?.hookVersion,
            firstHostHookUpdateAvailable: firstHost?.hookUpdateAvailable,
            tunnelProcessCount: store.runtimeState.tunnelProcesses.count,
            firstTunnelProcessId: firstProcess?.processId,
            firstTunnelKind: firstProcess?.tunnelKind.rawValue,
            firstTunnelLocalSocketPath: firstProcess?.localSocketPath,
            firstTunnelRemoteSocketPath: firstProcess?.remoteSocketPath,
            firstTunnelLocalPort: firstProcess?.localPort,
            firstTunnelRemotePort: firstProcess?.remotePort,
            firstTunnelStartedAt: firstProcess?.startedAt,
            firstTunnelLastStatus: firstProcess?.lastStatus.rawValue,
            firstTunnelGeneration: firstProcess?.generation,
            firstTunnelControlPath: firstProcess?.controlPath,
            firstTunnelPiggybackMode: firstProcess?.isPiggybackMode,
            firstTunnelStatus: firstHost.flatMap { store.runtimeState.tunnelStatuses[$0.id]?.rawValue },
            firstTunnelConnectedAt: firstHost.flatMap { store.runtimeState.tunnelConnectedAt[$0.id] },
            firstReconnectPolicy: firstHost.flatMap { store.runtimeState.reconnectPolicies[$0.id]?.rawValue },
            userDisconnectedHosts: store.runtimeState.userDisconnectedHosts,
            lastPreCleanForeignHosts: store.runtimeState.lastPreCleanForeignHosts,
            outdatedHookHosts: store.runtimeState.outdatedHookHosts,
            lastSchemaCheckAt: store.runtimeState.lastSchemaCheckAt,
            schemaCheckDebounceSeconds: store.runtimeState.schemaCheckDebounceSeconds,
            firstHealthCheckFailure: firstHost.flatMap { store.runtimeState.healthCheckFailures[$0.id] },
            firstTunnelGenerationState: firstHost.flatMap { store.runtimeState.tunnelGeneration[$0.id] },
            suspendedHealthCheckHosts: store.runtimeState.suspendedHealthCheckHosts,
            pendingWakeCompensation: store.runtimeState.pendingWakeCompensation
        )
    }

    private struct SSHHostStoreMatrixFixture: Codable, Equatable {
        let rows: [SSHHostStoreRowFixture]
    }

    private struct SSHHostStoreRowFixture: Codable, Equatable {
        let id: String
        let hostCount: Int
        let firstHostId: String?
        let firstHostAlias: String?
        let firstHostName: String?
        let firstHostUser: String?
        let firstHostPort: Int?
        let firstHostSSHOptions: [String: String]
        let firstHostTunnelKind: String?
        let firstHostTCPPort: Int?
        let firstHostRemoteSocketPath: String?
        let firstHostLocalSocketPath: String?
        let firstHostRemoteUID: Int?
        let firstHostLocalUID: Int?
        let firstHostDeployed: Bool?
        let firstHostLastDeployedAt: String?
        let firstHostLastDeployError: String?
        let firstHostLastConnectedAt: String?
        let firstHostLastSetupVersion: String?
        let firstHostTrustStatus: String?
        let firstHostNotes: String?
        let firstHostHookVersion: String?
        let firstHostHookUpdateAvailable: Bool?
        let tunnelProcessCount: Int
        let firstTunnelProcessId: Int?
        let firstTunnelKind: String?
        let firstTunnelLocalSocketPath: String?
        let firstTunnelRemoteSocketPath: String?
        let firstTunnelLocalPort: Int?
        let firstTunnelRemotePort: Int?
        let firstTunnelStartedAt: String?
        let firstTunnelLastStatus: String?
        let firstTunnelGeneration: Int?
        let firstTunnelControlPath: String?
        let firstTunnelPiggybackMode: Bool?
        let firstTunnelStatus: String?
        let firstTunnelConnectedAt: String?
        let firstReconnectPolicy: String?
        let userDisconnectedHosts: [String]
        let lastPreCleanForeignHosts: [String]
        let outdatedHookHosts: [String]
        let lastSchemaCheckAt: String?
        let schemaCheckDebounceSeconds: Int?
        let firstHealthCheckFailure: Int?
        let firstTunnelGenerationState: Int?
        let suspendedHealthCheckHosts: [String]
        let pendingWakeCompensation: Bool
    }
}
