import XCTest
@testable import MyVibeIslandCore

final class V3AutomaticExpansionGateTests: XCTestCase {
    func testAllowsTerminalSessionWithValidTTYWhenFrontmostBundleAndSelectedTTYMatch() {
        let input = JumpInput(
            sessionId: "session-1",
            source: "codex",
            bundleId: "com.apple.Terminal",
            cwd: "/tmp",
            tty: "/dev/ttys014"
        )

        XCTAssertTrue(
            V3AutomaticExpansionGate().allows(
                session: input,
                focus: V3AutomaticExpansionFocus(
                    frontmostBundleId: "com.apple.Terminal",
                    activeTTYs: ["ttys014"]
                )
            )
        )
    }

    func testAllowsTerminalSessionWhenAnotherAppIsFrontmost() {
        let input = JumpInput(
            sessionId: "session-1",
            source: "codex",
            bundleId: "com.apple.Terminal",
            cwd: "/tmp",
            tty: "ttys014"
        )

        XCTAssertTrue(
            V3AutomaticExpansionGate().allows(
                session: input,
                focus: V3AutomaticExpansionFocus(
                    frontmostBundleId: "com.googlecode.iterm2",
                    activeTTYs: ["ttys014"]
                )
            )
        )
    }

    func testRejectsTmuxSessionWithoutCurrentTargetAttachmentEvidence() {
        let input = JumpInput(
            sessionId: "session-1",
            source: "codex",
            bundleId: "com.apple.Terminal",
            cwd: "/tmp",
            isInTmux: true,
            tmuxPane: "%12",
            tmuxClientTTY: "/dev/ttys009"
        )

        XCTAssertFalse(
            V3AutomaticExpansionGate().allows(
                session: input,
                focus: V3AutomaticExpansionFocus(
                    frontmostBundleId: "com.apple.Terminal",
                    activeTTYs: ["ttys009"]
                )
            )
        )
    }

    func testAllowsTmuxSessionWhenCurrentTargetHasAttachedClient() {
        let input = JumpInput(
            sessionId: "session-1",
            source: "codex",
            bundleId: "com.apple.Terminal",
            cwd: "/tmp",
            isInTmux: true,
            tmuxPane: "%12",
            tmuxSocketPath: "/private/tmp/tmux-502/test"
        )

        XCTAssertTrue(
            V3AutomaticExpansionGate(
                tmuxAttachmentProbe: { socketPath, pane in
                    XCTAssertEqual(socketPath, "/private/tmp/tmux-502/test")
                    XCTAssertEqual(pane, "%12")
                    return TmuxClientAttachment(
                        hasAttachedClient: true,
                        clientTTY: "/dev/ttys009"
                    )
                }
            ).allows(
                session: input,
                focus: V3AutomaticExpansionFocus(
                    frontmostBundleId: "com.apple.Terminal",
                    activeTTYs: ["ttys009"]
                )
            )
        )
    }

    func testRejectsIdentityWithoutConcreteTerminalTTY() {
        let input = JumpInput(
            sessionId: "session-1",
            source: "codex",
            bundleId: "com.openai.codex",
            cwd: "/tmp",
            terminalFocusIdentity: TerminalFocusIdentity(
                bundleId: "com.openai.codex",
                confidence: .exact
            )
        )

        XCTAssertFalse(
            V3AutomaticExpansionGate().allows(
                session: input,
                focus: V3AutomaticExpansionFocus(
                    frontmostBundleId: "com.openai.codex",
                    activeTTYs: []
                )
            )
        )
    }
}
