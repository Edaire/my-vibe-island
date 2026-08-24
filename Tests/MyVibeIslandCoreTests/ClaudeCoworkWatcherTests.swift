import Foundation
import XCTest
@testable import MyVibeIslandCore

final class ClaudeCoworkWatcherTests: XCTestCase {
    func testRefreshPublishesStartAndActivityForNewSession() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let metadataURL = root.appendingPathComponent("_local-session-1.json")
        let auditDirectory = root.appendingPathComponent("_local-session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        let auditURL = auditDirectory.appendingPathComponent("audit.log")
        try write("{\"title\":\"Fix parser\",\"cwd\":\"/tmp/project\"}", to: metadataURL)
        try write("{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"Fix it\"}}\n", to: auditURL)

        let watcher = ClaudeCoworkWatcher(
            discovery: ClaudeCoworkSessionDiscovery(rootURL: root),
            timing: .init(maximumAuditBytes: 4_096)
        )

        let events = try watcher.refresh()

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0], .sessionStarted(source: "claude", sessionId: "cowork--session-1", cwd: "/tmp/project"))
        guard case let .sessionActivityUpdated(source, sessionId, activity) = events[1] else {
            return XCTFail("expected activity update")
        }
        XCTAssertEqual(source, "claude")
        XCTAssertEqual(sessionId, "cowork--session-1")
        XCTAssertEqual(activity.status, .active)
        XCTAssertEqual(activity.originalStatus, .processing)
        XCTAssertEqual(activity.safeTitle, "Fix parser")
        XCTAssertEqual(activity.cliSessionId, nil)
        XCTAssertEqual(activity.lastUserMessage, "Fix it")
        XCTAssertEqual(activity.summary, "Fix it")
    }

    func testRefreshDoesNotRepublishAnUnchangedTail() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("{\"title\":\"Fix parser\",\"cwd\":\"/tmp/project\"}", to: root.appendingPathComponent("_local-session-1.json"))
        let auditDirectory = root.appendingPathComponent("_local-session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        try write("{\"type\":\"result\",\"result\":\"done\",\"isError\":false}\n", to: auditDirectory.appendingPathComponent("audit.log"))

        let watcher = ClaudeCoworkWatcher(discovery: ClaudeCoworkSessionDiscovery(rootURL: root))

        XCTAssertEqual(try watcher.refresh().count, 2)
        XCTAssertTrue(try watcher.refresh().isEmpty)
    }

    func testResultMapsToOriginalWarningStateWithoutSyntheticCompletion() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("{\"title\":\"Broken parser\",\"cwd\":\"/tmp/project\"}", to: root.appendingPathComponent("_local-session-1.json"))
        let auditDirectory = root.appendingPathComponent("_local-session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        try write("{\"type\":\"result\",\"result\":\"failed\",\"isError\":true}\n", to: auditDirectory.appendingPathComponent("audit.log"))

        let watcher = ClaudeCoworkWatcher(discovery: ClaudeCoworkSessionDiscovery(rootURL: root))
        let events = try watcher.refresh()

        guard case let .sessionActivityUpdated(_, _, activity) = events.last else {
            return XCTFail("expected activity update")
        }
        XCTAssertEqual(activity.status, .idle)
        XCTAssertEqual(activity.originalStatus, .waitingForInput)
        XCTAssertEqual(activity.lastAssistantMessage, "failed")
        XCTAssertFalse(activity.hasUnreadCompletion)
    }

    func testAskUserQuestionMapsToWaitingAttentionState() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("{\"title\":\"Choose parser\",\"cwd\":\"/tmp/project\"}", to: root.appendingPathComponent("_local-session-1.json"))
        let auditDirectory = root.appendingPathComponent("_local-session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        try write("""
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Choose one"},{"type":"tool_use","name":"AskUserQuestion","input":{"question":"Which?","options":["A","B"]}}]}}
        """ + "\n", to: auditDirectory.appendingPathComponent("audit.log"))

        let watcher = ClaudeCoworkWatcher(discovery: ClaudeCoworkSessionDiscovery(rootURL: root))
        let events = try watcher.refresh()

        guard case let .sessionActivityUpdated(_, _, activity) = events.last else {
            return XCTFail("expected activity update")
        }
        XCTAssertEqual(activity.status, .waiting)
        XCTAssertEqual(activity.originalStatus, .question)
        XCTAssertTrue(activity.needsAttention)
        XCTAssertEqual(activity.activeTool, "AskUserQuestion")
        XCTAssertEqual(
            activity.toolInput,
            [
                "question": .string("Which?"),
                "options": .array([.string("A"), .string("B")]),
            ]
        )
        XCTAssertEqual(activity.lastAssistantMessage, "Choose one")
    }

    func testAskUserQuestionProjectsPromptIntoSessionPresentation() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("{\"title\":\"Choose parser\",\"cwd\":\"/tmp/project\"}", to: root.appendingPathComponent("_local-session-1.json"))
        let auditDirectory = root.appendingPathComponent("_local-session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        try write("""
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"AskUserQuestion","input":{"question":"Which parser?","options":["A","B"]}}]}}
        """ + "\n", to: auditDirectory.appendingPathComponent("audit.log"))

        let watcher = ClaudeCoworkWatcher(discovery: ClaudeCoworkSessionDiscovery(rootURL: root))
        let coordinator = SessionCoordinator()
        for event in try watcher.refresh() {
            coordinator.apply(event)
        }

        let session = try XCTUnwrap(coordinator.snapshot(sessionId: "cowork--session-1"))
        XCTAssertEqual(session.agentSession().questionPrompt, "Which parser?")
        XCTAssertTrue(session.agentSession().actionableRequests.isEmpty)
    }

    func testStaleNonResultUsesOriginalWarningState() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("{\"title\":\"Old parser\",\"cwd\":\"/tmp/project\"}", to: root.appendingPathComponent("_local-session-1.json"))
        let auditDirectory = root.appendingPathComponent("_local-session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        try write("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":\"Still working\"},\"auditTimestamp\":\"2026-07-20T00:00:00Z\"}\n", to: auditDirectory.appendingPathComponent("audit.log"))

        let watcher = ClaudeCoworkWatcher(
            discovery: ClaudeCoworkSessionDiscovery(rootURL: root),
            now: { ISO8601DateFormatter().date(from: "2026-07-20T00:01:00Z")! }
        )

        guard case let .sessionActivityUpdated(_, _, activity) = try watcher.refresh().last else {
            return XCTFail("expected activity update")
        }
        XCTAssertEqual(activity.status, .idle)
        XCTAssertEqual(activity.originalStatus, .waitingForInput)
    }

    func testArchivedMetadataRemovesExistingCoworkSession() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let metadataURL = root.appendingPathComponent("_local-session-1.json")
        let auditDirectory = root.appendingPathComponent("_local-session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        try write("{\"title\":\"Fix parser\",\"cwd\":\"/tmp/project\"}", to: metadataURL)
        try write("{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"Fix it\"}}\n", to: auditDirectory.appendingPathComponent("audit.log"))
        let watcher = ClaudeCoworkWatcher(discovery: ClaudeCoworkSessionDiscovery(rootURL: root))
        _ = try watcher.refresh()

        try write("{\"title\":\"Fix parser\",\"cwd\":\"/tmp/project\",\"isArchived\":true}", to: metadataURL)

        XCTAssertEqual(
            try watcher.refresh(),
            [.sessionEnded(source: "claude", sessionId: "cowork--session-1")]
        )
    }

    func testEmptyCoworkTurnDoesNotInventActivitySummary() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("{\"title\":\"Fix parser\",\"cwd\":\"/tmp/project\"}", to: root.appendingPathComponent("_local-session-1.json"))
        let auditDirectory = root.appendingPathComponent("_local-session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        try write("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":\"\"}}\n", to: auditDirectory.appendingPathComponent("audit.log"))

        let watcher = ClaudeCoworkWatcher(discovery: ClaudeCoworkSessionDiscovery(rootURL: root))

        guard case let .sessionActivityUpdated(_, _, activity) = try watcher.refresh().last else {
            return XCTFail("expected activity update")
        }
        XCTAssertNil(activity.summary)
    }

    func testCoworkMetadataCarriesCliSessionId() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("{\"title\":\"Fix parser\",\"cwd\":\"/tmp/project\",\"cliSessionId\":\"cli-42\"}", to: root.appendingPathComponent("_local-session-1.json"))
        let auditDirectory = root.appendingPathComponent("_local-session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
        try write("{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"Fix it\"}}\n", to: auditDirectory.appendingPathComponent("audit.log"))

        let watcher = ClaudeCoworkWatcher(discovery: ClaudeCoworkSessionDiscovery(rootURL: root))
        guard case let .sessionActivityUpdated(_, _, activity) = try watcher.refresh().last else {
            return XCTFail("expected activity update")
        }
        XCTAssertEqual(activity.cliSessionId, "cli-42")
    }

    private func write(_ string: String, to url: URL) throws {
        try Data(string.utf8).write(to: url)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-cowork-watcher-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
