import XCTest
@testable import MyVibeIslandCore

final class SSHTunnelLifecyclePlanTests: XCTestCase {
    func testTunnelLifecyclePlanMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHTunnelLifecyclePlanMatrixFixture.self,
            from: try FixtureLoader.data("remote/tunnel-lifecycle-plan-matrix")
        )

        let actual = SSHTunnelLifecyclePlanMatrixFixture(rows: [
            row(
                id: "uds-connect",
                plan: SSHTunnelLifecyclePlan(
                    host: Self.udsHost,
                    operation: .connect,
                    currentProcess: nil,
                    currentGeneration: 4
                )
            ),
            row(
                id: "uds-disconnect-owned",
                plan: SSHTunnelLifecyclePlan(
                    host: Self.udsHost,
                    operation: .disconnect,
                    currentProcess: Self.ownedUDSProcess,
                    currentGeneration: 4
                )
            ),
            row(
                id: "tcp-reconnect-owned",
                plan: SSHTunnelLifecyclePlan(
                    host: Self.tcpHost,
                    operation: .reconnect,
                    currentProcess: Self.ownedTCPProcess,
                    currentGeneration: 2
                )
            ),
            row(
                id: "tcp-reconnect-piggyback",
                plan: SSHTunnelLifecyclePlan(
                    host: Self.tcpHost,
                    operation: .reconnect,
                    currentProcess: Self.piggybackTCPProcess,
                    currentGeneration: 2
                )
            ),
            row(
                id: "foreign-process-disconnect",
                plan: SSHTunnelLifecyclePlan(
                    host: Self.tcpHost,
                    operation: .disconnect,
                    currentProcess: Self.foreignTCPProcess,
                    currentGeneration: 2
                )
            ),
            row(
                id: "uds-connect-missing-socket-preview",
                plan: SSHTunnelLifecyclePlan(
                    host: Self.incompleteUDSHost,
                    operation: .connect,
                    currentProcess: nil,
                    currentGeneration: 0
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testLifecyclePlanBuildsUDSConnectAndDisconnectActions() throws {
        let host = SSHHostStoreHost(
            id: "devbox",
            hostAlias: "devbox",
            hostName: "devbox.example.com",
            user: "dev",
            port: 22,
            tunnelKind: .uds,
            remoteSocketPath: "/tmp/remote.sock",
            localSocketPath: "/tmp/local.sock",
            deployed: true,
            trustStatus: "trusted"
        )
        let process = SSHTunnelProcess(
            processId: 2468,
            hostId: "devbox",
            tunnelKind: .uds,
            localSocketPath: "/tmp/local.sock",
            remoteSocketPath: "/tmp/remote.sock",
            startedAt: "2026-07-09T10:00:00Z",
            lastStatus: .connected,
            generation: 4
        )

        let connect = SSHTunnelLifecyclePlan(host: host, operation: .connect, currentProcess: nil, currentGeneration: 4)
        let disconnect = SSHTunnelLifecyclePlan(host: host, operation: .disconnect, currentProcess: process, currentGeneration: 4)
        let decoded = try JSONDecoder().decode(SSHTunnelLifecyclePlan.self, from: try JSONEncoder().encode(connect))

        XCTAssertEqual(decoded, connect)
        XCTAssertEqual(connect.nextStatus, .connecting)
        XCTAssertEqual(connect.nextGeneration, 5)
        XCTAssertEqual(connect.actions.map(\.kind), [.startTunnel])
        XCTAssertEqual(connect.actions.first?.commandPreview, "ssh -N devbox")
        XCTAssertEqual(connect.actions.first?.remoteForwardPreview, "RemoteForward /tmp/remote.sock /tmp/local.sock")
        XCTAssertEqual(disconnect.nextStatus, .disconnected)
        XCTAssertEqual(disconnect.nextGeneration, 4)
        XCTAssertEqual(disconnect.actions.map(\.kind), [.stopHostOwnedTunnel])
        XCTAssertEqual(disconnect.actions.first?.processId, 2468)
    }

    func testLifecyclePlanBuildsTCPReconnectWithoutStoppingPiggybackTunnel() {
        let host = SSHHostStoreHost(
            id: "devbox",
            hostAlias: "devbox",
            hostName: "devbox.example.com",
            user: "dev",
            port: 2222,
            tunnelKind: .tcp,
            tcpPort: 49152,
            deployed: true,
            trustStatus: "trusted"
        )
        let piggyback = SSHTunnelProcess(
            processId: 3579,
            hostId: "devbox",
            tunnelKind: .tcp,
            localPort: 49152,
            remotePort: 49152,
            startedAt: "2026-07-09T10:00:00Z",
            lastStatus: .connected,
            generation: 2,
            isPiggybackMode: true
        )

        let plan = SSHTunnelLifecyclePlan(host: host, operation: .reconnect, currentProcess: piggyback, currentGeneration: 2)

        XCTAssertEqual(plan.nextStatus, .reconnecting)
        XCTAssertEqual(plan.nextGeneration, 3)
        XCTAssertEqual(plan.actions.map(\.kind), [.startTunnel])
        XCTAssertEqual(plan.actions.first?.remoteForwardPreview, "RemoteForward 49152 127.0.0.1:49152")
    }

    private static let udsHost = SSHHostStoreHost(
        id: "devbox",
        hostAlias: "devbox",
        hostName: "devbox.example.com",
        user: "dev",
        port: 22,
        tunnelKind: .uds,
        remoteSocketPath: "/tmp/remote.sock",
        localSocketPath: "/tmp/local.sock",
        deployed: true,
        trustStatus: "trusted"
    )

    private static let incompleteUDSHost = SSHHostStoreHost(
        id: "incomplete",
        hostAlias: "incomplete",
        hostName: "incomplete.example.com",
        user: "dev",
        port: 22,
        tunnelKind: .uds,
        remoteSocketPath: "",
        localSocketPath: "/tmp/local.sock",
        deployed: true,
        trustStatus: "trusted"
    )

    private static let tcpHost = SSHHostStoreHost(
        id: "devbox",
        hostAlias: "devbox",
        hostName: "devbox.example.com",
        user: "dev",
        port: 2222,
        tunnelKind: .tcp,
        tcpPort: 49152,
        deployed: true,
        trustStatus: "trusted"
    )

    private static let ownedUDSProcess = SSHTunnelProcess(
        processId: 2468,
        hostId: "devbox",
        tunnelKind: .uds,
        localSocketPath: "/tmp/local.sock",
        remoteSocketPath: "/tmp/remote.sock",
        startedAt: "2026-07-09T10:00:00Z",
        lastStatus: .connected,
        generation: 4
    )

    private static let ownedTCPProcess = SSHTunnelProcess(
        processId: 1357,
        hostId: "devbox",
        tunnelKind: .tcp,
        localPort: 49152,
        remotePort: 49152,
        startedAt: "2026-07-09T10:00:00Z",
        lastStatus: .connected,
        generation: 2
    )

    private static let piggybackTCPProcess = SSHTunnelProcess(
        processId: 3579,
        hostId: "devbox",
        tunnelKind: .tcp,
        localPort: 49152,
        remotePort: 49152,
        startedAt: "2026-07-09T10:00:00Z",
        lastStatus: .connected,
        generation: 2,
        isPiggybackMode: true
    )

    private static let foreignTCPProcess = SSHTunnelProcess(
        processId: 9753,
        hostId: "otherbox",
        tunnelKind: .tcp,
        localPort: 49152,
        remotePort: 49152,
        startedAt: "2026-07-09T10:00:00Z",
        lastStatus: .connected,
        generation: 2
    )

    private func row(id: String, plan: SSHTunnelLifecyclePlan) -> SSHTunnelLifecyclePlanRowFixture {
        SSHTunnelLifecyclePlanRowFixture(
            id: id,
            hostId: plan.hostId,
            tunnelKind: plan.tunnelKind.rawValue,
            operation: plan.operation.rawValue,
            currentGeneration: plan.currentGeneration,
            nextGeneration: plan.nextGeneration,
            nextStatus: plan.nextStatus.rawValue,
            actions: plan.actions.map {
                SSHTunnelLifecycleActionFixture(
                    kind: $0.kind.rawValue,
                    processId: $0.processId,
                    commandPreview: $0.commandPreview,
                    remoteForwardPreview: $0.remoteForwardPreview
                )
            }
        )
    }

    private struct SSHTunnelLifecyclePlanMatrixFixture: Codable, Equatable {
        let rows: [SSHTunnelLifecyclePlanRowFixture]
    }

    private struct SSHTunnelLifecyclePlanRowFixture: Codable, Equatable {
        let id: String
        let hostId: String
        let tunnelKind: String
        let operation: String
        let currentGeneration: Int
        let nextGeneration: Int
        let nextStatus: String
        let actions: [SSHTunnelLifecycleActionFixture]
    }

    private struct SSHTunnelLifecycleActionFixture: Codable, Equatable {
        let kind: String
        let processId: Int?
        let commandPreview: String?
        let remoteForwardPreview: String?
    }
}
