import XCTest
@testable import MyVibeIslandCore

final class RemoteDiagnosticsSnapshotTests: XCTestCase {
    func testRemoteDiagnosticsSnapshotMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteDiagnosticsSnapshotMatrixFixture.self,
            from: try FixtureLoader.data("remote/diagnostics-snapshot-matrix")
        )

        let redactor = DiagnosticRedactor()
        let udsSnapshot = RemoteDiagnosticsSnapshot(
            host: Self.udsHost,
            deployResult: Self.deployResult,
            commandOutput: Self.commandOutput,
            portConflict: Self.portConflict,
            reachabilityObserver: Self.reachabilityObserver,
            tunnelStatus: .error,
            redactor: redactor
        )
        let tcpSnapshot = RemoteDiagnosticsSnapshot(
            host: SSHHostStoreHost(
                id: "tcpbox",
                hostAlias: "tcpbox",
                hostName: "tcpbox.example.com",
                user: "dev",
                port: 22,
                tunnelKind: .tcp,
                tcpPort: 49300,
                remoteUID: 501,
                localUID: 501,
                deployed: true,
                trustStatus: "trusted",
                hookVersion: nil
            ),
            redactor: redactor
        )

        let actual = RemoteDiagnosticsSnapshotMatrixFixture(rows: [
            row(id: "uds-redacted-mismatch", snapshot: udsSnapshot),
            row(id: "tcp-default-output", snapshot: tcpSnapshot),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRemoteDiagnosticsSnapshotRedactsSSHOptionsDeployStepAndCommandOutput() throws {
        let snapshot = RemoteDiagnosticsSnapshot(
            host: Self.udsHost,
            deployResult: Self.deployResult,
            commandOutput: Self.commandOutput,
            portConflict: Self.portConflict,
            reachabilityObserver: Self.reachabilityObserver,
            tunnelStatus: .error,
            redactor: DiagnosticRedactor()
        )
        let decoded = try JSONDecoder().decode(RemoteDiagnosticsSnapshot.self, from: try JSONEncoder().encode(snapshot))

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(snapshot.hostAlias, "devbox")
        XCTAssertEqual(snapshot.redactedSSHOptionsSummary, "<redacted>")
        XCTAssertEqual(snapshot.redactedSSHCommand, "ssh devbox")
        XCTAssertEqual(snapshot.redactedSocketPath, "/Users/<user>/.my-vibe-island/remote.sock")
        XCTAssertTrue(snapshot.hasUIDMismatch)
        XCTAssertEqual(snapshot.helperVersion, "0.9.0")
        XCTAssertEqual(snapshot.lastHeartbeatAt, "2026-07-09T10:00:00Z")
        XCTAssertEqual(snapshot.tunnelKind, .uds)
        XCTAssertEqual(snapshot.tunnelStatus, .error)
        XCTAssertEqual(snapshot.reconnectAttempt, 2)
        XCTAssertEqual(snapshot.redactedDeployStep, "copy /Users/<user>/private-helper token=<redacted>")
        XCTAssertEqual(snapshot.redactedCommandOutputTail.stdoutTail, "connected session_token=<redacted> at /Users/<user>/project")
        XCTAssertEqual(snapshot.redactedCommandOutputTail.stderrTail, "failed secret=<redacted> from /Users/<user>/project")
        XCTAssertEqual(snapshot.portConflictDecision, .foreignOccupied)
        XCTAssertFalse(snapshot.containsRawSSHOptions)
    }

    private static let udsHost = SSHHostStoreHost(
        id: "devbox",
        hostAlias: "devbox",
        hostName: "devbox.example.com",
        user: "dev",
        port: 22,
        sshOptions: [
            "IdentityFile": "/Users/admin/.ssh/id_ed25519",
            "ProxyCommand": "nc jump.example.com 22",
        ],
        tunnelKind: .uds,
        remoteSocketPath: "/Users/admin/.my-vibe-island/remote.sock",
        localSocketPath: "/Users/admin/.my-vibe-island/local.sock",
        remoteUID: 501,
        localUID: 502,
        deployed: false,
        trustStatus: "trusted",
        hookVersion: "0.9.0"
    )

    private static let deployResult = SSHDeployResult(
        success: false,
        message: "failed token=abc123",
        stderr: "scp /Users/admin/private-helper failed secret=xyz",
        durationMs: 240,
        usedGoBinary: true,
        hostId: "devbox",
        step: "copy /Users/admin/private-helper token=abc123",
        remotePath: "/Users/admin/remote/private",
        configPath: "/Users/admin/.ssh/config",
        repairCommand: "scp /Users/admin/private-helper devbox:",
        deployed: false,
        lastDeployError: "secret=xyz"
    )

    private static let commandOutput = SSHCommandOutputBuffer(
        stdout: "connected session_token=stdout-secret at /Users/admin/project",
        stderr: "failed secret=stderr-secret from /Users/admin/project",
        maxBytes: 120,
        exitCode: 1,
        durationMs: 50
    )

    private static let portConflict = SSHPortConflict(
        hostId: "devbox",
        port: 49152,
        foreignOwners: ["root"],
        checkedByLsof: true,
        checkedBySS: false,
        decision: .foreignOccupied
    )

    private static let reachabilityObserver = SSHReachabilityObserver(
        hostId: "devbox",
        heartbeatIntervalSeconds: 15,
        heartbeatTimeoutSeconds: 5,
        lastProbeResult: .heartbeatTimeout,
        lastSuccessAt: "2026-07-09T10:00:00Z",
        reconnectAttempt: 2,
        currentReachability: .unsatisfied
    )

    private func row(id: String, snapshot: RemoteDiagnosticsSnapshot) -> RemoteDiagnosticsSnapshotRowFixture {
        RemoteDiagnosticsSnapshotRowFixture(
            id: id,
            hostId: snapshot.hostId,
            hostAlias: snapshot.hostAlias,
            redactedSSHOptionsSummary: snapshot.redactedSSHOptionsSummary,
            redactedSSHCommand: snapshot.redactedSSHCommand,
            redactedSocketPath: snapshot.redactedSocketPath,
            hasUIDMismatch: snapshot.hasUIDMismatch,
            helperVersion: snapshot.helperVersion,
            lastHeartbeatAt: snapshot.lastHeartbeatAt,
            tunnelKind: snapshot.tunnelKind.rawValue,
            tunnelStatus: snapshot.tunnelStatus?.rawValue,
            reconnectAttempt: snapshot.reconnectAttempt,
            redactedDeployStep: snapshot.redactedDeployStep,
            stdoutTail: snapshot.redactedCommandOutputTail.stdoutTail,
            stderrTail: snapshot.redactedCommandOutputTail.stderrTail,
            commandOutputMaxBytes: snapshot.redactedCommandOutputTail.maxBytes,
            commandOutputRedactionApplied: snapshot.redactedCommandOutputTail.redactionApplied,
            portConflictDecision: snapshot.portConflictDecision?.rawValue,
            containsRawSSHOptions: snapshot.containsRawSSHOptions
        )
    }

    private struct RemoteDiagnosticsSnapshotMatrixFixture: Codable, Equatable {
        let rows: [RemoteDiagnosticsSnapshotRowFixture]
    }

    private struct RemoteDiagnosticsSnapshotRowFixture: Codable, Equatable {
        let id: String
        let hostId: String
        let hostAlias: String
        let redactedSSHOptionsSummary: String
        let redactedSSHCommand: String
        let redactedSocketPath: String?
        let hasUIDMismatch: Bool
        let helperVersion: String?
        let lastHeartbeatAt: String?
        let tunnelKind: String
        let tunnelStatus: String?
        let reconnectAttempt: Int
        let redactedDeployStep: String?
        let stdoutTail: String
        let stderrTail: String
        let commandOutputMaxBytes: Int
        let commandOutputRedactionApplied: Bool
        let portConflictDecision: String?
        let containsRawSSHOptions: Bool
    }
}
