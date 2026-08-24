import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitLocalSessionJumpCoordinator {
    public private(set) var lastSelectedSessionId: String?
    public private(set) var lastJumpedSessionId: String?
    public private(set) var lastJumpResult: TerminalJumpExecutionResult?
    public private(set) var lastLegacyResolution: ActionResolution?

    private let runtime: AppRuntime
    private let executeJump: @Sendable (String) -> TerminalJumpExecutionResult
    private var inFlightJumpSessionIDs = Set<String>()

    public init(runtime: AppRuntime) {
        self.runtime = runtime
        executeJump = { sessionID in
            runtime.executeJumpToSession(sessionId: sessionID, mode: .execute)
        }
    }

    public init(
        runtime: AppRuntime,
        executeJump: @escaping @Sendable (String) -> TerminalJumpExecutionResult
    ) {
        self.runtime = runtime
        self.executeJump = executeJump
    }

    public func selectSession(_ sessionId: String) {
        lastSelectedSessionId = sessionId
        runtime.setActiveSessionId(sessionId)
    }

    @discardableResult
    public func jumpToSession(_ sessionId: String) -> Bool {
        guard inFlightJumpSessionIDs.insert(sessionId).inserted else {
            return false
        }
        lastJumpedSessionId = sessionId
        Task.detached(priority: .utility) { [executeJump] in
            let result = executeJump(sessionId)
            await self.completeJump(sessionId, result: result)
        }
        return true
    }

    public func isJumpInFlight(_ sessionId: String) -> Bool {
        inFlightJumpSessionIDs.contains(sessionId)
    }

    private func completeJump(_ sessionId: String, result: TerminalJumpExecutionResult) {
        inFlightJumpSessionIDs.remove(sessionId)
        lastJumpResult = result
        SessionCompletionTraceLog.append(
            stage: "terminal.jump",
            sessionId: sessionId,
            metadata: [
                "status": result.status.rawValue,
                "handler": result.handlerId ?? "-",
                "precision": result.precision?.rawValue ?? "-",
                "blockReason": result.blockReason?.rawValue ?? "-",
                "diagnostic": result.diagnosticSummary,
                "target": result.actionDescription?.target ?? "-",
                "arguments": result.actionDescription?.arguments.joined(separator: ",") ?? "-",
            ]
        )
    }

    @discardableResult
    public func resolveAction(_ resolution: ActionResolution) -> Bool {
        runtime.resolveAction(resolution)
    }

    @discardableResult
    public func resolveAction(requestId: String, sessionId: String) -> Bool {
        resolveLegacyAction(ActionResolution(requestId: requestId, sessionId: sessionId, kind: .approve))
    }

    @discardableResult
    public func resolveAnswer(requestId: String, sessionId: String) -> Bool {
        resolveLegacyAction(ActionResolution(requestId: requestId, sessionId: sessionId, kind: .answer))
    }

    private func resolveLegacyAction(_ resolution: ActionResolution) -> Bool {
        lastLegacyResolution = resolution
        return runtime.resolveAction(resolution)
    }
}
