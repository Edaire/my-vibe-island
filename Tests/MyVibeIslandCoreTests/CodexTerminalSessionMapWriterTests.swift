import Foundation
import XCTest
@testable import MyVibeIslandCore

final class CodexTerminalSessionMapWriterTests: XCTestCase {
    func testWritesRenderableOriginalCompatibleTerminalSessionMap() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-terminal-map-writer-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let fileURL = root.appendingPathComponent("session-terminals.json")

        try CodexTerminalSessionMapWriter().write(
            sessions: [
                SessionState(
                    sessionId: "019f36a7-b73f-7750-85db-081ea9257dbb",
                    source: "codex",
                    cwd: "/repo/my-vibe-island",
                    activeTool: "Bash",
                    originalStatus: .runningTool,
                    toolTarget: "swift test",
                    lastAssistantMessage: "running focused tests",
                    updatedAt: Date(timeIntervalSinceReferenceDate: 806402514.0),
                    repoName: "my-vibe-island",
                    firstUserMessage: "run tests",
                    lastUserMessage: "please verify",
                    codexRolloutPath: "/Users/admin/.codex/sessions/rollout.jsonl",
                    reportedStatus: .active,
                    hasUnreadCompletion: true,
                    jumpInput: JumpInput(
                        sessionId: "019f36a7-b73f-7750-85db-081ea9257dbb",
                        source: "codex",
                        cwd: "/repo/my-vibe-island",
                        tty: "/dev/ttys016",
                        termProgram: "Apple_Terminal",
                        codexThreadId: "019f36a7-b73f-7750-85db-081ea9257dbb",
                        isInTmux: true,
                        tmuxPane: "%42",
                        tmuxSocketPath: "/private/tmp/tmux-502/default",
                        ottySocket: "/tmp/otty.sock",
                        ottyPaneId: "otty-pane",
                        termSessionId: "TERM-1"
                    )
                )
            ],
            to: fileURL
        )

        let entries = try JSONDecoder().decode([String: OriginalEntry].self, from: Data(contentsOf: fileURL))
        let entry = try XCTUnwrap(entries["codex-019f36a7-b73f-7750-85db-081ea9257dbb"])
        XCTAssertEqual(entry.termProgram, "Apple_Terminal")
        XCTAssertEqual(entry.termSessionId, "TERM-1")
        XCTAssertEqual(entry.codexRolloutPath, "/Users/admin/.codex/sessions/rollout.jsonl")
        XCTAssertEqual(entry.hasUnreadCompletion, true)
        XCTAssertEqual(entry.bundleIdentifiers, [])
        XCTAssertEqual(entry.gitIdentityStatus, "ok")
        XCTAssertEqual(entry.repoName, "my-vibe-island")
        XCTAssertEqual(entry.ottySocket, "/tmp/otty.sock")
        XCTAssertEqual(entry.ottyPaneId, "otty-pane")

        let sessions = try CodexTerminalSessionMapReader(fileURL: fileURL).readSessions()

