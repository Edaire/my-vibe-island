import XCTest
@testable import MyVibeIslandCore

final class RemoteSettingsModelsTests: XCTestCase {
    func testRemoteSettingsMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteSettingsMatrixFixture.self,
            from: try FixtureLoader.data("settings/remote-settings-matrix")
        )

        let alpha = remoteHost(
            id: "host-alpha",
            alias: "alpha",
            tunnelKind: .uds,
            remoteSocketPath: "/tmp/alpha.sock",
            localSocketPath: "/tmp/local-alpha.sock",
            deployed: true,
            trustStatus: "trusted",
            hookVersion: "1.0.0",
            hookUpdateAvailable: true
        )
        let beta = remoteHost(
            id: "host-beta",
            alias: "beta",
            port: 2222,
            tunnelKind: .tcp,
            tcpPort: 49152,
            deployed: false,
            trustStatus: "unknown"
        )
        let tunnel = SSHTunnelProcess(
            processId: 1234,
            hostId: "host-alpha",
            tunnelKind: .uds,
            localSocketPath: "/tmp/local-alpha.sock",
            remoteSocketPath: "/tmp/alpha.sock",
            startedAt: "2026-07-09T08:00:00Z",
            lastStatus: .connected,
            generation: 7
        )
        let observer = SSHReachabilityObserver(
            hostId: "host-alpha",
            heartbeatIntervalSeconds: 15,
            heartbeatTimeoutSeconds: 5,
            lastProbeResult: .succeeded,
            lastSuccessAt: "2026-07-09T08:01:00Z",
            currentReachability: .satisfied
        )
        let hostStore = SSHHostStore(
            hosts: [beta, alpha],
            runtimeState: SSHHostStoreRuntimeState(
                tunnelProcesses: ["host-alpha": tunnel],
                tunnelStatuses: ["host-alpha": .connected],
                reconnectPolicies: ["host-alpha": .manualOnly, "host-beta": .automaticForKnownHost],
                userDisconnectedHosts: ["host-beta"],
                outdatedHookHosts: ["host-alpha"],
                healthCheckFailures: ["host-alpha": 4, "host-beta": 3],
                tunnelGeneration: ["host-alpha": 7],
                suspendedHealthCheckHosts: ["host-beta"]
            )
        )

        let actual = RemoteSettingsMatrixFixture(rows: [
            row(
                id: "selected-connected-host",
                snapshot: RemoteSettingsModel().snapshot(
                    isEnabled: true,
                    hostStore: hostStore,
                    selectedHostId: "host-alpha",
                    reachabilityObservers: ["host-alpha": observer],
                    deployResults: [
                        "host-alpha": SSHDeployResult(
                            success: false,
                            message: "hook outdated",
                            stderr: "token=fixture-value",
                            durationMs: 40,
                            usedGoBinary: true,
                            hostId: "host-alpha",
                            step: "deploy token=fixture-value",
                            deployed: false
                        ),
                    ],
                    commandOutputs: [
                        "host-alpha": SSHCommandOutputBuffer(
                            stdout: "ok token=fixture-value",
                            stderr: "failed secret=fixture-value",
                            maxBytes: 100
                        ),
                    ],
                    portConflicts: [
                        "host-alpha": SSHPortConflict(
                            hostId: "host-alpha",
                            port: 49152,
                            checkedByLsof: true,
                            checkedBySS: false,
                            decision: .foreignOccupied
                        ),
                    ],
                    dockerSetups: [
                        "host-alpha": DockerSidecarSetup(
                            hostId: "host-alpha",
                            containerPlatform: "docker",
                            sidecarCommand: "docker run helper"
                        ),
                    ],
                    manualInstallGuides: [
                        "host-alpha": ManualRemoteInstallGuide(
                            platform: "linux-arm64",
                            localBinaryPath: "/Applications/MyVibeIsland/helper",
                            remoteDestination: "~/.my-vibe-island/helper",
                            transportInstructions: ["scp helper host:"],
                            remoteCommands: ["chmod +x helper"],
                            deployVerificationCommand: "helper --version"
                        ),
                    ],
                    forwardedSocketProbeResults: ["host-alpha": .remoteSocketMissing],
                    allowAutomaticReconnectOnJump: false
                )
            ),
            row(
                id: "fallback-metadata-only",
                snapshot: RemoteSettingsModel().snapshot(
                    isEnabled: true,
                    hostStore: SSHHostStore(hosts: [
                        remoteHost(
                            id: "metadata-only",
                            alias: "remote-dev",
                            tunnelKind: .tcp,
                            tcpPort: 49153,
                            deployed: true,
                            trustStatus: "trusted"
                        ),
                    ]),
                    selectedHostId: "missing",
                    allowAutomaticReconnectOnJump: true
                )
            ),
            row(
                id: "disabled-user-disconnected",
                snapshot: RemoteSettingsModel().snapshot(
                    isEnabled: false,
                    hostStore: hostStore,
                    selectedHostId: "host-beta",
                    reachabilityObservers: [
                        "host-beta": SSHReachabilityObserver(
                            hostId: "host-beta",
                            heartbeatIntervalSeconds: 15,
                            heartbeatTimeoutSeconds: 5,
                            lastProbeResult: .heartbeatTimeout,
                            currentReachability: .unsatisfied
                        ),
                    ],
                    forwardedSocketProbeResults: ["host-beta": .localSocketMissing],
                    allowAutomaticReconnectOnJump: true
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRemoteSettingsSnapshotAggregatesSelectedHostState() throws {
        let alpha = SSHHostStoreHost(
            id: "host-alpha",
            hostAlias: "alpha",
            hostName: "alpha.example.com",
            user: "dev",
            port: 22,
            tunnelKind: .uds,
            remoteSocketPath: "/tmp/alpha.sock",
            localSocketPath: "/tmp/local-alpha.sock",
            deployed: true,
            trustStatus: "trusted",
            hookVersion: "1.0.0",
            hookUpdateAvailable: true
        )
        let beta = SSHHostStoreHost(
            id: "host-beta",
            hostAlias: "beta",
            hostName: "beta.example.com",
            user: "dev",
            port: 2222,
            tunnelKind: .tcp,
            tcpPort: 49152,
            deployed: false,
            lastDeployError: "missing helper",
            trustStatus: "unknown"
        )
        let tunnel = SSHTunnelProcess(
            processId: 1234,
            hostId: "host-alpha",
            tunnelKind: .uds,
            localSocketPath: "/tmp/local-alpha.sock",
            remoteSocketPath: "/tmp/alpha.sock",
            startedAt: "2026-07-09T08:00:00Z",
            lastStatus: .connected,
            generation: 7
        )
        let hostStore = SSHHostStore(
            hosts: [beta, alpha],
            runtimeState: SSHHostStoreRuntimeState(
                tunnelProcesses: ["host-alpha": tunnel],
                tunnelStatuses: ["host-alpha": .connected],
                reconnectPolicies: ["host-alpha": .manualOnly],
                outdatedHookHosts: ["host-alpha"],
                healthCheckFailures: ["host-alpha": 4],
                tunnelGeneration: ["host-alpha": 7]
            )
        )
        let conflict = SSHPortConflict(
            hostId: "host-alpha",
            port: 49152,
            checkedByLsof: true,
            checkedBySS: false,
            decision: .foreignOccupied
        )
        let observer = SSHReachabilityObserver(
            hostId: "host-alpha",
            heartbeatIntervalSeconds: 15,
            heartbeatTimeoutSeconds: 5,
            lastProbeResult: .succeeded,
            lastSuccessAt: "2026-07-09T08:01:00Z",
            currentReachability: .satisfied
        )
        let dockerSetup = DockerSidecarSetup(
            hostId: "host-alpha",
            containerPlatform: "docker",
            sidecarCommand: "docker run helper"
        )
        let manualGuide = ManualRemoteInstallGuide(
            platform: "linux-arm64",
            localBinaryPath: "/Applications/MyVibeIsland/helper",
            remoteDestination: "~/.my-vibe-island/helper",
            transportInstructions: ["scp helper host:"],
            remoteCommands: ["chmod +x helper"],
            deployVerificationCommand: "helper --version"
        )

        let snapshot = RemoteSettingsModel().snapshot(
            isEnabled: true,
            hostStore: hostStore,
            selectedHostId: "host-alpha",
            reachabilityObservers: ["host-alpha": observer],
            deployResults: [
                "host-alpha": SSHDeployResult(
                    success: false,
                    message: "hook outdated",
                    stderr: "token=fixture-value",
                    durationMs: 40,
                    usedGoBinary: true,
                    hostId: "host-alpha",
                    step: "deploy token=fixture-value",
                    deployed: false
                )
            ],
            commandOutputs: [
                "host-alpha": SSHCommandOutputBuffer(
                    stdout: "ok token=fixture-value",
                    stderr: "failed secret=fixture-value",
                    maxBytes: 100
                )
            ],
            portConflicts: ["host-alpha": conflict],
            dockerSetups: ["host-alpha": dockerSetup],
            manualInstallGuides: ["host-alpha": manualGuide],
            forwardedSocketProbeResults: ["host-alpha": .remoteSocketMissing],
            allowAutomaticReconnectOnJump: false
        )

        let decoded = try JSONDecoder().decode(RemoteSettingsSnapshot.self, from: try JSONEncoder().encode(snapshot))

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(snapshot.hosts.map(\.id), ["host-alpha", "host-beta"])
        XCTAssertEqual(snapshot.selectedHost?.id, "host-alpha")
        XCTAssertEqual(snapshot.selectedTunnelProcess, tunnel)
        XCTAssertEqual(snapshot.selectedReachabilityObserver, observer)
        XCTAssertEqual(snapshot.selectedPortConflict, conflict)
        XCTAssertEqual(snapshot.selectedDockerSetup, dockerSetup)
        XCTAssertEqual(snapshot.selectedManualInstallGuide, manualGuide)
        XCTAssertEqual(snapshot.selectedRepairCommandPanel?.hostId, "host-alpha")
        XCTAssertEqual(snapshot.selectedRepairCommandPanel?.command(.sshConfigSnippet)?.body, """
Host alpha
    HostName alpha.example.com
    User dev
    Port 22
    RemoteForward /tmp/alpha.sock /tmp/local-alpha.sock
    StreamLocalBindUnlink yes
""")
        XCTAssertEqual(snapshot.selectedDiagnosticsSnapshot?.hostAlias, "alpha")
        XCTAssertEqual(snapshot.selectedDiagnosticsSnapshot?.redactedDeployStep, "deploy token=<redacted>")
        XCTAssertEqual(snapshot.selectedDiagnosticsSnapshot?.redactedCommandOutputTail.stdoutTail, "ok token=<redacted>")
        XCTAssertEqual(snapshot.selectedForwardedSocketHealth?.status, .missingRemoteSocket)
        XCTAssertEqual(snapshot.selectedForwardedSocketHealth?.remoteEndpoint, "/tmp/alpha.sock")
        XCTAssertEqual(snapshot.selectedForwardedSocketHealth?.reconnectHint?.repairAction, .reconnectSSHRemoteForward)
        XCTAssertEqual(snapshot.selectedHeartbeatSnapshot?.status, .healthy)
        XCTAssertEqual(snapshot.selectedHeartbeatSnapshot?.lastHeartbeatAt, "2026-07-09T08:01:00Z")
        XCTAssertEqual(snapshot.selectedReconnectPolicy, .manualOnly)
        XCTAssertEqual(snapshot.selectedReconnectDecision.action, .suppressedByPolicy)
        XCTAssertEqual(snapshot.selectedReconnectDecision.healthCheckFailureCount, 4)
        XCTAssertEqual(snapshot.selectedTunnelStatus, .connected)
        XCTAssertEqual(snapshot.selectedHookUpdateBanner?.repairAction, .redeployHelper)
        XCTAssertEqual(snapshot.selectedHookUpdateBanner?.redeployCommandPreview, "scp my-vibe-island-hooks alpha:~/.local/bin/my-vibe-island-hooks")
        XCTAssertTrue(snapshot.showsHookUpdateBanner)
        XCTAssertTrue(snapshot.showsPortConflictBanner)
        XCTAssertTrue(snapshot.showsDockerSidecarCommands)
        XCTAssertTrue(snapshot.showsManualInstallCommands)
        XCTAssertTrue(snapshot.canAttemptExactJump)
        XCTAssertFalse(snapshot.allowsAutomaticReconnectOnJump)
    }

    func testRemoteSettingsSnapshotFallsBackToFirstHostAndDisablesExactJumpForMetadataOnlyHost() {
        let host = SSHHostStoreHost(
            id: "metadata-only",
            hostAlias: "remote-dev",
            hostName: "remote.example.com",
            user: "dev",
            port: 22,
            tunnelKind: .tcp,
            tcpPort: 49153,
            deployed: true,
            trustStatus: "trusted"
        )

        let snapshot = RemoteSettingsModel().snapshot(
            isEnabled: true,
            hostStore: SSHHostStore(hosts: [host]),
            selectedHostId: "missing",
            allowAutomaticReconnectOnJump: true
        )

        XCTAssertEqual(snapshot.selectedHost?.id, "metadata-only")
        XCTAssertEqual(snapshot.selectedTunnelStatus, .disconnected)
        XCTAssertFalse(snapshot.showsHookUpdateBanner)
        XCTAssertFalse(snapshot.showsPortConflictBanner)
        XCTAssertFalse(snapshot.canAttemptExactJump)
        XCTAssertTrue(snapshot.allowsAutomaticReconnectOnJump)
    }

    private func remoteHost(
        id: String,
        alias: String,
        port: Int = 22,
        tunnelKind: SSHTunnelKind,
        remoteSocketPath: String? = nil,
        localSocketPath: String? = nil,
        tcpPort: Int? = nil,
        deployed: Bool,
        trustStatus: String,
        hookVersion: String? = nil,
        hookUpdateAvailable: Bool = false
    ) -> SSHHostStoreHost {
        SSHHostStoreHost(
            id: id,
            hostAlias: alias,
            hostName: "\(alias).example.com",
            user: "dev",
            port: port,
            tunnelKind: tunnelKind,
            tcpPort: tcpPort,
            remoteSocketPath: remoteSocketPath,
            localSocketPath: localSocketPath,
            deployed: deployed,
            trustStatus: trustStatus,
            hookVersion: hookVersion,
            hookUpdateAvailable: hookUpdateAvailable
        )
    }

    private func row(
        id: String,
        snapshot: RemoteSettingsSnapshot
    ) -> RemoteSettingsMatrixRow {
        RemoteSettingsMatrixRow(
            id: id,
            isEnabled: snapshot.isEnabled,
            hostIds: snapshot.hosts.map(\.id),
            selectedHostId: snapshot.selectedHost?.id,
            selectedTunnelStatus: snapshot.selectedTunnelStatus.rawValue,
            selectedReconnectPolicy: snapshot.selectedReconnectPolicy.rawValue,
            selectedReconnectAction: snapshot.selectedReconnectDecision.action.rawValue,
            healthCheckFailureCount: snapshot.selectedReconnectDecision.healthCheckFailureCount,
            heartbeatStatus: snapshot.selectedHeartbeatSnapshot?.status.rawValue,
            forwardedSocketStatus: snapshot.selectedForwardedSocketHealth?.status.rawValue,
            redactedDeployStep: snapshot.selectedDiagnosticsSnapshot?.redactedDeployStep,
            redactedStdoutTail: snapshot.selectedDiagnosticsSnapshot?.redactedCommandOutputTail.stdoutTail,
            showsHookUpdateBanner: snapshot.showsHookUpdateBanner,
            showsPortConflictBanner: snapshot.showsPortConflictBanner,
            showsDockerSidecarCommands: snapshot.showsDockerSidecarCommands,
            showsManualInstallCommands: snapshot.showsManualInstallCommands,
            canAttemptExactJump: snapshot.canAttemptExactJump,
            allowsAutomaticReconnectOnJump: snapshot.allowsAutomaticReconnectOnJump
        )
    }

    private struct RemoteSettingsMatrixFixture: Codable, Equatable {
        let rows: [RemoteSettingsMatrixRow]
    }

    private struct RemoteSettingsMatrixRow: Codable, Equatable {
        let id: String
        let isEnabled: Bool
        let hostIds: [String]
        let selectedHostId: String?
        let selectedTunnelStatus: String
        let selectedReconnectPolicy: String
        let selectedReconnectAction: String
        let healthCheckFailureCount: Int
        let heartbeatStatus: String?
        let forwardedSocketStatus: String?
        let redactedDeployStep: String?
        let redactedStdoutTail: String?
        let showsHookUpdateBanner: Bool
        let showsPortConflictBanner: Bool
        let showsDockerSidecarCommands: Bool
        let showsManualInstallCommands: Bool
        let canAttemptExactJump: Bool
        let allowsAutomaticReconnectOnJump: Bool
    }
}
