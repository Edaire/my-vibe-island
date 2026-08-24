import XCTest
@testable import MyVibeIslandCore

final class SSHRemoteHostTests: XCTestCase {
    func testRemoteHostMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHRemoteHostMatrixFixture.self,
            from: try FixtureLoader.data("remote/remote-host-matrix")
        )

        let actual = SSHRemoteHostMatrixFixture(rows: [
            row(
                id: "connected-uds-host",
                host: SSHRemoteHost(
                    hostId: "devbox",
                    displayName: "Dev Box",
                    connectionState: "connected",
                    activeRemoteSessions: ["session-a", "session-b"],
                    lastHeartbeatAt: "2026-07-09T12:40:00Z",
                    lastError: nil,
                    tunnelStatus: .connected,
                    deployStatus: "deployed",
                    hookVersion: "1.4.1",
                    reconnectAttempt: 0
                )
            ),
            row(
                id: "reconnecting-tcp-host",
                host: SSHRemoteHost(
                    hostId: "labbox",
                    displayName: "Lab Box",
                    connectionState: "reconnecting",
                    activeRemoteSessions: [],
                    lastHeartbeatAt: "2026-07-09T12:38:00Z",
                    lastError: "heartbeat timeout",
                    tunnelStatus: .reconnecting,
                    deployStatus: "deployed",
                    hookVersion: "1.4.0",
                    reconnectAttempt: 3
                )
            ),
            row(
                id: "setup-required-host",
                host: SSHRemoteHost(
                    hostId: "freshbox",
                    displayName: "Fresh Box",
                    connectionState: "setupRequired",
                    activeRemoteSessions: [],
                    lastHeartbeatAt: nil,
                    lastError: "helper missing",
                    tunnelStatus: .disconnected,
                    deployStatus: "notDeployed",
                    hookVersion: nil,
                    reconnectAttempt: 0
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRemoteHostRoundTripsRuntimeFields() throws {
        let host = SSHRemoteHost(
            hostId: "devbox",
            displayName: "Dev Box",
            connectionState: "connected",
            activeRemoteSessions: ["session-a", "session-b"],
            lastHeartbeatAt: "2026-07-08T22:45:00Z",
            lastError: nil,
            tunnelStatus: .connected,
            deployStatus: "deployed",
            hookVersion: "1.2.3",
            reconnectAttempt: 2
        )

        let decoded = try JSONDecoder().decode(SSHRemoteHost.self, from: try JSONEncoder().encode(host))

        XCTAssertEqual(decoded, host)
    }

    private func row(id: String, host: SSHRemoteHost) -> SSHRemoteHostRowFixture {
        SSHRemoteHostRowFixture(
            id: id,
            hostId: host.hostId,
            displayName: host.displayName,
            connectionState: host.connectionState,
            activeRemoteSessions: host.activeRemoteSessions,
            lastHeartbeatAt: host.lastHeartbeatAt,
            lastError: host.lastError,
            tunnelStatus: host.tunnelStatus.rawValue,
            deployStatus: host.deployStatus,
            hookVersion: host.hookVersion,
            reconnectAttempt: host.reconnectAttempt
        )
    }

    private struct SSHRemoteHostMatrixFixture: Codable, Equatable {
        let rows: [SSHRemoteHostRowFixture]
    }

    private struct SSHRemoteHostRowFixture: Codable, Equatable {
        let id: String
        let hostId: String
        let displayName: String
        let connectionState: String
        let activeRemoteSessions: [String]
        let lastHeartbeatAt: String?
        let lastError: String?
        let tunnelStatus: String
        let deployStatus: String
        let hookVersion: String?
        let reconnectAttempt: Int
    }
}
