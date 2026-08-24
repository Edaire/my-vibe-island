import XCTest
@testable import MyVibeIslandCore

final class SessionSummaryTelemetryModelsTests: XCTestCase {
    func testSessionSummaryTelemetryMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SessionSummaryTelemetryMatrixFixture.self,
            from: try FixtureLoader.data("runtime/session-summary-telemetry-matrix")
        )

        let actual = SessionSummaryTelemetryMatrixFixture(rows: [
            row(id: "default-local-redacted", telemetry: SessionSummaryTelemetry(
                sessionId: "session-1",
                agentSource: "codex"
            )),
            row(id: "completed-remote-team-medium", telemetry: SessionSummaryTelemetry(
                sessionId: "session-1",
                agentSource: "codex",
                modelFamily: "gpt",
                permissionMode: "plan",
                everBypassed: true,
                codexReviewer: "reviewer",
                surface: "terminal",
                codexOrigin: "cli",
                multiplexer: "tmux",
                isSSHRemote: true,
                isTeamMember: true,
                durationSeconds: 125,
                turnCount: 7,
                toolUseCount: 12,
                taskCount: 3,
                approvalCount: 2,
                subagentCount: 4,
                status: .completed,
                completionOutcome: .succeeded,
                redactionLevel: .metadataOnly
            )),
            row(id: "negative-counts-clamped-high", telemetry: SessionSummaryTelemetry(
                sessionId: "session-1",
                agentSource: "codex",
                durationSeconds: -10,
                turnCount: -1,
                toolUseCount: 101,
                taskCount: -2,
                approvalCount: -3,
                subagentCount: -4
            )),
            row(id: "hour-long-failed-ide", telemetry: SessionSummaryTelemetry(
                sessionId: "session-2",
                agentSource: "claude",
                claudeOrigin: "desktop",
                isIDEExtension: true,
                wasRestored: true,
                durationSeconds: 3_600,
                turnCount: 1,
                status: .failed,
                completionOutcome: .failed,
                redactionLevel: .redacted
            )),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testSessionSummaryTelemetryRoundTripsObservedFieldsAndBuckets() throws {
        let telemetry = SessionSummaryTelemetry(
            sessionId: "session-1",
            agentSource: "codex",
            modelFamily: "gpt",
            permissionMode: "plan",
            everBypassed: true,
            codexReviewer: "reviewer",
            surface: "terminal",
            codexOrigin: "cli",
            claudeOrigin: nil,
            multiplexer: "tmux",
            isSSHRemote: true,
            isIDEExtension: false,
            isTeamMember: true,
            wasRestored: false,
            durationSeconds: 125,
            turnCount: 7,
            toolUseCount: 12,
            taskCount: 3,
            approvalCount: 2,
            subagentCount: 4,
            status: .completed,
            completionOutcome: .succeeded,
            redactionLevel: .metadataOnly
        )

        let data = try JSONEncoder().encode(telemetry)
        let decoded = try JSONDecoder().decode(SessionSummaryTelemetry.self, from: data)

        XCTAssertEqual(decoded, telemetry)
        XCTAssertEqual(decoded.source, "codex")
        XCTAssertEqual(decoded.durationBucket, .minutes)
        XCTAssertEqual(decoded.eventCountBucket, .medium)
    }

    func testSessionSummaryTelemetryClampsCountsAndDerivesBuckets() {
        let telemetry = SessionSummaryTelemetry(
            sessionId: "session-1",
            agentSource: "codex",
            durationSeconds: -10,
            turnCount: -1,
            toolUseCount: 101,
            taskCount: -2,
            approvalCount: -3,
            subagentCount: -4
        )

        XCTAssertEqual(telemetry.durationSeconds, 0)
        XCTAssertEqual(telemetry.turnCount, 0)
        XCTAssertEqual(telemetry.toolUseCount, 101)
        XCTAssertEqual(telemetry.taskCount, 0)
        XCTAssertEqual(telemetry.approvalCount, 0)
        XCTAssertEqual(telemetry.subagentCount, 0)
        XCTAssertEqual(telemetry.durationBucket, .instant)
        XCTAssertEqual(telemetry.eventCountBucket, .high)
    }

    func testSessionSummaryTelemetryDefaultsAreLocalAndRedacted() {
        let telemetry = SessionSummaryTelemetry(sessionId: "session-1", agentSource: "codex")

        XCTAssertEqual(telemetry.status, .unknown)
        XCTAssertEqual(telemetry.completionOutcome, .unknown)
        XCTAssertEqual(telemetry.redactionLevel, .metadataOnly)
        XCTAssertFalse(telemetry.isSSHRemote)
        XCTAssertFalse(telemetry.wasRestored)
    }

    private func row(
        id: String,
        telemetry: SessionSummaryTelemetry
    ) -> SessionSummaryTelemetryMatrixRow {
        SessionSummaryTelemetryMatrixRow(
            id: id,
            sessionId: telemetry.sessionId,
            source: telemetry.source,
            modelFamily: telemetry.modelFamily,
            permissionMode: telemetry.permissionMode,
            everBypassed: telemetry.everBypassed,
            codexReviewer: telemetry.codexReviewer,
            surface: telemetry.surface,
            codexOrigin: telemetry.codexOrigin,
            claudeOrigin: telemetry.claudeOrigin,
            multiplexer: telemetry.multiplexer,
            isSSHRemote: telemetry.isSSHRemote,
            isIDEExtension: telemetry.isIDEExtension,
            isTeamMember: telemetry.isTeamMember,
            wasRestored: telemetry.wasRestored,
            durationSeconds: telemetry.durationSeconds,
            durationBucket: telemetry.durationBucket.rawValue,
            eventCountBucket: telemetry.eventCountBucket.rawValue,
            turnCount: telemetry.turnCount,
            toolUseCount: telemetry.toolUseCount,
            taskCount: telemetry.taskCount,
            approvalCount: telemetry.approvalCount,
            subagentCount: telemetry.subagentCount,
            status: telemetry.status.rawValue,
            completionOutcome: telemetry.completionOutcome.rawValue,
            redactionLevel: telemetry.redactionLevel.rawValue
        )
    }

    private struct SessionSummaryTelemetryMatrixFixture: Codable, Equatable {
        let rows: [SessionSummaryTelemetryMatrixRow]
    }

    private struct SessionSummaryTelemetryMatrixRow: Codable, Equatable {
        let id: String
        let sessionId: String
        let source: String
        let modelFamily: String?
        let permissionMode: String?
        let everBypassed: Bool
        let codexReviewer: String?
        let surface: String?
        let codexOrigin: String?
        let claudeOrigin: String?
        let multiplexer: String?
        let isSSHRemote: Bool
        let isIDEExtension: Bool
        let isTeamMember: Bool
        let wasRestored: Bool
        let durationSeconds: Int
        let durationBucket: String
        let eventCountBucket: String
        let turnCount: Int
        let toolUseCount: Int
        let taskCount: Int
        let approvalCount: Int
        let subagentCount: Int
        let status: String
        let completionOutcome: String
        let redactionLevel: String
    }
}
