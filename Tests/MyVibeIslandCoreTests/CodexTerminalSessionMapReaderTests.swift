import Foundation
import XCTest
@testable import MyVibeIslandCore

final class CodexTerminalSessionMapReaderTests: XCTestCase {
    func testReadsOriginalSessionTerminalsMapIntoRenderableCodexSessions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-terminal-map-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("session-terminals.json")
        try Data("""
        {
          "codex-019f36a7-b73f-7750-85db-081ea9257dbb": {
            "source": "codex",
            "status": "running_tool",
            "currentTool": "Bash",
            "toolTarget": "swift test",
            "cwd": "/repo/my-vibe-island",
            "firstUserMessage": "run tests",
            "lastUserMessage": "please verify",
            "lastAssistantMessage": "running focused tests",
            "lastAssistantMessageFull": "running focused tests\\nwith full output",
            "lastActivityAt": 806402514.762777,
            "bundleIdentifiers": ["com.apple.Terminal"],
            "gitIdentityStatus": "ok",
            "repoName": "my-vibe-island",
            "worktreeName": "feature",
            "gitBranch": "main",
            "termProgram": "tmux",
            "termSessionId": "TERM-1",
            "tty": "/dev/ttys016",
            "isInTmux": true,
            "tmuxPane": "%42",
            "tmuxSocketPath": "/private/tmp/tmux-502/default",
            "ottySocket": "/tmp/otty.sock",
            "ottyPaneId": "otty-pane",
            "codexNotifyThreadId": "019f36a7-b73f-7750-85db-081ea9257dbb",
            "codexRolloutPath": "/Users/admin/.codex/sessions/rollout.jsonl"
          },
          "codex-019f7e7c-6a11-7ab3-8a20-54d8164c5931": {
            "source": "codex",
            "status": "waiting_for_input",
            "cwd": "/repo/analysis",
            "lastUserMessage": "next question",
            "lastAssistantMessage": "answer",
            "lastActivityAt": 806402000.0,
            "tty": "/dev/ttys017"
          }
        }
        """.utf8).write(to: fileURL)

        let sessions = try CodexTerminalSessionMapReader(fileURL: fileURL).readSessions()

        XCTAssertEqual(sessions.map(\.sessionId), [
            "codex-019f36a7-b73f-7750-85db-081ea9257dbb",
            "codex-019f7e7c-6a11-7ab3-8a20-54d8164c5931",
        ])
        let running = try XCTUnwrap(sessions.first)
        XCTAssertEqual(running.source, "codex")
        XCTAssertEqual(running.cwd, "/repo/my-vibe-island")
        XCTAssertEqual(running.activeTool, "Bash")
        XCTAssertEqual(running.toolTarget, "swift test")
        XCTAssertEqual(running.lastAssistantMessage, "running focused tests\nwith full output")
        XCTAssertEqual(running.lastUserMessage, "please verify")
        XCTAssertEqual(
            running.agentSession().lastActivityAt,
            Date(timeIntervalSinceReferenceDate: 806402514.762777)
        )
        XCTAssertEqual(running.repoName, "my-vibe-island")
        XCTAssertEqual(running.originalStatus, .runningTool)
        XCTAssertEqual(running.jumpInput?.tty, "/dev/ttys016")
        XCTAssertEqual(running.jumpInput?.bundleId, "com.apple.Terminal")
        XCTAssertEqual(running.jumpInput?.isInTmux, true)
        XCTAssertEqual(running.jumpInput?.tmuxPane, "%42")
        XCTAssertEqual(running.jumpInput?.tmuxSocketPath, "/private/tmp/tmux-502/default")
        XCTAssertEqual(running.jumpInput?.ottySocket, "/tmp/otty.sock")
        XCTAssertEqual(running.jumpInput?.ottyPaneId, "otty-pane")
        XCTAssertEqual(running.jumpInput?.sessionId, "codex-019f36a7-b73f-7750-85db-081ea9257dbb")
        XCTAssertEqual(running.jumpInput?.codexThreadId, "019f36a7-b73f-7750-85db-081ea9257dbb")
        XCTAssertNotNil(running.resolvedJumpTarget)
    }

}
