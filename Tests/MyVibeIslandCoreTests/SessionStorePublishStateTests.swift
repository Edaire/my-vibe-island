import XCTest
@testable import MyVibeIslandCore

final class SessionStorePublishStateTests: XCTestCase {
    func testSessionStorePublishStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SessionStorePublishStateMatrixFixture.self,
            from: try FixtureLoader.data("runtime/session-store-publish-state-matrix")
        )

        let actual = SessionStorePublishStateMatrixFixture(rows: [
            try row(id: "default-empty-state", state: SessionStorePublishState()),
            try row(id: "scheduled-without-silence-snapshot", state: SessionStorePublishState(isPublishScheduled: true)),
            try row(
                id: "scheduled-with-redacted-silence-summary",
                state: SessionStorePublishState(silenceSnapshot: silenceSnapshot(), isPublishScheduled: true)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testPublishStateSummarizesSilenceSnapshotAndScheduledPublishWithoutRuleDetails() throws {
        let state = SessionStorePublishState(
            silenceSnapshot: SilenceRulesSnapshot(
                disabledBuiltInIds: ["activity"],
                customRules: [
                    SilenceRule(
                        id: "custom-codex",
                        enabled: true,
                        matcher: SilenceMatcher(scope: .agent, target: "codex"),
                        action: SilenceAction(suppressesPeek: true, suppressesSound: false),
                        createdAt: "2026-07-09T01:50:00Z"
                    )
                ]
            ),
            isPublishScheduled: true
        )

        let summary = state.diagnosticSummary
        let encoded = String(data: try JSONEncoder().encode(summary), encoding: .utf8) ?? ""

        XCTAssertTrue(summary.hasSilenceSnapshot)
        XCTAssertTrue(summary.isPublishScheduled)
        XCTAssertEqual(summary.disabledBuiltInRuleCount, 1)
        XCTAssertEqual(summary.customSilenceRuleCount, 1)
        XCTAssertFalse(encoded.contains("activity"))
        XCTAssertFalse(encoded.contains("custom-codex"))
        XCTAssertFalse(encoded.contains("codex"))
        XCTAssertFalse(encoded.contains("2026-07-09T01:50:00Z"))
    }

    private func silenceSnapshot() -> SilenceRulesSnapshot {
        SilenceRulesSnapshot(
            disabledBuiltInIds: ["activity", "completion"],
            customRules: [
                SilenceRule(
                    id: "custom-codex",
                    enabled: true,
                    matcher: SilenceMatcher(scope: .agent, target: "codex"),
                    action: SilenceAction(suppressesPeek: true, suppressesSound: false),
                    createdAt: "2026-07-09T01:50:00Z"
                ),
                SilenceRule(
                    id: "custom-workspace",
                    enabled: true,
                    matcher: SilenceMatcher(scope: .workspace, target: "/tmp/project"),
                    action: SilenceAction(suppressesPeek: false, suppressesSound: true),
                    createdAt: "2026-07-09T02:00:00Z"
                ),
            ]
        )
    }

    private func row(id: String, state: SessionStorePublishState) throws -> SessionStorePublishStateMatrixRow {
        let encodedSummary = String(data: try JSONEncoder().encode(state.diagnosticSummary), encoding: .utf8) ?? ""
        let sensitiveTokens = [
            "activity",
            "completion",
            "custom-codex",
            "custom-workspace",
            "codex",
            "/tmp/project",
            "2026-07-09T01:50:00Z",
            "2026-07-09T02:00:00Z",
        ]

        return SessionStorePublishStateMatrixRow(
            id: id,
            hasSilenceSnapshot: state.silenceSnapshot != nil,
            isPublishScheduled: state.isPublishScheduled,
            summary: state.diagnosticSummary,
            diagnosticSummaryLeaksSensitiveTokens: sensitiveTokens.contains { encodedSummary.contains($0) }
        )
    }

    private struct SessionStorePublishStateMatrixFixture: Codable, Equatable {
        let rows: [SessionStorePublishStateMatrixRow]
    }

    private struct SessionStorePublishStateMatrixRow: Codable, Equatable {
        let id: String
        let hasSilenceSnapshot: Bool
        let isPublishScheduled: Bool
        let summary: SessionStorePublishSummary
        let diagnosticSummaryLeaksSensitiveTokens: Bool
    }
}
