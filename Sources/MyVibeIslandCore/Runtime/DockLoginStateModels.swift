public enum DockActivationPolicy: String, Codable, Equatable, Sendable {
    case accessory
    case regular
}

public enum DockPolicyChangeReason: String, Codable, Equatable, Sendable {
    case initial
    case userPreference
    case restoredSettings
}

public enum DockReopenBehavior: String, Codable, Equatable, Sendable {
    case showIsland
    case openSettings
    case ignore
}

public struct DockIconControllerState: Codable, Equatable, Sendable {
    public let preferredDockVisible: Bool
    public let currentPolicy: DockActivationPolicy
    public let lastPolicyChangeReason: DockPolicyChangeReason
    public let reopenBehavior: DockReopenBehavior

    public init(
        preferredDockVisible: Bool = false,
        currentPolicy: DockActivationPolicy = .accessory,
        lastPolicyChangeReason: DockPolicyChangeReason = .initial,
        reopenBehavior: DockReopenBehavior = .showIsland
    ) {
        self.preferredDockVisible = preferredDockVisible
        self.currentPolicy = currentPolicy
        self.lastPolicyChangeReason = lastPolicyChangeReason
        self.reopenBehavior = reopenBehavior
    }
}

public enum DockIconControllerCommand: Equatable, Sendable {
    case setPreferredDockVisible(Bool, reason: DockPolicyChangeReason)
}

public enum DockIconControllerAction: String, Codable, Equatable, Sendable {
    case noChange
    case setAccessoryPolicy
    case setRegularPolicy
}

public struct DockIconControllerPlan: Equatable, Sendable {
    public let action: DockIconControllerAction
    public let nextState: DockIconControllerState

    public init(action: DockIconControllerAction, nextState: DockIconControllerState) {
        self.action = action
        self.nextState = nextState
    }
}

public struct DockIconController: Sendable {
    public init() {}

    public func plan(
        _ command: DockIconControllerCommand,
        from state: DockIconControllerState
    ) -> DockIconControllerPlan {
        switch command {
        case let .setPreferredDockVisible(isVisible, reason):
            let targetPolicy: DockActivationPolicy = isVisible ? .regular : .accessory
            guard state.preferredDockVisible != isVisible || state.currentPolicy != targetPolicy else {
                return DockIconControllerPlan(action: .noChange, nextState: state)
            }

            return DockIconControllerPlan(
                action: isVisible ? .setRegularPolicy : .setAccessoryPolicy,
                nextState: DockIconControllerState(
                    preferredDockVisible: isVisible,
                    currentPolicy: targetPolicy,
                    lastPolicyChangeReason: reason,
                    reopenBehavior: state.reopenBehavior
                )
            )
        }
    }

    public static func safeDockMenuCommands(from snapshot: AppMenuSnapshot) -> [AppCommand] {
        [.openSettings, .checkForUpdates, .exportDiagnostics, .quit]
            .filter(snapshot.isEnabled)
            .filter { command in
                command != .exportDiagnostics || snapshot.diagnosticsExportAvailable
            }
    }
}

public enum LaunchAtLoginReconciliationResult: String, Codable, Equatable, Sendable {
    case unknown
    case pending
    case matched
    case mismatched
    case failed
}

public struct LaunchAtLoginState: Codable, Equatable, Sendable {
    public let desiredEnabled: Bool
    public let observedEnabled: Bool
    public let reconciliationResult: LaunchAtLoginReconciliationResult
    public let lastError: String?

    public init(
        desiredEnabled: Bool = false,
        observedEnabled: Bool = false,
        reconciliationResult: LaunchAtLoginReconciliationResult = .unknown,
        lastError: String? = nil
    ) {
        self.desiredEnabled = desiredEnabled
        self.observedEnabled = observedEnabled
        self.reconciliationResult = reconciliationResult
        self.lastError = lastError
    }
}

public enum LaunchAtLoginCommand: Equatable, Sendable {
    case setDesiredEnabled(Bool)
    case observeEnabled(Bool)
    case recordFailure(String)
}

public enum LaunchAtLoginPlanAction: String, Codable, Equatable, Sendable {
    case updateDesired
    case stateMatched
    case needsReconcile
    case recordRepairHint
}

public struct LaunchAtLoginPlan: Equatable, Sendable {
    public let action: LaunchAtLoginPlanAction
    public let nextState: LaunchAtLoginState

    public init(action: LaunchAtLoginPlanAction, nextState: LaunchAtLoginState) {
        self.action = action
        self.nextState = nextState
    }
}

public struct LaunchAtLoginService: Sendable {
    public init() {}

    public func plan(_ command: LaunchAtLoginCommand, from state: LaunchAtLoginState) -> LaunchAtLoginPlan {
        switch command {
        case let .setDesiredEnabled(isEnabled):
            return LaunchAtLoginPlan(
                action: .updateDesired,
                nextState: LaunchAtLoginState(
                    desiredEnabled: isEnabled,
                    observedEnabled: state.observedEnabled,
                    reconciliationResult: .pending
                )
            )
        case let .observeEnabled(isEnabled):
            let result: LaunchAtLoginReconciliationResult = state.desiredEnabled == isEnabled ? .matched : .mismatched
            return LaunchAtLoginPlan(
                action: result == .matched ? .stateMatched : .needsReconcile,
                nextState: LaunchAtLoginState(
                    desiredEnabled: state.desiredEnabled,
                    observedEnabled: isEnabled,
                    reconciliationResult: result
                )
            )
        case let .recordFailure(error):
            return LaunchAtLoginPlan(
                action: .recordRepairHint,
                nextState: LaunchAtLoginState(
                    desiredEnabled: state.desiredEnabled,
                    observedEnabled: state.observedEnabled,
                    reconciliationResult: .failed,
                    lastError: error
                )
            )
        }
    }
}
