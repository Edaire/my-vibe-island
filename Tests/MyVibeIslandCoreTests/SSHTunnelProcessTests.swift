import XCTest
@testable import MyVibeIslandCore

final class SSHTunnelProcessTests: XCTestCase {
    func testSSHTunnelProcessMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHTunnelProcessMatrixFixture.self,
            from: try FixtureLoader.data("remote/ssh-tunnel-process-matrix")
        )

        let actual = SSHTunnelProcessMatrixFixture(
            reconnectPolicies: [
                SSHReconnectPolicy.manualOnly,
                .promptBeforeReconnect,
                .automaticForKnownHost,
            ].map(\.rawValue),
            processes: [
                row(id: "uds-piggyback-process", process: SSHTunnelProcess(
                    processId: 5150,
                    hostId: "devbox",
                    tunnelKind: .uds,
                    localSocketPath: "/tmp/local.sock",
                    remoteSocketPath: "/tmp/remote.sock",
                    startedAt: "2026-07-09T05:00:00Z",
                    lastStatus: .connected,
                    generation: 7,
                    controlPath: "~/.ssh/control-devbox",
                    isPiggybackMode: true
                )),
                row(id: "tcp-port-process", process: SSHTunnelProcess(
                    processId: 6161,
                    hostId: "labbox",
                    tunnelKind: .tcp,
                    localPort: 49221,
                    remotePort: 49222,
                    startedAt: "2026-07-09T05:01:00Z",
                    lastStatus: .reconnecting,
                    generation: 2
                )),
            ]
        )

        XCTAssertEqual(actual, expected)
    }

    func testReconnectPolicyRoundTripsDesignValues() throws {
        let policies: [SSHReconnectPolicy] = [
            .manualOnly,
            .promptBeforeReconnect,
            .automaticForKnownHost
        ]

        let decoded = try JSONDecoder().decode([SSHReconnectPolicy].self, from: try JSONEncoder().encode(policies))

        XCTAssertEqual(decoded, policies)
    }

    func testTunnelProcessRoundTripsRuntimeFields() throws {
        let process = SSHTunnelProcess(
            processId: 5150,
            hostId: "devbox",
            tunnelKind: .uds,
            localSocketPath: "/tmp/local.sock",
            remoteSocketPath: "/tmp/remote.sock",
            localPort: nil,
            remotePort: nil,
            startedAt: "2026-07-08T22:30:00Z",
            lastStatus: .connected,
            generation: 7,
            controlPath: "~/.ssh/control-devbox",
            isPiggybackMode: true
        )

        let decoded = try JSONDecoder().decode(SSHTunnelProcess.self, from: try JSONEncoder().encode(process))

        XCTAssertEqual(decoded, process)
    }

    private func row(id: String, process: SSHTunnelProcess) -> SSHTunnelProcessRowFixture {
        SSHTunnelProcessRowFixture(
            id: id,
            processId: process.processId,
            hostId: process.hostId,
            tunnelKind: process.tunnelKind.rawValue,
            hasSocketPaths: process.localSocketPath != nil || process.remoteSocketPath != nil,
            localPort: process.localPort,
            remotePort: process.remotePort,
            startedAt: process.startedAt,
            lastStatus: process.lastStatus.rawValue,
            generation: process.generation,
            hasControlPath: process.controlPath != nil,
            isPiggybackMode: process.isPiggybackMode
        )
    }

    private struct SSHTunnelProcessMatrixFixture: Codable, Equatable {
        let reconnectPolicies: [String]
        let processes: [SSHTunnelProcessRowFixture]
    }

    private struct SSHTunnelProcessRowFixture: Codable, Equatable {
        let id: String
        let processId: Int
        let hostId: String
        let tunnelKind: String
        let hasSocketPaths: Bool
        let localPort: Int?
        let remotePort: Int?
        let startedAt: String
        let lastStatus: String
        let generation: Int
        let hasControlPath: Bool
        let isPiggybackMode: Bool
    }
}
