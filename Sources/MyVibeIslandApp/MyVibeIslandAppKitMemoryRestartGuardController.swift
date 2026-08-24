import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitMemoryRestartGuardController {
    public private(set) var state: MemoryRestartGuardState
    public private(set) var lastDecision: MemoryRestartGuardDecision?

    private let guardModel: MemoryRestartGuard
    private let policy: MemoryRestartGuardPolicy
    private let publishDecision: @MainActor (MemoryRestartGuardDecision) -> Void

    public init(
        guardModel: MemoryRestartGuard = MemoryRestartGuard(),
        policy: MemoryRestartGuardPolicy = MemoryRestartGuardPolicy(
            warningThresholdBytes: 512 * 1_024 * 1_024,
            restartThresholdBytes: 1_024 * 1_024 * 1_024,
            maxRestartAttempts: 0,
            labsRestartOptInEnabled: false
        ),
        state: MemoryRestartGuardState = MemoryRestartGuardState(restartCount: 0),
        publishDecision: @escaping @MainActor (MemoryRestartGuardDecision) -> Void = { _ in }
    ) {
        self.guardModel = guardModel
        self.policy = policy
        self.state = state
        self.publishDecision = publishDecision
    }

    @discardableResult
    public func evaluate(
        snapshot: MemoryFootprintSnapshot,
        context: MemoryRestartGuardContext
    ) -> MemoryRestartGuardDecision {
        let decision = guardModel.evaluate(
            snapshot: snapshot,
            state: state,
            policy: policy,
            context: context
        )
        lastDecision = decision
        publishDecision(decision)
        return decision
    }

    @discardableResult
    public func recordRestartAttempt(at timestamp: String) -> MemoryRestartGuardState {
        state = MemoryRestartGuardState(
            restartCount: state.restartCount + 1,
            lastRestartAt: timestamp,
            lastWarningAt: state.lastWarningAt
        )
        return state
    }
}
