import Foundation
import XCTest
@testable import MyVibeIslandCore

final class CodexRolloutReducerTests: XCTestCase {
    func testFirstSessionMetadataOwnsRolloutWhenEmbeddedMetadataHasOtherThreads() {
        let snapshot = CodexRolloutReducer.snapshot(for: [
            #"{"type":"session_meta","payload":{"id":"owner-thread","cwd":"/tmp/owner","source":"cli"}}"#,
            #"{"type":"session_meta","payload":{"id":"embedded-thread","cwd":"/tmp/embedded","source":"subagent"}}"#,
            #"{"type":"event_msg","payload":{"type":"task_started"}}"#,
        ])

        XCTAssertEqual(snapshot.sessionId, "owner-thread")
        XCTAssertEqual(snapshot.cwd, "/tmp/owner")
        XCTAssertEqual(snapshot.codexOrigin, "cli")
    }

    func testCodexInternalContextDoesNotBecomeConversationPrompt() {
        let snapshot = CodexRolloutReducer.snapshot(for: [
            #"{"type":"session_meta","payload":{"id":"root-thread","cwd":"/tmp/project"}}"#,
            #"{"type":"event_msg","payload":{"type":"user_message","message":"<codex_internal_context source=\"goal\">\n<objective>internal</objective>"}}"#,
            #"{"type":"event_msg","payload":{"type":"user_message","message":"real prompt"}}"#,
        ])

        XCTAssertEqual(snapshot.firstUserMessage, "real prompt")
        XCTAssertEqual(snapshot.lastUserMessage, "real prompt")
    }

    func testSubagentNotificationDoesNotBecomeConversationPrompt() {
        let snapshot = CodexRolloutReducer.snapshot(for: [
            #"{"type":"session_meta","payload":{"id":"root-thread","cwd":"/tmp/project"}}"#,
            #"{"type":"event_msg","payload":{"type":"user_message","message":"<subagent_notification>\n{\"agent_path\":\"/tmp/agent\",\"status\":{\"errored\":\"exceeded retry limit\"}}\n</subagent_notification>"}}"#,
            #"{"type":"event_msg","payload":{"type":"user_message","message":"real prompt after transport event"}}"#,
        ])

        XCTAssertEqual(snapshot.firstUserMessage, "real prompt after transport event")
        XCTAssertEqual(snapshot.lastUserMessage, "real prompt after transport event")
    }

    func testSessionMetaPropagatesExplicitCodexOriginAndSubagentKind() throws {
        let snapshot = CodexRolloutReducer.snapshot(for: [
            #"{"type":"session_meta","payload":{"id":"root-thread","cwd":"/tmp/project","source":"cli","subagent_kind":"reviewer"}}"#,
            #"{"type":"event_msg","payload":{"type":"task_started"}}"#,
        ])

        XCTAssertEqual(snapshot.codexOrigin, "cli")
        XCTAssertEqual(snapshot.codexSubagentKind, "reviewer")

        let events = CodexRolloutReducer.agentEvents(from: nil, to: snapshot)
        guard case let .sessionActivityUpdated(_, _, activity) = events.last else {
            return XCTFail("expected activity update")
        }
        XCTAssertEqual(activity.codexOrigin, "cli")
        XCTAssertEqual(activity.codexSubagentKind, "reviewer")
    }

    func testNestedSubagentMetadataDoesNotInventOriginOrKind() throws {
        let snapshot = CodexRolloutReducer.snapshot(
            for: try lines("codex/live-child-rollout")
        )

        XCTAssertNil(snapshot.codexOrigin)
        XCTAssertNil(snapshot.codexSubagentKind)
        XCTAssertEqual(snapshot.subagentParentThreadId, "runtime-parent-rollout-probe")
    }

