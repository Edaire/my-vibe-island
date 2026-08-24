import XCTest
@testable import MyVibeIslandCore

final class TmuxClientAttachmentProbeTests: XCTestCase {
    func testFindsAttachedClientForTargetPaneSession() {
        let probe = TmuxClientAttachmentProbe { _, arguments in
            arguments.first == "display-message"
                ? "agent-session\n"
                : "/dev/ttys001 unrelated\n/dev/ttys009 agent-session\n"
        }

        XCTAssertEqual(
            probe.probe(socketPath: "/private/tmp/tmux-502/default", pane: "%1"),
            TmuxClientAttachment(hasAttachedClient: true, clientTTY: "/dev/ttys009")
        )
    }

    func testReportsNoAttachedClientWhenTmuxListsNoMatchingSession() {
        let probe = TmuxClientAttachmentProbe { _, arguments in
            arguments.first == "display-message"
                ? "detached-session\n"
                : "/dev/ttys009 other-session\n"
        }

        XCTAssertEqual(
            probe.probe(socketPath: "/private/tmp/tmux-502/default", pane: "%1"),
            TmuxClientAttachment(hasAttachedClient: false)
        )
    }

    func testReturnsUnknownWhenTmuxCannotInspectPane() {
        let probe = TmuxClientAttachmentProbe { _, _ in nil }

        XCTAssertNil(probe.probe(socketPath: "/private/tmp/tmux-502/default", pane: "%1"))
    }
}
