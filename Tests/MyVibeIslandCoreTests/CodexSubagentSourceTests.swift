import XCTest
@testable import MyVibeIslandCore

final class CodexSubagentSourceTests: XCTestCase {
    func testCodexSubagentSourceMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CodexSubagentSourceMatrixFixture.self,
            from: try FixtureLoader.data("codex/subagent-source-matrix")
        )

        let thread = CodexSubagentThread(
            parentThreadId: "parent-thread",
            agentNickname: "Reviewer",
            agentRole: "review",
            childThreadId: "child-thread",
            spawnKind: "subagent",
            sourceWrapperId: "wrapper-1",
            observedAt: "2026-07-08T20:30:00Z",
            confidence: 0.8
        )

        let actual = CodexSubagentSourceMatrixFixture(rows: [
            CodexSubagentSourceMatrixRow(
                id: "full-source",
                source: CodexSubagentSource(
                    sourceId: "codex",
                    wrapperKind: "subagent-source",
                    subagentKind: "reviewer",
                    sourceThreadSpawn: thread,
                    detailThreadSpawn: thread,
                    detailOther: "redacted-detail",
                    parentThreadId: "parent-thread",
                    subagentDetailId: "detail-1",
                    rawEventId: "event-1",
                    sessionId: "session-1",
                    observedAt: "2026-07-08T20:30:00Z",
                    confidence: 0.8
                )
            ),
            CodexSubagentSourceMatrixRow(
                id: "low-confidence-clamped",
                source: CodexSubagentSource(
                    sourceId: "codex",
                    rawEventId: "event-low",
                    sessionId: "session-low",
                    confidence: -1
                )
            ),
            CodexSubagentSourceMatrixRow(
                id: "high-confidence-clamped",
                source: CodexSubagentSource(
                    sourceId: "codex",
                    rawEventId: "event-high",
                    sessionId: "session-high",
                    confidence: 2
                )
            ),
            CodexSubagentSourceMatrixRow(
                id: "empty-event-id",
                source: CodexSubagentSource(
                    sourceId: "codex",
                    rawEventId: "",
                    sessionId: "session-empty-event"
                )
            ),
            CodexSubagentSourceMatrixRow(
                id: "detached-without-session",
                source: CodexSubagentSource(
                    sourceId: "codex",
                    rawEventId: "event-detached"
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCodexSubagentSourceRoundTripsObservedAndDesignFields() throws {
        let thread = CodexSubagentThread(
            parentThreadId: "parent-thread",
            agentNickname: "Reviewer",
            agentRole: "review"
        )
        let source = CodexSubagentSource(
            sourceId: "codex",
            wrapperKind: "subagent-source",
            subagentKind: "reviewer",
            sourceThreadSpawn: thread,
            detailThreadSpawn: thread,
            detailOther: "redacted-detail",
            parentThreadId: "parent-thread",
            subagentDetailId: "detail-1",
            rawEventId: "event-1",
            sessionId: "session-1",
            observedAt: "2026-07-08T20:30:00Z",
            confidence: 0.8
        )

        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(CodexSubagentSource.self, from: data)

        XCTAssertEqual(decoded, source)
        XCTAssertEqual(decoded.subagentKind, "reviewer")
        XCTAssertEqual(decoded.sourceThreadSpawn, thread)
        XCTAssertEqual(decoded.detailThreadSpawn, thread)
        XCTAssertEqual(decoded.detailOther, "redacted-detail")
    }

    func testCodexSubagentSourceClampsConfidence() {
        let low = CodexSubagentSource(sourceId: "codex", confidence: -1.0)
        let high = CodexSubagentSource(sourceId: "codex", confidence: 2.0)

        XCTAssertEqual(low.confidence, 0.0)
        XCTAssertEqual(high.confidence, 1.0)
    }

    func testCodexSubagentSourceBuildsStableWrapperKeyWhenPossible() {
        let source = CodexSubagentSource(sourceId: "codex", rawEventId: "event-1")

        XCTAssertEqual(source.wrapperKey, "codex:event-1")
    }

    func testCodexSubagentSourceCannotCreateTopLevelSessionWithoutSessionId() {
        let detached = CodexSubagentSource(sourceId: "codex", rawEventId: "event-1")
        let attached = CodexSubagentSource(
            sourceId: "codex",
            rawEventId: "event-1",
            sessionId: "session-1"
        )

        XCTAssertFalse(detached.canCreateTopLevelSession)
        XCTAssertTrue(attached.canCreateTopLevelSession)
    }
}

private struct CodexSubagentSourceMatrixFixture: Codable, Equatable {
    let rows: [CodexSubagentSourceMatrixRow]
}

private struct CodexSubagentSourceMatrixRow: Codable, Equatable {
    let id: String
    let sourceId: String
    let wrapperKind: String?
    let subagentKind: String?
    let wrapperKey: String?
    let canCreateTopLevelSession: Bool
    let confidence: Double
    let sourceThreadIdentityKey: String?
    let detailThreadIdentityKey: String?
    let hasDetailOther: Bool

    init(id: String, source: CodexSubagentSource) {
        self.id = id
        self.sourceId = source.sourceId
        self.wrapperKind = source.wrapperKind
        self.subagentKind = source.subagentKind
        self.wrapperKey = source.wrapperKey
        self.canCreateTopLevelSession = source.canCreateTopLevelSession
        self.confidence = source.confidence
        self.sourceThreadIdentityKey = source.sourceThreadSpawn?.identityKey
        self.detailThreadIdentityKey = source.detailThreadSpawn?.identityKey
        self.hasDetailOther = source.detailOther?.isEmpty == false
    }
}