    func testActiveChildRolloutEmitsOnlyParentLinkedRunningLifecycleEvent() {
        let snapshot = CodexRolloutReducer.snapshot(for: [
            #"{"timestamp":"2026-08-19T09:00:00.000Z","type":"session_meta","payload":{"id":"child-thread","cwd":"/tmp/project","thread_source":"subagent","agent_nickname":"Godel","agent_role":"explorer","source":{"subagent":{"thread_spawn":{"parent_thread_id":"parent-thread","depth":1,"agent_nickname":"Godel","agent_role":"explorer"}}}}}"#,
            #"{"timestamp":"2026-08-19T09:00:01.000Z","type":"event_msg","payload":{"type":"task_started"}}"#,
        ])

        XCTAssertEqual(snapshot.status, .active)
        XCTAssertEqual(CodexRolloutReducer.agentEvents(from: nil, to: snapshot), [
            .subagentLifecycleUpdated(
                source: "codex",
                childSessionId: "codex-child-thread",
                lifecycle: SubagentLifecycleUpdate(
                    parentThreadId: "parent-thread",
                    nickname: "Godel",
                    role: "explorer",
                    status: .running,
                    observedAt: ISO8601DateFormatter.vibeIslandTestDate(
                        "2026-08-19T09:00:01.000Z"
                    )
                )
            ),
        ])
    }

    func testChildRolloutCompletionEmitsOnlyParentLinkedLifecycleEvent() {
        let snapshot = CodexRolloutReducer.snapshot(for: [
            #"{"timestamp":"2026-08-19T09:00:00.000Z","type":"session_meta","payload":{"id":"child-thread","cwd":"/tmp/project","thread_source":"subagent","agent_nickname":"Godel","agent_role":"explorer","source":{"subagent":{"thread_spawn":{"parent_thread_id":"parent-thread","depth":1,"agent_nickname":"Godel","agent_role":"explorer"}}}}}"#,
            #"{"timestamp":"2026-08-19T09:00:01.000Z","type":"event_msg","payload":{"type":"task_complete"}}"#,
        ])

        XCTAssertEqual(snapshot.sessionId, "child-thread")
        XCTAssertEqual(CodexRolloutReducer.agentEvents(from: nil, to: snapshot), [
            .subagentLifecycleUpdated(
                source: "codex",
                childSessionId: "codex-child-thread",
                lifecycle: SubagentLifecycleUpdate(
                    parentThreadId: "parent-thread",
                    kind: nil,
                    nickname: "Godel",
                    role: "explorer",
                    status: .completed,
                    observedAt: ISO8601DateFormatter.vibeIslandTestDate(
                        "2026-08-19T09:00:01.000Z"
                    )
                )
            ),
        ])
    }

