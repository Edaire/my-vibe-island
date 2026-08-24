import XCTest
@testable import MyVibeIslandCore

final class AgentSessionPreviewTests: XCTestCase {
    func testSessionCardPreviewMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SessionCardPreviewMatrixFixture.self,
            from: try FixtureLoader.data("runtime/session-card-preview-matrix")
        )

        let exactRemoteJump = JumpInput(
            sessionId: "session-1",
            source: "codex",
            cwd: "/Users/admin/project",
            isSSHRemote: true,
            sshTTY: "/dev/ttys003",
            remoteHostId: "devbox",
            remoteCwd: "/srv/project"
        )
        let metadataOnlyRemoteJump = JumpInput(
            sessionId: "session-1",
            source: "codex",
            cwd: "/Users/admin/project",
            isSSHRemote: true,
            remoteHostId: "devbox",
            remoteCwd: "/srv/project"
        )

        let actual = SessionCardPreviewMatrixFixture(rows: [
            row(id: "safe-title-active-summary", preview: SessionCardPreview(session: populatedSession(), snapshot: nil)),
            row(id: "workspace-title-fallback", preview: SessionCardPreview(
                session: populatedSession(safeTitle: nil),
                snapshot: snapshot(cwdDisplay: "project")
            )),
            row(id: "snapshot-title-fallback", preview: SessionCardPreview(
                session: populatedSession(safeTitle: nil, workspaceName: nil),
                snapshot: snapshot(cwdDisplay: "project")
            )),
            row(id: "session-id-title-fallback", preview: SessionCardPreview(
                session: populatedSession(safeTitle: nil, workspaceName: nil),
                snapshot: nil
            )),
            row(id: "waiting-status-from-request", preview: SessionCardPreview(
                session: populatedSession(pendingRequestIds: ["request-1"]),
                snapshot: nil
            )),
            row(id: "completed-status-from-tasks", preview: SessionCardPreview(
                session: populatedSession(tasks: [completedTask], pendingRequestIds: []),
                snapshot: nil
            )),
            row(id: "failed-status-from-tasks", preview: SessionCardPreview(
                session: populatedSession(tasks: [failedTask], pendingRequestIds: []),
                snapshot: nil
            )),
            row(id: "idle-status-from-empty-session", preview: SessionCardPreview(
                session: populatedSession(tasks: [], pendingRequestIds: []),
                snapshot: nil
            )),
            row(id: "snapshot-status-wins", preview: SessionCardPreview(
                session: populatedSession(tasks: [task], pendingRequestIds: []),
                snapshot: snapshot(status: .waiting)
            )),
            row(id: "remote-exact-jump", preview: SessionCardPreview(
                session: populatedSession(
                    cwd: "/Users/admin/project",
                    safeTitle: nil,
                    workspaceName: nil,
                    jumpInput: exactRemoteJump
                ),
                snapshot: snapshot(cwdDisplay: "project")
            )),
            row(id: "remote-metadata-only-jump", preview: SessionCardPreview(
                session: populatedSession(
                    cwd: "/Users/admin/project",
                    safeTitle: nil,
                    workspaceName: nil,
                    jumpInput: metadataOnlyRemoteJump
                ),
                snapshot: snapshot(cwdDisplay: "project")
            )),
            row(id: "redacted-session", preview: SessionCardPreview(
                session: populatedSession(redactionLevel: .redacted),
                snapshot: nil
            )),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testAgentSessionStoresSafeMetadataAndContent() {
        let session = populatedSession()

        XCTAssertEqual(session.id, "session-1")
        XCTAssertEqual(session.source, "codex")
        XCTAssertEqual(session.safeTitle, "Safe session title")
        XCTAssertEqual(session.tasks, [task])
        XCTAssertEqual(session.todos, [todo])
        XCTAssertEqual(session.subagents, [subagent])
        XCTAssertEqual(session.pendingRequestIds, ["request-1"])
        XCTAssertTrue(session.hasUnreadCompletion)
        XCTAssertEqual(session.redactionLevel, .metadataOnly)
    }

    func testDisplayTitleUsesConversationMetadataBeforeActivitySummary() {
        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/work/project",
            activitySummary: "Codex is working.",
            summary: "Conversation summary",
            firstUserMessage: "Build the session card",
            lastUserMessage: "Show the real session"
        )

        XCTAssertEqual(SessionCardPreview(session: session).displayTitle, "Conversation summary")
        XCTAssertEqual(
            SessionCardPreview(session: AgentSession(
                id: session.id,
                source: session.source,
                cwd: session.cwd,
                activitySummary: session.activitySummary,
                firstUserMessage: session.firstUserMessage,
                lastUserMessage: session.lastUserMessage
            )).displayTitle,
            "Build the session card"
        )
    }

    func testAgentSessionRoundTripPreservesLiveConversationMetadata() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_752_736_803)
        let session = AgentSession(
            id: "session-live-metadata",
            source: "codex",
            cwd: "/work/project",
            activeTool: "exec",
            lastAssistantMessage: "Focused tests passed.",
            currentCommandPreview: "swift test --filter SessionTests",
            updatedAt: updatedAt
        )

        let decoded = try JSONDecoder().decode(
            AgentSession.self,
            from: JSONEncoder().encode(session)
        )

        XCTAssertEqual(decoded.lastAssistantMessage, "Focused tests passed.")
        XCTAssertEqual(decoded.currentCommandPreview, "swift test --filter SessionTests")
        XCTAssertEqual(decoded.updatedAt, updatedAt)
    }

    func testPreviewTitleFallbackOrder() {
        let snapshot = snapshot(cwdDisplay: "project")

        XCTAssertEqual(SessionCardPreview(session: populatedSession(), snapshot: snapshot).displayTitle, "Safe session title")
        XCTAssertEqual(SessionCardPreview(session: populatedSession(safeTitle: nil), snapshot: snapshot).displayTitle, "Workspace")
        XCTAssertEqual(SessionCardPreview(session: populatedSession(safeTitle: nil, workspaceName: nil), snapshot: snapshot).displayTitle, "project")
        XCTAssertEqual(SessionCardPreview(session: populatedSession(safeTitle: nil, workspaceName: nil), snapshot: nil).displayTitle, "session-1")
    }

    func testPreviewUsesLiveSessionSummaryBeforeWorkspaceFallback() {
        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            workspaceName: "Workspace",
            summary: "Show the real current session"
        )

        XCTAssertEqual(
            SessionCardPreview(session: session, snapshot: nil).displayTitle,
            "Show the real current session"
        )
    }

    func testPreviewUsesSnapshotStatusWhenProvided() {
        let preview = SessionCardPreview(
            session: populatedSession(tasks: [task], pendingRequestIds: []),
            snapshot: snapshot(status: .waiting)
        )

        XCTAssertEqual(preview.statusBadge, "waiting")
    }

    func testPreviewDerivesFallbackStatusWithoutSnapshot() {
        XCTAssertEqual(SessionCardPreview(session: populatedSession(pendingRequestIds: ["request-1"]), snapshot: nil).statusBadge, "waiting")
        XCTAssertEqual(SessionCardPreview(session: populatedSession(tasks: [task], pendingRequestIds: []), snapshot: nil).statusBadge, "active")
        XCTAssertEqual(SessionCardPreview(session: populatedSession(tasks: [completedTask], pendingRequestIds: []), snapshot: nil).statusBadge, "completed")
        XCTAssertEqual(SessionCardPreview(session: populatedSession(tasks: [failedTask], pendingRequestIds: []), snapshot: nil).statusBadge, "failed")
        XCTAssertEqual(SessionCardPreview(session: populatedSession(tasks: [], pendingRequestIds: []), snapshot: nil).statusBadge, "idle")
    }

    func testPreviewReportsTaskTodoAndSubagentSummaries() {
        let preview = SessionCardPreview(session: populatedSession(), snapshot: nil)

        XCTAssertEqual(preview.activeTaskSummary, "1/1 active tasks")
        XCTAssertEqual(preview.todoSummary, "1 todos")
        XCTAssertEqual(preview.subagentSummary, "1 subagents")
        XCTAssertTrue(preview.unreadCompletionMarker)
    }

    func testPreviewJumpAvailabilityFollowsCwd() {
        XCTAssertTrue(SessionCardPreview(session: populatedSession(cwd: "/tmp/project"), snapshot: nil).jumpAvailable)
        XCTAssertFalse(SessionCardPreview(session: populatedSession(cwd: ""), snapshot: nil).jumpAvailable)
    }

    func testDetachedTmuxSessionDoesNotExposeJumpAffordance() {
        let session = AgentSession(
            id: "detached-hermes-session",
            source: "hermes",
            cwd: "/tmp/project",
            jumpInput: JumpInput(
                sessionId: "detached-hermes-session",
                source: "hermes",
                bundleId: "com.apple.Terminal",
                tmuxPane: "%1",
                tmuxSocketPath: "/private/tmp/tmux-502/kanban-agency",
                tmuxHasAttachedClient: false
            )
        )

        XCTAssertFalse(SessionCardPreview(session: session).jumpAvailable)
    }

    func testPreviewDistinguishesRemoteSessionDisplayAndJumpHint() {
        let jumpInput = JumpInput(
            sessionId: "session-1",
            source: "codex",
            cwd: "/Users/admin/project",
            isSSHRemote: true,
            sshTTY: "/dev/ttys003",
            remoteHostId: "devbox",
            remoteCwd: "/srv/project"
        )
        let session = populatedSession(
            cwd: "/Users/admin/project",
            safeTitle: nil,
            workspaceName: nil,
            jumpInput: jumpInput
        )

        let preview = SessionCardPreview(session: session, snapshot: snapshot(cwdDisplay: "project"))

        XCTAssertTrue(preview.isRemote)
        XCTAssertEqual(preview.remoteBadge, "remote")
        XCTAssertEqual(preview.remoteHostLabel, "devbox")
        XCTAssertEqual(preview.remoteSessionIdentity?.stableLocalSessionId, "remote:codex:devbox:session-1")
        XCTAssertEqual(preview.localCwdDisplay, "project")
        XCTAssertEqual(preview.remoteCwdDisplay, "/srv/project")
        XCTAssertEqual(preview.cwdContextSummary, "devbox:/srv/project")
        XCTAssertNil(preview.remoteJumpHint)
        XCTAssertTrue(preview.jumpAvailable)
    }

    func testPreviewShowsRemoteHintAndDisablesExactJumpWhenRemoteHasOnlyMetadata() {
        let jumpInput = JumpInput(
            sessionId: "session-1",
            source: "codex",
            cwd: "/Users/admin/project",
            isSSHRemote: true,
            remoteHostId: "devbox",
            remoteCwd: "/srv/project"
        )
        let session = populatedSession(
            cwd: "/Users/admin/project",
            safeTitle: nil,
            workspaceName: nil,
            jumpInput: jumpInput
        )

        let preview = SessionCardPreview(session: session, snapshot: snapshot(cwdDisplay: "project"))

        XCTAssertTrue(preview.isRemote)
        XCTAssertEqual(preview.cwdContextSummary, "devbox:/srv/project")
        XCTAssertEqual(preview.remoteJumpHint, "reconnect or repair remote session")
        XCTAssertFalse(preview.jumpAvailable)
    }

    func testPreviewUsesRedactedWhenEitherInputIsRedacted() {
        let redactedSession = populatedSession(redactionLevel: .redacted)
        let redactedSnapshot = snapshot(redactionLevel: .redacted)

        XCTAssertEqual(SessionCardPreview(session: redactedSession, snapshot: nil).redactionLevel, .redacted)
        XCTAssertEqual(SessionCardPreview(session: populatedSession(), snapshot: redactedSnapshot).redactionLevel, .redacted)
    }

    private var task: TaskItem {
        TaskItem(id: "task-1", subject: "Implement", status: .active)
    }

    private var completedTask: TaskItem {
        TaskItem(id: "task-completed", subject: "Done", status: .completed)
    }

    private var failedTask: TaskItem {
        TaskItem(id: "task-failed", subject: "Failed", status: .failed)
    }

    private var todo: TodoItem {
        TodoItem(id: "todo-1", content: "Run tests", status: .pending)
    }

    private var subagent: SubagentState {
        SubagentState(
            id: "subagent-1",
            source: "codex",
            parentSessionId: "session-1",
            parentThreadId: "thread-parent",
            threadId: "thread-child",
            kind: "reviewer",
            nickname: "review",
            role: "Reviewer",
            status: "active",
            sourceDetailId: "detail-1"
        )
    }

    private func populatedSession(
        cwd: String = "/tmp/project",
        safeTitle: String? = "Safe session title",
        workspaceName: String? = "Workspace",
        tasks: [TaskItem]? = nil,
        pendingRequestIds: [String] = ["request-1"],
        jumpInput: JumpInput? = nil,
        redactionLevel: RedactionLevel = .metadataOnly
    ) -> AgentSession {
        AgentSession(
            id: "session-1",
            source: "codex",
            cwd: cwd,
            workspaceName: workspaceName,
            model: "gpt-5",
            permissionMode: "plan",
            activeTool: "Shell",
            activitySummary: "safe metadata summary",
            safeTitle: safeTitle,
            tasks: tasks ?? [task],
            todos: [todo],
            subagents: [subagent],
            pendingRequestIds: pendingRequestIds,
            questionPrompt: nil,
            isRestored: false,
            isRemote: jumpInput?.isSSHRemote == true,
            hasUnreadCompletion: true,
            jumpInput: jumpInput,
            redactionLevel: redactionLevel
        )
    }

    private func snapshot(
        status: SessionStatus = .active,
        cwdDisplay: String = "project",
        redactionLevel: RedactionLevel = .metadataOnly
    ) -> SessionSnapshot {
        SessionSnapshot(
            sessionId: "session-1",
            source: "codex",
            status: status,
            cwdDisplay: cwdDisplay,
            activeTaskCount: 1,
            todoCount: 1,
            waitingActionSummary: WaitingActionSummary(pendingRequestIds: [], needsAttention: false),
            redactionLevel: redactionLevel,
            isRestored: false
        )
    }

    private func row(
        id: String,
        preview: SessionCardPreview
    ) -> SessionCardPreviewMatrixRow {
        SessionCardPreviewMatrixRow(
            id: id,
            sessionId: preview.sessionId,
            displayTitle: preview.displayTitle,
            sourceBadge: preview.sourceBadge,
            statusBadge: preview.statusBadge,
            activeTaskSummary: preview.activeTaskSummary,
            todoSummary: preview.todoSummary,
            subagentSummary: preview.subagentSummary,
            unreadCompletionMarker: preview.unreadCompletionMarker,
            jumpAvailable: preview.jumpAvailable,
            isRemote: preview.isRemote,
            remoteBadge: preview.remoteBadge,
            remoteHostLabel: preview.remoteHostLabel,
            remoteSessionIdentity: preview.remoteSessionIdentity?.stableLocalSessionId,
            localCwdDisplay: preview.localCwdDisplay,
            remoteCwdDisplay: preview.remoteCwdDisplay,
            cwdContextSummary: preview.cwdContextSummary,
            remoteJumpHint: preview.remoteJumpHint,
            redactionLevel: preview.redactionLevel,
            restored: preview.restored
        )
    }

    private struct SessionCardPreviewMatrixFixture: Codable, Equatable {
        let rows: [SessionCardPreviewMatrixRow]
    }

    private struct SessionCardPreviewMatrixRow: Codable, Equatable {
        let id: String
        let sessionId: String
        let displayTitle: String
        let sourceBadge: String
        let statusBadge: String
        let activeTaskSummary: String
        let todoSummary: String
        let subagentSummary: String
        let unreadCompletionMarker: Bool
        let jumpAvailable: Bool
        let isRemote: Bool
        let remoteBadge: String?
        let remoteHostLabel: String?
        let remoteSessionIdentity: String?
        let localCwdDisplay: String
        let remoteCwdDisplay: String?
        let cwdContextSummary: String
        let remoteJumpHint: String?
        let redactionLevel: RedactionLevel
        let restored: Bool
    }
}
