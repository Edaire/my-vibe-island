import XCTest
@testable import MyVibeIslandCore

final class HookEnvironmentTests: XCTestCase {
    func testCapturePreservesTTYForTerminalTabJump() throws {
        let environment = HookEnvironment.capture(
            processEnvironment: [
                "PWD": "/tmp/project",
                "TTY": "/dev/ttys004",
            ],
            currentDirectoryPath: "/fallback",
            processIdentifier: 42,
            userName: "fixture-user"
        )

        let data = try JSONEncoder().encode(environment)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["tty"] as? String, "/dev/ttys004")
    }

    func testCaptureResolvesTTYFromHookProcessAncestorWhenEnvironmentOmitsIt() throws {
        let resolver = ProcessTTYResolver { processIdentifier in
            switch processIdentifier {
            case 42:
                return ProcessTTYInfo(tty: "??", parentProcessID: 41)
            case 41:
                return ProcessTTYInfo(tty: "ttys175", parentProcessID: 1)
            default:
                return nil
            }
        }

        let environment = HookEnvironment.capture(
            processEnvironment: ["PWD": "/tmp/project"],
            currentDirectoryPath: "/fallback",
            processIdentifier: 42,
            userName: "fixture-user",
            ttyResolver: resolver
        )

        XCTAssertEqual(environment.tty, "/dev/ttys175")
    }

    func testHookEnvironmentMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            HookEnvironmentMatrixFixture.self,
            from: try FixtureLoader.data("agents/hook-environment-matrix")
        )

        let mapped = HookEnvironment.capture(
            processEnvironment: [
                "PWD": "/tmp/project",
                "SHELL": "/bin/zsh",
                "TERM_PROGRAM": "iTerm.app",
                "ITERM_SESSION_ID": "iterm-1",
                "TERM_SESSION_ID": "term-1",
                "WARP_SESSION_ID": "warp-session",
                "WARP_TERMINAL_SESSION_UUID": "warp-pane",
                "WARP_FOCUS_URL": "warp://focus",
                "TMUX": "/tmp/tmux.sock,1,0",
                "TMUX_PANE": "%3",
                "KITTY_WINDOW_ID": "kitty-window",
                "KITTY_LISTEN_ON": "unix:/tmp/kitty",
                "ZELLIJ_SESSION_NAME": "zellij-main",
                "ZELLIJ_PANE_ID": "7",
                "__CFBundleIdentifier": "com.apple.Terminal",
                "CURSOR_TRACE_ID": "cursor-trace",
                "CONDUCTOR_WORKSPACE_NAME": "conductor-workspace",
                "CONDUCTOR_PORT": "4567",
                "CMUX_WORKSPACE_ID": "cmux-workspace",
                "CMUX_SURFACE_ID": "cmux-surface",
                "CMUX_SOCKET_PATH": "/tmp/cmux.sock",
                "SUPACODE_WORKTREE_ID": "supacode-worktree",
                "SUPACODE_TAB_ID": "supacode-tab",
                "SUPACODE_SURFACE_ID": "supacode-surface",
                "SUPACODE_SOCKET_PATH": "/tmp/supacode.sock",
                "WEZTERM_UNIX_SOCKET": "/tmp/wezterm.sock",
                "WEZTERM_PANE": "wezterm-pane",
                "OTTY_SOCKET": "/tmp/otty.sock",
                "OTTY_PANE_ID": "otty-pane",
                "SSH_CONNECTION": "client 1 server 2",
                "SSH_TTY": "/dev/ttys001",
                "OPENAI_API_KEY": "must-not-copy",
            ],
            currentDirectoryPath: "/fallback/cwd",
            processIdentifier: 1234,
            userName: "fixture-user"
        )
        let fallback = HookEnvironment.capture(
            processEnvironment: [
                "PWD": "   ",
                "SHELL": "",
                "TERM_PROGRAM": "  ",
                "TMUX_PANE": "%1",
                "OPENAI_API_KEY": "must-not-copy",
            ],
            currentDirectoryPath: "/fallback/cwd",
            processIdentifier: 4321,
            userName: "fixture-user"
        )

        let actual = HookEnvironmentMatrixFixture(rows: [
            row(id: "allowlisted-terminal-host-environment", environment: mapped),
            row(id: "empty-values-fallback-and-secret-omission", environment: fallback),
        ])

        XCTAssertEqual(actual, expected)
        let encoded = String(data: try JSONEncoder().encode(actual), encoding: .utf8) ?? ""
        XCTAssertFalse(encoded.contains("must-not-copy"))
    }

    func testCaptureMapsAllowlistedTerminalAndHostEnvironment() {
        let environment = HookEnvironment.capture(
            processEnvironment: [
                "PWD": "/tmp/project",
                "SHELL": "/bin/zsh",
                "TERM_PROGRAM": "iTerm.app",
                "ITERM_SESSION_ID": "iterm-1",
                "TERM_SESSION_ID": "term-1",
                "WARP_SESSION_ID": "warp-session",
                "WARP_TERMINAL_SESSION_UUID": "warp-pane",
                "WARP_FOCUS_URL": "warp://focus",
                "TMUX": "/tmp/tmux.sock,1,0",
                "TMUX_PANE": "%3",
                "KITTY_WINDOW_ID": "kitty-window",
                "KITTY_LISTEN_ON": "unix:/tmp/kitty",
                "ZELLIJ_SESSION_NAME": "zellij-main",
                "ZELLIJ_PANE_ID": "7",
                "__CFBundleIdentifier": "com.apple.Terminal",
                "CURSOR_TRACE_ID": "cursor-trace",
                "CONDUCTOR_WORKSPACE_NAME": "conductor-workspace",
                "CONDUCTOR_PORT": "4567",
                "CMUX_WORKSPACE_ID": "cmux-workspace",
                "CMUX_SURFACE_ID": "cmux-surface",
                "CMUX_SOCKET_PATH": "/tmp/cmux.sock",
                "SUPACODE_WORKTREE_ID": "supacode-worktree",
                "SUPACODE_TAB_ID": "supacode-tab",
                "SUPACODE_SURFACE_ID": "supacode-surface",
                "SUPACODE_SOCKET_PATH": "/tmp/supacode.sock",
                "WEZTERM_UNIX_SOCKET": "/tmp/wezterm.sock",
                "WEZTERM_PANE": "wezterm-pane",
                "OTTY_SOCKET": "/tmp/otty.sock",
                "OTTY_PANE_ID": "otty-pane",
                "SSH_CONNECTION": "client 1 server 2",
                "SSH_TTY": "/dev/ttys001",
                "OPENAI_API_KEY": "must-not-copy",
            ],
            currentDirectoryPath: "/fallback/cwd",
            processIdentifier: 1234,
            userName: "fixture-user"
        )

        XCTAssertEqual(environment.cwd, "/tmp/project")
        XCTAssertEqual(environment.shell, "/bin/zsh")
        XCTAssertEqual(environment.terminal, "iTerm.app")
        XCTAssertEqual(environment.pid, 1234)
        XCTAssertEqual(environment.user, "fixture-user")
        XCTAssertEqual(environment.termProgram, "iTerm.app")
        XCTAssertEqual(environment.itermSessionId, "iterm-1")
        XCTAssertEqual(environment.termSessionId, "term-1")
        XCTAssertEqual(environment.warpSessionId, "warp-session")
        XCTAssertEqual(environment.warpTerminalSessionUUID, "warp-pane")
        XCTAssertEqual(environment.warpFocusURL, "warp://focus")
        XCTAssertEqual(environment.tmux, "/tmp/tmux.sock,1,0")
        XCTAssertEqual(environment.tmuxPane, "%3")
        XCTAssertEqual(environment.kittyWindowId, "kitty-window")
        XCTAssertEqual(environment.kittyListenOn, "unix:/tmp/kitty")
        XCTAssertEqual(environment.zellijSessionName, "zellij-main")
        XCTAssertEqual(environment.zellijPaneId, "7")
        XCTAssertEqual(environment.cfBundleIdentifier, "com.apple.Terminal")
        XCTAssertEqual(environment.cursorTraceId, "cursor-trace")
        XCTAssertEqual(environment.conductorWorkspaceName, "conductor-workspace")
        XCTAssertEqual(environment.conductorPort, "4567")
        XCTAssertEqual(environment.cmuxWorkspaceId, "cmux-workspace")
        XCTAssertEqual(environment.cmuxSurfaceId, "cmux-surface")
        XCTAssertEqual(environment.cmuxSocketPath, "/tmp/cmux.sock")
        XCTAssertEqual(environment.supacodeWorktreeId, "supacode-worktree")
        XCTAssertEqual(environment.supacodeTabId, "supacode-tab")
        XCTAssertEqual(environment.supacodeSurfaceId, "supacode-surface")
        XCTAssertEqual(environment.supacodeSocketPath, "/tmp/supacode.sock")
        XCTAssertEqual(environment.weztermSocket, "/tmp/wezterm.sock")
        XCTAssertEqual(environment.weztermPane, "wezterm-pane")
        XCTAssertEqual(environment.ottySocket, "/tmp/otty.sock")
        XCTAssertEqual(environment.ottyPaneId, "otty-pane")
        XCTAssertEqual(environment.sshConnection, "client 1 server 2")
        XCTAssertEqual(environment.sshTTY, "/dev/ttys001")
    }

    func testCaptureNormalizesEmptyValuesAndFallsBackToCurrentDirectory() {
        let environment = HookEnvironment.capture(
            processEnvironment: [
                "PWD": "   ",
                "SHELL": "",
                "TERM_PROGRAM": "  ",
                "TMUX_PANE": "%1",
            ],
            currentDirectoryPath: "/fallback/cwd",
            processIdentifier: 4321,
            userName: "fixture-user"
        )

        XCTAssertEqual(environment.cwd, "/fallback/cwd")
        XCTAssertNil(environment.shell)
        XCTAssertNil(environment.terminal)
        XCTAssertNil(environment.termProgram)
        XCTAssertEqual(environment.tmuxPane, "%1")
        XCTAssertEqual(environment.pid, 4321)
        XCTAssertEqual(environment.user, "fixture-user")
    }

    func testDiagnosticSummaryRedactsRawEnvironmentValues() throws {
        let environment = HookEnvironment(
            cwd: "/tmp/project",
            shell: "/bin/zsh",
            terminal: "iTerm.app",
            pid: 1234,
            user: "fixture-user",
            termSessionId: "terminal-session",
            tmux: "/tmp/tmux.sock,1,0",
            tmuxPane: "%3",
            cursorTraceId: "cursor-trace",
            cmuxSocketPath: "/tmp/cmux.sock",
            sshConnection: "client 1 server 2",
            sshTTY: "/dev/ttys001"
        )

        let summary = environment.diagnosticSummary
        let encoded = String(data: try JSONEncoder().encode(summary), encoding: .utf8) ?? ""

        XCTAssertTrue(summary.hasCwd)
        XCTAssertTrue(summary.hasUser)
        XCTAssertTrue(summary.hasProcessIdentifier)
        XCTAssertTrue(summary.hasTerminalSession)
        XCTAssertTrue(summary.hasMultiplexer)
        XCTAssertTrue(summary.hasRemoteSSH)
        XCTAssertTrue(summary.hasEditorTrace)
        XCTAssertEqual(summary.capturedFieldCount, 12)

        XCTAssertFalse(encoded.contains("/tmp/project"))
        XCTAssertFalse(encoded.contains("/bin/zsh"))
        XCTAssertFalse(encoded.contains("iTerm.app"))
        XCTAssertFalse(encoded.contains("fixture-user"))
        XCTAssertFalse(encoded.contains("terminal-session"))
        XCTAssertFalse(encoded.contains("/tmp/tmux.sock"))
        XCTAssertFalse(encoded.contains("%3"))
        XCTAssertFalse(encoded.contains("/tmp/cmux.sock"))
        XCTAssertFalse(encoded.contains("cursor-trace"))
        XCTAssertFalse(encoded.contains("client 1 server 2"))
        XCTAssertFalse(encoded.contains("/dev/ttys001"))
    }

    private func row(
        id: String,
        environment: HookEnvironment
    ) -> HookEnvironmentMatrixRow {
        HookEnvironmentMatrixRow(
            id: id,
            environment: environment,
            diagnosticSummary: environment.diagnosticSummary
        )
    }

    private struct HookEnvironmentMatrixFixture: Codable, Equatable {
        let rows: [HookEnvironmentMatrixRow]
    }

    private struct HookEnvironmentMatrixRow: Codable, Equatable {
        let id: String
        let environment: HookEnvironment
        let diagnosticSummary: HookEnvironmentDiagnosticSummary
    }
}