    func testActiveChildRolloutPreservesObservedActivityAndLifecycleTimestamp() throws {
        let snapshot = CodexRolloutReducer.snapshot(for: [
            #"{"timestamp":"2026-08-19T09:00:00.000Z","type":"session_meta","payload":{"id":"child-thread","cwd":"/tmp/project","thread_source":"subagent","source":{"subagent":{"thread_spawn":{"parent_thread_id":"parent-thread"}}}}}"#,
            #"{"timestamp":"2026-08-19T09:00:01.000Z","type":"response_item","payload":{"type":"function_call","name":"exec","arguments":"{\"cmd\":\"swift test --filter ChildAgentsSectionModelTests\"}"}}"#,
        ])

        let events = CodexRolloutReducer.agentEvents(from: nil, to: snapshot)
        guard case let .subagentLifecycleUpdated(_, _, lifecycle) = try XCTUnwrap(events.first) else {
            return XCTFail("expected a child lifecycle event")
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertEqual(lifecycle.observedAt, formatter.date(from: "2026-08-19T09:00:01.000Z"))
        XCTAssertEqual(lifecycle.currentActivity, "swift test --filter ChildAgentsSectionModelTests")
        XCTAssertFalse(lifecycle.needsAttention)
    }

    func testStartupFixtureReducesToNormalizedActiveSnapshot() throws {
        let snapshot = CodexRolloutReducer.snapshot(
            for: try lines("codex/rollout-startup")
        )

        XCTAssertEqual(snapshot.sessionId, "codex-rollout-1")
        XCTAssertEqual(snapshot.cwd, "/tmp/private-project")
        XCTAssertEqual(snapshot.status, .active)
        XCTAssertEqual(snapshot.activeTool, "exec_command")
        XCTAssertEqual(snapshot.summary, "Codex is running a tool.")
        XCTAssertFalse(snapshot.needsAttention)
        XCTAssertFalse(snapshot.isCompletionFallback)
    }

    func testAttentionIdleExplicitCompletionAndFallbackStatesAreNormalized() throws {
        var snapshot = CodexRolloutReducer.snapshot(
            for: try lines("codex/rollout-startup")
        )

        try lines("codex/rollout-attention").forEach {
            CodexRolloutReducer.apply(line: $0, to: &snapshot)
        }
        XCTAssertEqual(snapshot.status, .waiting)
        XCTAssertTrue(snapshot.needsAttention)
        XCTAssertEqual(snapshot.summary, "Codex needs attention.")

        try lines("codex/rollout-idle").forEach {
            CodexRolloutReducer.apply(line: $0, to: &snapshot)
        }
        XCTAssertEqual(snapshot.status, .idle)
        XCTAssertFalse(snapshot.needsAttention)
        XCTAssertEqual(snapshot.summary, "Codex is idle.")

        let fallback = CodexRolloutReducer.completionFallback(from: snapshot)
        XCTAssertEqual(fallback.status, .completed)
        XCTAssertTrue(fallback.isCompletionFallback)
        XCTAssertEqual(fallback.summary, "Codex completed the turn.")

        try lines("codex/rollout-complete").forEach {
            CodexRolloutReducer.apply(line: $0, to: &snapshot)
        }
        XCTAssertEqual(snapshot.status, .completed)
        XCTAssertFalse(snapshot.isCompletionFallback)
    }

    func testRequestUserInputAndTurnCompleteAndTurnAbortedAreMapped() {
        var waiting = CodexRolloutSnapshot(sessionId: "s", cwd: "/tmp")
        CodexRolloutReducer.apply(line: #"{"type":"event_msg","payload":{"type":"request_user_input","prompt":"Need approval"}}"#, to: &waiting)
        XCTAssertEqual(waiting.status, .waiting)
        XCTAssertTrue(waiting.needsAttention)

        var completed = CodexRolloutSnapshot(sessionId: "s", cwd: "/tmp")
        CodexRolloutReducer.apply(line: #"{"type":"event_msg","payload":{"type":"turn_complete"}}"#, to: &completed)
        XCTAssertEqual(completed.status, .completed)
        XCTAssertFalse(completed.needsAttention)

        var aborted = CodexRolloutSnapshot(sessionId: "s", cwd: "/tmp")
        CodexRolloutReducer.apply(line: #"{"type":"event_msg","payload":{"type":"turn_aborted"}}"#, to: &aborted)
        XCTAssertEqual(aborted.status, .failed)
        XCTAssertFalse(aborted.needsAttention)
    }

    func testTaskCompleteWithoutAssistantMessageDoesNotMarkUnreadCompletion() {
        var snapshot = CodexRolloutSnapshot(sessionId: "s", cwd: "/tmp")

        CodexRolloutReducer.apply(
            line: #"{"type":"event_msg","payload":{"type":"task_complete"}}"#,
            to: &snapshot
        )

        XCTAssertEqual(snapshot.status, .completed)
        XCTAssertNil(snapshot.lastAssistantMessage)

        let events = CodexRolloutReducer.agentEvents(from: nil, to: snapshot)
        guard case let .sessionActivityUpdated(_, _, activity) = events.last else {
            return XCTFail("expected completion activity update")
        }

        XCTAssertFalse(activity.hasUnreadCompletion)
    }

    func testInitialCompletedRolloutDoesNotMarkHistoricalCompletionUnread() {
        var snapshot = CodexRolloutSnapshot(sessionId: "historical", cwd: "/tmp")
        snapshot.status = .completed
        snapshot.lastAssistantMessage = "Finished before the watcher started."

        let events = CodexRolloutReducer.agentEvents(from: nil, to: snapshot)
        guard case let .sessionActivityUpdated(_, _, activity) = events.last else {
            return XCTFail("expected completion activity update")
        }

        XCTAssertFalse(activity.hasUnreadCompletion)
    }

    func testAgentEventsAreDeduplicatedAndContainNoRawRolloutContent() throws {
        let snapshot = CodexRolloutReducer.snapshot(
            for: try lines("codex/rollout-startup")
        )

        let events = CodexRolloutReducer.agentEvents(from: nil, to: snapshot)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(CodexRolloutReducer.agentEvents(from: snapshot, to: snapshot), [])

        let description = String(describing: events)
        XCTAssertFalse(description.contains("cat /tmp/secret"))
        XCTAssertFalse(description.contains("raw private"))
    }

    func testRolloutAgentEventsUsePrefixedCodexSessionIdButKeepSnapshotRaw() {
        let snapshot = CodexRolloutReducer.snapshot(for: [
            #"{"type":"session_meta","payload":{"id":"019f36a7-b73f-7750-85db-081ea9257dbb","cwd":"/tmp/project"}}"#,
            #"{"type":"event_msg","payload":{"type":"user_message","message":"Run it"}}"#,
        ])

        XCTAssertEqual(snapshot.sessionId, "019f36a7-b73f-7750-85db-081ea9257dbb")

        let events = CodexRolloutReducer.agentEvents(from: nil, to: snapshot)
        guard case let .sessionStarted(_, startedSessionId, _) = events.first else {
            return XCTFail("expected session start")
        }
        guard case let .sessionActivityUpdated(_, activitySessionId, _) = events.last else {
            return XCTFail("expected activity update")
        }
        XCTAssertEqual(startedSessionId, "codex-019f36a7-b73f-7750-85db-081ea9257dbb")
        XCTAssertEqual(activitySessionId, "codex-019f36a7-b73f-7750-85db-081ea9257dbb")
    }

    func testTimestampOnlyChangesDoNotChangeSemanticFingerprintOrPublish() throws {
        let first = #"{"timestamp":"2026-07-16T08:00:00.000Z","type":"event_msg","payload":{"type":"agent_message","message":"one"}}"#
        let second = #"{"timestamp":"2026-07-16T08:00:01.000Z","type":"event_msg","payload":{"type":"agent_message","message":"one"}}"#
        var old = CodexRolloutSnapshot(sessionId: "s", cwd: "/tmp")
        var new = old

        CodexRolloutReducer.apply(line: first, to: &old)
        CodexRolloutReducer.apply(line: second, to: &new)

        XCTAssertEqual(old.semanticFingerprint, new.semanticFingerprint)
        XCTAssertEqual(CodexRolloutReducer.agentEvents(from: old, to: new), [])
    }

    func testCommandPreviewChangesPublishAnotherActivityUpdateForTheSameTool() {
        let old = CodexRolloutSnapshot(
            sessionId: "s",
            cwd: "/tmp/project",
            status: .active,
            summary: "Codex is running a tool.",
            activeTool: "exec",
            currentCommandPreview: "wait 14992"
        )
        let new = CodexRolloutSnapshot(
            sessionId: "s",
            cwd: "/tmp/project",
            status: .active,
            summary: "Codex is running a tool.",
            activeTool: "exec",
            currentCommandPreview: "wait 14993"
        )

        XCTAssertNotEqual(old.semanticFingerprint, new.semanticFingerprint)
        XCTAssertEqual(CodexRolloutReducer.agentEvents(from: old, to: new).count, 1)
    }

    func testFunctionCallArgumentsExposeTheCurrentCommandPreview() {
        let snapshot = CodexRolloutReducer.snapshot(for: [
            #"{"type":"session_meta","payload":{"id":"s","cwd":"/tmp/project"}}"#,
            #"{"type":"response_item","payload":{"type":"function_call","name":"exec","arguments":"{\"cmd\":\"wait 14993\"}"}}"#,
        ])

        XCTAssertEqual(snapshot.currentCommandPreview, "wait 14993")
    }

    func testToolOutputDoesNotEraseTheLastRenderableCommandPreview() {
        let snapshot = CodexRolloutReducer.snapshot(for: [
            #"{"type":"session_meta","payload":{"id":"s","cwd":"/tmp/project"}}"#,
            #"{"type":"response_item","payload":{"type":"function_call","name":"exec","arguments":"{\"cmd\":\"swift test --filter CodexRolloutReducerTests\"}"}}"#,
            #"{"type":"response_item","payload":{"type":"function_call_output","call_id":"call-1","output":"tests passed"}}"#,
        ])

        XCTAssertEqual(snapshot.currentCommandPreview, "swift test --filter CodexRolloutReducerTests")
    }

    func testRealUserMessageAndToolReachAuthoritativeSessionState() throws {
        let lines = [
            #"{"timestamp":"2026-07-17T06:00:00.000Z","type":"session_meta","payload":{"id":"real-session","cwd":"/tmp/project"}}"#,
            #"{"timestamp":"2026-07-17T06:00:01.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Implement the real session card"}]}}"#,
            #"{"timestamp":"2026-07-17T06:00:02.000Z","type":"response_item","payload":{"type":"custom_tool_call","name":"exec","input":"swift test"}}"#,
        ]
        let snapshot = CodexRolloutReducer.snapshot(for: lines)
        let coordinator = SessionCoordinator()

        CodexRolloutReducer.agentEvents(from: nil, to: snapshot).forEach(coordinator.apply)

        let session = try XCTUnwrap(coordinator.snapshot(sessionId: "codex-real-session")?.agentSession())
        XCTAssertEqual(session.lastUserMessage, "Implement the real session card")
        XCTAssertEqual(session.firstUserMessage, "Implement the real session card")
        XCTAssertEqual(session.activeTool, "exec")
        XCTAssertEqual(session.toolInput, ["input": .string("swift test")])
        XCTAssertEqual(session.cwd, "/tmp/project")
        XCTAssertEqual(session.summary, nil)
        XCTAssertEqual(session.activitySummary, "Codex is running a tool.")
    }

    func testLaterUserMessageUpdatesLastMessageWithoutReplacingFirstMessage() throws {
        let lines = [
            #"{"timestamp":"2026-07-17T06:00:00.000Z","type":"session_meta","payload":{"id":"real-session","cwd":"/tmp/project"}}"#,
            #"{"timestamp":"2026-07-17T06:00:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"First request"}}"#,
            #"{"timestamp":"2026-07-17T06:00:02.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Latest request"}]}}"#,
        ]
        let snapshot = CodexRolloutReducer.snapshot(for: lines)
        let coordinator = SessionCoordinator()

        CodexRolloutReducer.agentEvents(from: nil, to: snapshot).forEach(coordinator.apply)

        let session = try XCTUnwrap(coordinator.snapshot(sessionId: "codex-real-session")?.agentSession())
        XCTAssertEqual(session.firstUserMessage, "First request")
        XCTAssertEqual(session.lastUserMessage, "Latest request")
    }

    func testInjectedUserBlocksDoNotBecomeConversationPrompts() {
        let lines = [
            #"{"type":"session_meta","payload":{"id":"real-session","cwd":"/tmp/project"}}"#,
            #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>\n  <cwd>/tmp</cwd>\n</environment_context>"}]}}"#,
            #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<permissions instructions>internal</permissions instructions>"}]}}"#,
            #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Implement the actual island session"}]}}"#,
        ]

        let snapshot = CodexRolloutReducer.snapshot(for: lines)

        XCTAssertEqual(snapshot.firstUserMessage, "Implement the actual island session")
        XCTAssertEqual(snapshot.lastUserMessage, "Implement the actual island session")
    }

    func testAssistantMessageCommandPreviewAndTimestampReachAuthoritativeSession() throws {
        let lines = [
            #"{"timestamp":"2026-07-17T08:00:00.000Z","type":"session_meta","payload":{"id":"metadata-session","cwd":"/tmp/project"}}"#,
            #"{"timestamp":"2026-07-17T08:00:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"Run the focused tests"}}"#,
            #"{"timestamp":"2026-07-17T08:00:02.000Z","type":"event_msg","payload":{"type":"agent_message","message":"I will verify the session model."}}"#,
            #"{"timestamp":"2026-07-17T08:00:03.000Z","type":"response_item","payload":{"type":"custom_tool_call","name":"exec","input":"swift test --filter CodexRolloutReducerTests"}}"#,
        ]
        let snapshot = CodexRolloutReducer.snapshot(for: lines)
        let coordinator = SessionCoordinator()

        CodexRolloutReducer.agentEvents(from: nil, to: snapshot).forEach(coordinator.apply)

        let session = try XCTUnwrap(coordinator.snapshot(sessionId: "codex-metadata-session")?.agentSession())
        XCTAssertEqual(session.lastAssistantMessage, "I will verify the session model.")
        XCTAssertEqual(session.currentCommandPreview, "swift test --filter CodexRolloutReducerTests")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertEqual(session.updatedAt, formatter.date(from: "2026-07-17T08:00:03.000Z"))
    }

    private func lines(_ name: String) throws -> [String] {
        try FixtureLoader.string(name, extension: "jsonl")
            .split(separator: "\n")
            .map(String.init)
    }
}

private extension ISO8601DateFormatter {
    static func vibeIslandTestDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}
