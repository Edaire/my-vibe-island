import XCTest
@testable import MyVibeIslandCore

final class SessionCoordinatorStoreTests: XCTestCase {
    func testSaveMergesSessionsWithoutOverwritingStoreIndexes() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "opencode", sessionId: "live", cwd: "/tmp/live"))
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(
            activeSessionId: "active",
            summarizedSessionIds: ["summary"],
            questionSelections: ["question": "answer"]
        ))

        coordinator.save(to: store)

        let snapshot = store.loadSnapshot()
        XCTAssertEqual(snapshot.sessions.map(\.id), ["live"])
        XCTAssertEqual(snapshot.activeSessionId, "active")
        XCTAssertEqual(snapshot.summarizedSessionIds, ["summary"])
        XCTAssertEqual(snapshot.questionSelections, ["question": "answer"])
    }

    func testSavingSessionOmitsEphemeralActionableRequests() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(
            source: "codex",
            sessionId: "live",
            requestId: "request-1",
            toolName: "Bash"
        ))
        let store = InMemorySessionStore()

        coordinator.save(to: store)

        let session = try! XCTUnwrap(store.loadSnapshot().sessions.first)
        XCTAssertTrue(session.pendingRequestIds.isEmpty)
        XCTAssertTrue(session.actionableRequests.isEmpty)
        XCTAssertNil(session.questionPrompt)
    }

    func testConcurrentSessionMergePreservesConcurrentIndexUpdates() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "opencode", sessionId: "live", cwd: "/tmp/live"))
        let store = DeterministicMergeStore(snapshot: SessionStoreSnapshot(activeSessionId: "active"))
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            coordinator.save(to: store)
            group.leave()
        }
        XCTAssertEqual(store.mergeStarted.wait(timeout: .now() + 1), .success)
        group.enter()
        DispatchQueue.global().async {
            store.setQuestionSelection("answer", forRequestId: "question")
            group.leave()
        }
        XCTAssertEqual(group.wait(timeout: .now() + 2), .success)

        let snapshot = store.loadSnapshot()
        XCTAssertEqual(snapshot.activeSessionId, "active")
        XCTAssertEqual(snapshot.questionSelections, ["question": "answer"])
    }

    func testSessionCoordinatorStoreMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SessionCoordinatorStoreMatrixFixture.self,
            from: try FixtureLoader.data("runtime/session-coordinator-store-matrix")
        )

        let exportCoordinator = SessionCoordinator()
        exportCoordinator.apply(.sessionStarted(source: "codex", sessionId: "b", cwd: "/tmp/beta"))
        exportCoordinator.apply(.sessionStarted(source: "claude", sessionId: "a", cwd: "/tmp/alpha"))
        exportCoordinator.apply(.taskUpdated(source: "claude", sessionId: "a", task: task))
        exportCoordinator.apply(.todoUpdated(source: "claude", sessionId: "a", todo: todo))
        exportCoordinator.apply(.permissionRequested(
            source: "claude",
            sessionId: "a",
            requestId: "request-1",
            toolName: "Shell"
        ))

        let restoreCoordinator = SessionCoordinator()
        restoreCoordinator.restore(from: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "restored",
                source: "codex",
                cwd: "/tmp/restored",
                safeTitle: "Ignored title",
                tasks: [completedTask],
                todos: [completedTodo],
                pendingRequestIds: ["request-1"],
                questionPrompt: "Ignored prompt"
            ),
        ]))

        let replaceCoordinator = SessionCoordinator()
        replaceCoordinator.apply(.sessionStarted(source: "codex", sessionId: "old", cwd: "/tmp/old"))
        replaceCoordinator.restore(from: SessionStoreSnapshot(sessions: [
            AgentSession(id: "new", source: "claude", cwd: "/tmp/new"),
        ]))

        let saveCoordinator = SessionCoordinator()
        let saveStore = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(id: "old", source: "codex", cwd: "/tmp/old"),
        ]))
        saveCoordinator.apply(.sessionStarted(source: "claude", sessionId: "new", cwd: "/tmp/new"))
        saveCoordinator.save(to: saveStore)

        let restoreFromStoreCoordinator = SessionCoordinator()
        let restoreStore = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(id: "stored", source: "codex", cwd: "/tmp/stored"),
        ]))
        restoreFromStoreCoordinator.restore(from: restoreStore)

        let actual = SessionCoordinatorStoreMatrixFixture(rows: [
            row(id: "export-sorts-safe-sessions", coordinator: exportCoordinator),
            row(id: "restore-marks-sessions-restored", coordinator: restoreCoordinator),
            row(id: "restore-replaces-existing-sessions", coordinator: replaceCoordinator),
            row(id: "save-replaces-store-snapshot", snapshot: saveStore.loadSnapshot()),
            row(id: "restore-from-store-loads-snapshot", coordinator: restoreFromStoreCoordinator),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCoordinatorExportsSafeAgentSessions() {
        let coordinator = SessionCoordinator()
        let task = TaskItem(id: "task-1", subject: "Implement bridge", status: .active)
        let todo = TodoItem(id: "todo-1", content: "Run tests", status: .pending)

        coordinator.apply(.sessionStarted(source: "codex", sessionId: "b", cwd: "/tmp/beta"))
        coordinator.apply(.sessionStarted(source: "claude", sessionId: "a", cwd: "/tmp/alpha"))
        coordinator.apply(.taskUpdated(source: "claude", sessionId: "a", task: task))
        coordinator.apply(.todoUpdated(source: "claude", sessionId: "a", todo: todo))
        coordinator.apply(.permissionRequested(source: "claude", sessionId: "a", requestId: "request-1", toolName: "Shell"))

        let snapshot = coordinator.storeSnapshot()

        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertNil(snapshot.activeSessionId)
        XCTAssertEqual(snapshot.summarizedSessionIds, [])
        XCTAssertEqual(snapshot.questionSelections, [:])
        XCTAssertEqual(snapshot.sessions.map(\.id), ["a", "b"])
        XCTAssertEqual(snapshot.sessions[0].source, "claude")
        XCTAssertEqual(snapshot.sessions[0].cwd, "/tmp/alpha")
        XCTAssertEqual(snapshot.sessions[0].tasks, [task])
        XCTAssertEqual(snapshot.sessions[0].todos, [todo])
        XCTAssertEqual(snapshot.sessions[0].pendingRequestIds, [])
        XCTAssertEqual(snapshot.sessions[0].redactionLevel, .metadataOnly)
        XCTAssertNil(snapshot.sessions[0].safeTitle)
        XCTAssertEqual(snapshot.sessions[0].subagents, [])
    }

    func testCoordinatorRestoresSessionsFromStoreSnapshot() {
        let task = TaskItem(id: "task-1", subject: "Restore", status: .completed)
        let todo = TodoItem(id: "todo-1", content: "Check state", status: .completed)
        let coordinator = SessionCoordinator()

        coordinator.restore(from: SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "restored",
                source: "codex",
                cwd: "/tmp/restored",
                safeTitle: "Ignored title",
                tasks: [task],
                todos: [todo],
                pendingRequestIds: ["request-1"],
                questionPrompt: "Ignored prompt"
            ),
        ]))

        guard let restored = coordinator.snapshot(sessionId: "restored") else {
            return XCTFail("Expected restored session")
        }
        XCTAssertEqual(restored.sessionId, "restored")
        XCTAssertEqual(restored.source, "codex")
        XCTAssertEqual(restored.cwd, "/tmp/restored")
        XCTAssertEqual(restored.safeTitle, "Ignored title")
        XCTAssertEqual(restored.originalStatus, .unknown)
        XCTAssertEqual(restored.tasks, [task])
        XCTAssertEqual(restored.todos, [todo])
        XCTAssertTrue(restored.isRestored)
    }

    func testRestoreReplacesExistingSessionsInsteadOfMerging() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "codex", sessionId: "old", cwd: "/tmp/old"))

        coordinator.restore(from: SessionStoreSnapshot(sessions: [
            AgentSession(id: "new", source: "claude", cwd: "/tmp/new"),
        ]))

        XCTAssertNil(coordinator.snapshot(sessionId: "old"))
        XCTAssertEqual(coordinator.snapshots().map(\.sessionId), ["new"])
    }

    func testSaveToStoreReplacesStoreSnapshot() {
        let coordinator = SessionCoordinator()
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(id: "old", source: "codex", cwd: "/tmp/old"),
        ]))
        coordinator.apply(.sessionStarted(source: "claude", sessionId: "new", cwd: "/tmp/new"))

        coordinator.save(to: store)

        XCTAssertEqual(store.loadSnapshot().sessions.map(\.id), ["new"])
    }

    func testRestoreFromStoreLoadsStoreSnapshot() {
        let coordinator = SessionCoordinator()
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(id: "stored", source: "codex", cwd: "/tmp/stored"),
        ]))

        coordinator.restore(from: store)

        XCTAssertEqual(coordinator.snapshots().map(\.sessionId), ["stored"])
    }

    private var task: TaskItem {
        TaskItem(id: "task-1", subject: "Implement bridge", status: .active)
    }

    private var completedTask: TaskItem {
        TaskItem(id: "task-1", subject: "Restore", status: .completed)
    }

    private var todo: TodoItem {
        TodoItem(id: "todo-1", content: "Run tests", status: .pending)
    }

    private var completedTodo: TodoItem {
        TodoItem(id: "todo-1", content: "Check state", status: .completed)
    }

    private func row(
        id: String,
        coordinator: SessionCoordinator
    ) -> SessionCoordinatorStoreMatrixRow {
        row(id: id, snapshot: coordinator.storeSnapshot(), states: coordinator.snapshots())
    }

    private func row(
        id: String,
        snapshot: SessionStoreSnapshot,
        states: [SessionState] = []
    ) -> SessionCoordinatorStoreMatrixRow {
        SessionCoordinatorStoreMatrixRow(
            id: id,
            exportedSessionIds: snapshot.sessions.map(\.id),
            exportedSources: snapshot.sessions.map(\.source),
            exportedCwds: snapshot.sessions.map(\.cwd),
            exportedTaskCounts: snapshot.sessions.map(\.tasks.count),
            exportedTodoCounts: snapshot.sessions.map(\.todos.count),
            exportedPendingRequestIds: snapshot.sessions.map(\.pendingRequestIds),
            exportedRedactionLevels: snapshot.sessions.map(\.redactionLevel.rawValue),
            activeSessionId: snapshot.activeSessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds,
            questionSelectionCount: snapshot.questionSelections.count,
            stateSessionIds: states.map(\.sessionId),
            stateRestoredFlags: states.map(\.isRestored),
            stateNeedsAttentionFlags: states.map(\.needsAttention),
            stateActionableRequestIds: states.map { $0.actionableRequests.map(\.requestId) }
        )
    }

    private struct SessionCoordinatorStoreMatrixFixture: Codable, Equatable {
        let rows: [SessionCoordinatorStoreMatrixRow]
    }

    private struct SessionCoordinatorStoreMatrixRow: Codable, Equatable {
        let id: String
        let exportedSessionIds: [String]
        let exportedSources: [String]
        let exportedCwds: [String]
        let exportedTaskCounts: [Int]
        let exportedTodoCounts: [Int]
        let exportedPendingRequestIds: [[String]]
        let exportedRedactionLevels: [String]
        let activeSessionId: String?
        let summarizedSessionIds: [String]
        let questionSelectionCount: Int
        let stateSessionIds: [String]
        let stateRestoredFlags: [Bool]
        let stateNeedsAttentionFlags: [Bool]
        let stateActionableRequestIds: [[String]]
    }
}