        XCTAssertEqual(sessions.map(\.sessionId), ["codex-019f36a7-b73f-7750-85db-081ea9257dbb"])
        XCTAssertEqual(sessions.first?.originalStatus, .runningTool)
        XCTAssertEqual(sessions.first?.activeTool, "Bash")
        XCTAssertEqual(sessions.first?.toolTarget, "swift test")
        XCTAssertEqual(sessions.first?.jumpInput?.isInTmux, true)
        XCTAssertEqual(sessions.first?.jumpInput?.tmuxPane, "%42")
        XCTAssertEqual(sessions.first?.jumpInput?.termProgram, "Apple_Terminal")
        XCTAssertEqual(sessions.first?.jumpInput?.termSessionId, "TERM-1")
        XCTAssertEqual(sessions.first?.jumpInput?.ottySocket, "/tmp/otty.sock")
        XCTAssertEqual(sessions.first?.jumpInput?.ottyPaneId, "otty-pane")
        XCTAssertEqual(sessions.first?.codexRolloutPath, "/Users/admin/.codex/sessions/rollout.jsonl")
        XCTAssertEqual(sessions.first?.repoName, "my-vibe-island")
        XCTAssertEqual(sessions.first?.hasUnreadCompletion, true)
    }

    func testDoesNotWriteRestoredHistoricalCodexSessions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-terminal-map-writer-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let fileURL = root.appendingPathComponent("session-terminals.json")

        try CodexTerminalSessionMapWriter().write(
            sessions: [
                SessionState(
                    sessionId: "restored-history",
                    source: "codex",
                    cwd: "/tmp/history",
                    lastUserMessage: "old prompt",
                    isRestored: true
                ),
                SessionState(
                    sessionId: "live-hook",
                    source: "codex",
                    cwd: "/tmp/live",
                    lastUserMessage: "current prompt"
                ),
            ],
            to: fileURL
        )

        let sessions = try CodexTerminalSessionMapReader(fileURL: fileURL).readSessions()

        XCTAssertEqual(sessions.map(\.sessionId), ["codex-live-hook"])
        XCTAssertEqual(sessions.first?.lastUserMessage, "current prompt")
    }

    func testDoesNotPersistSyntheticConversationText() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-terminal-map-writer-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let fileURL = root.appendingPathComponent("session-terminals.json")

        try CodexTerminalSessionMapWriter().write(
            sessions: [
                SessionState(
                    sessionId: "synthetic",
                    source: "codex",
                    cwd: "/tmp/project",
                    firstUserMessage: "<subagent_notification>\n{\"status\":\"completed\"}\n</subagent_notification>",
                    lastUserMessage: "<codex_internal_context source=\"goal\">\ninternal\n</codex_internal_context>"
                )
            ],
            to: fileURL
        )

        let sessions = try CodexTerminalSessionMapReader(fileURL: fileURL).readSessions()
        let session = try XCTUnwrap(sessions.first)
        XCTAssertNil(session.firstUserMessage)
        XCTAssertNil(session.lastUserMessage)
    }

    func testDuplicateNormalizedCodexIdsDoNotCrashAndKeepNewestSession() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-terminal-map-writer-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let fileURL = root.appendingPathComponent("session-terminals.json")

        try CodexTerminalSessionMapWriter().write(
            sessions: [
                SessionState(
                    sessionId: "019f36a7-b73f-7750-85db-081ea9257dbb",
                    source: "codex",
                    cwd: "/tmp/old",
                    updatedAt: Date(timeIntervalSinceReferenceDate: 1),
                    lastUserMessage: "old"
                ),
                SessionState(
                    sessionId: "codex-019f36a7-b73f-7750-85db-081ea9257dbb",
                    source: "codex",
                    cwd: "/tmp/new",
                    updatedAt: Date(timeIntervalSinceReferenceDate: 2),
                    lastUserMessage: "new"
                ),
            ],
            to: fileURL
        )

        let sessions = try CodexTerminalSessionMapReader(fileURL: fileURL).readSessions()

        XCTAssertEqual(sessions.map(\.sessionId), ["codex-019f36a7-b73f-7750-85db-081ea9257dbb"])
        XCTAssertEqual(sessions.first?.cwd, "/tmp/new")
        XCTAssertEqual(sessions.first?.lastUserMessage, "new")
    }

    func testWritesKnownOriginalStatusStrings() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-terminal-map-writer-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let fileURL = root.appendingPathComponent("session-terminals.json")

        try CodexTerminalSessionMapWriter().write(
            sessions: [
                SessionState(sessionId: "running", source: "codex", cwd: "/tmp", originalStatus: .runningTool),
                SessionState(sessionId: "approval", source: "codex", cwd: "/tmp", originalStatus: .waitingForApproval),
                SessionState(sessionId: "question", source: "codex", cwd: "/tmp", originalStatus: .question),
                SessionState(sessionId: "working", source: "codex", cwd: "/tmp", originalStatus: .processing),
                SessionState(sessionId: "done", source: "codex", cwd: "/tmp", originalStatus: .ended),
                SessionState(sessionId: "idle", source: "codex", cwd: "/tmp", reportedStatus: .idle),
                SessionState(sessionId: "failed", source: "codex", cwd: "/tmp", reportedStatus: .failed),
            ],
            to: fileURL
        )

        let entries = try JSONDecoder().decode([String: Entry].self, from: Data(contentsOf: fileURL))

        XCTAssertEqual(entries["codex-running"]?.status, "running_tool")
        XCTAssertEqual(entries["codex-approval"]?.status, "waiting_for_approval")
        XCTAssertEqual(entries["codex-question"]?.status, "question")
        XCTAssertEqual(entries["codex-working"]?.status, "working")
        XCTAssertEqual(entries["codex-done"]?.status, "done")
        XCTAssertEqual(entries["codex-idle"]?.status, "waiting_for_input")
        XCTAssertEqual(entries["codex-failed"]?.status, "failed")
    }

    private struct Entry: Decodable {
        let status: String
    }

    private struct OriginalEntry: Decodable {
        let termProgram: String?
        let termSessionId: String?
        let codexRolloutPath: String?
        let hasUnreadCompletion: Bool?
        let bundleIdentifiers: [String]?
        let gitIdentityStatus: String?
        let repoName: String?
        let ottySocket: String?
        let ottyPaneId: String?
    }
}
