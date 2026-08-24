import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalSessionSurfacePolicyTests: XCTestCase {
    func testOrdersSurfacedSessionsWithOriginalStatusRank() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [
                session(id: "waiting", status: .waitingForInput, restored: false, updatedAt: now),
                session(id: "ended", status: .ended, restored: true, updatedAt: now.addingTimeInterval(-1)),
            ],
            now: now
        )

        XCTAssertEqual(decision.surfaced.map(\.id), ["waiting", "ended"])
    }

    func testRunningOrActionableSessionsAreSurfaced() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [
                session(id: "idle", restored: true, updatedAt: now),
                session(id: "running", status: .runningTool, restored: false, updatedAt: now),
                session(
                    id: "action",
                    status: .waitingForApproval,
                    restored: true,
                    pendingRequestIds: ["request"],
                    updatedAt: now
                )
            ],
            now: now
        )

        XCTAssertEqual(decision.surfaced.map(\.id), ["action", "running"])
        XCTAssertEqual(decision.deferred.map(\.id), ["idle"])
    }

    func testRestoredRunningMetadataWithoutFreshWatcherEvidenceIsDeferred() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [
                session(id: "historical-running", status: .processing, restored: true, updatedAt: nil)
            ],
            now: now
        )

        XCTAssertEqual(decision.surfaced, [] as [AgentSession])
        XCTAssertEqual(decision.deferred.map(\.id), ["historical-running"])
    }

    func testAttentionPrecedesRunningPrecedesRecentCompleted() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [
                session(id: "completed", status: .ended, restored: true, updatedAt: now.addingTimeInterval(-60)),
                session(id: "running", status: .runningTool, restored: false, updatedAt: now),
                session(
                    id: "attention",
                    status: .question,
                    restored: true,
                    questionPrompt: "Continue?",
                    updatedAt: now
                )
            ],
            now: now
        )

        XCTAssertEqual(decision.surfaced.map(\.id), ["attention", "running", "completed"])
        XCTAssertEqual(decision.spotlightID, "attention")
    }

    func testCompletedSessionsBecomeStaleAfterFiveMinutes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [
                session(id: "fresh", status: .ended, restored: true, updatedAt: now.addingTimeInterval(-299)),
                session(id: "stale", status: .ended, restored: true, updatedAt: now.addingTimeInterval(-300))
            ],
            now: now,
            staleCompletedAfter: 300
        )

        XCTAssertEqual(decision.surfaced.map(\.id), ["fresh"])
        XCTAssertEqual(decision.deferred.map(\.id), ["stale"])
    }

    func testInactiveRestoredSessionsDoNotTriggerFastPollingOrSpotlight() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [session(id: "inactive", restored: true, updatedAt: now)],
            now: now
        )

        XCTAssertEqual(decision.surfaced, [] as [AgentSession])
        XCTAssertEqual(decision.deferred.map(\.id), ["inactive"])
        XCTAssertNil(decision.spotlightID)
    }

    func testInactiveLiveSessionsOutsideTwentyMinutesAreDeferred() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [
                session(id: "recent", restored: false, updatedAt: now.addingTimeInterval(-1_199)),
                session(id: "inactive", restored: false, updatedAt: now.addingTimeInterval(-1_200))
            ],
            now: now,
            inactiveLiveAfter: 1_200
        )

        XCTAssertEqual(decision.surfaced.map(\.id), ["recent"])
        XCTAssertEqual(decision.deferred.map(\.id), ["inactive"])
    }

    func testTerminalBackedIdleSessionsRemainSurfacedAfterInactiveWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [
                session(
                    id: "terminal-idle",
                    restored: false,
                    updatedAt: now.addingTimeInterval(-3_600),
                    tty: "ttys016"
                ),
                session(id: "plain-idle", restored: false, updatedAt: now.addingTimeInterval(-3_600))
            ],
            now: now,
            inactiveLiveAfter: 1_200
        )

        XCTAssertEqual(decision.surfaced.map(\.id), ["terminal-idle"])
        XCTAssertEqual(decision.deferred.map(\.id), ["plain-idle"])
    }

    func testLiveSessionsWithoutActivityMetadataAreDeferred() {
        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [session(id: "empty-live", source: "claude", restored: false, updatedAt: nil)]
        )

        XCTAssertEqual(decision.surfaced, [] as [AgentSession])
        XCTAssertEqual(decision.deferred.map(\.id), ["empty-live"])
    }

    func testEmptyClaudeBootstrapIsDeferredEvenWhenItHasDiscoveryTimestamp() {
        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [session(id: "empty-claude", source: "claude", restored: false, updatedAt: Date())]
        )

        XCTAssertEqual(decision.surfaced, [] as [AgentSession])
        XCTAssertEqual(decision.deferred.map(\.id), ["empty-claude"])
    }

    func testClaudeQuestionWithoutConversationMessagesIsSurfaced() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [
                session(
                    id: "cowork-question",
                    source: "claude",
                    status: .question,
                    restored: false,
                    questionPrompt: "Which parser?",
                    updatedAt: now
                )
            ],
            now: now
        )

        XCTAssertEqual(decision.surfaced.map(\.id), ["cowork-question"])
        XCTAssertEqual(decision.spotlightID, "cowork-question")
    }

    func testDuplicateSessionIDsKeepTheFirstAuthoritativeRecord() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let first = session(id: "same", status: .runningTool, restored: false, updatedAt: now)
        let second = session(id: "same", restored: true, updatedAt: now)

        let decision = OriginalSessionSurfacePolicy.resolve(sessions: [first, second], now: now)

        XCTAssertEqual(decision.surfaced.map(\.id), ["same"])
        XCTAssertEqual(decision.surfaced.first?.originalStatus, .runningTool)
    }

    func testActiveCliTTYSelectsSpotlightBeforePersistedFocus() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let focused = session(
            id: "persisted-focus",
            status: .processing,
            restored: false,
            updatedAt: now,
            tty: "/dev/ttys001"
        )
        let frontmost = session(
            id: "frontmost-terminal",
            status: .processing,
            restored: false,
            updatedAt: now.addingTimeInterval(-1),
            tty: "ttys002"
        )

        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [focused, frontmost],
            now: now,
            focusedID: focused.id,
            activeCliTTYs: ["/dev/ttys002"]
        )

        XCTAssertEqual(decision.spotlightID, frontmost.id)
    }

    func testFocusedSessionWinsWhenMultipleActiveTTYsAlsoMatchIt() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let focused = session(
            id: "focused",
            status: .processing,
            restored: false,
            updatedAt: now,
            tty: "/dev/ttys016"
        )
        let otherActivePane = session(
            id: "other-pane",
            status: .processing,
            restored: false,
            updatedAt: now.addingTimeInterval(1),
            tty: "/dev/ttys017"
        )

        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [otherActivePane, focused],
            now: now,
            focusedID: focused.id,
            activeCliTTYs: ["ttys016", "ttys017"]
        )

        XCTAssertEqual(decision.spotlightID, focused.id)
    }

    func testMissingActiveCliTTYMatchFallsBackToPersistedFocus() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let focused = session(
            id: "persisted-focus",
            status: .processing,
            restored: false,
            updatedAt: now,
            tty: "/dev/ttys001"
        )

        let decision = OriginalSessionSurfacePolicy.resolve(
            sessions: [focused],
            now: now,
            focusedID: focused.id,
            activeCliTTYs: ["/dev/ttys999"]
        )

        XCTAssertEqual(decision.spotlightID, focused.id)
    }

    private func session(
        id: String,
        source: String = "codex",
        status: OriginalPixelStatusCompact = .waitingForInput,
        restored: Bool,
        pendingRequestIds: [String] = [],
        questionPrompt: String? = nil,
        updatedAt: Date?,
        tty: String? = nil
    ) -> AgentSession {
        AgentSession(
            id: id,
            source: source,
            cwd: "/tmp/\(id)",
            originalStatus: status,
            updatedAt: updatedAt,
            pendingRequestIds: pendingRequestIds,
            questionPrompt: questionPrompt,
            isRestored: restored,
            jumpInput: tty.map {
                JumpInput(sessionId: id, source: source, cwd: "/tmp/\(id)", tty: $0)
            }
        )
    }
}
