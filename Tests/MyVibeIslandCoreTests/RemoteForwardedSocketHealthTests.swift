import XCTest
@testable import MyVibeIslandCore

final class RemoteForwardedSocketHealthTests: XCTestCase {
    func testRemoteForwardedSocketHealthMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteForwardedSocketHealthMatrixFixture.self,
            from: try FixtureLoader.data("remote/forwarded-socket-health-matrix")
        )

        let udsHost = SSHHostStoreHost(
            id: "devbox",
            hostAlias: "devbox",
            hostName: "devbox.example.com",
            user: "dev",
            port: 22,
            tunnelKind: .uds,
            remoteSocketPath: "/tmp/remote.sock",
            localSocketPath: "/tmp/local.sock",
            remoteUID: 501,
            localUID: 502,
            deployed: true,
            trustStatus: "trusted"
        )
        let tcpHost = SSHHostStoreHost(
            id: "tcpbox",
            hostAlias: "tcpbox",
            hostName: "tcpbox.example.com",
            user: "dev",
            port: 22,
            tunnelKind: .tcp,
            tcpPort: 49152,
            deployed: true,
            trustStatus: "trusted"
        )

        let actual = RemoteForwardedSocketHealthMatrixFixture(rows: [
            row(
                id: "uds-missing-remote",
                health: RemoteForwardedSocketHealth(
                    host: udsHost,
                    tunnelStatus: .connected,
                    probeResult: .remoteSocketMissing
                )
            ),
            row(
                id: "tcp-healthy",
                health: RemoteForwardedSocketHealth(
                    host: tcpHost,
                    tunnelStatus: .connected,
                    probeResult: .succeeded
                )
            ),
            row(
                id: "uid-mismatch-requires-manual-setup",
                health: RemoteForwardedSocketHealth(
                    host: udsHost,
                    tunnelStatus: .connected,
                    probeResult: .uidMismatch
                )
            ),
            row(
                id: "missing-local-socket-fail-closed",
                health: RemoteForwardedSocketHealth(
                    host: udsHost,
                    tunnelStatus: .connected,
                    probeResult: .localSocketMissing
                )
            ),
            row(
                id: "disconnected-status-overrides-not-checked",
                health: RemoteForwardedSocketHealth(
                    host: tcpHost,
                    tunnelStatus: .disconnected,
                    probeResult: .notChecked
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testUDSForwardedSocketHealthReportsUIDMismatchAndRemoteMissingHint() throws {
        let host = SSHHostStoreHost(
            id: "devbox",
            hostAlias: "devbox",
            hostName: "devbox.example.com",
            user: "dev",
            port: 22,
            tunnelKind: .uds,
            remoteSocketPath: "/tmp/remote.sock",
            localSocketPath: "/tmp/local.sock",
            remoteUID: 501,
            localUID: 502,
            deployed: true,
            trustStatus: "trusted"
        )

        let health = RemoteForwardedSocketHealth(
            host: host,
            tunnelStatus: .connected,
            probeResult: .remoteSocketMissing
        )
        let decoded = try JSONDecoder().decode(RemoteForwardedSocketHealth.self, from: try JSONEncoder().encode(health))

        XCTAssertEqual(decoded, health)
        XCTAssertEqual(health.hostId, "devbox")
        XCTAssertEqual(health.transportKind, .uds)
        XCTAssertEqual(health.remoteEndpoint, "/tmp/remote.sock")
        XCTAssertEqual(health.localEndpoint, "/tmp/local.sock")
        XCTAssertTrue(health.hasUIDMismatch)
        XCTAssertEqual(health.status, .missingRemoteSocket)
        XCTAssertEqual(health.reconnectHint?.blockReason, .remoteSocketMissing)
        XCTAssertEqual(health.reconnectHint?.repairAction, .reconnectSSHRemoteForward)
    }

    func testTCPForwardedSocketHealthUsesConfiguredPortAndConnectedStatus() {
        let host = SSHHostStoreHost(
            id: "devbox",
            hostAlias: "devbox",
            hostName: "devbox.example.com",
            user: "dev",
            port: 22,
            tunnelKind: .tcp,
            tcpPort: 49152,
            deployed: true,
            trustStatus: "trusted"
        )

        let health = RemoteForwardedSocketHealth(
            host: host,
            tunnelStatus: .connected,
            probeResult: .succeeded
        )

        XCTAssertEqual(health.transportKind, .tcp)
        XCTAssertEqual(health.remoteEndpoint, "tcp:49152")
        XCTAssertEqual(health.localEndpoint, "127.0.0.1:49152")
        XCTAssertFalse(health.hasUIDMismatch)
        XCTAssertEqual(health.status, .healthy)
        XCTAssertNil(health.reconnectHint)
    }

    private func row(
        id: String,
        health: RemoteForwardedSocketHealth
    ) -> RemoteForwardedSocketHealthRowFixture {
        RemoteForwardedSocketHealthRowFixture(
            id: id,
            hostId: health.hostId,
            transportKind: health.transportKind.rawValue,
            remoteEndpoint: health.remoteEndpoint,
            localEndpoint: health.localEndpoint,
            hasUIDMismatch: health.hasUIDMismatch,
            tunnelStatus: health.tunnelStatus?.rawValue,
            probeResult: health.probeResult.rawValue,
            status: health.status.rawValue,
            reconnectBlockReason: health.reconnectHint?.blockReason.rawValue,
            reconnectRepairAction: health.reconnectHint?.repairAction.rawValue,
            reconnectRequiresManualSetup: health.reconnectHint?.requiresManualSetup,
            reconnectAllowsAttempt: health.reconnectHint?.allowsReconnectAttempt
        )
    }

    private struct RemoteForwardedSocketHealthMatrixFixture: Codable, Equatable {
        let rows: [RemoteForwardedSocketHealthRowFixture]
    }

    private struct RemoteForwardedSocketHealthRowFixture: Codable, Equatable {
        let id: String
        let hostId: String
        let transportKind: String
        let remoteEndpoint: String
        let localEndpoint: String
        let hasUIDMismatch: Bool
        let tunnelStatus: String?
        let probeResult: String
        let status: String
        let reconnectBlockReason: String?
        let reconnectRepairAction: String?
        let reconnectRequiresManualSetup: Bool?
        let reconnectAllowsAttempt: Bool?
    }
}
