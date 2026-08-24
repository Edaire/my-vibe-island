import XCTest
@testable import MyVibeIslandCore

final class AppRuntimeWatcherLifecycleTests: XCTestCase {
    func testStartupDoesNotImportHistoricalClaudeProjectTranscripts() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectRoot = home.appendingPathComponent(".claude/projects/old-project")
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        try Data("{\"sessionId\":\"historical-claude\",\"cwd\":\"/tmp/old\"}\n".utf8)
            .write(to: projectRoot.appendingPathComponent("historical-claude.jsonl"))
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }

        let runtime = AppRuntime(localWatcherHomeDirectory: home)
        defer { runtime.stop() }
        runtime.startLocalSessionWatchers()
        Thread.sleep(forTimeInterval: 0.2)

        XCTAssertNil(runtime.sessionSnapshot(sessionId: "historical-claude"))
    }

    func testStartLocalSessionWatchersWithoutArgumentUsesInjectedHomeDirectory() {
        let injectedHome = URL(fileURLWithPath: "/tmp/my-vibe-island-injected-home-\(UUID().uuidString)")
        let runtime = AppRuntime(localWatcherHomeDirectory: injectedHome)
        defer { runtime.stop() }

        runtime.startLocalSessionWatchers()

        XCTAssertTrue(runtime.areLocalSessionWatchersRunning)
    }

    func testCodexWatcherDoesNotAdmitRolloutWithoutLiveHookEvidence() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = home.appendingPathComponent(".codex/sessions")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }

        for index in 0..<16 {
            let sessionID = "codex-\(index)"
            let rollout = root.appendingPathComponent("rollout-\(index).jsonl")
            let contents = """
            {"timestamp":"2026-07-17T08:00:00.000Z","type":"session_meta","payload":{"id":"\(sessionID)","cwd":"/tmp/\(sessionID)"}}
            {"timestamp":"2026-07-17T08:00:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"message \(index)"}}

            """
            try Data(contents.utf8).write(to: rollout)
            try FileManager.default.setAttributes(
                [.modificationDate: Date().addingTimeInterval(Double(index - 16))],
                ofItemAtPath: rollout.path
            )
        }

        let runtime = AppRuntime(localWatcherHomeDirectory: home)
        defer { runtime.stop() }
        runtime.startLocalSessionWatchers()

        Thread.sleep(forTimeInterval: 0.2)

        for index in 0..<16 {
            XCTAssertNil(runtime.sessionSnapshot(sessionId: "codex-\(index)"))
        }
    }

    func testCoworkWatcherPublishesOnlyLocalAgentModeSessionAuditContent() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = home.appendingPathComponent("Library/Application Support/Claude/local-agent-mode-sessions")
        let sessionDirectory = root.appendingPathComponent("_local-session-1", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        try Data("{\"title\":\"Fix parser\",\"cwd\":\"/tmp/project\"}".utf8)
            .write(to: root.appendingPathComponent("_local-session-1.json"))
        try Data("{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"Fix it\"}}\n".utf8)
            .write(to: sessionDirectory.appendingPathComponent("audit.log"))
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }

        let runtime = AppRuntime(localWatcherHomeDirectory: home)
        defer { runtime.stop() }
        runtime.startLocalSessionWatchers()

        let deadline = Date().addingTimeInterval(2)
        while runtime.sessionSnapshot(sessionId: "cowork--session-1") == nil, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }

        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "cowork--session-1")?.source, "claude")
        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "cowork--session-1")?.lastUserMessage, "Fix it")
    }
}
