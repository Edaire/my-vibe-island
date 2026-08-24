import XCTest
@testable import MyVibeIslandCore

final class SessionStoreReadOnlySummaryTests: XCTestCase {
    func testSummaryReportsAuthoritativeStoreSessionsWithoutProcessObservation() {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(id: "codex-live", source: "codex", cwd: "/repo/codex"),
            AgentSession(id: "claude-live", source: "claude", cwd: "/repo/claude"),
            AgentSession(id: "codex-ended", source: "codex", cwd: "/repo/old"),
        ]))

        let summary = SessionStoreReadOnlySummaryReader(store: store).read()

        XCTAssertEqual(summary.sessionCount, 3)
        XCTAssertEqual(summary.sourceCounts, ["claude": 1, "codex": 2])
        XCTAssertEqual(summary.sessionIDs, ["claude-live", "codex-ended", "codex-live"])
    }
}
