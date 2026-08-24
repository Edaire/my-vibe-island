import XCTest
@testable import MyVibeIslandCore

final class SessionJumpTargetTests: XCTestCase {
    func testSessionJumpTargetMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SessionJumpTargetMatrixFixture.self,
            from: try FixtureLoader.data("runtime/session-jump-target-matrix")
        )

        let environment = HookEnvironment(
            cwd: "/tmp/project",
            pid: 42,
            itermSessionId: "iterm-1",
            termSessionId: "term-1",
            tmux: "/tmp/tmux.sock,1,0",
            tmuxPane: "%1",
            cfBundleIdentifier: "com.googlecode.iterm2"
        )
        let hook = HookEvent(
            rawEventName: "SessionStart",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            environment: environment
        )

        let hookCoordinator = SessionCoordinator()
        hook.agentEvents().forEach { hookCoordinator.apply($0) }

        let preserveCoordinator = SessionCoordinator()
        preserveCoordinator.apply(.jumpTargetUpdated(
            source: "codex",
            sessionId: "s1",
            jumpInput: JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1")
        ))
        preserveCoordinator.apply(.jumpTargetUpdated(
            source: "codex",
            sessionId: "s1",
            jumpInput: JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        ))

        let placeholderCoordinator = SessionCoordinator()
        placeholderCoordinator.apply(.jumpTargetUpdated(
            source: "codex",
            sessionId: "s1",
            jumpInput: JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project", tmuxPane: "%1")
        ))

        let roundTripJumpInput = JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project", tmuxPane: "%1")
        let roundTripResolved = TerminalResolver().resolve(roundTripJumpInput)
        let roundTripState = SessionState(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project",
            jumpInput: roundTripJumpInput,
            resolvedJumpTarget: roundTripResolved
        )
        let restoredRoundTripState = SessionState(agentSession: roundTripState.agentSession())

        let remoteHint = TerminalResolver().resolve(JumpInput(
            sessionId: "remote-1",
            source: "codex",
            cwd: "/Users/admin/project",
            isSSHRemote: true,
            remoteHostId: "devbox",
            remoteCwd: "/srv/project"
        ))

        let actual = SessionJumpTargetMatrixFixture(rows: [
            row(id: "hook-environment-emits-jump-target", events: hook.agentEvents()),
            row(id: "coordinator-stores-hook-jump-target", state: try XCTUnwrap(hookCoordinator.snapshot(sessionId: "s1"))),
            row(id: "coordinator-preserves-stronger-target", state: try XCTUnwrap(preserveCoordinator.snapshot(sessionId: "s1"))),
            row(id: "jump-target-creates-placeholder-session", state: try XCTUnwrap(placeholderCoordinator.snapshot(sessionId: "s1"))),
            row(id: "agent-session-round-trip-preserves-target", state: restoredRoundTripState),
            row(id: "remote-metadata-target-produces-reconnect-hint", resolvedTarget: remoteHint),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testHookEventWithEnvironmentEmitsJumpTargetUpdate() throws {
        let environment = HookEnvironment(
            cwd: "/tmp/project",
            pid: 42,
            itermSessionId: "iterm-1",
            termSessionId: "term-1",
            tmux: "/tmp/tmux.sock,1,0",
            tmuxPane: "%1",
            cfBundleIdentifier: "com.googlecode.iterm2"
        )
        let hook = HookEvent(
            rawEventName: "SessionStart",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            environment: environment
        )

        let events = hook.agentEvents()

        XCTAssertEqual(events.count, 2)
        guard case let .jumpTargetUpdated(source, sessionId, jumpInput) = events[1] else {
            return XCTFail("expected jump target event")
        }
        XCTAssertEqual(source, "codex")
        XCTAssertEqual(sessionId, "s1")
        XCTAssertEqual(jumpInput.sessionId, "s1")
        XCTAssertEqual(jumpInput.source, "codex")
        XCTAssertEqual(jumpInput.tmuxPane, "%1")
        XCTAssertEqual(jumpInput.tmuxSocketPath, "/tmp/tmux.sock")
        XCTAssertEqual(jumpInput.terminalFingerprint?.itermSessionId, "iterm-1")
    }

    func testSessionCoordinatorStoresJumpInputFromHookEvent() throws {
        let coordinator = SessionCoordinator()
        let hook = HookEvent(
            rawEventName: "SessionStart",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            environment: HookEnvironment(cwd: "/tmp/project", tmuxPane: "%1")
        )

        hook.agentEvents().forEach { coordinator.apply($0) }

        let state = try XCTUnwrap(coordinator.snapshot(sessionId: "s1"))
        XCTAssertEqual(state.jumpInput?.sessionId, "s1")
        XCTAssertEqual(state.jumpInput?.tmuxPane, "%1")
        XCTAssertEqual(state.snapshot().jumpInput?.tmuxPane, "%1")
    }

    func testSessionCoordinatorStoresResolvedJumpTargetFromHookEvent() throws {
        let coordinator = SessionCoordinator()
        let hook = HookEvent(
            rawEventName: "SessionStart",
            source: "codex",
            sessionId: "s1",
            cwd: "/tmp/project",
            environment: HookEnvironment(cwd: "/tmp/project", tmuxPane: "%1")
        )

        hook.agentEvents().forEach { coordinator.apply($0) }

        let state = try XCTUnwrap(coordinator.snapshot(sessionId: "s1"))
        XCTAssertEqual(state.resolvedJumpTarget?.strength, .exact)
        XCTAssertEqual(state.resolvedJumpTarget?.plannedHandlerId, "tmux")
        XCTAssertEqual(state.snapshot().resolvedJumpTarget?.plannedPrecision, .exactPane)
        XCTAssertEqual(state.jumpInput?.tmuxPane, "%1")
    }

    func testSessionCoordinatorPreservesStrongerResolvedJumpTarget() throws {
        let coordinator = SessionCoordinator()
        coordinator.apply(.jumpTargetUpdated(
            source: "codex",
            sessionId: "s1",
            jumpInput: JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1")
        ))
        coordinator.apply(.jumpTargetUpdated(
            source: "codex",
            sessionId: "s1",
            jumpInput: JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        ))

        let state = try XCTUnwrap(coordinator.snapshot(sessionId: "s1"))
        XCTAssertEqual(state.resolvedJumpTarget?.strength, .exact)
        XCTAssertEqual(state.resolvedJumpTarget?.plannedHandlerId, "tmux")
        XCTAssertEqual(state.jumpInput?.tmuxPane, "%1")
    }

    func testJumpTargetEventCreatesPlaceholderSession() throws {
        let coordinator = SessionCoordinator()
        let jumpInput = JumpInput(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project",
            tmuxPane: "%1"
        )

        coordinator.apply(.jumpTargetUpdated(source: "codex", sessionId: "s1", jumpInput: jumpInput))

        let state = try XCTUnwrap(coordinator.snapshot(sessionId: "s1"))
        XCTAssertEqual(state.source, "codex")
        XCTAssertEqual(state.cwd, "")
        XCTAssertEqual(state.jumpInput?.sessionId, jumpInput.sessionId)
        XCTAssertEqual(state.jumpInput?.source, jumpInput.source)
        XCTAssertEqual(state.jumpInput?.cwd, jumpInput.cwd)
        XCTAssertEqual(state.jumpInput?.tmuxPane, jumpInput.tmuxPane)
        XCTAssertEqual(state.resolvedJumpTarget?.plannedHandlerId, "tmux")
    }

    func testAgentSessionRoundTripPreservesJumpInput() throws {
        let jumpInput = JumpInput(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project",
            tmuxPane: "%1"
        )
        let state = SessionState(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project",
            jumpInput: jumpInput
        )

        let agentSession = state.agentSession()
        let restored = SessionState(agentSession: agentSession)

        XCTAssertEqual(agentSession.jumpInput, jumpInput)
        XCTAssertEqual(restored.jumpInput, jumpInput)
        XCTAssertEqual(restored.snapshot().jumpInput, jumpInput)
    }

    func testAgentSessionRoundTripPreservesResolvedJumpTarget() throws {
        let jumpInput = JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1")
        let resolved = TerminalResolver().resolve(jumpInput)
        let state = SessionState(
            sessionId: "s1",
            source: "codex",
            cwd: "/tmp/project",
            jumpInput: jumpInput,
            resolvedJumpTarget: resolved
        )

        let agentSession = state.agentSession()
        let restored = SessionState(agentSession: agentSession)

        XCTAssertEqual(agentSession.resolvedJumpTarget, resolved)
        XCTAssertEqual(restored.resolvedJumpTarget, resolved)
        XCTAssertEqual(restored.snapshot().resolvedJumpTarget, resolved)
    }

    private func row(
        id: String,
        events: [AgentEvent]
    ) -> SessionJumpTargetMatrixRow {
        let jumpInput = events.compactMap { event -> JumpInput? in
            guard case let .jumpTargetUpdated(_, _, input) = event else {
                return nil
            }
            return input
        }.first

        return SessionJumpTargetMatrixRow(
            id: id,
            eventKinds: events.map(agentEventKind),
            sessionId: jumpInput?.sessionId,
            source: jumpInput?.source,
            cwd: jumpInput?.cwd,
            stateCwd: nil,
            stateIsRestored: nil,
            tmuxPane: jumpInput?.tmuxPane,
            tmuxSocketPath: jumpInput?.tmuxSocketPath,
            terminalFingerprintItermSessionId: jumpInput?.terminalFingerprint?.itermSessionId,
            focusConfidence: jumpInput?.terminalFocusIdentity?.confidence.rawValue,
            resolvedStrength: nil,
            plannedHandlerId: nil,
            plannedPrecision: nil,
            diagnosticSummary: nil,
            remoteJumpFailureReason: nil,
            remoteRepairAction: nil
        )
    }

    private func row(
        id: String,
        state: SessionState
    ) -> SessionJumpTargetMatrixRow {
        let resolved = state.resolvedJumpTarget
        return SessionJumpTargetMatrixRow(
            id: id,
            eventKinds: [],
            sessionId: state.sessionId,
            source: state.source,
            cwd: state.jumpInput?.cwd,
            stateCwd: state.cwd,
            stateIsRestored: state.isRestored,
            tmuxPane: state.jumpInput?.tmuxPane,
            tmuxSocketPath: state.jumpInput?.tmuxSocketPath,
            terminalFingerprintItermSessionId: state.jumpInput?.terminalFingerprint?.itermSessionId,
            focusConfidence: state.jumpInput?.terminalFocusIdentity?.confidence.rawValue,
            resolvedStrength: resolved?.strength.rawValue,
            plannedHandlerId: resolved?.plannedHandlerId,
            plannedPrecision: resolved?.plannedPrecision.rawValue,
            diagnosticSummary: resolved?.diagnosticSummary,
            remoteJumpFailureReason: nil,
            remoteRepairAction: nil
        )
    }

    private func row(
        id: String,
        resolvedTarget: TerminalResolvedTarget
    ) -> SessionJumpTargetMatrixRow {
        SessionJumpTargetMatrixRow(
            id: id,
            eventKinds: [],
            sessionId: resolvedTarget.input.sessionId,
            source: resolvedTarget.input.source,
            cwd: resolvedTarget.input.cwd,
            stateCwd: nil,
            stateIsRestored: nil,
            tmuxPane: resolvedTarget.input.tmuxPane,
            tmuxSocketPath: resolvedTarget.input.tmuxSocketPath,
            terminalFingerprintItermSessionId: resolvedTarget.input.terminalFingerprint?.itermSessionId,
            focusConfidence: resolvedTarget.input.terminalFocusIdentity?.confidence.rawValue,
            resolvedStrength: resolvedTarget.strength.rawValue,
            plannedHandlerId: resolvedTarget.plannedHandlerId,
            plannedPrecision: resolvedTarget.plannedPrecision.rawValue,
            diagnosticSummary: resolvedTarget.diagnosticSummary,
            remoteJumpFailureReason: TerminalJumpRouter().planJump(resolvedTarget.input).failureReason?.rawValue,
            remoteRepairAction: TerminalJumpRouter().planJump(resolvedTarget.input).repairAction
        )
    }

    private func agentEventKind(_ event: AgentEvent) -> String {
        switch event {
        case .sessionStarted:
            "sessionStarted"
        case .sessionEnded:
            "sessionEnded"
        case .sessionActivityUpdated:
            "sessionActivityUpdated"
        case .permissionRequested:
            "permissionRequested"
        case .questionAsked:
            "questionAsked"
        case .messageReceived:
            "messageReceived"
        case .taskUpdated:
            "taskUpdated"
        case .todoUpdated:
            "todoUpdated"
        case .teamGroupingUpdated:
            "teamGroupingUpdated"
        case .jumpTargetUpdated:
            "jumpTargetUpdated"
        case .subagentLifecycleUpdated:
            "subagentLifecycleUpdated"
        case .actionResolved:
            "actionResolved"
        }
    }

    private struct SessionJumpTargetMatrixFixture: Codable, Equatable {
        let rows: [SessionJumpTargetMatrixRow]
    }

    private struct SessionJumpTargetMatrixRow: Codable, Equatable {
        let id: String
        let eventKinds: [String]
        let sessionId: String?
        let source: String?
        let cwd: String?
        let stateCwd: String?
        let stateIsRestored: Bool?
        let tmuxPane: String?
        let tmuxSocketPath: String?
        let terminalFingerprintItermSessionId: String?
        let focusConfidence: String?
        let resolvedStrength: Int?
        let plannedHandlerId: String?
        let plannedPrecision: String?
        let diagnosticSummary: String?
        let remoteJumpFailureReason: String?
        let remoteRepairAction: String?
    }
}
