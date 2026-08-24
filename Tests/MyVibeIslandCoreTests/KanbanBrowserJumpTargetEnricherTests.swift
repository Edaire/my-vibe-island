import XCTest
@testable import MyVibeIslandCore

final class KanbanBrowserJumpTargetEnricherTests: XCTestCase {
    func testGatewayURLUsesTaskIDEncodedInKanbanTmuxSessionName() {
        XCTAssertEqual(
            KanbanBrowserJumpTargetEnricher.gatewayURL(
                tmuxSessionName: "kanban-codex-t_4c1056f8"
            )?.absoluteString,
            "http://127.0.0.1:8766/s/t_4c1056f8"
        )
    }

    func testGatewayURLRejectsNonKanbanOrMalformedTmuxSessionNames() {
        XCTAssertNil(KanbanBrowserJumpTargetEnricher.gatewayURL(tmuxSessionName: "work"))
        XCTAssertNil(KanbanBrowserJumpTargetEnricher.gatewayURL(tmuxSessionName: "kanban-codex-task-4c1056f8"))
        XCTAssertNil(KanbanBrowserJumpTargetEnricher.gatewayURL(tmuxSessionName: "kanban-other-t_4c1056f8"))
    }

    func testEnrichAddsCustomURLUsingKnownTmuxSocketAndPane() {
        let enricher = KanbanBrowserJumpTargetEnricher(
            tmuxSessionName: { socketPath, pane in
                XCTAssertEqual(socketPath, "/private/tmp/tmux-502/kanban-agency")
                XCTAssertEqual(pane, "%147")
                return "kanban-codex-t_4c1056f8"
            }
        )
        let input = JumpInput(
            sessionId: "codex-thread-1",
            source: "codex",
            tmuxPane: "%147",
            tmuxSocketPath: "/private/tmp/tmux-502/kanban-agency"
        )

        let enriched = enricher.enrich(input)

        XCTAssertEqual(enriched.customJumpURL, "http://127.0.0.1:8766/s/t_4c1056f8")
        XCTAssertEqual(TerminalJumpRouter().planJump(enriched).handlerId, "custom-url")
    }

    func testEnrichPreservesExistingTargetWhenTmuxLookupFails() {
        let enricher = KanbanBrowserJumpTargetEnricher(tmuxSessionName: { _, _ in nil })
        let input = JumpInput(
            sessionId: "codex-thread-1",
            source: "codex",
            tmuxPane: "%147",
            tmuxSocketPath: "/private/tmp/tmux-502/kanban-agency"
        )

        XCTAssertEqual(enricher.enrich(input), input)
    }
}
