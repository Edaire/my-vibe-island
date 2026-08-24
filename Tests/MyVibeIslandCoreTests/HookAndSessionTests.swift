import XCTest
@testable import MyVibeIslandCore

final class HookAndSessionTests: XCTestCase {
    func testSessionEndRemovesTheMatchingScheduledLifecycleGeneration() {
        let scheduler = ManualSessionEndCleanupScheduler()
        let coordinator = SessionCoordinator(sessions: [], sessionEndCleanupScheduler: scheduler)

        coordinator.apply(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))
        coordinator.apply(.sessionEnded(source: "codex", sessionId: "s1"))

        XCTAssertNotNil(coordinator.snapshot(sessionId: "s1"))
        XCTAssertEqual(scheduler.pendingCount, 1)

        scheduler.runNext()

        XCTAssertNil(coordinator.snapshot(sessionId: "s1"))
    }

    func testNewActivityRejectsAnOlderScheduledSessionEndIntent() {
        let scheduler = ManualSessionEndCleanupScheduler()
        let coordinator = SessionCoordinator(sessions: [], sessionEndCleanupScheduler: scheduler)

        coordinator.apply(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))
        coordinator.apply(.sessionEnded(source: "codex", sessionId: "s1"))
        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "s1",
            activity: SessionActivityUpdate(status: .active, summary: "new turn")
        ))

        scheduler.runNext()

        XCTAssertNotNil(coordinator.snapshot(sessionId: "s1"))
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.snapshot().status, .active)
    }

    func testMatchingSessionEndCleanupPublishesOneStateChange() {
        let scheduler = ManualSessionEndCleanupScheduler()
        let coordinator = SessionCoordinator(sessions: [], sessionEndCleanupScheduler: scheduler)
        let counter = SessionEndCleanupCounter()
        let observerID = coordinator.addSessionEndCleanupObserver {
            counter.increment()
        }
        defer { coordinator.removeSessionEndCleanupObserver(observerID) }

        coordinator.apply(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))
        coordinator.apply(.sessionEnded(source: "codex", sessionId: "s1"))
        scheduler.runNext()

        XCTAssertEqual(counter.value, 1)
    }

    func testSessionEndWithEnvironmentEmitsOnlySessionEndedEvent() {
        let hook = HookEvent(
            rawEventName: "SessionEnd",
            source: "codex",
            sessionId: "ended-session",
            cwd: "/tmp/project",
            environment: HookEnvironment(
                cwd: "/tmp/project",
                pid: 42,
                itermSessionId: "iterm-1",
                termSessionId: "term-1",
                tmux: "/tmp/tmux.sock,1,0",
                tmuxPane: "%1",
                cfBundleIdentifier: "com.googlecode.iterm2"
            )
        )

        XCTAssertEqual(hook.agentEvents(), [
            .sessionEnded(source: "codex", sessionId: "ended-session"),
        ])
    }

    func testSessionActivityPreservesExplicitOriginalStatus() {
        var state = SessionState(sessionId: "cowork-1", source: "claude-cowork", cwd: "/tmp")

        state.apply(.sessionActivityUpdated(
            source: "claude-cowork",
            sessionId: "cowork-1",
            activity: SessionActivityUpdate(
                status: .active,
                summary: "Working",
                originalStatus: .thinking
            )
        ))

        XCTAssertEqual(state.originalStatus, .thinking)
    }

    func testSessionActivityUpdatesSafeTitleFromCoworkMetadata() {
        var state = SessionState(sessionId: "cowork-1", source: "claude", cwd: "/tmp")

        state.apply(.sessionActivityUpdated(
            source: "claude",
            sessionId: "cowork-1",
            activity: SessionActivityUpdate(
                status: .active,
                summary: "Working",
                safeTitle: "Fix parser"
            )
        ))

        XCTAssertEqual(state.safeTitle, "Fix parser")
    }

    func testSessionActivityUpdatesCliSessionId() {
        var state = SessionState(sessionId: "cowork-1", source: "claude", cwd: "/tmp")

        state.apply(.sessionActivityUpdated(
            source: "claude",
            sessionId: "cowork-1",
            activity: SessionActivityUpdate(
                status: .active,
                summary: "Working",
                cliSessionId: "cli-42"
            )
        ))

        XCTAssertEqual(state.cliSessionId, "cli-42")
    }

    func testSessionActivityAdvancesLastActivityAtFromTheProviderTimestamp() {
        var state = SessionState(
            sessionId: "codex-activity-time",
            source: "codex",
            cwd: "/tmp",
            lastActivityAt: Date(timeIntervalSince1970: 100)
        )
        let activityTime = Date(timeIntervalSince1970: 250)

        state.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: state.sessionId,
            activity: SessionActivityUpdate(
                status: .active,
                summary: "Working",
                updatedAt: activityTime
            )
        ))

        XCTAssertEqual(state.lastActivityAt, activityTime)
        XCTAssertEqual(state.agentSession().lastActivityAt, activityTime)
    }

    func testPermissionRequestSetsOriginalWaitingForApprovalStatus() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")

        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Bash"))

        XCTAssertEqual(state.originalStatus, .waitingForApproval)
    }

    func testActivityAfterPendingPermissionKeepsWaitingForApprovalStatus() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Bash"))

        state.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "s1",
            activity: SessionActivityUpdate(
                status: .active,
                summary: "Codex is running a tool.",
                originalStatus: .runningTool
            )
        ))

        XCTAssertEqual(state.originalStatus, .waitingForApproval)
    }

    func testCompletedActivityWithPendingPermissionDoesNotCreateUnreadCompletion() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Bash"))

        state.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "s1",
            activity: SessionActivityUpdate(
                status: .completed,
                summary: "Codex stopped while the permission is pending.",
                lastAssistantMessage: "I need approval to continue.",
                hasUnreadCompletion: true
            )
        ))

        XCTAssertEqual(state.pendingRequestIds, ["r1"])
        XCTAssertEqual(state.originalStatus, .waitingForApproval)
        XCTAssertFalse(state.hasUnreadCompletion)
        XCTAssertEqual(state.snapshot().status, .waiting)
    }

    func testCompletionWithoutANewUserPromptDoesNotCreateAnotherUnreadMarker() {
        let coordinator = SessionCoordinator()

        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "s1",
            activity: SessionActivityUpdate(
                status: .active,
                summary: "Run tool",
                firstUserMessage: "Inspect the runtime",
                lastUserMessage: "Inspect the runtime",
                isBootstrapFirstUserMessage: true
            )
        ))
        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "s1",
            activity: SessionActivityUpdate(
                status: .completed,
                summary: "First completion",
                hasUnreadCompletion: true
            )
        ))

        XCTAssertTrue(coordinator.snapshot(sessionId: "s1")?.hasUnreadCompletion == true)

        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "s1",
            activity: SessionActivityUpdate(
                status: .active,
                summary: "Internal follow-up"
            )
        ))
        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "s1",
            activity: SessionActivityUpdate(
                status: .completed,
                summary: "Internal stop",
                hasUnreadCompletion: true
            )
        ))

        // A watcher update without a new user prompt must not consume the
        // first unread completion or create a second completion opportunity.
        XCTAssertTrue(coordinator.snapshot(sessionId: "s1")?.hasUnreadCompletion == true)
    }

    func testRolloutCompletionArmsFromRecoveredUserMessageWithoutHookBootstrapFlag() {
        let coordinator = SessionCoordinator()

        // Rollout replay publishes recovered prompt fields, but it is not a hook
        // event and therefore does not set the hook-only bootstrap marker.
        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "codex-rollout-1",
            activity: SessionActivityUpdate(
                status: .active,
                summary: "Codex is working.",
                firstUserMessage: "Inspect the completion route",
                lastUserMessage: "Inspect the completion route"
            )
        ))
        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "codex-rollout-1",
            activity: SessionActivityUpdate(
                status: .completed,
                summary: "Codex completed the turn.",
                lastAssistantMessage: "Completion is available.",
                hasUnreadCompletion: true
            )
        ))

        XCTAssertTrue(coordinator.snapshot(sessionId: "codex-rollout-1")?.hasUnreadCompletion == true)
    }

    func testQuestionRequestSetsOriginalQuestionStatus() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")

        state.apply(.questionAsked(source: "codex", sessionId: "s1", requestId: "q1", toolName: "AskUserQuestion"))

        XCTAssertEqual(state.originalStatus, .question)
    }

    func testPreToolUseSetsOriginalRunningToolStatus() {
        let hook = HookEvent(
            rawEventName: "PreToolUse",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            toolName: "Bash"
        )

        guard case let .sessionActivityUpdated(_, _, activity)? = AgentEvent(hookEvent: hook) else {
            return XCTFail("expected activity update")
        }

        XCTAssertEqual(activity.originalStatus, .runningTool)
    }

    func testCodexSubagentStopDoesNotPublishChildCardLifecycle() {
        let hook = HookEvent(
            rawEventName: "SubagentStop",
            source: "codex",
            sessionId: "codex-child-thread",
            cwd: "/tmp/project",
            message: "Subagent finished",
            subagentParentThreadId: "parent-thread",
            subagentKind: "task",
            subagentNickname: "Reviewer",
            subagentRole: "review"
        )

        XCTAssertNil(AgentEvent(hookEvent: hook))
    }

    func testRolloutChildLifecycleUpdatesAParentThatIsNotWaitingForInput() {
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "codex-parent-thread",
                source: "codex",
                cwd: "/tmp/project",
                originalStatus: .runningTool
            ),
        ])

        coordinator.apply(.subagentLifecycleUpdated(
            source: "codex",
            childSessionId: "codex-child-thread",
            lifecycle: SubagentLifecycleUpdate(
                parentThreadId: "parent-thread",
                status: .completed
            )
        ))

        XCTAssertEqual(
            coordinator.snapshot(sessionId: "codex-parent-thread")?.subagents,
            [SubagentState(
                id: "codex-child-thread",
                source: "codex",
                parentSessionId: "codex-parent-thread",
                parentThreadId: "parent-thread",
                threadId: "child-thread",
                kind: nil,
                nickname: nil,
                role: nil,
                status: "completed",
                sourceDetailId: nil,
                startedAt: nil,
                completedAt: nil,
                hasLifecycleSignal: true,
                currentActivity: nil,
                needsAttention: false
            )]
        )
    }

    func testSubagentStopDoesNotEmitChildScopedMetadataEvents() {
        let hook = HookEvent(
            rawEventName: "SubagentStop",
            source: "codex",
            sessionId: "codex-child-thread",
            cwd: "/tmp/project",
            environment: HookEnvironment(
                terminal: "Terminal",
                tty: "/dev/ttys001"
            ),
            subagentParentThreadId: "parent-thread"
        )

        XCTAssertEqual(hook.agentEvents(), [])
    }

    func testHookAndSessionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            HookAndSessionMatrixFixture.self,
            from: try FixtureLoader.data("runtime/hook-and-session-matrix")
        )

        var permissionState = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        permissionState.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))

        var questionState = SessionState(sessionId: "s1", source: "opencode", cwd: "/tmp/project")
        questionState.apply(.questionAsked(source: "opencode", sessionId: "s1", requestId: "q1", toolName: "Question"))

        var duplicateState = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        duplicateState.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        duplicateState.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))

        let actual = HookAndSessionMatrixFixture(rows: [
            row(id: "session-start-event", hook: HookEvent(
                rawEventName: "SessionStart",
                source: "codex",
                sessionId: "s1",
                cwd: "/tmp/project"
            )),
            row(id: "permission-request-event", hook: HookEvent(
                rawEventName: "PermissionRequest",
                source: "codex",
                sessionId: "s1",
                requestId: "r1",
                cwd: "/tmp/project",
                toolName: "Shell"
            )),
            row(id: "question-request-event", hook: HookEvent(
                rawEventName: "QuestionRequest",
                source: "opencode",
                sessionId: "s1",
                requestId: "q1",
                cwd: "/tmp/project",
                toolName: "Question"
            )),
            row(id: "permission-missing-request-id", hook: HookEvent(
                rawEventName: "PermissionRequest",
                source: "codex",
                sessionId: "s1",
                cwd: "/tmp/project",
                toolName: "Shell"
            )),
            row(id: "permission-state", state: permissionState),
            row(id: "question-state", state: questionState),
            row(id: "duplicate-request-state", state: duplicateState),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testHookEventNormalizesSessionStartIntoAgentEvent() {
        let hook = HookEvent(
            rawEventName: "SessionStart",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            model: "gpt",
            permissionMode: nil,
            toolName: nil,
            message: nil
        )

        XCTAssertEqual(
            AgentEvent(hookEvent: hook),
            AgentEvent?.some(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))
        )
    }

    func testHookEventNormalizesPermissionRequestWithRequestIdIntoAgentEvent() {
        let hook = HookEvent(
            rawEventName: "PermissionRequest",
            source: "codex",
            sessionId: "s1",
            requestId: "req-1",
            cwd: "/tmp/project",
            model: "gpt",
            permissionMode: nil,
            toolName: "Shell",
            message: nil
        )

        XCTAssertEqual(
            AgentEvent(hookEvent: hook),
            AgentEvent?.some(.permissionRequested(source: "codex", sessionId: "s1", requestId: "req-1", toolName: "Shell"))
        )
    }

    func testHookEventNormalizesQuestionRequestWithRequestIdIntoAgentEvent() {
        let hook = HookEvent(
            rawEventName: "QuestionRequest",
            source: "opencode",
            sessionId: "s1",
            requestId: "q1",
            cwd: "/tmp/project",
            model: nil,
            permissionMode: nil,
            toolName: "Question",
            message: nil
        )

        XCTAssertEqual(
            AgentEvent(hookEvent: hook),
            AgentEvent?.some(.questionAsked(source: "opencode", sessionId: "s1", requestId: "q1", toolName: "Question"))
        )
    }

    func testHookEventIgnoresPermissionRequestWithoutRequestId() {
        let hook = HookEvent(
            rawEventName: "PermissionRequest",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            model: "gpt",
            permissionMode: nil,
            toolName: "Shell",
            message: nil
        )

        let event: AgentEvent? = AgentEvent(hookEvent: hook)

        XCTAssertNil(event)
    }

    func testHookEventNormalizesUserPromptSubmitIntoActiveSessionActivity() {
        let hook = HookEvent(
            rawEventName: "UserPromptSubmit",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            message: "Implement the session display"
        )

        XCTAssertEqual(
            AgentEvent(hookEvent: hook),
            .some(.sessionActivityUpdated(
                source: "codex",
                sessionId: "s1",
                activity: SessionActivityUpdate(
                    status: .active,
                    summary: "Implement the session display",
                    firstUserMessage: "Implement the session display",
                    lastUserMessage: "Implement the session display",
                    startsNewTurn: true,
                    isBootstrapFirstUserMessage: true,
                    cwd: "/tmp/project"
                )
            ))
        )
    }

    func testSessionStateKeepsFirstUserMessageAcrossLaterPromptSubmits() {
        let coordinator = SessionCoordinator()
        let firstHook = HookEvent(
            rawEventName: "UserPromptSubmit",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            message: "Initial request"
        )
        let secondHook = HookEvent(
            rawEventName: "UserPromptSubmit",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            message: "Latest request"
        )

        guard let firstEvent = AgentEvent(hookEvent: firstHook),
              let secondEvent = AgentEvent(hookEvent: secondHook) else {
            return XCTFail("expected session activity updates")
        }

        coordinator.apply(firstEvent)
        coordinator.apply(secondEvent)

        let session = coordinator.snapshot(sessionId: "s1")
        XCTAssertEqual(session?.firstUserMessage, "Initial request")
        XCTAssertEqual(session?.lastUserMessage, "Latest request")
    }

    func testHookEventNormalizesPreToolUseWithActiveTool() {
        let hook = HookEvent(
            rawEventName: "PreToolUse",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            toolName: "Terminal"
        )

        XCTAssertEqual(
            AgentEvent(hookEvent: hook),
            .some(.sessionActivityUpdated(
                source: "codex",
                sessionId: "s1",
                activity: SessionActivityUpdate(
                    status: .active,
                    summary: "Codex is running Terminal.",
                    originalStatus: .runningTool,
                    activeTool: "Terminal",
                    cwd: "/tmp/project"
                )
            ))
        )
    }

    func testHookEventNormalizesStopIntoUnreadCompletedActivity() {
        let hook = HookEvent(
            rawEventName: "Stop",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            message: "Implemented the session display"
        )

        XCTAssertEqual(
            AgentEvent(hookEvent: hook),
            .some(.sessionActivityUpdated(
                source: "codex",
                sessionId: "s1",
                activity: SessionActivityUpdate(
                    status: .completed,
                    summary: "Implemented the session display",
                    lastAssistantMessage: "Implemented the session display",
                    hasUnreadCompletion: true,
                    cwd: "/tmp/project"
                )
            ))
        )
    }

    func testHookEventNormalizesStopWithoutAssistantMessageIntoNonUnreadCompletion() {
        let hook = HookEvent(
            rawEventName: "Stop",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project"
        )

        guard case let .some(.sessionActivityUpdated(_, _, activity)) = AgentEvent(hookEvent: hook) else {
            return XCTFail("Stop should still record the completed session state")
        }

        XCTAssertEqual(activity.status, .completed)
        XCTAssertNil(activity.lastAssistantMessage)
        XCTAssertFalse(activity.hasUnreadCompletion)
    }

    func testHookEventNormalizesStopFailureWithoutAssistantMessageIntoNonUnreadCompletion() {
        let hook = HookEvent(
            rawEventName: "StopFailure",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project"
        )

        guard case let .some(.sessionActivityUpdated(_, _, activity)) = AgentEvent(hookEvent: hook) else {
            return XCTFail("StopFailure should still record the failed session state")
        }

        XCTAssertEqual(activity.status, .failed)
        XCTAssertNil(activity.lastAssistantMessage)
        XCTAssertFalse(activity.hasUnreadCompletion)
    }

    func testSessionCoordinatorKeepsOneRealSessionActiveAfterPrompt() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))
        let hook = HookEvent(
            rawEventName: "UserPromptSubmit",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            message: "Implement the session display"
        )

        coordinator.apply(try! XCTUnwrap(AgentEvent(hookEvent: hook)))

        let session = try! XCTUnwrap(coordinator.snapshot(sessionId: "s1"))
        XCTAssertEqual(coordinator.snapshots().count, 1)
        XCTAssertEqual(session.snapshot().status, .active)
        XCTAssertEqual(session.activitySummary, "Implement the session display")
        XCTAssertEqual(session.cwd, "/tmp/project")
    }

    func testSessionStateTracksPermissionRequest() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")

        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))

        XCTAssertEqual(state.pendingRequestIds, ["r1"])
        XCTAssertTrue(state.needsAttention)
    }

    func testSessionStateTracksQuestionRequest() {
        var state = SessionState(sessionId: "s1", source: "opencode", cwd: "/tmp/project")

        state.apply(.questionAsked(source: "opencode", sessionId: "s1", requestId: "q1", toolName: "Question"))

        XCTAssertEqual(state.pendingRequestIds, ["q1"])
        XCTAssertEqual(state.actionableRequests.count, 1)
        XCTAssertEqual(state.actionableRequests.first?.requestId, "q1")
        XCTAssertEqual(state.actionableRequests.first?.toolName, "Question")
        XCTAssertNotNil(state.actionableRequests.first?.actionableRequestLifecycleTimestamp)
        XCTAssertTrue(state.needsAttention)
    }

    func testSessionStateDerivesV3SameTreeAttentionFromStatusOrOwnedPendingRequests() {
        let activityOnly = SessionState(
            sessionId: "activity-only",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .runningTool,
            needsAttention: true
        )
        XCTAssertFalse(activityOnly.hasV3SameTreeAttention)

        var permission = SessionState(sessionId: "permission", source: "codex", cwd: "/tmp/project")
        permission.apply(.permissionRequested(
            source: "codex",
            sessionId: "permission",
            requestId: "p1",
            toolName: "Shell"
        ))
        XCTAssertTrue(permission.hasV3SameTreeAttention)

        var question = SessionState(sessionId: "question", source: "codex", cwd: "/tmp/project")
        question.apply(.questionAsked(
            source: "codex",
            sessionId: "question",
            requestId: "q1",
            toolName: "AskUserQuestion"
        ))
        XCTAssertTrue(question.hasV3SameTreeAttention)
    }

    func testSessionStateKeepsPendingRequestIdsUnique() {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")

        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        state.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))

        XCTAssertEqual(state.pendingRequestIds, ["r1"])
        XCTAssertTrue(state.needsAttention)
    }

    func testAuthoritativeActivityCorrectsPersistedFirstUserMessage() {
        var state = SessionState(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project",
            firstUserMessage: "Incorrect tail bootstrap message"
        )

        state.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "s1",
            activity: SessionActivityUpdate(
                status: .active,
                summary: "Codex is working.",
                firstUserMessage: "Original session request"
            )
        ))

        XCTAssertEqual(state.firstUserMessage, "Original session request")
    }

    private func row(id: String, hook: HookEvent) -> HookAndSessionRowFixture {
        let event = AgentEvent(hookEvent: hook)
        return HookAndSessionRowFixture(
            id: id,
            eventKind: eventKind(event),
            eventSource: hook.source,
            eventSessionId: hook.sessionId,
            requestId: hook.requestId,
            toolName: hook.toolName,
            pendingRequestIds: nil,
            needsAttention: nil,
            actionableKinds: nil
        )
    }

    private func row(id: String, state: SessionState) -> HookAndSessionRowFixture {
        HookAndSessionRowFixture(
            id: id,
            eventKind: nil,
            eventSource: nil,
            eventSessionId: nil,
            requestId: nil,
            toolName: nil,
            pendingRequestIds: state.pendingRequestIds,
            needsAttention: state.needsAttention,
            actionableKinds: state.actionableRequests.map { $0.kind.rawValue }
        )
    }

    private func eventKind(_ event: AgentEvent?) -> String? {
        guard let event else {
            return nil
        }

        switch event {
        case .sessionStarted:
            return "sessionStarted"
        case .sessionEnded:
            return "sessionEnded"
        case .sessionActivityUpdated:
            return "sessionActivityUpdated"
        case .permissionRequested:
            return "permissionRequested"
        case .questionAsked:
            return "questionAsked"
        case .messageReceived:
            return "messageReceived"
        case .taskUpdated:
            return "taskUpdated"
        case .todoUpdated:
            return "todoUpdated"
        case .teamGroupingUpdated:
            return "teamGroupingUpdated"
        case .jumpTargetUpdated:
            return "jumpTargetUpdated"
        case .subagentLifecycleUpdated:
            return "subagentLifecycleUpdated"
        case .actionResolved:
            return "actionResolved"
        }
    }

    private struct HookAndSessionMatrixFixture: Codable, Equatable {
        let rows: [HookAndSessionRowFixture]
    }

    private struct HookAndSessionRowFixture: Codable, Equatable {
        let id: String
        let eventKind: String?
        let eventSource: String?
        let eventSessionId: String?
        let requestId: String?
        let toolName: String?
        let pendingRequestIds: [String]?
        let needsAttention: Bool?
        let actionableKinds: [String]?
    }
}

private final class ManualSessionEndCleanupScheduler: SessionEndCleanupScheduling, @unchecked Sendable {
    private var workItems: [@Sendable () -> Void] = []

    var pendingCount: Int {
        workItems.count
    }

    func schedule(_ work: @escaping @Sendable () -> Void) {
        workItems.append(work)
    }

    func runNext() {
        workItems.removeFirst()()
    }
}

private final class SessionEndCleanupCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
