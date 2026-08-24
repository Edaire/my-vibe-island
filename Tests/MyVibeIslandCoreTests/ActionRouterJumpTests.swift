import XCTest
@testable import MyVibeIslandCore

final class ActionRouterJumpTests: XCTestCase {
    func testActionRouterJumpMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ActionRouterJumpMatrixFixture.self,
            from: try FixtureLoader.data("terminal/action-router-jump-matrix")
        )

        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "exact",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: JumpInput(sessionId: "exact", source: "codex", tmuxPane: "%1"),
                resolvedJumpTarget: TerminalResolver().resolve(JumpInput(sessionId: "exact", source: "codex", tmuxPane: "%1"))
            ),
            SessionState(
                sessionId: "workspace",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: JumpInput(sessionId: "workspace", source: "codex", cwd: "/tmp/project")
            ),
            SessionState(
                sessionId: "remote",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: JumpInput(
                    sessionId: "remote",
                    source: "codex",
                    isSSHRemote: true,
                    sshConnection: "client 1 server 2",
                    remoteHostId: "server-1"
                )
            ),
            SessionState(sessionId: "empty", source: "codex", cwd: ""),
            SessionState(
                sessionId: "unsupported",
                source: "codex",
                cwd: "",
                jumpInput: JumpInput(sessionId: "unsupported", source: "codex")
            )
        ])
        let router = ActionRouter(sessionCoordinator: coordinator)

        let actual = ActionRouterJumpMatrixFixture(rows: [
            row(id: "resolved-exact-target", plan: router.jumpToSession(sessionId: "exact")),
            row(id: "raw-workspace-target", plan: router.jumpToSession(sessionId: "workspace")),
            row(id: "remote-repair-target", plan: router.jumpToSession(sessionId: "remote")),
            row(id: "missing-session", plan: router.jumpToSession(sessionId: "missing")),
            row(id: "missing-jump-target", plan: router.jumpToSession(sessionId: "empty")),
            row(id: "unsupported-target", plan: router.jumpToSession(sessionId: "unsupported")),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testJumpToSessionPlansResolvedExactTarget() {
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1"),
                resolvedJumpTarget: TerminalResolver().resolve(JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1"))
            )
        ])

        let plan = ActionRouter(sessionCoordinator: coordinator).jumpToSession(sessionId: "s1")

        XCTAssertEqual(plan.status, .planned)
        XCTAssertEqual(plan.handlerId, "tmux")
        XCTAssertEqual(plan.precision, .exactPane)
        XCTAssertEqual(plan.failureReason, nil)
        XCTAssertEqual(plan.resolvedTarget?.strength, .exact)
    }

    func testJumpToSessionResolvesRawJumpInputOnDemand() {
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project")
            )
        ])

        let plan = ActionRouter(sessionCoordinator: coordinator).jumpToSession(sessionId: "s1")

        XCTAssertEqual(plan.status, .planned)
        XCTAssertEqual(plan.handlerId, "workspace")
        XCTAssertEqual(plan.precision, .workspace)
        XCTAssertEqual(plan.resolvedTarget?.strength, .weak)
    }

    func testJumpToSessionReturnsRepairPlanForRemoteHint() {
        let coordinator = SessionCoordinator(sessions: [
            SessionState(
                sessionId: "s1",
                source: "codex",
                cwd: "/tmp/project",
                jumpInput: JumpInput(
                    sessionId: "s1",
                    source: "codex",
                    isSSHRemote: true,
                    sshConnection: "client 1 server 2",
                    remoteHostId: "server-1"
                )
            )
        ])

        let plan = ActionRouter(sessionCoordinator: coordinator).jumpToSession(sessionId: "s1")

        XCTAssertEqual(plan.status, .repairRequired)
        XCTAssertEqual(plan.handlerId, "remote-hint")
        XCTAssertEqual(plan.precision, .remoteHint)
        XCTAssertEqual(plan.failureReason, .remoteRequiresReconnect)
        XCTAssertEqual(plan.jumpResult?.failureReason, .remoteRequiresReconnect)
    }

    func testJumpToSessionReturnsUnavailableForMissingSessionTargetAndUnsupported() {
        let coordinator = SessionCoordinator(sessions: [
            SessionState(sessionId: "empty", source: "codex", cwd: ""),
            SessionState(
                sessionId: "unsupported",
                source: "codex",
                cwd: "",
                jumpInput: JumpInput(sessionId: "unsupported", source: "codex")
            )
        ])
        let router = ActionRouter(sessionCoordinator: coordinator)

        XCTAssertEqual(router.jumpToSession(sessionId: "missing").failureReason, .missingSession)
        XCTAssertEqual(router.jumpToSession(sessionId: "empty").failureReason, .missingJumpTarget)

        let unsupported = router.jumpToSession(sessionId: "unsupported")
        XCTAssertEqual(unsupported.status, .unavailable)
        XCTAssertEqual(unsupported.handlerId, "unsupported")
        XCTAssertEqual(unsupported.precision, .unsupported)
        XCTAssertEqual(unsupported.failureReason, .unsupportedTarget)
    }

    private func row(id: String, plan: JumpActionPlan) -> ActionRouterJumpRowFixture {
        ActionRouterJumpRowFixture(
            id: id,
            sessionId: plan.sessionId,
            status: plan.status.rawValue,
            handlerId: plan.handlerId,
            precision: plan.precision?.rawValue,
            failureReason: plan.failureReason?.rawValue,
            repairAction: plan.repairAction,
            diagnosticSummary: plan.diagnosticSummary,
            resolvedStrength: plan.resolvedTarget?.strength.rawValue,
            resolvedHandlerId: plan.resolvedTarget?.plannedHandlerId,
            jumpFailureReason: plan.jumpResult?.failureReason?.rawValue,
            jumpSucceeded: plan.jumpResult?.succeeded
        )
    }

    private struct ActionRouterJumpMatrixFixture: Codable, Equatable {
        let rows: [ActionRouterJumpRowFixture]
    }

    private struct ActionRouterJumpRowFixture: Codable, Equatable {
        let id: String
        let sessionId: String
        let status: String
        let handlerId: String?
        let precision: String?
        let failureReason: String?
        let repairAction: String?
        let diagnosticSummary: String
        let resolvedStrength: Int?
        let resolvedHandlerId: String?
        let jumpFailureReason: String?
        let jumpSucceeded: Bool?
    }
}
