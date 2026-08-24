import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalSessionDisplayOrderTests: XCTestCase {
    func testOrdersAllStatusesByRecoveredOriginalRank() {
        let sessions = [
            session("ended", .ended, 900),
            session("unknown", .unknown, 800),
            session("waiting", .waitingForInput, 700),
            session("tool", .runningTool, 100),
            session("compacting", .compacting, 200),
            session("processing", .processing, 300),
            session("thinking", .thinking, 50),
            session("question", .question, 40),
            session("approval", .waitingForApproval, 30),
        ]

        XCTAssertEqual(
            OriginalSessionDisplayOrder.sort(sessions).map(\.id),
            ["approval", "question", "thinking", "processing", "compacting", "tool", "waiting", "unknown", "ended"]
        )
    }

    func testOrdersEqualStatusRankByLastActivityDescending() {
        let sessions = [
            session("older", .runningTool, 100),
            session("newest", .processing, 300),
            session("middle", .compacting, 200),
        ]

        XCTAssertEqual(
            OriginalSessionDisplayOrder.sort(sessions).map(\.id),
            ["newest", "middle", "older"]
        )
    }

    func testFiltersOnlyRecoveredMemoryConsolidationWorkingDirectories() {
        XCTAssertTrue(OriginalSessionDisplayEligibility.isKnownInternalSessionCWD(
            "memory_consolidation"
        ))
        XCTAssertTrue(OriginalSessionDisplayEligibility.isKnownInternalSessionCWD(
            "memory_consolidation///"
        ))
        XCTAssertTrue(OriginalSessionDisplayEligibility.isKnownInternalSessionCWD(
            "prefix</conversation_history>suffix"
        ))
        XCTAssertFalse(OriginalSessionDisplayEligibility.isKnownInternalSessionCWD(""))
        XCTAssertFalse(OriginalSessionDisplayEligibility.isKnownInternalSessionCWD("/repo/normal-session"))
        XCTAssertFalse(OriginalSessionDisplayEligibility.isKnownInternalSessionCWD("memory_consolidation_work"))
    }

    func testEligibilityReadsCwdRatherThanSessionIdentity() {
        let normalIDWithInternalCWD = AgentSession(
            id: "normal-id",
            source: "codex",
            cwd: "/tmp/memory_consolidation"
        )
        let internalLookingIDWithNormalCWD = AgentSession(
            id: "memory_consolidation",
            source: "codex",
            cwd: "/repo/normal"
        )

        XCTAssertTrue(OriginalSessionDisplayEligibility.isKnownInternalSessionCWD(normalIDWithInternalCWD.cwd))
        XCTAssertFalse(OriginalSessionDisplayEligibility.isKnownInternalSessionCWD(internalLookingIDWithNormalCWD.cwd))
    }

    func testOnlyCodexSubagentOriginAppliesRecoveredInternalKindExclusions() {
        let hiddenLastRun = AgentSession(
            id: "hidden-last-run",
            source: "codex",
            cwd: "/repo/normal",
            codexOrigin: "subagent",
            codexSubagentKind: "/tmp/vibe-island.lastrun"
        )
        let hiddenGuardian = AgentSession(
            id: "hidden-guardian",
            source: "CODEX",
            cwd: "/repo/normal",
            codexOrigin: "subagent",
            codexSubagentKind: "guardian"
        )
        let normalOrigin = AgentSession(
            id: "visible-cli",
            source: "codex",
            cwd: "/repo/normal",
            codexOrigin: "cli",
            codexSubagentKind: "guardian"
        )

        XCTAssertFalse(OriginalSessionDisplayEligibility.isEligible(hiddenLastRun))
        XCTAssertFalse(OriginalSessionDisplayEligibility.isEligible(hiddenGuardian))
        XCTAssertTrue(OriginalSessionDisplayEligibility.isEligible(normalOrigin))
    }

    func testExcludesPersistedRestoredSessionsUntilLiveEvidenceArrives() {
        let restored = AgentSession(
            id: "restored-history",
            source: "codex",
            cwd: "/repo/current",
            isRestored: true
        )

        XCTAssertFalse(OriginalSessionDisplayEligibility.isEligible(restored))
        XCTAssertTrue(
            OriginalSessionDisplayEligibility.isEligible(
                restored,
                liveSessionIDs: [restored.id]
            )
        )
    }

    private func session(
        _ id: String,
        _ status: OriginalPixelStatusCompact,
        _ activityTime: TimeInterval
    ) -> AgentSession {
        AgentSession(
            id: id,
            source: "codex",
            cwd: "/repo/\(id)",
            originalStatus: status,
            updatedAt: Date(timeIntervalSinceReferenceDate: activityTime)
        )
    }
}
