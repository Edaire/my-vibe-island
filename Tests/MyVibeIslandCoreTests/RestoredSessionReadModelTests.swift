import XCTest
@testable import MyVibeIslandCore

final class RestoredSessionReadModelTests: XCTestCase {
    func testRestoredSessionReadModelMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RestoredSessionReadModelMatrixFixture.self,
            from: try FixtureLoader.data("runtime/restored-session-read-model-matrix")
        )

        let restoredCoordinator = SessionCoordinator()
        restoredCoordinator.restore(from: SessionStoreSnapshot(sessions: [
            AgentSession(id: "restored", source: "codex", cwd: "/tmp/restored"),
        ]))

        let liveCoordinator = SessionCoordinator()
        liveCoordinator.apply(.sessionStarted(source: "codex", sessionId: "live", cwd: "/tmp/live"))

        let mutatedCoordinator = SessionCoordinator()
        mutatedCoordinator.restore(from: SessionStoreSnapshot(sessions: [
            AgentSession(id: "restored", source: "codex", cwd: "/tmp/restored"),
        ]))
        mutatedCoordinator.apply(.taskUpdated(
            source: "codex",
            sessionId: "restored",
            task: TaskItem(id: "task-1", subject: "Live update", status: .active)
        ))

        let restoredState = SessionState(agentSession: AgentSession(
            id: "restored",
            source: "codex",
            cwd: "/tmp/restored"
        ))

        let actual = RestoredSessionReadModelMatrixFixture(rows: [
            row(id: "coordinator-restore-marks-session", coordinator: restoredCoordinator, sessionId: "restored"),
            row(id: "live-session-start-is-not-restored", coordinator: liveCoordinator, sessionId: "live"),
            row(id: "live-mutation-clears-restored-state", coordinator: mutatedCoordinator, sessionId: "restored"),
            RestoredSessionReadModelMatrixRow(
                id: "state-projections-expose-restored-state",
                sessionId: restoredState.sessionId,
                snapshotRestored: restoredState.snapshot().isRestored,
                presentationRestored: restoredState.presentation().restored,
                previewRestored: SessionCardPreview(
                    session: restoredState.agentSession(),
                    snapshot: restoredState.snapshot()
                ).restored,
                storedSessionRestored: restoredState.agentSession().isRestored
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCoordinatorRestoreMarksSessionStateAsRestored() {
        let coordinator = SessionCoordinator()

        coordinator.restore(from: SessionStoreSnapshot(sessions: [
            AgentSession(id: "restored", source: "codex", cwd: "/tmp/restored"),
        ]))

        XCTAssertEqual(coordinator.snapshot(sessionId: "restored")?.isRestored, true)
    }

    func testRestoredStateExportsBackToAgentSession() {
        let state = SessionState(agentSession: AgentSession(id: "restored", source: "codex", cwd: "/tmp/restored"))

        XCTAssertTrue(state.agentSession().isRestored)
    }

    func testLiveSessionStartIsNotRestored() {
        let coordinator = SessionCoordinator()

        coordinator.apply(.sessionStarted(source: "codex", sessionId: "live", cwd: "/tmp/live"))

        XCTAssertEqual(coordinator.snapshot(sessionId: "live")?.isRestored, false)
        XCTAssertEqual(coordinator.storeSnapshot().sessions.first?.isRestored, false)
    }

    func testLiveMutationClearsRestoredState() {
        let coordinator = SessionCoordinator()
        coordinator.restore(from: SessionStoreSnapshot(sessions: [
            AgentSession(id: "restored", source: "codex", cwd: "/tmp/restored"),
        ]))

        coordinator.apply(.taskUpdated(
            source: "codex",
            sessionId: "restored",
            task: TaskItem(id: "task-1", subject: "Live update", status: .active)
        ))

        XCTAssertEqual(coordinator.snapshot(sessionId: "restored")?.isRestored, false)
        XCTAssertEqual(coordinator.storeSnapshot().sessions.first?.isRestored, false)
    }

    func testSnapshotPresentationAndPreviewExposeRestoredState() {
        let state = SessionState(agentSession: AgentSession(id: "restored", source: "codex", cwd: "/tmp/restored"))
        let snapshot = state.snapshot()
        let presentation = state.presentation()
        let preview = SessionCardPreview(session: state.agentSession(), snapshot: snapshot)

        XCTAssertTrue(snapshot.isRestored)
        XCTAssertTrue(presentation.restored)
        XCTAssertTrue(preview.restored)
    }

    private func row(
        id: String,
        coordinator: SessionCoordinator,
        sessionId: String
    ) -> RestoredSessionReadModelMatrixRow {
        let state = coordinator.snapshot(sessionId: sessionId)
        let snapshot = state?.snapshot()
        let presentation = state?.presentation()
        let storedSession = coordinator.storeSnapshot().sessions.first { $0.id == sessionId }
        let preview = storedSession.map { session in
            SessionCardPreview(session: session, snapshot: snapshot)
        }

        return RestoredSessionReadModelMatrixRow(
            id: id,
            sessionId: sessionId,
            snapshotRestored: snapshot?.isRestored,
            presentationRestored: presentation?.restored,
            previewRestored: preview?.restored,
            storedSessionRestored: storedSession?.isRestored
        )
    }

    private struct RestoredSessionReadModelMatrixFixture: Codable, Equatable {
        let rows: [RestoredSessionReadModelMatrixRow]
    }

    private struct RestoredSessionReadModelMatrixRow: Codable, Equatable {
        let id: String
        let sessionId: String
        let snapshotRestored: Bool?
        let presentationRestored: Bool?
        let previewRestored: Bool?
        let storedSessionRestored: Bool?
    }
}
