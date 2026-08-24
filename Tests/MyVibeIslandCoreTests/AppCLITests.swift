import Foundation
import XCTest
@testable import MyVibeIslandCore

final class AppCLITests: XCTestCase {
    private final class RecordingJumpRunner: TerminalJumpActionRunning, @unchecked Sendable {
        private(set) var actions: [TerminalJumpActionDescription] = []
        private let result: TerminalJumpRunnerResult

        init(result: TerminalJumpRunnerResult) {
            self.result = result
        }

        func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
            actions.append(action)
            return result
        }
    }

    func testDefaultOutputPreservesRunnableSkeletonText() throws {
        let output = try AppCLI().run(arguments: [])

        XCTAssertTrue(output.contains("My Vibe Island starting: runnable skeleton"))
        XCTAssertTrue(output.contains("Bridge socket:"))
    }

    func testAppCLIBasicEntryMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppCLIBasicEntryMatrixFixture.self,
            from: try FixtureLoader.data("app/app-cli-basic-entry-matrix")
        )

        let cli = AppCLI(runtimeFactory: {
            XCTFail("basic CLI entry matrix should not create runtime")
            return AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        })
        let actual = AppCLIBasicEntryMatrixFixture(rows: [
            row(id: "default", arguments: [], output: try cli.run(arguments: [])),
            row(id: "help", arguments: ["--help"], output: try cli.run(arguments: ["--help"])),
            row(id: "unknown-option", arguments: ["--unknown"], output: try cli.run(arguments: ["--unknown"])),
            row(id: "double-dash-app", arguments: ["--", "--app"], output: try cli.run(arguments: ["--", "--app"])),
            row(id: "jump-missing-session", arguments: ["jump"], output: try cli.run(arguments: ["jump"])),
            row(id: "status-missing-home", arguments: ["status", "--home"], output: try cli.run(arguments: ["status", "--home"])),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testHelpOutputIncludesAppShellEntry() throws {
        let output = try AppCLI().run(arguments: ["--help"])

        XCTAssertTrue(output.contains("My Vibe Island"))
        XCTAssertTrue(output.contains("--app"))
        XCTAssertTrue(output.contains("status"))
        XCTAssertTrue(output.contains("jump"))
    }

    func testInvalidTopLevelOptionPrintsDiagnostic() throws {
        let output = try AppCLI().run(arguments: ["--unknown"])

        XCTAssertEqual(output, "unknown top-level option: --unknown")
    }

    func testAppShellModePrintsExplicitNotWiredMessage() throws {
        let output = try AppCLI().run(arguments: ["--app"])

        XCTAssertTrue(output.contains("My Vibe Island app shell"))
        XCTAssertTrue(output.contains("launch plan: dry run"))
        XCTAssertTrue(output.contains("target: Built-in Display"))
        XCTAssertTrue(output.contains("route: island"))
        XCTAssertTrue(output.contains("runtime starts: 19"))
        XCTAssertTrue(output.contains("actions: 36"))
        XCTAssertTrue(output.contains("status menu entries: 14"))
        XCTAssertTrue(output.contains("closed frame: 416,402 680x580"))
        XCTAssertTrue(output.contains("platform launch: not wired"))
    }

    func testAppShellModePrintsPlatformIntentDryRunSummary() throws {
        let output = try AppCLI().run(arguments: ["--app"])

        XCTAssertTrue(output.contains("platform intents: 36"))
        XCTAssertTrue(output.contains("lifecycle intents: 10"))
        XCTAssertTrue(output.contains("runtime start intents: 19"))
        XCTAssertTrue(output.contains("notch window intents: 5"))
        XCTAssertTrue(output.contains("route intents: 1"))
        XCTAssertTrue(output.contains("platform intent plan: lifecycle, runtime, notch, statusMenu, route"))
    }

    func testDoubleDashPassesArgumentsToCLI() throws {
        let output = try AppCLI().run(arguments: ["--", "--app"])

        XCTAssertTrue(output.contains("My Vibe Island starting: runnable skeleton"))
        XCTAssertFalse(output.contains("platform launch: not wired"))
    }

    func testStatusPrintsRuntimeStatusWithoutOpenCodeSync() throws {
        let output = try AppCLI(runtimeFactory: {
            AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        }).run(arguments: ["status"])

        XCTAssertTrue(output.contains("My Vibe Island runtime status"))
        XCTAssertTrue(output.contains("bridge: stopped"))
        XCTAssertTrue(output.contains("sessions: 0"))
        XCTAssertTrue(output.contains("opencode sync: not run"))
    }

    func testStatusUsesHomeOverrideSessionStore() throws {
        let home = try temporaryRoot()
        writeStoredSession(id: "stored", cwd: "/tmp/stored", to: home)

        let output = try AppCLI().run(arguments: ["status", "--home", home.path])

        XCTAssertTrue(output.contains("My Vibe Island runtime status"))
        XCTAssertTrue(output.contains("sessions: 1"))
    }

    func testSyncOpenCodePrintsDiagnosticsForExplicitRoot() throws {
        let root = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/opencode-cli", to: root.appendingPathComponent("session.json"))
        let output = try AppCLI(runtimeFactory: {
            AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        }).run(arguments: ["sync-opencode", "--root", root.path])

        XCTAssertTrue(output.contains("My Vibe Island OpenCode sync"))
        XCTAssertTrue(output.contains("root: \(root.path)"))
        XCTAssertTrue(output.contains("attempted: 1"))
        XCTAssertTrue(output.contains("successful: 1"))
        XCTAssertTrue(output.contains("failed: 0"))
        XCTAssertTrue(output.contains("events: 1"))
        XCTAssertTrue(output.contains("root missing: false"))
        XCTAssertTrue(output.contains("synced sessions:"))
        XCTAssertTrue(output.contains("- opencode: /tmp/opencode-cli"))
    }

    func testSyncOpenCodeWithoutRootDoesNotScan() throws {
        let output = try AppCLI().run(arguments: ["sync-opencode"])

        XCTAssertEqual(output, "Missing --root for OpenCode sync")
    }

    func testSyncOpenCodeWithMissingRootPrintsNoSyncedSessions() throws {
        let missingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-app-cli-tests")
            .appendingPathComponent(UUID().uuidString)
        let output = try AppCLI(runtimeFactory: {
            AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        }).run(arguments: ["sync-opencode", "--root", missingRoot.path])

        XCTAssertTrue(output.contains("root missing: true"))
        XCTAssertTrue(output.contains("synced sessions: none"))
    }

    func testJumpPrintsPlanForSession() throws {
        let jumpInput = JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1")
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: jumpInput,
                resolvedJumpTarget: TerminalResolver().resolve(jumpInput)
            )
        ])
        let output = try AppCLI(runtimeFactory: {
            AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionCoordinator: coordinator)
        }).run(arguments: ["jump", "--session", "s1"])

        XCTAssertTrue(output.contains("My Vibe Island jump plan"))
        XCTAssertTrue(output.contains("session: s1"))
        XCTAssertTrue(output.contains("status: planned"))
        XCTAssertTrue(output.contains("handler: tmux"))
        XCTAssertTrue(output.contains("precision: exactPane"))
        XCTAssertTrue(output.contains("diagnostic: tmux: exactPane"))
    }

    func testJumpDryRunPrintsExecutionDecisionForSession() throws {
        let jumpInput = JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1")
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: jumpInput,
                resolvedJumpTarget: TerminalResolver().resolve(jumpInput)
            )
        ])
        let output = try AppCLI(runtimeFactory: {
            AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionCoordinator: coordinator)
        }).run(arguments: ["jump", "--session", "s1", "--dry-run"])

        XCTAssertTrue(output.contains("My Vibe Island jump dry run"))
        XCTAssertTrue(output.contains("session: s1"))
        XCTAssertTrue(output.contains("status: dryRun"))
        XCTAssertTrue(output.contains("handler: tmux"))
        XCTAssertTrue(output.contains("precision: exactPane"))
        XCTAssertTrue(output.contains("permissions: cli"))
        XCTAssertTrue(output.contains("action: runCLI"))
        XCTAssertTrue(output.contains("target: tmux"))
        XCTAssertTrue(output.contains("diagnostic: dry run: tmux exactPane"))
    }

    func testJumpDryRunUsesHomeOverrideSessionStore() throws {
        let home = try temporaryRoot()
        writeStoredSession(id: "stored", cwd: "/tmp/stored", to: home)

        let output = try AppCLI().run(arguments: ["jump", "--session", "stored", "--dry-run", "--home", home.path])

        XCTAssertTrue(output.contains("My Vibe Island jump dry run"))
        XCTAssertTrue(output.contains("session: stored"))
        XCTAssertTrue(output.contains("status: dryRun"))
        XCTAssertTrue(output.contains("handler: workspace"))
        XCTAssertTrue(output.contains("precision: workspace"))
        XCTAssertTrue(output.contains("action: openWorkspace"))
        XCTAssertTrue(output.contains("target: /tmp/stored"))
    }

    func testJumpExecutePrintsExecutionResultForWorkspaceSession() throws {
        let jumpInput = JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: jumpInput,
                resolvedJumpTarget: TerminalResolver().resolve(jumpInput)
            )
        ])
        let runner = RecordingJumpRunner(result: .succeeded("opened workspace: /tmp/project"))
        let output = try AppCLI(runtimeFactory: {
            AppRuntime(
                socketPath: BridgeSocketPath.temporaryForTests(),
                sessionCoordinator: coordinator,
                jumpRunner: runner
            )
        }).run(arguments: ["jump", "--session", "s1", "--execute"])

        XCTAssertTrue(output.contains("My Vibe Island jump execute"))
        XCTAssertTrue(output.contains("session: s1"))
        XCTAssertTrue(output.contains("status: executed"))
        XCTAssertTrue(output.contains("handler: workspace"))
        XCTAssertTrue(output.contains("precision: workspace"))
        XCTAssertTrue(output.contains("permissions: none"))
        XCTAssertTrue(output.contains("action: openWorkspace"))
        XCTAssertTrue(output.contains("target: /tmp/project"))
        XCTAssertTrue(output.contains("diagnostic: opened workspace: /tmp/project"))
        XCTAssertEqual(runner.actions.map(\.kind), [.openWorkspace])
    }

    func testJumpExecutePrintsRunnerFailureBlock() throws {
        let jumpInput = JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: jumpInput,
                resolvedJumpTarget: TerminalResolver().resolve(jumpInput)
            )
        ])
        let output = try AppCLI(runtimeFactory: {
            AppRuntime(
                socketPath: BridgeSocketPath.temporaryForTests(),
                sessionCoordinator: coordinator,
                jumpRunner: RecordingJumpRunner(result: .failed(.executionFailed, diagnosticSummary: "failed to open workspace: /tmp/project"))
            )
        }).run(arguments: ["jump", "--session", "s1", "--execute"])

        XCTAssertTrue(output.contains("My Vibe Island jump execute"))
        XCTAssertTrue(output.contains("status: blocked"))
        XCTAssertTrue(output.contains("block: runnerFailed"))
        XCTAssertTrue(output.contains("diagnostic: failed to open workspace: /tmp/project"))
    }

    func testJumpDryRunPrintsUnavailableExecutionDecisionForMissingSession() throws {
        let output = try AppCLI(runtimeFactory: {
            AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        }).run(arguments: ["jump", "--session", "missing", "--dry-run"])

        XCTAssertTrue(output.contains("My Vibe Island jump dry run"))
        XCTAssertTrue(output.contains("session: missing"))
        XCTAssertTrue(output.contains("status: unavailable"))
        XCTAssertTrue(output.contains("permissions: none"))
        XCTAssertTrue(output.contains("action: unsupported"))
        XCTAssertTrue(output.contains("target: missing session"))
        XCTAssertTrue(output.contains("block: unavailablePlan"))
        XCTAssertTrue(output.contains("diagnostic: missing session"))
    }

    func testJumpDryRunWithoutSessionDoesNotCreateRuntime() throws {
        let output = try AppCLI(runtimeFactory: {
            XCTFail("runtime should not be created when --session is missing")
            return AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        }).run(arguments: ["jump", "--dry-run"])

        XCTAssertEqual(output, "Missing --session for jump")
    }

    func testJumpExecuteWithoutSessionDoesNotCreateRuntime() throws {
        let output = try AppCLI(runtimeFactory: {
            XCTFail("runtime should not be created when --session is missing")
            return AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        }).run(arguments: ["jump", "--execute"])

        XCTAssertEqual(output, "Missing --session for jump")
    }

    func testRuntimeCommandWithMissingHomeValueDoesNotCreateRuntime() throws {
        let output = try AppCLI(runtimeFactory: {
            XCTFail("runtime should not be created when --home value is missing")
            return AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        }).run(arguments: ["status", "--home"])

        XCTAssertEqual(output, "Missing --home value")
    }

    func testJumpMissingSessionStillDoesNotCreateRuntimeWhenHomeValueIsMissing() throws {
        let output = try AppCLI(runtimeFactory: {
            XCTFail("runtime should not be created when --session is missing")
            return AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        }).run(arguments: ["jump", "--dry-run", "--home"])

        XCTAssertEqual(output, "Missing --session for jump")
    }

    func testJumpPrintsMissingSessionPlan() throws {
        let output = try AppCLI(runtimeFactory: {
            AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        }).run(arguments: ["jump", "--session", "missing"])

        XCTAssertTrue(output.contains("status: unavailable"))
        XCTAssertTrue(output.contains("failure: missingSession"))
        XCTAssertTrue(output.contains("diagnostic: missing session"))
    }

    func testJumpWithoutSessionDoesNotCreateRuntime() throws {
        let output = try AppCLI(runtimeFactory: {
            XCTFail("runtime should not be created when --session is missing")
            return AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        }).run(arguments: ["jump"])

        XCTAssertEqual(output, "Missing --session for jump")
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-app-cli-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private func writeSnapshot(directory: String, to url: URL) throws {
        try """
        {
          "session": {
            "directory": "\(directory)"
          },
          "messages": []
        }
        """.write(to: url, atomically: true, encoding: .utf8)
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

    private func row(
        id: String,
        arguments: [String],
        output: String
    ) -> AppCLIBasicEntryRowFixture {
        let lines = output.components(separatedBy: "\n")
        return AppCLIBasicEntryRowFixture(
            id: id,
            arguments: arguments,
            firstLine: lines.first ?? "",
            lineCount: lines.count,
            containsRunnableSkeleton: output.contains("runnable skeleton"),
            containsBridgeSocketLine: output.contains("Bridge socket:"),
            containsAppShellDryRun: output.contains("platform launch: not wired"),
            containsHelpUsage: output.contains("Usage:"),
            containsRuntimeStatus: output.contains("runtime status")
        )
    }

    private struct AppCLIBasicEntryMatrixFixture: Codable, Equatable {
        let rows: [AppCLIBasicEntryRowFixture]
    }

    private struct AppCLIBasicEntryRowFixture: Codable, Equatable {
        let id: String
        let arguments: [String]
        let firstLine: String
        let lineCount: Int
        let containsRunnableSkeleton: Bool
        let containsBridgeSocketLine: Bool
        let containsAppShellDryRun: Bool
        let containsHelpUsage: Bool
        let containsRuntimeStatus: Bool
    }
}
