import XCTest
@testable import MyVibeIslandCore

final class CodexSubagentThreadTests: XCTestCase {
    func testCodexSubagentThreadMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CodexSubagentThreadMatrixFixture.self,
            from: try FixtureLoader.data("codex/subagent-thread-matrix")
        )

        let actual = CodexSubagentThreadMatrixFixture(rows: [
            row(id: "observed-and-design-fields", thread: CodexSubagentThread(
                parentThreadId: "parent-thread",
                agentNickname: "Reviewer",
                agentRole: "review",
                childThreadId: "child-thread",
                spawnKind: "subagent",
                sourceWrapperId: "source-wrapper-1",
                observedAt: "2026-07-08T20:15:00Z",
                confidence: 0.8
            )),
            row(id: "confidence-low-clamped", thread: CodexSubagentThread(
                parentThreadId: "parent-thread",
                confidence: -1.0
            )),
            row(id: "confidence-high-clamped", thread: CodexSubagentThread(
                parentThreadId: "parent-thread",
                confidence: 2.0
            )),
            row(id: "weak-fallback-identity", thread: CodexSubagentThread(
                parentThreadId: "parent-thread",
                agentNickname: "Reviewer",
                agentRole: "review",
                spawnKind: "subagent"
            )),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCodexSubagentThreadRoundTripsObservedAndDesignFields() throws {
        let thread = CodexSubagentThread(
            parentThreadId: "parent-thread",
            agentNickname: "Reviewer",
            agentRole: "review",
            childThreadId: "child-thread",
            spawnKind: "subagent",
            sourceWrapperId: "source-wrapper-1",
            observedAt: "2026-07-08T20:15:00Z",
            confidence: 0.8
        )

        let data = try JSONEncoder().encode(thread)
        let decoded = try JSONDecoder().decode(CodexSubagentThread.self, from: data)

        XCTAssertEqual(decoded, thread)
        XCTAssertEqual(decoded.parentThreadId, "parent-thread")
        XCTAssertEqual(decoded.agentNickname, "Reviewer")
        XCTAssertEqual(decoded.agentRole, "review")
        XCTAssertEqual(decoded.sourceWrapperId, "source-wrapper-1")
    }

    func testCodexSubagentThreadClampsConfidence() {
        let low = CodexSubagentThread(parentThreadId: "parent", confidence: -1.0)
        let high = CodexSubagentThread(parentThreadId: "parent", confidence: 2.0)

        XCTAssertEqual(low.confidence, 0.0)
        XCTAssertEqual(high.confidence, 1.0)
    }

    func testCodexSubagentThreadStableIdentityPrefersChildThreadId() {
        let thread = CodexSubagentThread(
            parentThreadId: "parent-thread",
            agentNickname: "Nickname changes",
            agentRole: "review",
            childThreadId: "child-thread"
        )

        XCTAssertEqual(thread.identityKey, "child-thread")
        XCTAssertFalse(thread.identityIsWeak)
    }

    func testCodexSubagentThreadUsesWeakFallbackIdentityWithoutChildThreadId() {
        let thread = CodexSubagentThread(
            parentThreadId: "parent-thread",
            agentNickname: "Reviewer",
            agentRole: "review",
            spawnKind: "subagent"
        )

        XCTAssertEqual(
            thread.identityKey,
            "weak:agentNickname=Reviewer|agentRole=review|parentThreadId=parent-thread|spawnKind=subagent"
        )
        XCTAssertTrue(thread.identityIsWeak)
    }

    private func row(
        id: String,
        thread: CodexSubagentThread
    ) -> CodexSubagentThreadMatrixRow {
        CodexSubagentThreadMatrixRow(
            id: id,
            thread: thread,
            identityKey: thread.identityKey,
            identityIsWeak: thread.identityIsWeak
        )
    }

    private struct CodexSubagentThreadMatrixFixture: Codable, Equatable {
        let rows: [CodexSubagentThreadMatrixRow]
    }

    private struct CodexSubagentThreadMatrixRow: Codable, Equatable {
        let id: String
        let thread: CodexSubagentThread
        let identityKey: String
        let identityIsWeak: Bool
    }
}
