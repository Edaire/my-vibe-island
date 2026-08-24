import XCTest
@testable import MyVibeIslandCore

final class SessionSnapshotTests: XCTestCase {
    func testSessionSnapshotMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SessionSnapshotMatrixFixture.self,
            from: try FixtureLoader.data("runtime/session-snapshot-matrix")
        )

        let actual = SessionSnapshotMatrixFixture(rows: [
            row(id: "waiting-pending-request", state: SessionState(
                sessionId: "waiting",
                source: "codex",
                cwd: "/tmp/project",
                pendingRequestIds: ["req-1"],
                needsAttention: true
            )),
            row(id: "active-task", state: SessionState(
                sessionId: "active",
                source: "codex",
                cwd: "/tmp/project",
                tasks: [
                    TaskItem(id: "t1", subject: "Implement", status: .active),
                    TaskItem(id: "t2", subject: "Plan", status: .completed),
                ]
            )),
            row(id: "completed-tasks", state: SessionState(
                sessionId: "completed",
                source: "codex",
                cwd: "/tmp/project",
                tasks: [
                    TaskItem(id: "t1", subject: "Plan", status: .completed),
                    TaskItem(id: "t2", subject: "Implement", status: .completed),
                ]
            )),
            row(id: "failed-task", state: SessionState(
                sessionId: "failed",
                source: "codex",
                cwd: "/tmp/project",
                tasks: [TaskItem(id: "t1", subject: "Implement", status: .failed)]
            )),
            row(id: "idle-empty-root-cwd", state: SessionState(
                sessionId: "idle-root",
                source: "codex",
                cwd: "/"
            )),
            row(id: "presentation-summaries", state: SessionState(
                sessionId: "summary",
                source: "claude",
                cwd: "/tmp/project",
                pendingRequestIds: ["req-1"],
                needsAttention: true,
                tasks: [
                    TaskItem(id: "t1", subject: "Implement", status: .active),
                    TaskItem(id: "t2", subject: "Plan", status: .completed),
                ],
                todos: [
                    TodoItem(id: "todo-1", content: "Run tests", status: .pending)
                ]
            )),
            row(id: "restored-state", state: SessionState(agentSession: AgentSession(
                id: "restored",
                source: "codex",
                cwd: "/tmp/restored"
            ))),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testSnapshotStatusIsWaitingWhenPendingRequestExists() {
        let state = SessionState(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project",
            pendingRequestIds: ["req-1"],
            needsAttention: true
        )

        let snapshot = state.snapshot()

        XCTAssertEqual(snapshot.status, .waiting)
        XCTAssertEqual(snapshot.waitingActionSummary.pendingRequestCount, 1)
        XCTAssertEqual(snapshot.waitingActionSummary.firstPendingRequestId, "req-1")
        XCTAssertTrue(snapshot.waitingActionSummary.needsAttention)
    }

    func testSnapshotStatusIsActiveWhenTaskIsActive() {
        let state = SessionState(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project",
            tasks: [
                TaskItem(id: "t1", subject: "Implement", status: .active),
                TaskItem(id: "t2", subject: "Plan", status: .completed),
            ]
        )

        let snapshot = state.snapshot()

        XCTAssertEqual(snapshot.status, .active)
        XCTAssertEqual(snapshot.activeTaskCount, 1)
    }

    func testSnapshotStatusIsCompletedWhenAllTasksCompleted() {
        let state = SessionState(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project",
            tasks: [
                TaskItem(id: "t1", subject: "Plan", status: .completed),
                TaskItem(id: "t2", subject: "Implement", status: .completed),
            ]
        )

        XCTAssertEqual(state.snapshot().status, .completed)
    }

    func testSnapshotStatusIsFailedWhenTaskFailedWithoutWaitingOrActive() {
        let state = SessionState(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project",
            tasks: [TaskItem(id: "t1", subject: "Implement", status: .failed)]
        )

        XCTAssertEqual(state.snapshot().status, .failed)
    }

    func testSnapshotStatusIsIdleWithoutPendingRequestsOrTasks() {
        let state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")

        XCTAssertEqual(state.snapshot().status, .idle)
    }

    func testSnapshotCwdDisplayUsesOnlyLastPathComponent() {
        XCTAssertEqual(SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project").snapshot().cwdDisplay, "project")
        XCTAssertEqual(SessionState(sessionId: "s2", source: "codex", cwd: "/").snapshot().cwdDisplay, "/")
        XCTAssertEqual(SessionState(sessionId: "s3", source: "codex", cwd: "").snapshot().cwdDisplay, "")
    }

    func testPresentationDerivesSafeBadgesAndSummaries() {
        let state = SessionState(
            sessionId: "s1",
            source: "claude",
            cwd: "/tmp/project",
            pendingRequestIds: ["req-1"],
            needsAttention: true,
            tasks: [
                TaskItem(id: "t1", subject: "Implement", status: .active),
                TaskItem(id: "t2", subject: "Plan", status: .completed),
            ],
            todos: [
                TodoItem(id: "todo-1", content: "Run tests", status: .pending)
            ]
        )

        let presentation = state.presentation()

        XCTAssertEqual(presentation.sessionId, "s1")
        XCTAssertEqual(presentation.sourceBadge, "claude")
        XCTAssertEqual(presentation.statusBadge, "waiting")
        XCTAssertEqual(presentation.taskSummary, "1/2 active tasks")
        XCTAssertEqual(presentation.todoSummary, "1 todos")
        XCTAssertTrue(presentation.attentionRequired)
        XCTAssertEqual(presentation.redactionLevel, .metadataOnly)
    }

    private func row(id: String, state: SessionState) -> SessionSnapshotMatrixRow {
        let snapshot = state.snapshot()
        let presentation = state.presentation()

        return SessionSnapshotMatrixRow(
            id: id,
            sessionId: snapshot.sessionId,
            source: snapshot.source,
            status: snapshot.status.rawValue,
            cwdDisplay: snapshot.cwdDisplay,
            activeTaskCount: snapshot.activeTaskCount,
            todoCount: snapshot.todoCount,
            pendingRequestCount: snapshot.waitingActionSummary.pendingRequestCount,
            firstPendingRequestId: snapshot.waitingActionSummary.firstPendingRequestId,
            needsAttention: snapshot.waitingActionSummary.needsAttention,
            redactionLevel: snapshot.redactionLevel.rawValue,
            restored: snapshot.isRestored,
            sourceBadge: presentation.sourceBadge,
            statusBadge: presentation.statusBadge,
            taskSummary: presentation.taskSummary,
            todoSummary: presentation.todoSummary,
            attentionRequired: presentation.attentionRequired,
            presentationRestored: presentation.restored
        )
    }

    private struct SessionSnapshotMatrixFixture: Codable, Equatable {
        let rows: [SessionSnapshotMatrixRow]
    }

    private struct SessionSnapshotMatrixRow: Codable, Equatable {
        let id: String
        let sessionId: String
        let source: String
        let status: String
        let cwdDisplay: String
        let activeTaskCount: Int
        let todoCount: Int
        let pendingRequestCount: Int
        let firstPendingRequestId: String?
        let needsAttention: Bool
        let redactionLevel: String
        let restored: Bool
        let sourceBadge: String
        let statusBadge: String
        let taskSummary: String
        let todoSummary: String
        let attentionRequired: Bool
        let presentationRestored: Bool
    }
}
