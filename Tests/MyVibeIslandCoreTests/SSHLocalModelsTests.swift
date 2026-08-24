import XCTest
@testable import MyVibeIslandCore

final class SSHLocalModelsTests: XCTestCase {
    func testLocalProcessAndIdentityMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHLocalProcessAndIdentityMatrixFixture.self,
            from: try FixtureLoader.data("remote/local-process-identity-matrix")
        )

        let actual = SSHLocalProcessAndIdentityMatrixFixture(rows: [
            row(
                id: "terminal-forwarded-socket",
                process: SSHLocalProcessRow(
                    pid: 4242,
                    tty: "ttys003",
                    command: "ssh",
                    arguments: ["-R", "<redacted>", "devbox"]
                ),
                identity: SSHLocalClientIdentity(
                    bundleIdentifier: "com.apple.Terminal",
                    pid: 4242,
                    tty: "ttys003",
                    resolution: "processScan",
                    commandLineRedacted: "ssh -R <redacted> devbox",
                    hostAlias: "devbox",
                    remoteForwardSpec: "<redacted>"
                )
            ),
            row(
                id: "iterm-tcp-forward",
                process: SSHLocalProcessRow(
                    pid: 5252,
                    tty: "ttys007",
                    command: "ssh",
                    arguments: ["-L", "127.0.0.1:47240:127.0.0.1:47240", "lab"]
                ),
                identity: SSHLocalClientIdentity(
                    bundleIdentifier: "com.googlecode.iterm2",
                    pid: 5252,
                    tty: "ttys007",
                    resolution: "windowOwner",
                    commandLineRedacted: "ssh -L 127.0.0.1:47240:127.0.0.1:47240 lab",
                    hostAlias: "lab",
                    remoteForwardSpec: nil
                )
            ),
            row(
                id: "vscode-integrated-terminal",
                process: SSHLocalProcessRow(
                    pid: 6262,
                    tty: nil,
                    command: "ssh",
                    arguments: ["devcontainer"]
                ),
                identity: SSHLocalClientIdentity(
                    bundleIdentifier: "com.microsoft.VSCode",
                    pid: 6262,
                    tty: nil,
                    resolution: "frontmostApplication",
                    commandLineRedacted: "ssh devcontainer",
                    hostAlias: "devcontainer",
                    remoteForwardSpec: nil
                )
            ),
            row(
                id: "unknown-client-no-command-line",
                process: SSHLocalProcessRow(
                    pid: 7272,
                    tty: nil,
                    command: "ssh",
                    arguments: []
                ),
                identity: SSHLocalClientIdentity(
                    bundleIdentifier: nil,
                    pid: 7272,
                    tty: nil,
                    resolution: "unresolved",
                    commandLineRedacted: nil,
                    hostAlias: nil,
                    remoteForwardSpec: nil
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testLocalProcessRowRoundTripsObservedFields() throws {
        let row = SSHLocalProcessRow(
            pid: 4242,
            tty: "ttys003",
            command: "ssh",
            arguments: ["-R", "<redacted>", "devbox"]
        )

        let decoded = try JSONDecoder().decode(SSHLocalProcessRow.self, from: try JSONEncoder().encode(row))

        XCTAssertEqual(decoded, row)
    }

    func testLocalClientIdentityRoundTripsObservedAndDesignFields() throws {
        let identity = SSHLocalClientIdentity(
            bundleIdentifier: "com.apple.Terminal",
            pid: 4242,
            tty: "ttys003",
            resolution: "processScan",
            commandLineRedacted: "ssh -R <redacted> devbox",
            hostAlias: "devbox",
            remoteForwardSpec: "<redacted>"
        )

        let decoded = try JSONDecoder().decode(SSHLocalClientIdentity.self, from: try JSONEncoder().encode(identity))

        XCTAssertEqual(decoded, identity)
    }

    private func row(
        id: String,
        process: SSHLocalProcessRow,
        identity: SSHLocalClientIdentity
    ) -> SSHLocalProcessAndIdentityRowFixture {
        SSHLocalProcessAndIdentityRowFixture(
            id: id,
            processPid: process.pid,
            processTTY: process.tty,
            processCommand: process.command,
            processArguments: process.arguments,
            identityBundleIdentifier: identity.bundleIdentifier,
            identityPid: identity.pid,
            identityTTY: identity.tty,
            identityResolution: identity.resolution,
            identityCommandLineRedacted: identity.commandLineRedacted,
            identityHostAlias: identity.hostAlias,
            identityRemoteForwardSpec: identity.remoteForwardSpec
        )
    }

    private struct SSHLocalProcessAndIdentityMatrixFixture: Codable, Equatable {
        let rows: [SSHLocalProcessAndIdentityRowFixture]
    }

    private struct SSHLocalProcessAndIdentityRowFixture: Codable, Equatable {
        let id: String
        let processPid: Int
        let processTTY: String?
        let processCommand: String
        let processArguments: [String]
        let identityBundleIdentifier: String?
        let identityPid: Int
        let identityTTY: String?
        let identityResolution: String
        let identityCommandLineRedacted: String?
        let identityHostAlias: String?
        let identityRemoteForwardSpec: String?
    }
}
