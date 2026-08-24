import Foundation
import XCTest
@testable import MyVibeIslandCore

final class ClaudeTranscriptDiscoveryTests: XCTestCase {
    func testStartupDiscoveryUsesProvenClaudeProjectsPathAndEmitsMetadataOnly() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectRoot = home.appendingPathComponent(".claude/projects/project")
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let transcript = projectRoot.appendingPathComponent("session-1.jsonl")
        try "{\"sessionId\":\"session-1\",\"cwd\":\"/tmp/project\",\"message\":\"secret\"}\n".write(to: transcript, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }

        let result = ClaudeTranscriptDiscovery(homeDirectory: home).discover()

        XCTAssertEqual(result.map(\.sessionId), ["session-1"])
        XCTAssertEqual(result.first?.cwd, "/tmp/project")
        XCTAssertEqual(result.first?.agentEvents(), [
            .sessionStarted(source: "claude", sessionId: "session-1", cwd: "/tmp/project")
        ])
        XCTAssertFalse(result.first?.description.contains("secret") ?? true)
    }

    func testDiscoveryBoundsFileCountDepthAndFirstLineSize() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let shallow = root.appendingPathComponent("shallow")
        let deep = root.appendingPathComponent("deep/one/two")
        try FileManager.default.createDirectory(at: shallow, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        try "{\"sessionId\":\"small\",\"cwd\":\"/tmp/small\"}\n".write(to: shallow.appendingPathComponent("small.jsonl"), atomically: true, encoding: .utf8)
        try String(repeating: "x", count: 300).write(to: deep.appendingPathComponent("too-deep.jsonl"), atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        let result = ClaudeTranscriptDiscovery(
            rootURL: root,
            maximumFiles: 1,
            maximumDepth: 1,
            maximumFirstLineBytes: 128
        ).discover()

        XCTAssertEqual(result.map(\.sessionId), ["small"])
    }

    func testStopCancelsQueuedStartupDiscovery() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "{\"sessionId\":\"cancelled\",\"cwd\":\"/tmp/cancelled\"}\n".write(
            to: root.appendingPathComponent("session.jsonl"), atomically: true, encoding: .utf8
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let queue = DispatchQueue(label: "claude-test-queue")
        queue.suspend()
        let discovery = ClaudeTranscriptDiscovery(rootURL: root, queue: queue)
        let recorder = EventRecorder()

        discovery.start { recorder.append($0) }
        discovery.stop()
        queue.resume()
        Thread.sleep(forTimeInterval: 0.05)

        XCTAssertEqual(recorder.count, 0)
    }

    func testLargeTranscriptOnlyReadsBoundedFirstLine() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let firstLine = "{\"sessionId\":\"large\",\"cwd\":\"/tmp/large\"}\n"
        try (firstLine + String(repeating: "x", count: 2_000_000)).write(
            to: root.appendingPathComponent("large.jsonl"), atomically: true, encoding: .utf8
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        let result = ClaudeTranscriptDiscovery(rootURL: root).discover()

        XCTAssertEqual(result.map(\.sessionId), ["large"])
    }
}

private final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [AgentEvent] = []
    var count: Int { lock.lock(); defer { lock.unlock() }; return events.count }
    func append(_ event: AgentEvent) { lock.lock(); events.append(event); lock.unlock() }
}
