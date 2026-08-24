import XCTest
@testable import MyVibeIslandCore

final class SessionStoreMaintenanceStateTests: XCTestCase {
    func testSessionStoreMaintenanceStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SessionStoreMaintenanceStateMatrixFixture.self,
            from: try FixtureLoader.data("runtime/session-store-maintenance-state-matrix")
        )

        let actual = SessionStoreMaintenanceStateMatrixFixture(rows: [
            try row(id: "default-empty-state", state: SessionStoreMaintenanceState()),
            try row(
                id: "scheduled-refresh-state-redacts-identifiers",
                state: populatedState(parseDebounceDelayMillis: 250)
            ),
            try row(
                id: "negative-delay-is-clamped",
                state: populatedState(parseDebounceDelayMillis: -10)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testMaintenanceStateTracksParseWriteAndRefreshStateWithoutLeakingIdentifiers() throws {
        let parseTask = EventSchedulerTask(
            id: "debounce:parse:/tmp/project:1250",
            key: "parse:/tmp/project",
            kind: .debounce,
            dueAtMillis: 1_250,
            sourceId: "codex",
            sessionId: "session-1"
        )
        let writeTask = EventSchedulerTask(
            id: "debounce:metadata:session-2:1500",
            key: "metadata:session-2",
            kind: .debounce,
            dueAtMillis: 1_500,
            sourceId: "codex",
            sessionId: "session-2"
        )

        let state = SessionStoreMaintenanceState(
            hasConfiguredGhosttyEnv: true,
            hasConfiguredCmuxSocket: true,
            pendingParseRequests: [
                SessionParseRequest(id: "parse-1", sessionId: "session-1", rootPath: "/tmp/project")
            ],
            parseDebounceTask: parseTask,
            parseDebounceDelayMillis: 250,
            metadataWriteTask: writeTask,
            refreshingSessionIds: ["session-1", "session-3", "session-1"],
            refreshingCodexTitleSessionIds: ["session-2"]
        )

        XCTAssertEqual(state.refreshingSessionIds, ["session-1", "session-3"])
        XCTAssertEqual(state.refreshingCodexTitleSessionIds, ["session-2"])

        let summary = state.diagnosticSummary
        let encoded = String(data: try JSONEncoder().encode(summary), encoding: .utf8) ?? ""

        XCTAssertTrue(summary.hasConfiguredGhosttyEnv)
        XCTAssertTrue(summary.hasConfiguredCmuxSocket)
        XCTAssertEqual(summary.pendingParseRequestCount, 1)
        XCTAssertTrue(summary.hasParseDebounceTask)
        XCTAssertEqual(summary.parseDebounceDelayMillis, 250)
        XCTAssertTrue(summary.hasMetadataWriteTask)
        XCTAssertEqual(summary.refreshingSessionCount, 2)
        XCTAssertEqual(summary.refreshingCodexTitleSessionCount, 1)

        XCTAssertFalse(encoded.contains("session-1"))
        XCTAssertFalse(encoded.contains("session-2"))
        XCTAssertFalse(encoded.contains("session-3"))
        XCTAssertFalse(encoded.contains("/tmp/project"))
        XCTAssertFalse(encoded.contains("parse-1"))
    }

    private func populatedState(parseDebounceDelayMillis: Int) -> SessionStoreMaintenanceState {
        SessionStoreMaintenanceState(
            hasConfiguredGhosttyEnv: true,
            hasConfiguredCmuxSocket: true,
            pendingParseRequests: [
                SessionParseRequest(id: "parse-b", sessionId: "session-3", rootPath: "/tmp/b"),
                SessionParseRequest(id: "parse-a", sessionId: "session-1", rootPath: "/tmp/a"),
            ],
            parseDebounceTask: EventSchedulerTask(
                id: "debounce:parse:/tmp/project:1250",
                key: "parse:/tmp/project",
                kind: .debounce,
                dueAtMillis: 1_250,
                sourceId: "codex",
                sessionId: "session-1"
            ),
            parseDebounceDelayMillis: parseDebounceDelayMillis,
            metadataWriteTask: EventSchedulerTask(
                id: "debounce:metadata:session-2:1500",
                key: "metadata:session-2",
                kind: .debounce,
                dueAtMillis: 1_500,
                sourceId: "codex",
                sessionId: "session-2"
            ),
            refreshingSessionIds: ["session-3", "session-1", "session-1"],
            refreshingCodexTitleSessionIds: ["session-2", "session-2"]
        )
    }

    private func row(id: String, state: SessionStoreMaintenanceState) throws -> SessionStoreMaintenanceStateMatrixRow {
        let encodedSummary = String(data: try JSONEncoder().encode(state.diagnosticSummary), encoding: .utf8) ?? ""
        let sensitiveTokens = [
            "session-1",
            "session-2",
            "session-3",
            "/tmp/a",
            "/tmp/b",
            "/tmp/project",
            "parse-a",
            "parse-b",
            "codex",
        ]

        return SessionStoreMaintenanceStateMatrixRow(
            id: id,
            pendingParseRequestIds: state.pendingParseRequests.map(\.id),
            parseDebounceDelayMillis: state.parseDebounceDelayMillis,
            refreshingSessionIds: state.refreshingSessionIds,
            refreshingCodexTitleSessionIds: state.refreshingCodexTitleSessionIds,
            summary: state.diagnosticSummary,
            diagnosticSummaryLeaksSensitiveTokens: sensitiveTokens.contains { encodedSummary.contains($0) }
        )
    }

    private struct SessionStoreMaintenanceStateMatrixFixture: Codable, Equatable {
        let rows: [SessionStoreMaintenanceStateMatrixRow]
    }

    private struct SessionStoreMaintenanceStateMatrixRow: Codable, Equatable {
        let id: String
        let pendingParseRequestIds: [String]
        let parseDebounceDelayMillis: Int
        let refreshingSessionIds: [String]
        let refreshingCodexTitleSessionIds: [String]
        let summary: SessionStoreMaintenanceSummary
        let diagnosticSummaryLeaksSensitiveTokens: Bool
    }
}
