import Foundation
import XCTest
@testable import MyVibeIslandCore

final class AppExecutableSmokeTests: XCTestCase {
    func testExecutableSmokeMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppExecutableSmokeMatrixFixture.self,
            from: try FixtureLoader.data("app/app-executable-smoke-matrix")
        )
        let home = try temporaryHomeDirectory()
        writeStoredSession(id: "stored", cwd: "/tmp/stored", to: home)

        let actual = AppExecutableSmokeMatrixFixture(rows: [
            row(
                id: "status-home-override",
                result: try runExecutable(arguments: ["status", "--home", home.path])
            ),
            row(
                id: "jump-dry-run-home-override",
                result: try runExecutable(arguments: ["jump", "--session", "stored", "--dry-run", "--home", home.path])
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testExecutableStatusAndJumpDryRunUseHomeOverrideStore() throws {
        let home = try temporaryHomeDirectory()
        writeStoredSession(id: "stored", cwd: "/tmp/stored", to: home)

        let status = try runExecutable(arguments: ["status", "--home", home.path])

        XCTAssertEqual(status.exitCode, 0)
        XCTAssertTrue(status.output.contains("My Vibe Island runtime status"))
        XCTAssertTrue(status.output.contains("sessions: 1"))

        let jump = try runExecutable(arguments: ["jump", "--session", "stored", "--dry-run", "--home", home.path])

        XCTAssertEqual(jump.exitCode, 0)
        XCTAssertTrue(jump.output.contains("My Vibe Island jump dry run"))
        XCTAssertTrue(jump.output.contains("session: stored"))
        XCTAssertTrue(jump.output.contains("status: dryRun"))
        XCTAssertTrue(jump.output.contains("handler: workspace"))
        XCTAssertTrue(jump.output.contains("precision: workspace"))
        XCTAssertTrue(jump.output.contains("action: openWorkspace"))
        XCTAssertTrue(jump.output.contains("target: /tmp/stored"))
    }

    private func runExecutable(arguments: [String]) throws -> ProcessResult {
        let executableURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/debug/my-vibe-island")
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, output: output)
    }

    private func writeStoredSession(
        id: String,
        cwd: String,
        to home: URL
    ) {
        let jumpInput = JumpInput(sessionId: id, source: "codex", cwd: cwd)
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: id,
                source: "codex",
                cwd: cwd,
                jumpInput: jumpInput,
                resolvedJumpTarget: TerminalResolver().resolve(jumpInput)
            ),
        ]))
    }

    private func temporaryHomeDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-executable-smoke-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private func row(id: String, result: ProcessResult) -> AppExecutableSmokeMatrixRow {
        AppExecutableSmokeMatrixRow(
            id: id,
            exitCode: result.exitCode,
            firstLine: result.output.split(separator: "\n").first.map(String.init),
            containsRuntimeStatus: result.output.contains("My Vibe Island runtime status"),
            containsSessionCount: result.output.contains("sessions: 1"),
            containsJumpDryRun: result.output.contains("My Vibe Island jump dry run"),
            containsStoredSession: result.output.contains("session: stored"),
            containsDryRunStatus: result.output.contains("status: dryRun"),
            containsWorkspaceHandler: result.output.contains("handler: workspace"),
            containsOpenWorkspaceAction: result.output.contains("action: openWorkspace"),
            containsStoredTarget: result.output.contains("target: /tmp/stored")
        )
    }
}

private struct ProcessResult {
    let exitCode: Int32
    let output: String
}

private struct AppExecutableSmokeMatrixFixture: Codable, Equatable {
    let rows: [AppExecutableSmokeMatrixRow]
}

private struct AppExecutableSmokeMatrixRow: Codable, Equatable {
    let id: String
    let exitCode: Int32
    let firstLine: String?
    let containsRuntimeStatus: Bool
    let containsSessionCount: Bool
    let containsJumpDryRun: Bool
    let containsStoredSession: Bool
    let containsDryRunStatus: Bool
    let containsWorkspaceHandler: Bool
    let containsOpenWorkspaceAction: Bool
    let containsStoredTarget: Bool
}
