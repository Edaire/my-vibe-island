import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitLaunchAtLoginController {
    public private(set) var state: LaunchAtLoginState
    public private(set) var lastPlan: LaunchAtLoginPlan?

    private let service: LaunchAtLoginService
    private let applyDesiredEnabled: @MainActor (Bool) -> Void
    private let publishRepairHint: @MainActor (String) -> Void

    public init(
        state: LaunchAtLoginState = LaunchAtLoginState(),
        service: LaunchAtLoginService = LaunchAtLoginService(),
        applyDesiredEnabled: @escaping @MainActor (Bool) -> Void = { _ in },
        publishRepairHint: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        self.state = state
        self.service = service
        self.applyDesiredEnabled = applyDesiredEnabled
        self.publishRepairHint = publishRepairHint
    }

    @discardableResult
    public func setEnabled(_ isEnabled: Bool) -> LaunchAtLoginPlan {
        apply(.setDesiredEnabled(isEnabled))
    }

    @discardableResult
    public func observeEnabled(_ isEnabled: Bool) -> LaunchAtLoginPlan {
        apply(.observeEnabled(isEnabled))
    }

    @discardableResult
    public func recordFailure(_ error: String) -> LaunchAtLoginPlan {
        apply(.recordFailure(error))
    }

    private func apply(_ command: LaunchAtLoginCommand) -> LaunchAtLoginPlan {
        let plan = service.plan(command, from: state)
        state = plan.nextState
        lastPlan = plan

        switch plan.action {
        case .updateDesired:
            applyDesiredEnabled(state.desiredEnabled)
        case .recordRepairHint:
            if let lastError = state.lastError {
                publishRepairHint(lastError)
            }
        case .stateMatched, .needsReconcile:
            break
        }

        return plan
    }
}
