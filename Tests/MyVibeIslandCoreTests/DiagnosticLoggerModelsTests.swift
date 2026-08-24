import XCTest
@testable import MyVibeIslandCore

final class DiagnosticLoggerModelsTests: XCTestCase {
    func testDiagnosticLoggerModelsMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DiagnosticLoggerModelsMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/logger-models-matrix")
        )

        let states = [
            DiagnosticLogger.defaultState,
            DiagnosticLoggerState(
                logFileURL: "/Users/<user>/Library/Logs/MyVibeIsland/app.log",
                currentFileSize: 2_048,
                dateFormatIdentifier: "iso8601"
            ),
            DiagnosticLoggerState(
                logFileURL: "/Users/<user>/Library/Logs/MyVibeIsland/rotated.log",
                currentFileSize: 0,
                dateFormatIdentifier: "rfc3339"
            )
        ]
        let entries = [
            DiagnosticLogEntry(
                eventID: "runtime-warning",
                category: .runtime,
                severity: .warning,
                source: "bridge",
                redactedMessage: "bridge restart skipped while session active",
                redactedMetadata: [
                    "sessionCount": "2",
                    "cwd": "/Users/<user>/project"
                ],
                createdAt: "2026-07-08T10:15:00Z"
            ),
            DiagnosticLogEntry(
                eventID: "environment-info",
                category: .environment,
                severity: .info,
                source: "scanner",
                redactedMessage: "environment scan completed",
                redactedMetadata: [
                    "ready": "true",
                    "repairableIssues": "0"
                ],
                createdAt: "2026-07-08T10:16:00Z"
            ),
            DiagnosticLogEntry(
                eventID: "diagnostics-error",
                category: .diagnostics,
                severity: .error,
                source: "export",
                redactedMessage: "required diagnostic section missing",
                redactedMetadata: [
                    "section": "sessions-snapshot.txt"
                ],
                createdAt: "2026-07-08T10:17:00Z"
            )
        ]

        XCTAssertEqual(states, expected.states)
        XCTAssertEqual(entries, expected.entries)
        XCTAssertEqual(DiagnosticLogCategory.allFixtureCases, expected.categories)
        XCTAssertEqual(DiagnosticLogSeverity.allFixtureCases, expected.severities)
    }

    func testDiagnosticLoggerStateRoundTripsLocalObservedFields() throws {
        let state = DiagnosticLoggerState(
            logFileURL: "/Users/<user>/Library/Logs/MyVibeIsland/app.log",
            currentFileSize: 2_048,
            dateFormatIdentifier: "iso8601"
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(DiagnosticLoggerState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.logFileURL, "/Users/<user>/Library/Logs/MyVibeIsland/app.log")
        XCTAssertEqual(decoded.currentFileSize, 2_048)
        XCTAssertEqual(decoded.dateFormatIdentifier, "iso8601")
    }

    func testDiagnosticLogEntryRoundTripsRedactedFields() throws {
        let entry = DiagnosticLogEntry(
            eventID: "event-1",
            category: .runtime,
            severity: .warning,
            source: "bridge",
            redactedMessage: "bridge restart skipped while session active",
            redactedMetadata: [
                "sessionCount": "2",
                "cwd": "/Users/<user>/project"
            ],
            createdAt: "2026-07-08T10:15:00Z"
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(DiagnosticLogEntry.self, from: data)

        XCTAssertEqual(decoded, entry)
        XCTAssertEqual(decoded.category, .runtime)
        XCTAssertEqual(decoded.severity, .warning)
        XCTAssertEqual(decoded.redactedMetadata["cwd"], "/Users/<user>/project")
    }

    func testDiagnosticLoggerNamespaceDefaultsToEmptyLocalState() {
        XCTAssertEqual(DiagnosticLogger.defaultState.currentFileSize, 0)
        XCTAssertNil(DiagnosticLogger.defaultState.logFileURL)
        XCTAssertEqual(DiagnosticLogger.defaultState.dateFormatIdentifier, "iso8601")
    }

    private struct DiagnosticLoggerModelsMatrixFixture: Codable, Equatable {
        let states: [DiagnosticLoggerState]
        let entries: [DiagnosticLogEntry]
        let categories: [DiagnosticLogCategory]
        let severities: [DiagnosticLogSeverity]
    }
}

private extension DiagnosticLogCategory {
    static let allFixtureCases: [DiagnosticLogCategory] = [
        .runtime,
        .hooks,
        .environment,
        .diagnostics,
        .usage
    ]
}

private extension DiagnosticLogSeverity {
    static let allFixtureCases: [DiagnosticLogSeverity] = [
        .debug,
        .info,
        .warning,
        .error
    ]
}
