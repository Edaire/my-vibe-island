import Foundation
import MyVibeIslandShared
import XCTest
@testable import MyVibeIslandCore

final class CodexActiveSessionListBuilderTests: XCTestCase {
    func testCachedBuilderReusesProcessCorrelationUntilRefreshIntervalExpires() throws {
        let counter = LockedBuildCounter()
        let clock = CachedBuilderClock(Date(timeIntervalSince1970: 1_000))
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(id: "cached", source: "codex", cwd: "/repo", jumpInput: JumpInput(sessionId: "cached", source: "codex", tty: "ttys001"))
        ]))
        let builder = CodexActiveSessionListBuilder(processSnapshots: {
            counter.increment()
            return [LocalProcessSnapshot(pid: 101, tty: "ttys001", command: "codex")]
        })
        let cachedBuilder = CachedCodexActiveSessionListBuilder(
            builder: builder,
            minimumRefreshInterval: 5,
            now: clock.now
        )

        XCTAssertEqual(try cachedBuilder.build(from: store).processCorrelatedSessions.map(\.sessionId), ["cached"])
        clock.advance(by: 4.9)
        XCTAssertEqual(try cachedBuilder.build(from: store).processCorrelatedSessions.map(\.sessionId), ["cached"])
        XCTAssertEqual(counter.value, 1)

        clock.advance(by: 0.1)
        _ = try cachedBuilder.build(from: store)
        XCTAssertEqual(counter.value, 2)
    }

    func testPersistedApprovalStatusDoesNotRecreateAnActionableApproval() throws {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "processing",
                source: "codex",
                cwd: "/repo/processing",
                originalStatus: .processing,
                updatedAt: Date(timeIntervalSinceReferenceDate: 300),
                jumpInput: JumpInput(sessionId: "processing", source: "codex", tty: "ttys001")
            ),
            AgentSession(
                id: "approval",
                source: "codex",
                cwd: "/repo/approval",
                originalStatus: .waitingForApproval,
                updatedAt: Date(timeIntervalSinceReferenceDate: 100),
                jumpInput: JumpInput(sessionId: "approval", source: "codex", tty: "ttys002")
            ),
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: {
                [
                    LocalProcessSnapshot(pid: 101, tty: "ttys001", command: "/opt/homebrew/bin/codex"),
                    LocalProcessSnapshot(pid: 102, tty: "ttys002", command: "/opt/homebrew/bin/codex"),
                ]
            },
            activeTTYs: { _ in ["ttys001"] }
        )

        XCTAssertEqual(try builder.build(from: store).sessions.map(\.sessionId), ["processing", "approval"])
    }

    func testBuildsOnlyCorrelatedCodexSessionsAndPrioritizesHookReportedRunningState() throws {
        let updatedAt = Date(timeIntervalSince1970: 2_000)
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "inactive",
                source: "codex",
                cwd: "/repo/inactive",
                originalStatus: .waitingForInput,
                updatedAt: updatedAt.addingTimeInterval(100),
                jumpInput: JumpInput(sessionId: "inactive", source: "codex", tty: "ttys003")
            ),
            AgentSession(
                id: "active",
                source: "codex",
                cwd: "/repo/active",
                originalStatus: .processing,
                updatedAt: updatedAt,
                jumpInput: JumpInput(sessionId: "active", source: "codex", tty: "ttys002")
            ),
            AgentSession(id: "claude", source: "claude", cwd: "/repo/active"),
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: {
                [
                    LocalProcessSnapshot(pid: 101, tty: "ttys002", command: "/opt/homebrew/bin/codex"),
                    LocalProcessSnapshot(pid: 202, tty: "ttys003", command: "/opt/homebrew/bin/codex"),
                    LocalProcessSnapshot(pid: 303, tty: "ttys004", command: "/opt/homebrew/bin/claude"),
                    LocalProcessSnapshot(pid: 404, tty: "ttys005", command: "/opt/homebrew/bin/codex"),
                ]
            },
            activeTTYs: { _ in ["ttys002"] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), ["active", "inactive"])
        XCTAssertEqual(result.diagnostics.codexProcessCount, 3)
        XCTAssertEqual(result.diagnostics.correlatedSessionCount, 2)
        XCTAssertEqual(result.diagnostics.unmatchedCandidateCount, 1)
    }

    func testCorrelatesCodexProcessByCommandCWDWhenTTYIsMissing() throws {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(id: "cwd-session", source: "codex", cwd: "/repo/cwd")
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: {
                [
                    LocalProcessSnapshot(pid: 101, tty: "??", command: "codex --cwd /repo/cwd"),
                ]
            },
            activeTTYs: { _ in [] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), ["cwd-session"])
        XCTAssertEqual(result.diagnostics.unmatchedCandidateCount, 0)
    }

    func testResumeCommandRefreshesTerminalJumpTargetFromLiveTTY() throws {
        let threadID = "019f6a24-4b29-7eb1-a86a-fbfc5e7a6f85"
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "codex-\(threadID)",
                source: "codex",
                cwd: "/repo/resumed",
                originalStatus: .processing,
                jumpInput: JumpInput(
                    sessionId: "codex-\(threadID)",
                    source: "codex",
                    bundleId: "com.apple.Terminal",
                    cwd: "/repo/resumed",
                    pid: 99_999,
                    codexThreadId: threadID,
                    termSessionId: "old-terminal-tab"
                )
            )
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: {
                [
                    LocalProcessSnapshot(
                        pid: 101,
                        tty: "ttys024",
                        command: "codex --dangerously-bypass-approvals-and-sandbox resume \(threadID)"
                    ),
                ]
            },
            activeTTYs: { _ in [] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), ["codex-\(threadID)"])
        XCTAssertEqual(result.sessions.first?.originalStatus, .processing)
        XCTAssertEqual(result.sessions.first?.jumpInput?.pid, 101)
        XCTAssertEqual(result.sessions.first?.jumpInput?.tty, "/dev/ttys024")
        XCTAssertEqual(result.sessions.first?.resolvedJumpTarget?.plannedHandlerId, "terminal-tty")
        XCTAssertEqual(result.diagnostics.unmatchedCandidateCount, 0)
    }

    func testPreservesUnreadCompletionForCorrelatedCompletedSession() throws {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "019f9361-53a8-7112-b6fa-3ae0c13fca45",
                source: "codex",
                cwd: "/repo/current",
                activitySummary: "Finished the turn.",
                originalStatus: .ended,
                lastAssistantMessage: "Done.",
                updatedAt: Date(timeIntervalSince1970: 2_000),
                hasUnreadCompletion: true,
                jumpInput: JumpInput(sessionId: "019f9361-53a8-7112-b6fa-3ae0c13fca45", source: "codex", tty: "ttys016")
            )
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: {
                [
                    LocalProcessSnapshot(pid: 101, tty: "ttys016", command: "codex resume 019f9361-53a8-7112-b6fa-3ae0c13fca45"),
                ]
            },
            activeTTYs: { _ in ["ttys016"] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.first?.sessionId, "codex-019f9361-53a8-7112-b6fa-3ae0c13fca45")
        XCTAssertTrue(result.sessions.first?.hasUnreadCompletion == true)
        XCTAssertEqual(result.sessions.first?.originalStatus, .ended)
    }

    func testDoesNotPromoteLiveTerminalSessionsOverHookReportedStates() throws {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "working",
                source: "codex",
                cwd: "/repo/working",
                originalStatus: .processing,
                updatedAt: Date(timeIntervalSince1970: 1_000),
                jumpInput: JumpInput(sessionId: "working", source: "codex", tty: "ttys041")
            ),
            AgentSession(
                id: "waiting",
                source: "codex",
                cwd: "/repo/waiting",
                originalStatus: .waitingForInput,
                updatedAt: Date(timeIntervalSince1970: 3_000),
                jumpInput: JumpInput(sessionId: "waiting", source: "codex", tty: "ttys042")
            ),
            AgentSession(
                id: "completed",
                source: "codex",
                cwd: "/repo/completed",
                originalStatus: .ended,
                updatedAt: Date(timeIntervalSince1970: 2_000),
                jumpInput: JumpInput(sessionId: "completed", source: "codex", tty: "ttys043")
            ),
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: {
                [
                    LocalProcessSnapshot(pid: 101, tty: "ttys041", command: "/opt/homebrew/bin/codex"),
                    LocalProcessSnapshot(pid: 102, tty: "ttys042", command: "/opt/homebrew/bin/codex"),
                    LocalProcessSnapshot(pid: 103, tty: "ttys043", command: "/opt/homebrew/bin/codex"),
                ]
            },
            activeTTYs: { _ in ["ttys041", "ttys042", "ttys043"] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), ["working", "waiting", "completed"])
        XCTAssertEqual(result.sessions.first(where: { $0.sessionId == "working" })?.originalStatus, .processing)
        XCTAssertEqual(result.sessions.first(where: { $0.sessionId == "waiting" })?.originalStatus, .waitingForInput)
        XCTAssertEqual(result.sessions.first(where: { $0.sessionId == "completed" })?.originalStatus, .ended)
    }

    func testPreservesUnreadCompletionWhenCompletedSessionHasNoLiveProcess() throws {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "completed-unread",
                source: "codex",
                cwd: "/repo/completed",
                activitySummary: "Finished.",
                originalStatus: .ended,
                lastAssistantMessage: "Done.",
                updatedAt: Date(timeIntervalSince1970: 2_000),
                hasUnreadCompletion: true
            )
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: {
                [
                    LocalProcessSnapshot(pid: 101, tty: "ttys175", command: "/opt/homebrew/bin/codex"),
                ]
            },
            activeTTYs: { _ in [] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), ["completed-unread"])
        XCTAssertTrue(result.sessions.first(where: { $0.sessionId == "completed-unread" })?.hasUnreadCompletion == true)
        XCTAssertEqual(result.sessions.first(where: { $0.sessionId == "completed-unread" })?.originalStatus, .ended)
    }

    func testDoesNotApplyASecondRenderTimeFilterToRestoredEndedSessions() throws {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "restored-ended",
                source: "codex",
                cwd: "/repo/restored-ended",
                originalStatus: .ended,
                updatedAt: Date(timeIntervalSince1970: 2_000),
                isRestored: true
            )
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: { [] },
            activeTTYs: { _ in [] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), ["restored-ended"])
    }

    func testPromotesRestoredEndedSessionWhenLiveResumeThreadMatchesExactly() throws {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "019eab7e-b63e-7de0-81b3-ffede0ecdf8f",
                source: "codex",
                cwd: "/repo/old",
                activitySummary: "Codex completed the turn.",
                originalStatus: .ended,
                isRestored: true,
                hasUnreadCompletion: true
            )
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: {
                [
                    LocalProcessSnapshot(
                        pid: 101,
                        tty: "ttys018",
                        command: "codex resume 019eab7e-b63e-7de0-81b3-ffede0ecdf8f"
                    ),
                ]
            },
            activeTTYs: { _ in [] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), ["codex-019eab7e-b63e-7de0-81b3-ffede0ecdf8f"])
        XCTAssertEqual(result.diagnostics.correlatedSessionCount, 1)
        XCTAssertEqual(result.diagnostics.unmatchedCandidateCount, 0)
    }

    func testDisplaysHookSessionWithoutCommandLineThreadId() throws {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "codex-019f939e-7d4a-7c52-b431-e4ab7dcf3fe4",
                source: "codex",
                cwd: "/repo/current",
                activeTool: "Bash",
                activitySummary: "Codex is running a tool.",
                originalStatus: .runningTool,
                currentCommandPreview: "swift test",
                updatedAt: Date(timeIntervalSince1970: 2_000),
                firstUserMessage: "Run tests",
                lastUserMessage: "Run tests",
                codexRolloutPath: "/home/.codex/sessions/rollout.jsonl",
                jumpInput: JumpInput(
                    sessionId: "codex-019f939e-7d4a-7c52-b431-e4ab7dcf3fe4",
                    source: "codex",
                    cwd: "/repo/current",
                    tty: "ttys180",
                    isInTmux: true,
                    tmuxPane: "%142",
                    tmuxSocketPath: "/tmp/tmux-502/kanban-agency"
                )
            )
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: {
                [
                    LocalProcessSnapshot(
                        pid: 21449,
                        tty: "ttys180",
                        command: "node /Users/admin/.nvm/versions/node/v20.19.5/bin/codex --dangerously-bypass-approvals-and-sandbox"
                    ),
                ]
            },
            activeTTYs: { _ in ["ttys180"] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), ["codex-019f939e-7d4a-7c52-b431-e4ab7dcf3fe4"])
        XCTAssertEqual(result.sessions.first?.activeTool, "Bash")
        XCTAssertEqual(result.sessions.first?.currentCommandPreview, "swift test")
        XCTAssertEqual(result.sessions.first?.jumpInput?.tmuxPane, "%142")
        XCTAssertEqual(result.diagnostics.codexProcessCount, 1)
        XCTAssertEqual(result.diagnostics.correlatedSessionCount, 1)
        XCTAssertEqual(result.diagnostics.unmatchedCandidateCount, 0)
    }

    func testDeduplicatesBareAndPrefixedCodexThreadIdsBeforeRendering() throws {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "019f36a7-b73f-7750-85db-081ea9257dbb",
                source: "codex",
                cwd: "/repo/current",
                activitySummary: "Codex is working.",
                originalStatus: .processing,
                updatedAt: Date(timeIntervalSince1970: 3_000),
                firstUserMessage: "Original task",
                lastUserMessage: "Check screenshot"
            ),
            AgentSession(
                id: "codex-019f36a7-b73f-7750-85db-081ea9257dbb",
                source: "codex",
                cwd: "/repo/current",
                activeTool: "Bash",
                activitySummary: "Codex is running a tool.",
                originalStatus: .runningTool,
                currentCommandPreview: "jq sessions.json",
                updatedAt: Date(timeIntervalSince1970: 2_000),
                firstUserMessage: "Original task",
                lastUserMessage: "Check screenshot",
                codexRolloutPath: "/Users/admin/.codex/sessions/rollout.jsonl",
                jumpInput: JumpInput(
                    sessionId: "codex-019f36a7-b73f-7750-85db-081ea9257dbb",
                    source: "codex",
                    cwd: "/repo/current",
                    codexThreadId: "019f36a7-b73f-7750-85db-081ea9257dbb",
                    isInTmux: true,
                    tmuxPane: "%147"
                )
            )
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: {
                [
                    LocalProcessSnapshot(
                        pid: 101,
                        tty: "ttys024",
                        command: "node /Users/admin/.nvm/versions/node/v20.19.5/bin/codex --dangerously-bypass-approvals-and-sandbox"
                    ),
                ]
            },
            activeTTYs: { _ in [] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), ["codex-019f36a7-b73f-7750-85db-081ea9257dbb"])
        XCTAssertEqual(result.sessions.first?.currentCommandPreview, "jq sessions.json")
        XCTAssertEqual(result.sessions.first?.jumpInput?.tmuxPane, "%147")
        XCTAssertEqual(result.sessions.first?.codexRolloutPath, "/Users/admin/.codex/sessions/rollout.jsonl")
    }

    func testCanonicalizesLegacyBareAndPrefixedCodexSessionsBeforeChoosingRenderableContent() throws {
        let rawThreadId = "019f36a7-b73f-7750-85db-081ea9257dbb"
        let store = RawSnapshotSessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: rawThreadId,
                source: "codex",
                cwd: "/repo/current",
                activeTool: "Bash",
                activitySummary: "Codex is running a tool.",
                originalStatus: .runningTool,
                currentCommandPreview: "swift test --filter CodexActiveSessionListBuilderTests",
                updatedAt: Date(timeIntervalSince1970: 2_000),
                firstUserMessage: "Run the focused test",
                lastUserMessage: "Run the focused test",
                codexRolloutPath: "/Users/admin/.codex/sessions/rollout.jsonl",
                jumpInput: JumpInput(
                    sessionId: rawThreadId,
                    source: "codex",
                    cwd: "/repo/current",
                    codexThreadId: rawThreadId,
                    isInTmux: true,
                    tmuxPane: "%147"
                )
            ),
            AgentSession(
                id: "codex-\(rawThreadId)",
                source: "codex",
                cwd: "/repo/current",
                activitySummary: "Codex is working.",
                originalStatus: .processing,
                updatedAt: Date(timeIntervalSince1970: 3_000)
            )
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: { [] },
            activeTTYs: { _ in [] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), ["codex-\(rawThreadId)"])
        XCTAssertEqual(result.sessions.first?.activeTool, "Bash")
        XCTAssertEqual(result.sessions.first?.currentCommandPreview, "swift test --filter CodexActiveSessionListBuilderTests")
        XCTAssertEqual(result.sessions.first?.jumpInput?.codexThreadId, rawThreadId)
        XCTAssertEqual(result.sessions.first?.jumpInput?.tmuxPane, "%147")
        XCTAssertEqual(result.sessions.first?.codexRolloutPath, "/Users/admin/.codex/sessions/rollout.jsonl")
    }

    func testDoesNotBuildProcessOnlyCodexSessionsForUncorrelatedLiveTTYs() throws {
        let store = InMemorySessionStore()
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: {
                [
                    LocalProcessSnapshot(pid: 101, tty: "ttys001", command: "/opt/homebrew/bin/codex"),
                    LocalProcessSnapshot(pid: 102, tty: "ttys001", command: "/vendor/bin/codex"),
                    LocalProcessSnapshot(pid: 201, tty: "ttys002", command: "/opt/homebrew/bin/codex"),
                ]
            },
            activeTTYs: { _ in [] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), [])
        XCTAssertEqual(result.diagnostics.codexProcessCount, 2)
        XCTAssertEqual(result.diagnostics.correlatedSessionCount, 0)
        XCTAssertEqual(result.diagnostics.unmatchedCandidateCount, 2)
    }

    func testDoesNotReturnStoredSessionWithoutLiveProcessCorrelation() throws {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "codex-stale-store-record",
                source: "codex",
                cwd: "/repo/stale",
                originalStatus: .processing,
                lastUserMessage: "a prior run that never emitted SessionEnd"
            ),
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: { [] },
            activeTTYs: { _ in [] }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.processCorrelatedSessions, [])
    }

    func testAdmissionDeniedCodexRuntimeWorkspaceIsNotRendered() throws {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "codex-019fa262-649e-74b3-8bd9-c3fbf15dc670",
                source: "codex",
                cwd: "/repo/smoketest/bff/logs/codex-runtime-data/workspaces/tester-direct-runtime-20260727",
                activitySummary: "Codex completed the turn.",
                originalStatus: .ended,
                lastAssistantMessage: "DIRECT_RUNTIME_CONFIRM",
                updatedAt: Date(timeIntervalSince1970: 3_000),
                lastUserMessage: "SYSTEM:\nwrapped prompt\n\nUSER:\n只回复：DIRECT_RUNTIME_CONFIRM",
                hasUnreadCompletion: true,
                jumpInput: JumpInput(
                    sessionId: "codex-019fa262-649e-74b3-8bd9-c3fbf15dc670",
                    source: "codex",
                    cwd: "/repo/smoketest/bff/logs/codex-runtime-data/workspaces/tester-direct-runtime-20260727",
                    codexThreadId: "019fa262-649e-74b3-8bd9-c3fbf15dc670",
                    isInTmux: true,
                    tmuxPane: "%142"
                )
            ),
            AgentSession(
                id: "codex-019f36a7-b73f-7750-85db-081ea9257dbb",
                source: "codex",
                cwd: "/repo/real",
                activitySummary: "Codex is working.",
                originalStatus: .processing,
                updatedAt: Date(timeIntervalSince1970: 2_000)
            ),
        ]))
        let builder = CodexActiveSessionListBuilder(
            processSnapshots: { [] },
            activeTTYs: { _ in [] },
            admissionRules: {
                PersistedSessionAdmissionRulesV1(deniedCwdPatterns: [
                    CwdAdmissionRule(
                        pattern: "/smoketest/bff/logs/codex-runtime-data/workspaces/",
                        matchType: .contains,
                        reason: "runtime smoke workspace"
                    )
                ])
            }
        )

        let result = try builder.build(from: store)

        XCTAssertEqual(result.sessions.map(\.sessionId), ["codex-019f36a7-b73f-7750-85db-081ea9257dbb"])
    }
}

private final class LockedBuildCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    func increment() { lock.lock(); count += 1; lock.unlock() }
}

private final class CachedBuilderClock: @unchecked Sendable {
    private var value: Date
    init(_ value: Date) { self.value = value }
    func now() -> Date { value }
    func advance(by interval: TimeInterval) { value = value.addingTimeInterval(interval) }
}

private final class RawSnapshotSessionStore: SessionStore, @unchecked Sendable {
    private let snapshot: SessionStoreSnapshot

    init(snapshot: SessionStoreSnapshot) {
        self.snapshot = snapshot
    }

    func loadSnapshot() -> SessionStoreSnapshot { snapshot }
    func replaceSnapshot(_ snapshot: SessionStoreSnapshot) {}
    func mergeSessions(_ sessions: [AgentSession]) {}
    func upsert(_ session: AgentSession) {}
    func remove(sessionId: String) {}
    func setActiveSessionId(_ sessionId: String?) {}
    func markSummarized(sessionId: String) {}
    func setQuestionSelection(_ selection: String, forRequestId requestId: String) {}
}
