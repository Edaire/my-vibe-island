public enum JumpActionStatus: String, Codable, Equatable, Sendable {
    case planned
    case repairRequired
    case unavailable
}

public enum JumpActionFailureReason: String, Codable, Equatable, Sendable {
    case missingSession
    case missingJumpTarget
    case unsupportedTarget
    case remoteRequiresReconnect
}

public struct JumpActionPlan: Codable, Equatable, Sendable {
    public let sessionId: String
    public let status: JumpActionStatus
    public let handlerId: String?
    public let precision: JumpPrecision?
    public let failureReason: JumpActionFailureReason?
    public let repairAction: String?
    public let diagnosticSummary: String
    public let resolvedTarget: TerminalResolvedTarget?
    public let jumpResult: JumpResult?

    public init(
        sessionId: String,
        status: JumpActionStatus,
        handlerId: String? = nil,
        precision: JumpPrecision? = nil,
        failureReason: JumpActionFailureReason? = nil,
        repairAction: String? = nil,
        diagnosticSummary: String,
        resolvedTarget: TerminalResolvedTarget? = nil,
        jumpResult: JumpResult? = nil
    ) {
        self.sessionId = sessionId
        self.status = status
        self.handlerId = handlerId
        self.precision = precision
        self.failureReason = failureReason
        self.repairAction = repairAction
        self.diagnosticSummary = diagnosticSummary
        self.resolvedTarget = resolvedTarget
        self.jumpResult = jumpResult
    }
}

public struct ActionRouter: Sendable {
    private let sessionCoordinator: SessionCoordinator
    private let resolver: TerminalResolver
    private let jumpRouter: TerminalJumpRouter

    public init(
        sessionCoordinator: SessionCoordinator,
        resolver: TerminalResolver = TerminalResolver(),
        jumpRouter: TerminalJumpRouter = TerminalJumpRouter()
    ) {
        self.sessionCoordinator = sessionCoordinator
        self.resolver = resolver
        self.jumpRouter = jumpRouter
    }

    public func jumpToSession(sessionId: String) -> JumpActionPlan {
        guard let state = sessionCoordinator.snapshot(sessionId: sessionId) else {
            return unavailable(
                sessionId: sessionId,
                reason: .missingSession,
                diagnosticSummary: "missing session"
            )
        }

        return jumpToSession(state: state)
    }

    public func jumpToSession(state: SessionState) -> JumpActionPlan {
        let sessionId = state.sessionId

        guard let target = state.resolvedJumpTarget ?? state.jumpInput.map({ resolver.resolve($0) }) else {
            return unavailable(
                sessionId: sessionId,
                reason: .missingJumpTarget,
                diagnosticSummary: "missing jump target"
            )
        }

        let result = jumpRouter.planJump(target.input)
        let status: JumpActionStatus
        let failureReason: JumpActionFailureReason?

        switch result.precision {
        case .unsupported:
            status = .unavailable
            failureReason = .unsupportedTarget
        case .remoteHint:
            status = .repairRequired
            failureReason = .remoteRequiresReconnect
        case .exactPane, .exactWindow, .workspace, .application:
            status = .planned
            failureReason = nil
        }

        return JumpActionPlan(
            sessionId: sessionId,
            status: status,
            handlerId: result.handlerId,
            precision: result.precision,
            failureReason: failureReason,
            repairAction: result.repairAction,
            diagnosticSummary: result.diagnosticSummary,
            resolvedTarget: target,
            jumpResult: result
        )
    }

    private func unavailable(
        sessionId: String,
        reason: JumpActionFailureReason,
        diagnosticSummary: String
    ) -> JumpActionPlan {
        JumpActionPlan(
            sessionId: sessionId,
            status: .unavailable,
            failureReason: reason,
            diagnosticSummary: diagnosticSummary
        )
    }
}
