import XCTest
@testable import MyVibeIslandCore

final class SessionCoordinatorTests: XCTestCase {
    func testRolloutActivityDoesNotClearUnreadCompletionUntilANewTurnStarts() throws {
        let coordinator = SessionCoordinator()
        let sessionId = "codex-non-hook"

        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: sessionId,
            activity: SessionActivityUpdate(
                status: .active,
                summary: "working",
                lastUserMessage: "first turn",
                startsNewTurn: true,
                cwd: "/tmp/project"
            )
        ))
        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: sessionId,
            activity: SessionActivityUpdate(
                status: .completed,
                summary: "done",
                lastAssistantMessage: "completed response",
                hasUnreadCompletion: true,
                cwd: "/tmp/project"
            )
        ))
        XCTAssertTrue(try XCTUnwrap(coordinator.snapshot(sessionId: sessionId)).hasUnreadCompletion)

        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: sessionId,
            activity: SessionActivityUpdate(
                status: .active,
                summary: "rollout metadata update",
                lastAssistantMessage: "completed response",
                cwd: "/tmp/project"
            )
        ))
        XCTAssertTrue(try XCTUnwrap(coordinator.snapshot(sessionId: sessionId)).hasUnreadCompletion)

        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: sessionId,
            activity: SessionActivityUpdate(
                status: .active,
                summary: "new turn",
                lastUserMessage: "second turn",
                startsNewTurn: true,
                cwd: "/tmp/project"
            )
        ))
        XCTAssertFalse(try XCTUnwrap(coordinator.snapshot(sessionId: sessionId)).hasUnreadCompletion)
    }

    func testCodexOriginMetadataSurvivesActivityReductionAndPersistenceProjection() throws {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionActivityUpdated(
            source: "codex",
            sessionId: "codex-origin-thread",
            activity: SessionActivityUpdate(
                status: .active,
                summary: "Codex is working.",
                codexOrigin: "cli",
                codexSubagentKind: "reviewer",
                cwd: "/tmp/project"
            )
        ))

        let state = try XCTUnwrap(coordinator.snapshot(sessionId: "codex-origin-thread"))
        XCTAssertEqual(state.codexOrigin, "cli")
        XCTAssertEqual(state.codexSubagentKind, "reviewer")

        let session = state.agentSession(includeEphemeralActionState: false)
        XCTAssertEqual(session.codexOrigin, "cli")
        XCTAssertEqual(session.codexSubagentKind, "reviewer")
    }

    func testRunningParentAcceptsChildLifecycleWithoutCreatingATopLevelChildSession() {
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "codex-parent-thread",
                source: "codex",
                cwd: "/tmp/project",
                originalStatus: .processing
            ),
        ])

        coordinator.apply(.subagentLifecycleUpdated(
            source: "codex",
            childSessionId: "codex-child-thread",
            lifecycle: SubagentLifecycleUpdate(
                parentThreadId: "parent-thread",
                nickname: "Godel",
                role: "explorer",
                status: .running
            )
        ))

        XCTAssertEqual(coordinator.snapshots().map(\.sessionId), ["codex-parent-thread"])
        XCTAssertEqual(
            coordinator.snapshot(sessionId: "codex-parent-thread")?.subagents.map(\.id),
            ["codex-child-thread"]
        )
    }

    func testChildLifecycleRevisionTracksAcceptedEventsAndTreeGenerationTracksNewRunningTree() {
        let parent = SessionState(sessionId: "codex-parent", source: "codex", cwd: "/tmp")
        let coordinator = SessionCoordinator(sessions: [parent])

        coordinator.apply(.subagentLifecycleUpdated(
            source: "codex",
            childSessionId: "codex-child-1",
            lifecycle: SubagentLifecycleUpdate(
                parentThreadId: "parent",
                status: .running,
                observedAt: Date(timeIntervalSinceReferenceDate: 1)
            )
        ))

        let first = try! XCTUnwrap(coordinator.snapshot(sessionId: "codex-parent"))
        XCTAssertEqual(first.childLifecycleRevision, 1)
        XCTAssertEqual(first.childTreeGeneration, 1)
        XCTAssertTrue(first.childTreeHasAuthoritativeChildren)

        coordinator.apply(.subagentLifecycleUpdated(
            source: "codex",
            childSessionId: "codex-child-1",
            lifecycle: SubagentLifecycleUpdate(
                parentThreadId: "parent",
                status: .completed,
                observedAt: Date(timeIntervalSinceReferenceDate: 2)
            )
        ))

        let completed = try! XCTUnwrap(coordinator.snapshot(sessionId: "codex-parent"))
        XCTAssertEqual(completed.childLifecycleRevision, 2)
        XCTAssertEqual(completed.childTreeGeneration, 1)

        coordinator.apply(.subagentLifecycleUpdated(
            source: "codex",
            childSessionId: "codex-child-2",
            lifecycle: SubagentLifecycleUpdate(
                parentThreadId: "parent",
                status: .running,
                observedAt: Date(timeIntervalSinceReferenceDate: 3)
            )
        ))

        let secondTree = try! XCTUnwrap(coordinator.snapshot(sessionId: "codex-parent"))
        XCTAssertEqual(secondTree.childLifecycleRevision, 3)
        XCTAssertEqual(secondTree.childTreeGeneration, 2)
    }

    func testRunningChildLifecycleUpdatesParentWithoutCreatingATopLevelChildSession() {
        let coordinator = SessionCoordinator(sessions: [
            SessionState(sessionId: "codex-parent-thread", source: "codex", cwd: "/tmp/project"),
        ])

        coordinator.apply(.subagentLifecycleUpdated(
            source: "codex",
            childSessionId: "codex-child-thread",
            lifecycle: SubagentLifecycleUpdate(
                parentThreadId: "parent-thread",
                nickname: "Godel",
                role: "explorer",
                status: .running
            )
        ))

        XCTAssertEqual(coordinator.snapshots().map(\.sessionId), ["codex-parent-thread"])
        XCTAssertEqual(
            coordinator.snapshot(sessionId: "codex-parent-thread")?.subagents,
            [SubagentState(
                id: "codex-child-thread",
                source: "codex",
                parentSessionId: "codex-parent-thread",
                parentThreadId: "parent-thread",
                threadId: "child-thread",
                kind: nil,
                nickname: "Godel",
                role: "explorer",
                status: "running",
                sourceDetailId: nil,
                startedAt: nil,
                completedAt: nil,
                hasLifecycleSignal: true,
                currentActivity: nil,
                needsAttention: false
            )]
        )
    }

    func testChildLifecyclePreservesInitialObservationAndActivityOnCompletion() throws {
        let coordinator = SessionCoordinator(sessions: [
            SessionState(sessionId: "codex-parent-thread", source: "codex", cwd: "/tmp/project"),
        ])
        let startedAt = Date(timeIntervalSinceReferenceDate: 100)
        let completedAt = Date(timeIntervalSinceReferenceDate: 200)

        coordinator.apply(.subagentLifecycleUpdated(
            source: "codex",
            childSessionId: "codex-child-thread",
            lifecycle: SubagentLifecycleUpdate(
                parentThreadId: "parent-thread",
                status: .running,
                observedAt: startedAt,
                currentActivity: "swift test",
                needsAttention: false
            )
        ))
        coordinator.apply(.subagentLifecycleUpdated(
            source: "codex",
            childSessionId: "codex-child-thread",
            lifecycle: SubagentLifecycleUpdate(
                parentThreadId: "parent-thread",
                status: .completed,
                observedAt: completedAt
            )
        ))

        let child = try XCTUnwrap(coordinator.snapshot(sessionId: "codex-parent-thread")?.subagents.first)
        XCTAssertEqual(child.startedAt, startedAt)
        XCTAssertEqual(child.completedAt, completedAt)
        XCTAssertEqual(child.currentActivity, "swift test")
        XCTAssertTrue(child.hasLifecycleSignal)
    }

    func testSessionEndKeepsSessionInCoordinatorUntilStoreOwnedCleanup() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "opencode", sessionId: "ended", cwd: "/tmp/ended"))

        coordinator.apply(.sessionEnded(source: "opencode", sessionId: "ended"))

        XCTAssertEqual(coordinator.snapshot(sessionId: "ended")?.sessionId, "ended")
    }

    func testSessionEndSchedulesGuardedCardRemoval() {
        let scheduler = SessionCoordinatorManualCleanupScheduler()
        let coordinator = SessionCoordinator(
            sessions: [],
            sessionEndCleanupScheduler: scheduler
        )
        coordinator.apply(.sessionStarted(source: "codex", sessionId: "ended", cwd: "/tmp/ended"))

        coordinator.apply(.sessionEnded(source: "codex", sessionId: "ended"))

        XCTAssertEqual(scheduler.scheduledWorkCount, 1)
        XCTAssertEqual(coordinator.snapshot(sessionId: "ended")?.sessionId, "ended")
    }

    func testSessionEndRetainsCompletedCardForObservedCompletionWindowBeforeCleanup() {
        let scheduler = SessionCoordinatorRecordingDelayedCleanupScheduler()
        let coordinator = SessionCoordinator(
            sessions: [],
            sessionEndCleanupScheduler: scheduler
        )
        coordinator.apply(.sessionStarted(source: "codex", sessionId: "completed", cwd: "/tmp/completed"))

        coordinator.apply(.sessionEnded(source: "codex", sessionId: "completed"))

        // The V3 live completion probe remains in the original render registry
        // for about two seconds after SessionEnd, providing the flash source.
        XCTAssertEqual(scheduler.delays, [2])
        XCTAssertEqual(coordinator.snapshot(sessionId: "completed")?.sessionId, "completed")

        scheduler.runNext()

        XCTAssertNil(coordinator.snapshot(sessionId: "completed"))
    }

    func testReadSnapshotCapturesOneAtomicRevision() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "codex", sessionId: "a", cwd: "/tmp/a"))

        let read = coordinator.readSnapshot()

        XCTAssertEqual(read.revision, 1)
        XCTAssertEqual(read.sessions.map(\.sessionId), ["a"])
        XCTAssertEqual(read.sessionSnapshots.map(\.sessionId), ["a"])
    }

    func testSessionCoordinatorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SessionCoordinatorMatrixFixture.self,
            from: try FixtureLoader.data("runtime/session-coordinator-matrix")
        )

        let actual = SessionCoordinatorMatrixFixture(rows: [
            row(id: "session-start-creates-session") {
                let coordinator = SessionCoordinator()
                coordinator.apply(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))
                return coordinator
            },
            row(id: "permission-placeholder-tracks-request") {
                let coordinator = SessionCoordinator()
                coordinator.apply(.permissionRequested(
                    source: "codex",
                    sessionId: "s1",
                    requestId: "r1",
                    toolName: "Shell"
                ))
                coordinator.apply(.permissionRequested(
                    source: "codex",
                    sessionId: "s1",
                    requestId: "r1",
                    toolName: "Shell"
                ))
                return coordinator
            },
            row(id: "session-start-preserves-pending-content") {
                let coordinator = SessionCoordinator()
                coordinator.apply(.permissionRequested(
                    source: "codex",
                    sessionId: "s1",
                    requestId: "r1",
                    toolName: "Shell"
                ))
                coordinator.apply(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))
                return coordinator
            },
            row(id: "content-events-create-placeholder-and-preserve-on-start") {
                let coordinator = SessionCoordinator()
                coordinator.apply(.taskUpdated(
                    source: "codex",
                    sessionId: "s1",
                    task: TaskItem(id: "t1", subject: "Plan", status: .active)
                ))
                coordinator.apply(.todoUpdated(
                    source: "codex",
                    sessionId: "s1",
                    todo: TodoItem(id: "todo-1", content: "Run tests", status: .pending)
                ))
                coordinator.apply(.teamGroupingUpdated(
                    source: "codex",
                    sessionId: "s1",
                    grouping: TeamGrouping(rootSessionId: "s1", childToParent: ["child-1": "s1"])
                ))
                coordinator.apply(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))
                return coordinator
            },
            row(id: "sorted-session-read-models") {
                let coordinator = SessionCoordinator()
                coordinator.apply(.sessionStarted(source: "codex", sessionId: "b", cwd: "/tmp/beta"))
                coordinator.apply(.sessionStarted(source: "claude", sessionId: "a", cwd: "/tmp/alpha"))
                coordinator.apply(.taskUpdated(
                    source: "claude",
                    sessionId: "a",
                    task: TaskItem(id: "t1", subject: "Plan", status: .active)
                ))
                coordinator.apply(.todoUpdated(
                    source: "claude",
                    sessionId: "a",
                    todo: TodoItem(id: "todo-1", content: "Run tests", status: .pending)
                ))
                return coordinator
            },
            row(id: "resolved-action-clears-pending-request") {
                let coordinator = SessionCoordinator()
                coordinator.apply(.permissionRequested(
                    source: "codex",
                    sessionId: "s1",
                    requestId: "r1",
                    toolName: "Shell"
                ))
                _ = coordinator.resolveAction(ActionResolution(
                    requestId: "r1",
                    sessionId: "s1",
                    kind: .approve,
                    selection: "approve-once"
                ))
                return coordinator
            },
        ])

        XCTAssertEqual(actual, expected)
    }

    func testSessionStartedCreatesSessionWithSourceSessionIdAndCwd() throws {
        let coordinator = SessionCoordinator()

        coordinator.apply(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))

        let session = try XCTUnwrap(coordinator.snapshot(sessionId: "s1"))
        XCTAssertEqual(session.sessionId, "s1")
        XCTAssertEqual(session.source, "codex")
        XCTAssertEqual(session.cwd, "/tmp/project")
    }

    func testPermissionRequestedUpdatesExistingSessionWithoutCreatingDuplicateSession() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))

        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))
        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))

        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.pendingRequestIds, ["r1"])
        XCTAssertEqual(coordinator.snapshots().count, 1)
    }

    func testPermissionRequestedForMissingSessionCreatesPlaceholderWithEmptyCwdAndTracksRequest() {
        let coordinator = SessionCoordinator()

        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))

        let snapshot = coordinator.snapshot(sessionId: "s1")
        XCTAssertEqual(snapshot?.sessionId, "s1")
        XCTAssertEqual(snapshot?.source, "codex")
        XCTAssertEqual(snapshot?.cwd, "")
        XCTAssertEqual(snapshot?.pendingRequestIds, ["r1"])
        XCTAssertTrue(snapshot?.needsAttention == true)
        XCTAssertEqual(snapshot?.actionableRequests.count, 1)
        XCTAssertNotNil(snapshot?.actionableRequests.first?.actionableRequestLifecycleTimestamp)
    }

    func testSessionStartedAfterPermissionRequestedPreservesPendingAttention() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.permissionRequested(source: "codex", sessionId: "s1", requestId: "r1", toolName: "Shell"))

        coordinator.apply(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))

        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.cwd, "/tmp/project")
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.pendingRequestIds, ["r1"])
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.actionableRequests.count, 1)
        XCTAssertNotNil(coordinator.snapshot(sessionId: "s1")?.actionableRequests.first?.actionableRequestLifecycleTimestamp)
        XCTAssertEqual(coordinator.snapshot(sessionId: "s1")?.needsAttention, true)
    }

    func testTaskTodoAndTeamEventsCreatePlaceholderSessions() {
        let coordinator = SessionCoordinator()
        let task = TaskItem(id: "t1", subject: "Plan", status: .active)
        let todo = TodoItem(id: "todo-1", content: "Run tests", status: .pending)
        let grouping = TeamGrouping(rootSessionId: "s1", childToParent: ["child-1": "s1"])

        coordinator.apply(.taskUpdated(source: "codex", sessionId: "s1", task: task))
        coordinator.apply(.todoUpdated(source: "codex", sessionId: "s1", todo: todo))
        coordinator.apply(.teamGroupingUpdated(source: "codex", sessionId: "s1", grouping: grouping))

        let snapshot = coordinator.snapshot(sessionId: "s1")
        XCTAssertEqual(snapshot?.source, "codex")
        XCTAssertEqual(snapshot?.cwd, "")
        XCTAssertEqual(snapshot?.tasks, [task])
        XCTAssertEqual(snapshot?.todos, [todo])
        XCTAssertEqual(snapshot?.teamGrouping, grouping)
    }

    func testSessionStartedPreservesExistingContent() {
        let coordinator = SessionCoordinator()
        let task = TaskItem(id: "t1", subject: "Plan", status: .active)
        let todo = TodoItem(id: "todo-1", content: "Run tests", status: .pending)
        let grouping = TeamGrouping(rootSessionId: "s1", childToParent: ["child-1": "s1"])

        coordinator.apply(.taskUpdated(source: "codex", sessionId: "s1", task: task))
        coordinator.apply(.todoUpdated(source: "codex", sessionId: "s1", todo: todo))
        coordinator.apply(.teamGroupingUpdated(source: "codex", sessionId: "s1", grouping: grouping))
        coordinator.apply(.sessionStarted(source: "codex", sessionId: "s1", cwd: "/tmp/project"))

        let snapshot = coordinator.snapshot(sessionId: "s1")
        XCTAssertEqual(snapshot?.cwd, "/tmp/project")
        XCTAssertEqual(snapshot?.tasks, [task])
        XCTAssertEqual(snapshot?.todos, [todo])
        XCTAssertEqual(snapshot?.teamGrouping, grouping)
    }

    func testSessionSnapshotsReturnSortedReadModels() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "codex", sessionId: "b", cwd: "/tmp/beta"))
        coordinator.apply(.sessionStarted(source: "claude", sessionId: "a", cwd: "/tmp/alpha"))
        coordinator.apply(.taskUpdated(source: "claude", sessionId: "a", task: TaskItem(id: "t1", subject: "Plan", status: .active)))

        let snapshots = coordinator.sessionSnapshots()

        XCTAssertEqual(snapshots.map(\.sessionId), ["a", "b"])
        XCTAssertEqual(snapshots[0].source, "claude")
        XCTAssertEqual(snapshots[0].status, .active)
        XCTAssertEqual(snapshots[0].cwdDisplay, "alpha")
    }

    func testSessionPresentationsReturnSortedReadModels() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "codex", sessionId: "b", cwd: "/tmp/beta"))
        coordinator.apply(.sessionStarted(source: "claude", sessionId: "a", cwd: "/tmp/alpha"))
        coordinator.apply(.todoUpdated(source: "claude", sessionId: "a", todo: TodoItem(id: "todo-1", content: "Run tests", status: .pending)))

        let presentations = coordinator.sessionPresentations()

        XCTAssertEqual(presentations.map(\.sessionId), ["a", "b"])
        XCTAssertEqual(presentations[0].sourceBadge, "claude")
        XCTAssertEqual(presentations[0].todoSummary, "1 todos")
    }

    func testConcurrentApplyAndSnapshotsRemainConsistent() {
        let coordinator = SessionCoordinator()
        let group = DispatchGroup()
        let iterations = 200

        for index in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let sessionId = "s\(index % 10)"
                coordinator.apply(.sessionStarted(source: "codex", sessionId: sessionId, cwd: "/tmp/\(sessionId)"))
                coordinator.apply(.permissionRequested(source: "codex", sessionId: sessionId, requestId: "r\(index)", toolName: "Shell"))
                group.leave()
            }

            group.enter()
            DispatchQueue.global().async {
                _ = coordinator.snapshot(sessionId: "s\(index % 10)")
                _ = coordinator.snapshots()
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 3.0), .success)
        XCTAssertLessThanOrEqual(coordinator.snapshots().count, 10)
    }

    private func row(id: String, makeCoordinator: () -> SessionCoordinator) -> SessionCoordinatorMatrixRow {
        let coordinator = makeCoordinator()
        let snapshots = coordinator.snapshots()
        let readModels = coordinator.sessionSnapshots()
        let presentations = coordinator.sessionPresentations()

        return SessionCoordinatorMatrixRow(
            id: id,
            sessionIds: snapshots.map(\.sessionId),
            sources: snapshots.map(\.source),
            cwds: snapshots.map(\.cwd),
            pendingRequestIds: snapshots.map(\.pendingRequestIds),
            actionableRequestIds: snapshots.map { $0.actionableRequests.map(\.requestId) },
            taskIds: snapshots.map { $0.tasks.map(\.id) },
            todoIds: snapshots.map { $0.todos.map(\.id) },
            teamRootSessionIds: snapshots.map { $0.teamGrouping?.rootSessionId },
            readModelStatuses: readModels.map(\.status.rawValue),
            readModelCwdDisplays: readModels.map(\.cwdDisplay),
            presentationStatusBadges: presentations.map(\.statusBadge),
            presentationTodoSummaries: presentations.map(\.todoSummary)
        )
    }

    private struct SessionCoordinatorMatrixFixture: Codable, Equatable {
        let rows: [SessionCoordinatorMatrixRow]
    }

    private struct SessionCoordinatorMatrixRow: Codable, Equatable {
        let id: String
        let sessionIds: [String]
        let sources: [String]
        let cwds: [String]
        let pendingRequestIds: [[String]]
        let actionableRequestIds: [[String]]
        let taskIds: [[String]]
        let todoIds: [[String]]
        let teamRootSessionIds: [String?]
        let readModelStatuses: [String]
        let readModelCwdDisplays: [String]
        let presentationStatusBadges: [String]
        let presentationTodoSummaries: [String]
    }
}

private final class SessionCoordinatorManualCleanupScheduler: SessionEndCleanupScheduling, @unchecked Sendable {
    private(set) var scheduledWorkCount = 0

    func schedule(_ work: @escaping @Sendable () -> Void) {
        scheduledWorkCount += 1
    }
}

private final class SessionCoordinatorRecordingDelayedCleanupScheduler: SessionEndCleanupScheduling, @unchecked Sendable {
    private var workItems: [@Sendable () -> Void] = []
    private(set) var delays: [TimeInterval] = []

    func schedule(_ work: @escaping @Sendable () -> Void) {
        workItems.append(work)
    }

    func schedule(after delay: TimeInterval, _ work: @escaping @Sendable () -> Void) {
        delays.append(delay)
        workItems.append(work)
    }

    func runNext() {
        workItems.removeFirst()()
    }
}
