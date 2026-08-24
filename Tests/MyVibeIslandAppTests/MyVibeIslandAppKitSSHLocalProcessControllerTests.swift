import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSSHLocalProcessControllerTests: XCTestCase {
    @MainActor
    func testSSHLocalProcessControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHLocalProcessControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/ssh-local-process-controller-matrix")
        )
        let sshRow = SSHLocalProcessRow(
            pid: 42,
            tty: "ttys001",
            command: "ssh",
            arguments: ["-R", "<redacted>", "devbox"]
        )

        let actual = SSHLocalProcessControllerMatrixFixture(rows: [
            row(id: "resolve-ssh-identity", scannedRows: [sshRow]) { row in
                SSHLocalClientIdentity(
                    bundleIdentifier: "com.apple.Terminal",
                    pid: row.pid,
                    tty: row.tty,
                    resolution: "processScan",
                    commandLineRedacted: ([row.command] + row.arguments).joined(separator: " "),
                    hostAlias: "devbox",
                    remoteForwardSpec: "<redacted>"
                )
            },
            row(
                id: "filter-unresolved-row",
                scannedRows: [
                    SSHLocalProcessRow(pid: 1, command: "ssh"),
                    SSHLocalProcessRow(pid: 2, command: "zsh")
                ]
            ) { row in
                row.command == "ssh"
                    ? SSHLocalClientIdentity(pid: row.pid, resolution: "processScan")
                    : nil
            }
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testRefreshScansRowsAndPublishesResolvedIdentities() {
        var published: [[Int]] = []
        let controller = MyVibeIslandAppKitSSHLocalProcessController(
            scanRows: {
                [
                    SSHLocalProcessRow(
                        pid: 42,
                        tty: "ttys001",
                        command: "ssh",
                        arguments: ["-R", "<redacted>", "devbox"]
                    )
                ]
            },
            resolveIdentity: { row in
                SSHLocalClientIdentity(
                    bundleIdentifier: "com.apple.Terminal",
                    pid: row.pid,
                    tty: row.tty,
                    resolution: "processScan",
                    commandLineRedacted: ([row.command] + row.arguments).joined(separator: " "),
                    hostAlias: "devbox",
                    remoteForwardSpec: "<redacted>"
                )
            },
            publishIdentities: { identities in
                published.append(identities.map(\.pid))
            }
        )

        let identities = controller.refresh()

        XCTAssertEqual(identities.map(\.pid), [42])
        XCTAssertEqual(controller.rows.map(\.pid), [42])
        XCTAssertEqual(controller.identities.map(\.hostAlias), ["devbox"])
        XCTAssertEqual(controller.lastPublishedIdentities?.map(\.pid), [42])
        XCTAssertEqual(published, [[42]])
    }

    @MainActor
    func testRefreshIgnoresRowsWithoutResolvedIdentity() {
        let controller = MyVibeIslandAppKitSSHLocalProcessController(
            scanRows: {
                [
                    SSHLocalProcessRow(pid: 1, command: "ssh"),
                    SSHLocalProcessRow(pid: 2, command: "zsh")
                ]
            },
            resolveIdentity: { row in
                row.command == "ssh"
                    ? SSHLocalClientIdentity(pid: row.pid, resolution: "processScan")
                    : nil
            }
        )

        let identities = controller.refresh()

        XCTAssertEqual(controller.rows.map(\.pid), [1, 2])
        XCTAssertEqual(identities.map(\.pid), [1])
        XCTAssertEqual(controller.identities.map(\.pid), [1])
        XCTAssertEqual(controller.lastPublishedIdentities?.map(\.pid), [1])
    }

    @MainActor
    private func row(
        id: String,
        scannedRows: [SSHLocalProcessRow],
        resolveIdentity: @escaping @MainActor (SSHLocalProcessRow) -> SSHLocalClientIdentity?
    ) -> SSHLocalProcessControllerMatrixRow {
        var events: [[SSHLocalClientIdentitySummary]] = []
        let controller = MyVibeIslandAppKitSSHLocalProcessController(
            scanRows: { scannedRows },
            resolveIdentity: resolveIdentity,
            publishIdentities: { events.append($0.map(SSHLocalClientIdentitySummary.init)) }
        )
        let result = controller.refresh()

        return SSHLocalProcessControllerMatrixRow(
            id: id,
            rows: controller.rows.map(SSHLocalProcessRowSummary.init),
            result: result.map(SSHLocalClientIdentitySummary.init),
            identities: controller.identities.map(SSHLocalClientIdentitySummary.init),
            lastPublishedIdentities: controller.lastPublishedIdentities?.map(SSHLocalClientIdentitySummary.init),
            events: events
        )
    }
}

private struct SSHLocalProcessControllerMatrixFixture: Codable, Equatable {
    let rows: [SSHLocalProcessControllerMatrixRow]
}

private struct SSHLocalProcessControllerMatrixRow: Codable, Equatable {
    let id: String
    let rows: [SSHLocalProcessRowSummary]
    let result: [SSHLocalClientIdentitySummary]
    let identities: [SSHLocalClientIdentitySummary]
    let lastPublishedIdentities: [SSHLocalClientIdentitySummary]?
    let events: [[SSHLocalClientIdentitySummary]]
}

private struct SSHLocalProcessRowSummary: Codable, Equatable {
    let pid: Int
    let command: String
    let arguments: [String]

    init(_ row: SSHLocalProcessRow) {
        self.pid = row.pid
        self.command = row.command
        self.arguments = row.arguments
    }
}

private struct SSHLocalClientIdentitySummary: Codable, Equatable {
    let pid: Int
    let resolution: String
    let hostAlias: String?
    let commandLineRedacted: String?

    init(_ identity: SSHLocalClientIdentity) {
        self.pid = identity.pid
        self.resolution = identity.resolution
        self.hostAlias = identity.hostAlias
        self.commandLineRedacted = identity.commandLineRedacted
    }
}
