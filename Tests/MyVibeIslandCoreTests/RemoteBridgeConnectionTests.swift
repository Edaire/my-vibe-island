import XCTest
@testable import MyVibeIslandCore

final class RemoteBridgeConnectionTests: XCTestCase {
    func testRemoteBridgeConnectionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteBridgeConnectionMatrixFixture.self,
            from: try FixtureLoader.data("remote/bridge-connection-matrix")
        )

        let actual = RemoteBridgeConnectionMatrixFixture(rows: [
            row(
                id: "forwarded-unix-socket-minimal",
                connection: RemoteBridgeConnection(
                    connectionId: "connection-forwarded",
                    hostId: "host-a",
                    transportKind: .forwardedUnixSocket,
                    connectedAt: "2026-07-09T12:00:00Z"
                )
            ),
            row(
                id: "uds-tunnel-with-heartbeat",
                connection: RemoteBridgeConnection(
                    connectionId: "connection-uds",
                    hostId: "host-b",
                    transportKind: .udsTunnel,
                    connectedAt: "2026-07-09T12:01:00Z",
                    lastMessageAt: "2026-07-09T12:01:10Z",
                    localTunnelProcessId: 5150,
                    remoteEnvironmentToken: "redacted-token",
                    heartbeatIntervalSeconds: 15,
                    heartbeatTimeout: 5,
                    didFireEarlyHeartbeat: true
                )
            ),
            row(
                id: "tcp-tunnel-with-process",
                connection: RemoteBridgeConnection(
                    connectionId: "connection-tcp",
                    hostId: "host-c",
                    transportKind: .tcpTunnel,
                    connectedAt: "2026-07-09T12:02:00Z",
                    lastMessageAt: nil,
                    localTunnelProcessId: 6161,
                    remoteEnvironmentToken: nil,
                    heartbeatIntervalSeconds: 30,
                    heartbeatTimeout: 10,
                    didFireEarlyHeartbeat: false
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRemoteBridgeConnectionRoundTripsTransportFields() throws {
        let connection = RemoteBridgeConnection(
            connectionId: "connection-1",
            hostId: "devbox",
            transportKind: .udsTunnel,
            connectedAt: "2026-07-08T23:00:00Z",
            lastMessageAt: "2026-07-08T23:00:10Z",
            localTunnelProcessId: 5150,
            remoteEnvironmentToken: "redacted-token",
            heartbeatIntervalSeconds: 15,
            heartbeatTimeout: 5,
            didFireEarlyHeartbeat: true
        )

        let decoded = try JSONDecoder().decode(RemoteBridgeConnection.self, from: try JSONEncoder().encode(connection))

        XCTAssertEqual(decoded, connection)
    }

    func testTransportKindRoundTripsDocumentedValues() throws {
        let values: [RemoteBridgeTransportKind] = [
            .forwardedUnixSocket,
            .udsTunnel,
            .tcpTunnel
        ]

        let decoded = try JSONDecoder().decode(
            [RemoteBridgeTransportKind].self,
            from: try JSONEncoder().encode(values)
        )

        XCTAssertEqual(decoded, values)
    }

    private func row(
        id: String,
        connection: RemoteBridgeConnection
    ) -> RemoteBridgeConnectionRowFixture {
        RemoteBridgeConnectionRowFixture(
            id: id,
            connectionId: connection.connectionId,
            hostId: connection.hostId,
            transportKind: connection.transportKind.rawValue,
            connectedAt: connection.connectedAt,
            lastMessageAt: connection.lastMessageAt,
            localTunnelProcessId: connection.localTunnelProcessId,
            remoteEnvironmentToken: connection.remoteEnvironmentToken,
            heartbeatIntervalSeconds: connection.heartbeatIntervalSeconds,
            heartbeatTimeout: connection.heartbeatTimeout,
            didFireEarlyHeartbeat: connection.didFireEarlyHeartbeat
        )
    }

    private struct RemoteBridgeConnectionMatrixFixture: Codable, Equatable {
        let rows: [RemoteBridgeConnectionRowFixture]
    }

    private struct RemoteBridgeConnectionRowFixture: Codable, Equatable {
        let id: String
        let connectionId: String
        let hostId: String
        let transportKind: String
        let connectedAt: String
        let lastMessageAt: String?
        let localTunnelProcessId: Int?
        let remoteEnvironmentToken: String?
        let heartbeatIntervalSeconds: Int?
        let heartbeatTimeout: Int?
        let didFireEarlyHeartbeat: Bool
    }
}
