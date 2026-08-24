import Foundation
import XCTest
@testable import MyVibeIslandCore

final class LocalProcessSnapshotProviderTests: XCTestCase {
    func testCachedProviderReusesSnapshotUntilRefreshIntervalExpires() throws {
        let runner = SequencedPSRunner(outputs: [
            " 101 ttys001 /usr/bin/codex resume one\n",
            " 202 ttys002 /usr/bin/codex resume two\n",
        ])
        let clock = MutableDateClock(Date(timeIntervalSince1970: 1_000))
        let provider = CachedLocalProcessSnapshotProvider(
            provider: LocalProcessSnapshotProvider(runner: runner),
            minimumRefreshInterval: 5,
            now: clock.now
        )

        XCTAssertEqual(try provider.snapshot().map(\.pid), [101])
        clock.advance(by: 4.9)
        XCTAssertEqual(try provider.snapshot().map(\.pid), [101])
        XCTAssertEqual(runner.callCount, 1)

        clock.advance(by: 0.1)
        XCTAssertEqual(try provider.snapshot().map(\.pid), [202])
        XCTAssertEqual(runner.callCount, 2)
    }

    func testUsesFixedPSArgumentsAndParsesRows() throws {
        let runner = RecordingPSRunner(output: " 101 ttys001 /usr/bin/codex --cwd /tmp/a\n 202 ?? /usr/bin/claude\n")
        let provider = LocalProcessSnapshotProvider(runner: runner)

        let rows = try provider.snapshot()

        XCTAssertEqual(runner.executable, "/bin/ps")
        XCTAssertEqual(runner.arguments, ["-axo", "pid=,tty=,command="])
        XCTAssertEqual(rows, [
            LocalProcessSnapshot(pid: 101, tty: "ttys001", command: "/usr/bin/codex --cwd /tmp/a"),
            LocalProcessSnapshot(pid: 202, tty: "??", command: "/usr/bin/claude")
        ])
    }

    func testProcessOnlyCandidateDoesNotCreateSessionWithoutCorrelation() throws {
        let candidate = ProcessOnlyAgentCandidate(source: "codex", pid: 101, cwd: "/tmp/a", processName: "codex")
        let result = AgentProcessCorrelator().correlate(candidate: candidate, sessions: [])

        XCTAssertNil(result)
    }

    func testExplicitMismatchedSessionIdDoesNotFallbackToMatchingCWD() {
        let candidate = ProcessOnlyAgentCandidate(
            source: "codex",
            sessionId: "missing-session",
            pid: 101,
            cwd: "/tmp/a",
            processName: "codex"
        )
        let sessions = [AgentSession(id: "known-session", source: "codex", cwd: "/tmp/a")]

        XCTAssertNil(AgentProcessCorrelator().correlate(candidate: candidate, sessions: sessions))
    }

    func testMissingSessionIdWithAmbiguousCWDFailsClosed() {
        let candidate = ProcessOnlyAgentCandidate(source: "codex", pid: 101, cwd: "/tmp/a", processName: "codex")
        let sessions = [
            AgentSession(id: "session-a", source: "codex", cwd: "/tmp/a"),
            AgentSession(id: "session-b", source: "codex", cwd: "/tmp/a"),
        ]

        XCTAssertNil(AgentProcessCorrelator().correlate(candidate: candidate, sessions: sessions))
    }

    func testBatchCorrelationRejectsDuplicateProcessMappings() {
        let candidates = [
            ProcessOnlyAgentCandidate(source: "codex", sessionId: "session-a", pid: 101),
            ProcessOnlyAgentCandidate(source: "codex", sessionId: "session-a", pid: 102),
        ]
        let sessions = [AgentSession(id: "session-a", source: "codex", cwd: "/tmp/a")]

        XCTAssertEqual(AgentProcessCorrelator().correlate(candidates: candidates, sessions: sessions), [])
    }

    func testSystemRunnerBoundsConcurrentStdoutAndStderr() {
        let runner = SystemLocalProcessSnapshotRunner()

        XCTAssertThrowsError(try runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "(yes o | head -c 200000) & (yes e | head -c 200000 >&2) & wait"],
            timeout: 2,
            maximumOutputBytes: 4_096
        )) { error in
            XCTAssertEqual(error as? LocalProcessSnapshotError, .outputLimitExceeded)
        }
    }

    func testSystemRunnerTerminatesTimedOutProcess() {
        let runner = SystemLocalProcessSnapshotRunner()

        XCTAssertThrowsError(try runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "sleep 5"],
            timeout: 0.05,
            maximumOutputBytes: 4_096
        )) { error in
            XCTAssertEqual(error as? LocalProcessSnapshotError, .timedOut)
        }
    }

    func testLaunchFailureDoesNotLeakPipeFileDescriptors() throws {
        let runner = SystemLocalProcessSnapshotRunner()
        let before = try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count

        for _ in 0..<20 {
            XCTAssertThrowsError(try runner.run(
                executable: "/definitely/missing/process",
                arguments: [],
                timeout: 0.05,
                maximumOutputBytes: 4_096
            ))
        }

        let after = try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
        XCTAssertLessThanOrEqual(after - before, 2)
    }
}

private final class RecordingPSRunner: LocalProcessSnapshotRunning, @unchecked Sendable {
    let output: String
    var executable: String?
    var arguments: [String]?
    init(output: String) { self.output = output }
    func run(executable: String, arguments: [String]) throws -> String {
        self.executable = executable
        self.arguments = arguments
        return output
    }
}

private final class SequencedPSRunner: LocalProcessSnapshotRunning, @unchecked Sendable {
    private var outputs: [String]
    private(set) var callCount = 0

    init(outputs: [String]) {
        self.outputs = outputs
    }

    func run(executable: String, arguments: [String]) throws -> String {
        callCount += 1
        return outputs.removeFirst()
    }
}

private final class MutableDateClock: @unchecked Sendable {
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    func now() -> Date {
        value
    }

    func advance(by interval: TimeInterval) {
        value = value.addingTimeInterval(interval)
    }
}
