import XCTest
@testable import MyVibeIslandCore

final class SocketServerSnapshotTests: XCTestCase {
    func testSocketServerSnapshotMatrixMatchesFixtureDiagnostics() throws {
        let expected = try JSONDecoder().decode(
            SocketServerSnapshotMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/socket-server-snapshot-matrix")
        )

        let actual = SocketServerSnapshotMatrixFixture(rows: [
            try row(
                id: "empty-snapshot",
                snapshot: SocketServerSnapshot()
            ),
            try row(
                id: "local-and-remote-active",
                snapshot: SocketServerSnapshot(
                    unixServerFD: 11,
                    tcpServerFD: 12,
                    tcpListener: SocketServerTCPListener(host: "127.0.0.1", port: 4567, isListening: true),
                    sshRemoteConnections: [
                        remoteConnection(
                            id: "connection-active",
                            hostId: "host-active",
                            token: "active-token-value"
                        )
                    ],
                    activeLocalClientCount: 2
                )
            ),
            try row(
                id: "tcp-listener-not-listening",
                snapshot: SocketServerSnapshot(
                    tcpServerFD: 13,
                    tcpListener: SocketServerTCPListener(host: "127.0.0.1", port: 4568, isListening: false),
                    activeLocalClientCount: 1
                )
            ),
            try row(
                id: "negative-local-count-clamped",
                snapshot: SocketServerSnapshot(
                    unixServerFD: 14,
                    activeLocalClientCount: -4
                )
            ),
            try row(
                id: "multiple-remote-connections-redacted",
                snapshot: SocketServerSnapshot(
                    sshRemoteConnections: [
                        remoteConnection(
                            id: "connection-redacted-a",
                            hostId: "host-redacted-a",
                            token: "secret-token-a"
                        ),
                        remoteConnection(
                            id: "connection-redacted-b",
                            hostId: "host-redacted-b",
                            token: "secret-token-b"
                        ),
                    ]
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testSocketServerDiagnosticSummaryCountsListenersAndRemoteConnectionsWithoutRawTokens() throws {
        let snapshot = SocketServerSnapshot(
            unixServerFD: 11,
            tcpServerFD: 12,
            tcpListener: SocketServerTCPListener(host: "127.0.0.1", port: 4567, isListening: true),
            sshRemoteConnections: [
                RemoteBridgeConnection(
                    connectionId: "connection-1",
                    hostId: "devbox",
                    transportKind: .tcpTunnel,
                    connectedAt: "2026-07-09T01:40:00Z",
                    remoteEnvironmentToken: "remote-env-value"
                )
            ],
            activeLocalClientCount: 2
        )

        let summary = snapshot.diagnosticSummary
        let encoded = String(data: try JSONEncoder().encode(summary), encoding: .utf8) ?? ""

        XCTAssertTrue(summary.hasUnixServer)
        XCTAssertTrue(summary.hasTCPServer)
        XCTAssertTrue(summary.isTCPListenerActive)
        XCTAssertEqual(summary.remoteConnectionCount, 1)
        XCTAssertEqual(summary.activeLocalClientCount, 2)
        XCTAssertEqual(summary.totalConnectionCount, 3)
        XCTAssertFalse(encoded.contains("remote-env-value"))
        XCTAssertFalse(encoded.contains("devbox"))
        XCTAssertFalse(encoded.contains("connection-1"))
    }

    private func row(id: String, snapshot: SocketServerSnapshot) throws -> SocketServerSnapshotRowFixture {
        let summary = snapshot.diagnosticSummary
        let encodedSummary = String(data: try JSONEncoder().encode(summary), encoding: .utf8) ?? ""
        let rawRemoteValues = snapshot.sshRemoteConnections.flatMap { connection in
            [
                connection.connectionId,
                connection.hostId,
                connection.remoteEnvironmentToken,
            ].compactMap { $0 }
        }

        return SocketServerSnapshotRowFixture(
            id: id,
            hasUnixServer: summary.hasUnixServer,
            hasTCPServer: summary.hasTCPServer,
            isTCPListenerActive: summary.isTCPListenerActive,
            remoteConnectionCount: summary.remoteConnectionCount,
            activeLocalClientCount: summary.activeLocalClientCount,
            totalConnectionCount: summary.totalConnectionCount,
            encodedSummaryContainsRawRemoteValues: rawRemoteValues.contains { encodedSummary.contains($0) }
        )
    }

    private func remoteConnection(id: String, hostId: String, token: String) -> RemoteBridgeConnection {
        RemoteBridgeConnection(
            connectionId: id,
            hostId: hostId,
            transportKind: .tcpTunnel,
            connectedAt: "2026-07-09T01:40:00Z",
            remoteEnvironmentToken: token
        )
    }

    private struct SocketServerSnapshotMatrixFixture: Codable, Equatable {
        let rows: [SocketServerSnapshotRowFixture]
    }

    private struct SocketServerSnapshotRowFixture: Codable, Equatable {
        let id: String
        let hasUnixServer: Bool
        let hasTCPServer: Bool
        let isTCPListenerActive: Bool
        let remoteConnectionCount: Int
        let activeLocalClientCount: Int
        let totalConnectionCount: Int
        let encodedSummaryContainsRawRemoteValues: Bool
    }
}
