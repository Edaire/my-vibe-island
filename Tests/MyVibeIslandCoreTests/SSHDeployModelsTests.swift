import XCTest
@testable import MyVibeIslandCore

final class SSHDeployModelsTests: XCTestCase {
    func testDeployAndCommandOutputMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHDeployAndCommandOutputMatrixFixture.self,
            from: try FixtureLoader.data("remote/deploy-command-output-matrix")
        )

        let actual = SSHDeployAndCommandOutputMatrixFixture(rows: [
            row(
                id: "successful-go-deploy",
                deployResult: SSHDeployResult(
                    success: true,
                    message: "helper deployed",
                    durationMs: 840,
                    usedGoBinary: true,
                    hostId: "host-go",
                    step: "install-helper",
                    remotePath: "/home/dev/.my-vibe-island/helper",
                    configPath: "/home/dev/.config/my-vibe-island/config.json",
                    repairCommand: nil,
                    deployed: true,
                    lastDeployedAt: "2026-07-09T12:30:00Z"
                ),
                commandOutput: SSHCommandOutputBuffer(
                    stdout: "build ok\ninstall ok",
                    stderr: "",
                    maxBytes: 64,
                    exitCode: 0,
                    durationMs: 840
                )
            ),
            row(
                id: "failed-permission-deploy",
                deployResult: SSHDeployResult(
                    success: false,
                    message: "setup failed",
                    stderr: "permission denied",
                    durationMs: 240,
                    usedGoBinary: false,
                    hostId: "host-permission",
                    step: "install-hook",
                    remotePath: "/opt/my-vibe-island",
                    configPath: "~/.config/my-vibe-island",
                    repairCommand: "chmod u+w ~/.config/my-vibe-island",
                    deployed: false,
                    lastDeployError: "permission denied"
                ),
                commandOutput: SSHCommandOutputBuffer(
                    stdout: "checking target\nretrying install\n",
                    stderr: "mkdir: permission denied\n",
                    maxBytes: 18,
                    exitCode: 13,
                    durationMs: 240,
                    redactionApplied: true
                )
            ),
            row(
                id: "zero-byte-output-buffer",
                deployResult: SSHDeployResult(
                    success: false,
                    message: "command failed",
                    stderr: nil,
                    usedGoBinary: false,
                    hostId: nil,
                    step: nil,
                    remotePath: nil,
                    configPath: nil,
                    repairCommand: nil,
                    deployed: false,
                    lastDeployError: "exit 127"
                ),
                commandOutput: SSHCommandOutputBuffer(
                    stdout: "secret output",
                    stderr: "secret error",
                    maxBytes: -1,
                    exitCode: 127,
                    durationMs: nil,
                    redactionApplied: true
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testDeployResultRoundTripsObservedAndDesignFields() throws {
        let result = SSHDeployResult(
            success: false,
            message: "setup failed",
            stderr: "permission denied",
            durationMs: 240,
            usedGoBinary: true,
            hostId: "devbox",
            step: "install-hook",
            remotePath: "/tmp/my-vibe-island",
            configPath: "~/.config/my-vibe-island",
            repairCommand: "rerun setup",
            deployed: false,
            lastDeployedAt: "2026-07-08T22:10:00Z",
            lastDeployError: "permission denied"
        )

        let decoded = try JSONDecoder().decode(SSHDeployResult.self, from: try JSONEncoder().encode(result))

        XCTAssertEqual(decoded, result)
    }

    func testCommandOutputBufferStoresBoundedTails() throws {
        let buffer = SSHCommandOutputBuffer(
            stdout: "0123456789",
            stderr: "abcdefghij",
            maxBytes: 4,
            exitCode: 2,
            durationMs: 99,
            redactionApplied: true
        )

        XCTAssertEqual(buffer.stdoutTail, "6789")
        XCTAssertEqual(buffer.stderrTail, "ghij")
        XCTAssertEqual(buffer.maxBytes, 4)
        XCTAssertTrue(buffer.truncated)
        XCTAssertEqual(buffer.exitCode, 2)
        XCTAssertEqual(buffer.durationMs, 99)
        XCTAssertTrue(buffer.redactionApplied)

        let decoded = try JSONDecoder().decode(SSHCommandOutputBuffer.self, from: try JSONEncoder().encode(buffer))

        XCTAssertEqual(decoded, buffer)
    }

    private func row(
        id: String,
        deployResult: SSHDeployResult,
        commandOutput: SSHCommandOutputBuffer
    ) -> SSHDeployAndCommandOutputRowFixture {
        SSHDeployAndCommandOutputRowFixture(
            id: id,
            success: deployResult.success,
            message: deployResult.message,
            stderr: deployResult.stderr,
            durationMs: deployResult.durationMs,
            usedGoBinary: deployResult.usedGoBinary,
            hostId: deployResult.hostId,
            step: deployResult.step,
            remotePath: deployResult.remotePath,
            configPath: deployResult.configPath,
            repairCommand: deployResult.repairCommand,
            deployed: deployResult.deployed,
            lastDeployedAt: deployResult.lastDeployedAt,
            lastDeployError: deployResult.lastDeployError,
            stdoutTail: commandOutput.stdoutTail,
            stderrTail: commandOutput.stderrTail,
            maxBytes: commandOutput.maxBytes,
            truncated: commandOutput.truncated,
            exitCode: commandOutput.exitCode,
            commandDurationMs: commandOutput.durationMs,
            redactionApplied: commandOutput.redactionApplied
        )
    }

    private struct SSHDeployAndCommandOutputMatrixFixture: Codable, Equatable {
        let rows: [SSHDeployAndCommandOutputRowFixture]
    }

    private struct SSHDeployAndCommandOutputRowFixture: Codable, Equatable {
        let id: String
        let success: Bool
        let message: String
        let stderr: String?
        let durationMs: Int?
        let usedGoBinary: Bool
        let hostId: String?
        let step: String?
        let remotePath: String?
        let configPath: String?
        let repairCommand: String?
        let deployed: Bool
        let lastDeployedAt: String?
        let lastDeployError: String?
        let stdoutTail: String
        let stderrTail: String
        let maxBytes: Int
        let truncated: Bool
        let exitCode: Int?
        let commandDurationMs: Int?
        let redactionApplied: Bool
    }
}