private final class DeterministicMergeStore: SessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: SessionStoreSnapshot
    let mergeStarted = DispatchSemaphore(value: 0)
    private let setterCompleted = DispatchSemaphore(value: 0)

    init(snapshot: SessionStoreSnapshot) {
        self.snapshot = snapshot
    }

    func loadSnapshot() -> SessionStoreSnapshot {
        lock.lock(); defer { lock.unlock() }
        return snapshot
    }

    func replaceSnapshot(_ snapshot: SessionStoreSnapshot) {
        lock.lock(); self.snapshot = snapshot; lock.unlock()
    }

    func mergeSessions(_ sessions: [AgentSession]) {
        mergeStarted.signal()
        _ = setterCompleted.wait(timeout: .now() + 1)
        lock.lock()
        snapshot = SessionStoreSnapshot(
            schemaVersion: snapshot.schemaVersion,
            sessions: sessions,
            activeSessionId: snapshot.activeSessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds,
            questionSelections: snapshot.questionSelections
        )
        lock.unlock()
    }

    func upsert(_ session: AgentSession) { mergeSessions([session]) }
    func remove(sessionId: String) {}
    func setActiveSessionId(_ sessionId: String?) {}
    func markSummarized(sessionId: String) {}

    func setQuestionSelection(_ selection: String, forRequestId requestId: String) {
        lock.lock()
        var selections = snapshot.questionSelections
        selections[requestId] = selection
        snapshot = SessionStoreSnapshot(
            schemaVersion: snapshot.schemaVersion,
            sessions: snapshot.sessions,
            activeSessionId: snapshot.activeSessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds,
            questionSelections: selections
        )
        lock.unlock()
        setterCompleted.signal()
    }
}
