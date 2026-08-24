import XCTest
@testable import MyVibeIslandCore

final class ProcessOnlyAgentCandidateTests: XCTestCase {
    func testProcessOnlyAgentCandidateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ProcessOnlyAgentCandidateMatrixFixture.self,
            from: try FixtureLoader.data("agents/process-only-agent-candidate-matrix")
        )

        let actual = ProcessOnlyAgentCandidateMatrixFixture(rows: [
            row(id: "observed-design-fields", candidate: ProcessOnlyAgentCandidate(
                source: "codex",
                sessionId: "session-1",
                pid: 4242,
                tty: "/dev/ttys001",
                cwd: "/tmp/project",
                bundleIdentifier: "com.googlecode.iterm2",
                command: "codex --ask",
                processName: "codex",
                executablePath: "/opt/homebrew/bin/codex",
                detectedAgentKind: "codex-cli",
                confidence: 0.75,
                observedAt: "2026-07-08T20:00:00Z"
            )),
            row(id: "confidence-low-clamped", candidate: ProcessOnlyAgentCandidate(
                source: "codex",
                pid: 1,
                confidence: -1.0
            )),
            row(id: "confidence-high-clamped", candidate: ProcessOnlyAgentCandidate(
                source: "codex",
                pid: 2,
                confidence: 2.0
            )),
            row(id: "detected-only-minimal", candidate: ProcessOnlyAgentCandidate(
                source: "codex",
                sessionId: "session-1",
                pid: 4242,
                tty: "/dev/ttys001"
            )),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testProcessOnlyAgentCandidateRoundTripsObservedAndDesignFields() throws {
        let candidate = ProcessOnlyAgentCandidate(
            source: "codex",
            sessionId: "session-1",
            pid: 4242,
            tty: "/dev/ttys001",
            cwd: "/tmp/project",
            bundleIdentifier: "com.googlecode.iterm2",
            command: "codex --ask",
            processName: "codex",
            executablePath: "/opt/homebrew/bin/codex",
            detectedAgentKind: "codex-cli",
            confidence: 0.75,
            observedAt: "2026-07-08T20:00:00Z"
        )

        let data = try JSONEncoder().encode(candidate)
        let decoded = try JSONDecoder().decode(ProcessOnlyAgentCandidate.self, from: data)

        XCTAssertEqual(decoded, candidate)
        XCTAssertEqual(decoded.source, "codex")
        XCTAssertEqual(decoded.sessionId, "session-1")
        XCTAssertEqual(decoded.pid, 4242)
        XCTAssertEqual(decoded.bundleIdentifier, "com.googlecode.iterm2")
    }

    func testProcessOnlyAgentCandidateClampsConfidence() {
        let low = ProcessOnlyAgentCandidate(source: "codex", pid: 1, confidence: -1.0)
        let high = ProcessOnlyAgentCandidate(source: "codex", pid: 2, confidence: 2.0)

        XCTAssertEqual(low.confidence, 0.0)
        XCTAssertEqual(high.confidence, 1.0)
    }

    func testProcessOnlyAgentCandidateRemainsDetectedOnly() {
        let candidate = ProcessOnlyAgentCandidate(
            source: "codex",
            sessionId: "session-1",
            pid: 4242,
            tty: "/dev/ttys001"
        )

        XCTAssertTrue(candidate.isDetectedOnly)
        XCTAssertFalse(candidate.canCreateSessionWithoutCorrelation)
    }

    func testProcessOnlyAgentCandidateBuildsDeterministicCorrelationHints() {
        let candidate = ProcessOnlyAgentCandidate(
            source: "codex",
            sessionId: "session-1",
            pid: 4242,
            tty: "/dev/ttys001",
            cwd: "/tmp/project",
            bundleIdentifier: "com.googlecode.iterm2",
            command: "codex --ask"
        )

        XCTAssertEqual(candidate.correlationHints, [
            ProcessOnlyAgentCorrelationHint(kind: "bundleIdentifier", value: "com.googlecode.iterm2"),
            ProcessOnlyAgentCorrelationHint(kind: "cwd", value: "/tmp/project"),
            ProcessOnlyAgentCorrelationHint(kind: "pid", value: "4242"),
            ProcessOnlyAgentCorrelationHint(kind: "sessionId", value: "session-1"),
            ProcessOnlyAgentCorrelationHint(kind: "source", value: "codex"),
            ProcessOnlyAgentCorrelationHint(kind: "tty", value: "/dev/ttys001")
        ])
    }

    private func row(
        id: String,
        candidate: ProcessOnlyAgentCandidate
    ) -> ProcessOnlyAgentCandidateMatrixRow {
        ProcessOnlyAgentCandidateMatrixRow(
            id: id,
            source: candidate.source,
            sessionId: candidate.sessionId,
            pid: candidate.pid,
            tty: candidate.tty,
            cwd: candidate.cwd,
            bundleIdentifier: candidate.bundleIdentifier,
            command: candidate.command,
            processName: candidate.processName,
            executablePath: candidate.executablePath,
            detectedAgentKind: candidate.detectedAgentKind,
            confidence: candidate.confidence,
            observedAt: candidate.observedAt,
            isDetectedOnly: candidate.isDetectedOnly,
            canCreateSessionWithoutCorrelation: candidate.canCreateSessionWithoutCorrelation,
            correlationHints: candidate.correlationHints.map {
                ProcessOnlyAgentCandidateHintFixture(kind: $0.kind, value: $0.value)
            }
        )
    }

    private struct ProcessOnlyAgentCandidateMatrixFixture: Codable, Equatable {
        let rows: [ProcessOnlyAgentCandidateMatrixRow]
    }

    private struct ProcessOnlyAgentCandidateMatrixRow: Codable, Equatable {
        let id: String
        let source: String
        let sessionId: String?
        let pid: Int
        let tty: String?
        let cwd: String?
        let bundleIdentifier: String?
        let command: String?
        let processName: String?
        let executablePath: String?
        let detectedAgentKind: String?
        let confidence: Double
        let observedAt: String?
        let isDetectedOnly: Bool
        let canCreateSessionWithoutCorrelation: Bool
        let correlationHints: [ProcessOnlyAgentCandidateHintFixture]
    }

    private struct ProcessOnlyAgentCandidateHintFixture: Codable, Equatable {
        let kind: String
        let value: String
    }
}
