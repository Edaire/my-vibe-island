import XCTest
@testable import MyVibeIslandCore

final class TerminalJumpModelTests: XCTestCase {
    func testTerminalJumpModelMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            TerminalJumpModelMatrixFixture.self,
            from: try FixtureLoader.data("terminal/jump-model-matrix")
        )
        let environment = HookEnvironment(
            cwd: "/tmp/project",
            terminal: "iTerm.app",
            pid: 42,
            itermSessionId: "iterm-1",
            termSessionId: "term-1",
            tmux: "/tmp/tmux.sock,1,0",
            tmuxPane: "%1",
            kittyWindowId: "kitty-window",
            zellijSessionName: "zellij-main",
            zellijPaneId: "7",
            cfBundleIdentifier: "com.googlecode.iterm2",
            cmuxWorkspaceId: "cmux-workspace",
            cmuxSurfaceId: "cmux-surface",
            cmuxSocketPath: "/tmp/cmux.sock",
            supacodeWorktreeId: "supacode-worktree",
            supacodeTabId: "supacode-tab",
            supacodeSurfaceId: "supacode-surface",
            supacodeSocketPath: "/tmp/supacode.sock",
            weztermPane: "wezterm-pane",
            sshConnection: "client 1 server 2",
            sshTTY: "/dev/ttys002"
        )
        let input = JumpInput.fromHookEnvironment(
            sessionId: "session-1",
            source: "codex",
            environment: environment,
            createdAt: "2026-07-07T00:00:00Z"
        )
        let normalized = JumpInput(
            sessionId: "session-2",
            source: "codex",
            bundleId: " ",
            cwd: " ",
            tmuxPane: "",
            createdAt: ""
        )

        let actual = TerminalJumpModelMatrixFixture(rows: [
            row(id: "hook-environment-mapping", input: input),
            row(id: "empty-string-normalization", input: normalized),
            row(id: "weak-focus-from-cwd", input: JumpInput.fromHookEnvironment(
                sessionId: "session-3",
                source: "codex",
                environment: HookEnvironment(cwd: "/tmp/project")
            )),
            row(id: "unknown-focus-empty-environment", input: JumpInput.fromHookEnvironment(
                sessionId: "session-4",
                source: "codex",
                environment: HookEnvironment()
            )),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testJumpInputCodableRoundTripPreservesRepresentativeFields() throws {
        let fingerprint = TerminalFingerprint(
            sessionId: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            tty: "/dev/ttys001",
            termSessionId: "term-1",
            itermSessionId: "iterm-1",
            tmuxPane: "%1",
            zellijSessionName: "zellij-main",
            zellijPaneId: "7",
            kittyWindowId: "kitty-window",
            cmuxWorkspaceId: "cmux-workspace",
            cmuxSurfaceId: "cmux-surface",
            cmuxSocketPath: "/tmp/cmux.sock",
            isOpenCodeSubagent: true,
            isCodexThreadSpawnSubagent: true,
            weztermPane: "wezterm-pane",
            sshTTY: "/dev/ttys002",
            bundleId: "com.googlecode.iterm2"
        )
        let focusIdentity = TerminalFocusIdentity(
            supacode: "supacode-surface",
            bundleId: "com.googlecode.iterm2",
            processId: 42,
            windowId: "window-1",
            tabId: "tab-1",
            paneId: "pane-1",
            tty: "/dev/ttys001",
            cwd: "/tmp/project",
            externalSessionId: "iterm-1",
            confidence: .exact,
            observedAt: "2026-07-07T00:00:00Z"
        )
        let input = JumpInput(
            sessionId: "session-1",
            source: "codex",
            bundleId: "com.googlecode.iterm2",
            cwd: "/tmp/project",
            cliSessionId: "term-1",
            pid: 42,
            tty: "/dev/ttys001",
            customJumpURL: "codex://threads/thread-1",
            isGhosttyFamilyHost: true,
            supportsGhosttyPrivateFocus: true,
            isIDEHost: true,
            parentId: "parent-1",
            inferredParentId: "inferred-parent",
            openCodeParentID: "opencode-parent",
            codexThreadId: "thread-1",
            isSSHRemote: true,
            sshLocalBundleIdentifier: "com.googlecode.iterm2",
            isInTmux: true,
            tmuxPane: "%1",
            tmuxSocketPath: "/tmp/tmux.sock",
            zellijSessionName: "zellij-main",
            zellijPaneId: "7",
            itermSessionId: "iterm-1",
            cmuxWorkspaceId: "cmux-workspace",
            cmuxSurfaceId: "cmux-surface",
            cmuxSocketPath: "/tmp/cmux.sock",
            terminalFocusIdentity: focusIdentity,
            warpPaneUUID: "warp-pane",
            warpFocusURL: "warp://focus",
            kittyWindowId: "kitty-window",
            kittyListenOn: "unix:/tmp/kitty",
            weztermSocket: "/tmp/wezterm.sock",
            weztermPane: "wezterm-pane",
            ottySocket: "/tmp/otty.sock",
            ottyPaneId: "otty-pane",
            ideWindowId: "ide-window",
            createdAt: "2026-07-07T00:00:00Z",
            terminalFingerprint: fingerprint,
            termSessionId: "term-1",
            supacodeWorktreeId: "supacode-worktree",
            supacodeTabId: "supacode-tab",
            supacodeSurfaceId: "supacode-surface",
            supacodeSocketPath: "/tmp/supacode.sock",
            sshConnection: "client 1 server 2",
            sshTTY: "/dev/ttys002",
            remoteHostId: "remote-host",
            remoteCwd: "/srv/project"
        )

        let data = try JSONEncoder().encode(input)
        let decoded = try JSONDecoder().decode(JumpInput.self, from: data)

        XCTAssertEqual(decoded, input)
    }

    func testJumpInputMapsHookEnvironmentIntoTerminalContext() {
        let environment = HookEnvironment(
            cwd: "/tmp/project",
            terminal: "iTerm.app",
            pid: 42,
            itermSessionId: "iterm-1",
            termSessionId: "term-1",
            tmux: "/tmp/tmux.sock,1,0",
            tmuxPane: "%1",
            kittyWindowId: "kitty-window",
            kittyListenOn: "unix:/tmp/kitty",
            zellijSessionName: "zellij-main",
            zellijPaneId: "7",
            cfBundleIdentifier: "com.googlecode.iterm2",
            cmuxWorkspaceId: "cmux-workspace",
            cmuxSurfaceId: "cmux-surface",
            cmuxSocketPath: "/tmp/cmux.sock",
            supacodeWorktreeId: "supacode-worktree",
            supacodeTabId: "supacode-tab",
            supacodeSurfaceId: "supacode-surface",
            supacodeSocketPath: "/tmp/supacode.sock",
            weztermSocket: "/tmp/wezterm.sock",
            weztermPane: "wezterm-pane",
            ottySocket: "/tmp/otty.sock",
            ottyPaneId: "otty-pane",
            sshConnection: "client 1 server 2",
            sshTTY: "/dev/ttys002"
        )

        let input = JumpInput.fromHookEnvironment(
            sessionId: "session-1",
            source: "codex",
            environment: environment,
            createdAt: "2026-07-07T00:00:00Z"
        )

        XCTAssertEqual(input.sessionId, "session-1")
        XCTAssertEqual(input.source, "codex")
        XCTAssertEqual(input.cwd, "/tmp/project")
        XCTAssertEqual(input.pid, 42)
        XCTAssertEqual(input.bundleId, "com.googlecode.iterm2")
        XCTAssertEqual(input.cliSessionId, "term-1")
        XCTAssertEqual(input.termSessionId, "term-1")
        XCTAssertEqual(input.itermSessionId, "iterm-1")
        XCTAssertEqual(input.tmuxPane, "%1")
        XCTAssertEqual(input.tmuxSocketPath, "/tmp/tmux.sock")
        XCTAssertEqual(input.isInTmux, true)
        XCTAssertEqual(input.zellijSessionName, "zellij-main")
        XCTAssertEqual(input.zellijPaneId, "7")
        XCTAssertEqual(input.kittyWindowId, "kitty-window")
        XCTAssertEqual(input.kittyListenOn, "unix:/tmp/kitty")
        XCTAssertEqual(input.cmuxWorkspaceId, "cmux-workspace")
        XCTAssertEqual(input.cmuxSurfaceId, "cmux-surface")
        XCTAssertEqual(input.cmuxSocketPath, "/tmp/cmux.sock")
        XCTAssertEqual(input.supacodeWorktreeId, "supacode-worktree")
        XCTAssertEqual(input.supacodeTabId, "supacode-tab")
        XCTAssertEqual(input.supacodeSurfaceId, "supacode-surface")
        XCTAssertEqual(input.supacodeSocketPath, "/tmp/supacode.sock")
        XCTAssertEqual(input.weztermSocket, "/tmp/wezterm.sock")
        XCTAssertEqual(input.weztermPane, "wezterm-pane")
        XCTAssertEqual(input.ottySocket, "/tmp/otty.sock")
        XCTAssertEqual(input.ottyPaneId, "otty-pane")
        XCTAssertEqual(input.sshConnection, "client 1 server 2")
        XCTAssertEqual(input.sshTTY, "/dev/ttys002")
        XCTAssertEqual(input.isSSHRemote, true)
        XCTAssertEqual(input.sshLocalBundleIdentifier, "com.googlecode.iterm2")
        XCTAssertEqual(input.createdAt, "2026-07-07T00:00:00Z")
        XCTAssertEqual(input.terminalFocusIdentity?.confidence, .exact)
        XCTAssertEqual(input.terminalFocusIdentity?.supacode, "supacode-surface")
        XCTAssertEqual(input.terminalFingerprint?.sessionId, "session-1")
    }

    func testTerminalFingerprintMapsStableHookEnvironmentFields() {
        let environment = HookEnvironment(
            cwd: "/tmp/project",
            itermSessionId: "iterm-1",
            termSessionId: "term-1",
            tmuxPane: "%1",
            kittyWindowId: "kitty-window",
            zellijSessionName: "zellij-main",
            zellijPaneId: "7",
            cfBundleIdentifier: "com.googlecode.iterm2",
            cmuxWorkspaceId: "cmux-workspace",
            cmuxSurfaceId: "cmux-surface",
            cmuxSocketPath: "/tmp/cmux.sock",
            weztermPane: "wezterm-pane",
            sshTTY: "/dev/ttys002"
        )

        let fingerprint = TerminalFingerprint.fromHookEnvironment(
            sessionId: "session-1",
            source: "opencode",
            environment: environment
        )

        XCTAssertEqual(fingerprint.sessionId, "session-1")
        XCTAssertEqual(fingerprint.source, "opencode")
        XCTAssertEqual(fingerprint.cwd, "/tmp/project")
        XCTAssertEqual(fingerprint.termSessionId, "term-1")
        XCTAssertEqual(fingerprint.itermSessionId, "iterm-1")
        XCTAssertEqual(fingerprint.tmuxPane, "%1")
        XCTAssertEqual(fingerprint.kittyWindowId, "kitty-window")
        XCTAssertEqual(fingerprint.zellijSessionName, "zellij-main")
        XCTAssertEqual(fingerprint.zellijPaneId, "7")
        XCTAssertEqual(fingerprint.cmuxWorkspaceId, "cmux-workspace")
        XCTAssertEqual(fingerprint.cmuxSurfaceId, "cmux-surface")
        XCTAssertEqual(fingerprint.cmuxSocketPath, "/tmp/cmux.sock")
        XCTAssertEqual(fingerprint.weztermPane, "wezterm-pane")
        XCTAssertEqual(fingerprint.sshTTY, "/dev/ttys002")
        XCTAssertEqual(fingerprint.bundleId, "com.googlecode.iterm2")
    }

    func testInitializersNormalizeEmptyStrings() {
        let focus = TerminalFocusIdentity(bundleId: " ", paneId: "", confidence: .weak)
        let fingerprint = TerminalFingerprint(sessionId: "s1", source: "codex", cwd: " ", tmuxPane: "")
        let input = JumpInput(sessionId: "s1", source: "codex", cwd: " ", tmuxPane: "")

        XCTAssertNil(focus.bundleId)
        XCTAssertNil(focus.paneId)
        XCTAssertNil(fingerprint.cwd)
        XCTAssertNil(fingerprint.tmuxPane)
        XCTAssertNil(input.cwd)
        XCTAssertNil(input.tmuxPane)
    }

    func testTerminalFocusIdentityConfidenceSelection() {
        XCTAssertEqual(
            JumpInput.fromHookEnvironment(
                sessionId: "s1",
                source: "codex",
                environment: HookEnvironment(supacodeSurfaceId: "surface")
            ).terminalFocusIdentity?.confidence,
            .exact
        )
        XCTAssertEqual(
            JumpInput.fromHookEnvironment(
                sessionId: "s1",
                source: "codex",
                environment: HookEnvironment(tmuxPane: "%1")
            ).terminalFocusIdentity?.confidence,
            .strong
        )
        XCTAssertEqual(
            JumpInput.fromHookEnvironment(
                sessionId: "s1",
                source: "codex",
                environment: HookEnvironment(cwd: "/tmp/project")
            ).terminalFocusIdentity?.confidence,
            .weak
        )
        XCTAssertEqual(
            JumpInput.fromHookEnvironment(
                sessionId: "s1",
                source: "codex",
                environment: HookEnvironment()
            ).terminalFocusIdentity?.confidence,
            .unknown
        )
    }

    private func row(
        id: String,
        input: JumpInput
    ) -> TerminalJumpModelMatrixRow {
        TerminalJumpModelMatrixRow(
            id: id,
            sessionId: input.sessionId,
            source: input.source,
            bundleId: input.bundleId,
            cwd: input.cwd,
            cliSessionId: input.cliSessionId,
            pid: input.pid,
            isSSHRemote: input.isSSHRemote,
            sshLocalBundleIdentifier: input.sshLocalBundleIdentifier,
            isInTmux: input.isInTmux,
            tmuxPane: input.tmuxPane,
            tmuxSocketPath: input.tmuxSocketPath,
            itermSessionId: input.itermSessionId,
            cmuxSurfaceId: input.cmuxSurfaceId,
            supacodeSurfaceId: input.supacodeSurfaceId,
            sshConnection: input.sshConnection,
            sshTTY: input.sshTTY,
            createdAt: input.createdAt,
            focusConfidence: input.terminalFocusIdentity?.confidence.rawValue,
            focusSupacode: input.terminalFocusIdentity?.supacode,
            focusPaneId: input.terminalFocusIdentity?.paneId,
            focusExternalSessionId: input.terminalFocusIdentity?.externalSessionId,
            fingerprintSessionId: input.terminalFingerprint?.sessionId,
            fingerprintTmuxPane: input.terminalFingerprint?.tmuxPane,
            fingerprintBundleId: input.terminalFingerprint?.bundleId,
            fingerprintSSHTTY: input.terminalFingerprint?.sshTTY
        )
    }

    private struct TerminalJumpModelMatrixFixture: Codable, Equatable {
        let rows: [TerminalJumpModelMatrixRow]
    }

    private struct TerminalJumpModelMatrixRow: Codable, Equatable {
        let id: String
        let sessionId: String
        let source: String
        let bundleId: String?
        let cwd: String?
        let cliSessionId: String?
        let pid: Int?
        let isSSHRemote: Bool?
        let sshLocalBundleIdentifier: String?
        let isInTmux: Bool?
        let tmuxPane: String?
        let tmuxSocketPath: String?
        let itermSessionId: String?
        let cmuxSurfaceId: String?
        let supacodeSurfaceId: String?
        let sshConnection: String?
        let sshTTY: String?
        let createdAt: String?
        let focusConfidence: String?
        let focusSupacode: String?
        let focusPaneId: String?
        let focusExternalSessionId: String?
        let fingerprintSessionId: String?
        let fingerprintTmuxPane: String?
        let fingerprintBundleId: String?
        let fingerprintSSHTTY: String?
    }
}
