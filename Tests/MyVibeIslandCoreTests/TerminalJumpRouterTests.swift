import XCTest
@testable import MyVibeIslandCore

final class TerminalJumpRouterTests: XCTestCase {
    func testTerminalJumpRouterMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            TerminalJumpRouterMatrixFixture.self,
            from: try FixtureLoader.data("terminal/router-matrix")
        )
        let router = TerminalJumpRouter()

        let actual = TerminalJumpRouterMatrixFixture(rows: [
            row(id: "custom-url-priority", result: router.planJump(JumpInput(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                customJumpURL: "codex://threads/thread-1",
                tmuxPane: "%1"
            ))),
            row(id: "remote-requires-reconnect", result: router.planJump(JumpInput(
                sessionId: "s2",
                source: "codex",
                bundleId: "com.apple.Terminal",
                isSSHRemote: true,
                sshConnection: "client 1 server 2"
            ))),
            row(id: "remote-with-local-pane", result: router.planJump(JumpInput(
                sessionId: "s3",
                source: "codex",
                isSSHRemote: true,
                tmuxPane: "%1"
            ))),
            row(id: "known-ide-workspace", result: router.planJump(JumpInput(
                sessionId: "s4",
                source: "codex",
                bundleId: "com.microsoft.VSCode",
                cwd: "/tmp/project"
            ))),
            row(id: "missing-target", result: router.planJump(JumpInput(
                sessionId: "s5",
                source: "codex"
            ))),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCustomURLRoutesToExactPaneBeforeOtherContext() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project",
            customJumpURL: "codex://threads/thread-1",
            tmuxPane: "%1"
        ))

        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.handlerId, "custom-url")
        XCTAssertEqual(result.attemptedMechanism, "custom-url")
        XCTAssertNil(result.failureReason)
    }

    func testCodexThreadRoutesToDeepLink() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            codexThreadId: "thread-1"
        ))

        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.handlerId, "codex-deeplink")
    }

    func testTerminalTTYRoutesBeforeCodexDeepLink() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.apple.Terminal",
            tty: "ttys175",
            codexThreadId: "thread-1"
        ))

        XCTAssertEqual(result.precision, .exactWindow)
        XCTAssertEqual(result.handlerId, "terminal-tty")
    }

    func testCustomURLRoutesBeforeRemoteHint() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            customJumpURL: "codex://threads/thread-1",
            isSSHRemote: true,
            sshConnection: "client 1 server 2"
        ))

        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.handlerId, "custom-url")
        XCTAssertEqual(result.attemptedMechanism, "custom-url")
        XCTAssertNil(result.failureReason)
    }

    func testCodexThreadRoutesBeforeRemoteHint() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            codexThreadId: "thread-1",
            isSSHRemote: true,
            sshConnection: "client 1 server 2"
        ))

        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.handlerId, "codex-deeplink")
        XCTAssertEqual(result.attemptedMechanism, "codex-deeplink")
        XCTAssertNil(result.failureReason)
    }

    func testSupacodeRoutesToExactPane() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "supacode",
            supacodeSurfaceId: "surface-1"
        ))

        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.handlerId, "supacode")
    }

    func testCmuxRoutesToExactPaneWhenSurfaceAndSocketExist() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "cmux",
            cmuxSurfaceId: "surface-1",
            cmuxSocketPath: "/tmp/cmux.sock"
        ))

        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.handlerId, "cmux")
    }

    func testMultiplexerAndTerminalHandlersRouteByPrecision() {
        XCTAssertEqual(routerResult(tmuxPane: "%1").handlerId, "tmux")
        XCTAssertEqual(routerResult(zellijPaneId: "7").handlerId, "zellij")
        XCTAssertEqual(routerResult(weztermPane: "pane-1").handlerId, "wezterm")
        XCTAssertEqual(routerResult(ottyPaneId: "pane-1").handlerId, "otty")
        XCTAssertEqual(routerResult(kittyWindowId: "window-1").precision, .exactWindow)
        XCTAssertEqual(routerResult(kittyWindowId: "window-1").handlerId, "kitty")
        XCTAssertEqual(routerResult(warpFocusURL: "warp://focus").handlerId, "warp")
        XCTAssertEqual(routerResult(itermSessionId: "iterm-1").handlerId, "iterm")
    }

    func testWarpFocusURLRoutesToWarpExactWindow() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            warpPaneUUID: "pane-1",
            warpFocusURL: "warp://focus/pane-1"
        ))

        XCTAssertEqual(result.precision, .exactWindow)
        XCTAssertEqual(result.handlerId, "warp")
    }

    func testWarpPaneOnlyRoutesToApplicationFallback() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            warpPaneUUID: "pane-1"
        ))

        XCTAssertEqual(result.precision, .application)
        XCTAssertEqual(result.handlerId, "application")
    }

    func testWarpPaneOnlyDoesNotOverrideHigherPriorityExactPaneHandlers() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            tmuxPane: "%1",
            warpPaneUUID: "pane-1"
        ))

        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.handlerId, "tmux")
    }

    func testGhosttyFamilyHostRoutesToGhosttyExactWindow() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.mitchellh.ghostty",
            isGhosttyFamilyHost: true,
            termSessionId: "ghostty-session-1"
        ))

        XCTAssertEqual(result.precision, .exactWindow)
        XCTAssertEqual(result.handlerId, "ghostty")
        XCTAssertEqual(result.attemptedMechanism, "ghostty")
    }

    func testGhosttyDoesNotOverrideHigherPriorityExactPaneHandlers() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            isGhosttyFamilyHost: true,
            tmuxPane: "%7"
        ))

        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.handlerId, "tmux")
    }

    func testTerminalTTYRoutesToExactWindow() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.apple.Terminal",
            tty: "/dev/ttys001"
        ))

        XCTAssertEqual(result.precision, .exactWindow)
        XCTAssertEqual(result.handlerId, "terminal-tty")
    }

    func testTmuxPaneRoutesBeforeItsInnerTerminalTTY() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.apple.Terminal",
            tty: "/dev/ttys023",
            tmuxPane: "%1752",
            tmuxSocketPath: "/private/tmp/tmux-502/default"
        ))

        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.handlerId, "tmux")
    }

    func testDetachedTmuxPaneUsesOriginalNoAttachedClientOutcome() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "detached-hermes-session",
            source: "hermes",
            bundleId: "com.apple.Terminal",
            tmuxPane: "%1",
            tmuxSocketPath: "/private/tmp/tmux-502/kanban-agency",
            tmuxHasAttachedClient: false
        ))

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.precision, .unsupported)
        XCTAssertEqual(result.handlerId, "tmux")
        XCTAssertEqual(result.failureReason, .tmuxNoAttachedClient)
    }

    func testWorkspaceAndApplicationFallbacks() {
        XCTAssertEqual(TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "cursor",
            cwd: "/tmp/project",
            isIDEHost: true
        )).handlerId, "ide-workspace")

        XCTAssertEqual(TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project"
        )).precision, .workspace)

        XCTAssertEqual(TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.apple.Terminal"
        )).precision, .application)
    }

    func testKnownIDEBundleWithWorkspaceRoutesToIDEWorkspace() {
        let jetBrainsResult = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.jetbrains.intellij",
            cwd: "/tmp/project"
        ))
        let vscodeResult = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s2",
            source: "codex",
            bundleId: "com.microsoft.VSCode",
            cwd: "/tmp/project"
        ))
        let cursorResult = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s3",
            source: "codex",
            bundleId: "com.todesktop.230313mzl4w4u92",
            cwd: "/tmp/project"
        ))

        XCTAssertEqual(jetBrainsResult.precision, .workspace)
        XCTAssertEqual(jetBrainsResult.handlerId, "ide-workspace")
        XCTAssertEqual(vscodeResult.precision, .workspace)
        XCTAssertEqual(vscodeResult.handlerId, "ide-workspace")
        XCTAssertEqual(cursorResult.precision, .workspace)
        XCTAssertEqual(cursorResult.handlerId, "ide-workspace")
    }

    func testUnknownBundleWithWorkspaceStillRoutesToGenericWorkspace() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.example.UnknownEditor",
            cwd: "/tmp/project"
        ))

        XCTAssertEqual(result.precision, .workspace)
        XCTAssertEqual(result.handlerId, "workspace")
    }

    func testKnownIDEBundleWithoutWorkspaceStillRoutesToApplication() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.jetbrains.intellij"
        ))

        XCTAssertEqual(result.precision, .application)
        XCTAssertEqual(result.handlerId, "application")
    }

    func testRemoteWithoutLocalPaneReturnsRemoteHint() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.apple.Terminal",
            isSSHRemote: true,
            sshConnection: "client 1 server 2"
        ))

        XCTAssertEqual(result.precision, .remoteHint)
        XCTAssertEqual(result.handlerId, "remote-hint")
        XCTAssertEqual(result.failureReason, .remoteRequiresReconnect)
    }

    func testRemoteWithLocalPaneRoutesToLocalExactPane() {
        let result = TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            isSSHRemote: true,
            tmuxPane: "%1"
        ))

        XCTAssertEqual(result.precision, .exactPane)
        XCTAssertEqual(result.handlerId, "tmux")
    }

    func testMissingTargetIsUnsupported() {
        let result = TerminalJumpRouter().planJump(JumpInput(sessionId: "s1", source: "codex"))

        XCTAssertEqual(result.precision, .unsupported)
        XCTAssertEqual(result.handlerId, "unsupported")
        XCTAssertEqual(result.failureReason, .missingTarget)
        XCTAssertFalse(result.succeeded)
    }

    private func routerResult(
        tmuxPane: String? = nil,
        zellijPaneId: String? = nil,
        weztermPane: String? = nil,
        ottyPaneId: String? = nil,
        kittyWindowId: String? = nil,
        warpFocusURL: String? = nil,
        itermSessionId: String? = nil
    ) -> JumpResult {
        TerminalJumpRouter().planJump(JumpInput(
            sessionId: "s1",
            source: "codex",
            tmuxPane: tmuxPane,
            zellijPaneId: zellijPaneId,
            itermSessionId: itermSessionId,
            warpFocusURL: warpFocusURL,
            kittyWindowId: kittyWindowId,
            weztermPane: weztermPane,
            ottyPaneId: ottyPaneId
        ))
    }

    private func row(
        id: String,
        result: JumpResult
    ) -> TerminalJumpRouterMatrixRow {
        TerminalJumpRouterMatrixRow(
            id: id,
            result: result
        )
    }

    private struct TerminalJumpRouterMatrixFixture: Codable, Equatable {
        let rows: [TerminalJumpRouterMatrixRow]
    }

    private struct TerminalJumpRouterMatrixRow: Codable, Equatable {
        let id: String
        let result: JumpResult
    }
}
