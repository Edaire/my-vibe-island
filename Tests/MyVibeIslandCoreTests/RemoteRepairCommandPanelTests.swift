import XCTest
@testable import MyVibeIslandCore

final class RemoteRepairCommandPanelTests: XCTestCase {
    func testRemoteRepairCommandPanelMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteRepairCommandPanelMatrixFixture.self,
            from: try FixtureLoader.data("remote/repair-command-panel-matrix")
        )

        let actual = RemoteRepairCommandPanelMatrixFixture(rows: [
            row(
                id: "uds-uid-mismatch",
                panel: RemoteRepairCommandPanel(host: Self.udsMismatchedHost)
            ),
            row(
                id: "uds-same-uid-no-env",
                panel: RemoteRepairCommandPanel(host: SSHHostStoreHost(
                    id: "sameuid",
                    hostAlias: "sameuid",
                    hostName: "sameuid.example.com",
                    user: "dev",
                    port: 22,
                    tunnelKind: .uds,
                    remoteSocketPath: "/tmp/my-vibe-island.sock",
                    localSocketPath: "/tmp/my-vibe-island.sock",
                    remoteUID: 501,
                    localUID: 501,
                    deployed: true,
                    trustStatus: "trusted"
                ))
            ),
            row(
                id: "tcp-forwarding",
                panel: RemoteRepairCommandPanel(host: Self.tcpHost)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRepairCommandPanelBuildsCopyableUDSCommandsWithRemoteSocketEnvWhenUIDsDiffer() throws {
        let panel = RemoteRepairCommandPanel(host: Self.udsMismatchedHost)
        let decoded = try JSONDecoder().decode(RemoteRepairCommandPanel.self, from: try JSONEncoder().encode(panel))

        XCTAssertEqual(decoded, panel)
        XCTAssertTrue(panel.commands.allSatisfy(\.requiresUserRun))
        XCTAssertEqual(panel.command(.sshConfigSnippet)?.body, """
Host devbox
    HostName devbox.example.com
    User dev
    Port 22
    RemoteForward /tmp/my-vibe-island-501.sock /tmp/my-vibe-island-502.sock
    SetEnv MY_VIBE_ISLAND_SOCKET_PATH=/tmp/my-vibe-island-501.sock
    SetEnv VIBE_ISLAND_SOCKET_PATH=/tmp/my-vibe-island-501.sock
    StreamLocalBindUnlink yes
""")
        XCTAssertEqual(panel.command(.socketCleanup)?.body, "rm -f /tmp/my-vibe-island-501.sock")
        XCTAssertEqual(panel.command(.helperReinstall)?.body, "scp my-vibe-island-hooks devbox:~/.local/bin/my-vibe-island-hooks")
        XCTAssertEqual(panel.command(.hookStatus)?.body, "~/.local/bin/my-vibe-island-hooks health")
        XCTAssertEqual(panel.command(.tunnel)?.body, "ssh -N devbox")
    }

    func testRepairCommandPanelBuildsTCPForwardingSnippet() {
        let panel = RemoteRepairCommandPanel(host: Self.tcpHost)

        XCTAssertEqual(panel.command(.sshConfigSnippet)?.body, """
Host devbox
    HostName devbox.example.com
    User dev
    Port 2222
    RemoteForward 49152 127.0.0.1:49152
""")
        XCTAssertEqual(panel.command(.socketCleanup), nil)
        XCTAssertEqual(panel.command(.tunnel)?.body, "ssh -N devbox")
    }

    private static let udsMismatchedHost = SSHHostStoreHost(
        id: "devbox",
        hostAlias: "devbox",
        hostName: "devbox.example.com",
        user: "dev",
        port: 22,
        tunnelKind: .uds,
        remoteSocketPath: "/tmp/my-vibe-island-501.sock",
        localSocketPath: "/tmp/my-vibe-island-502.sock",
        remoteUID: 501,
        localUID: 502,
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

    private func row(id: String, panel: RemoteRepairCommandPanel) -> RemoteRepairCommandPanelRowFixture {
        RemoteRepairCommandPanelRowFixture(
            id: id,
            hostId: panel.hostId,
            hostAlias: panel.hostAlias,
            tunnelKind: panel.tunnelKind.rawValue,
            commandKinds: panel.commands.map { $0.kind.rawValue },
            commands: panel.commands.map { "\($0.kind.rawValue)=\($0.body)" },
            allRequireUserRun: panel.commands.allSatisfy(\.requiresUserRun)
        )
    }

    private struct RemoteRepairCommandPanelMatrixFixture: Codable, Equatable {
        let rows: [RemoteRepairCommandPanelRowFixture]
    }

    private struct RemoteRepairCommandPanelRowFixture: Codable, Equatable {
        let id: String
        let hostId: String
        let hostAlias: String
        let tunnelKind: String
        let commandKinds: [String]
        let commands: [String]
        let allRequireUserRun: Bool
    }
}
