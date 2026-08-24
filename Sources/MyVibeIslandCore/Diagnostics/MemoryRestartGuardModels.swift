import Foundation

public enum MemoryRestartGuardAction: String, Codable, Equatable, Sendable {
    case none
    case warnOnly
    case restartEligible
}

public enum MemoryRestartGuardReason: String, Codable, Equatable, Sendable {
    case belowWarningThreshold
    case belowRestartThreshold
    case labsOptInDisabled
    case notIdle
    case restartLimitReached
    case eligible
}

public struct MemoryRestartGuardPolicy: Codable, Equatable, Sendable {
    public let warningThresholdBytes: Int64
    public let restartThresholdBytes: Int64
    public let maxRestartAttempts: Int
    public let labsRestartOptInEnabled: Bool

    public init(
        warningThresholdBytes: Int64,
        restartThresholdBytes: Int64,
        maxRestartAttempts: Int,
        labsRestartOptInEnabled: Bool
    ) {
        self.warningThresholdBytes = warningThresholdBytes
        self.restartThresholdBytes = restartThresholdBytes
        self.maxRestartAttempts = max(0, maxRestartAttempts)
        self.labsRestartOptInEnabled = labsRestartOptInEnabled
    }
}

public struct MemoryRestartGuardState: Codable, Equatable, Sendable {
    public let restartCount: Int
    public let lastRestartAt: String?
    public let lastWarningAt: String?

    public init(
        restartCount: Int,
        lastRestartAt: String? = nil,
        lastWarningAt: String? = nil
    ) {
        self.restartCount = max(0, restartCount)
        self.lastRestartAt = lastRestartAt
        self.lastWarningAt = lastWarningAt
    }
}

public struct MemoryRestartGuardContext: Codable, Equatable, Sendable {
    public let isIdle: Bool
    public let hasActiveSession: Bool
    public let hasPendingApproval: Bool

    public init(
        isIdle: Bool,
        hasActiveSession: Bool,
        hasPendingApproval: Bool
    ) {
        self.isIdle = isIdle
        self.hasActiveSession = hasActiveSession
        self.hasPendingApproval = hasPendingApproval
    }
}

public struct MemoryRestartGuardDecision: Codable, Equatable, Sendable {
    public let action: MemoryRestartGuardAction
    public let reason: MemoryRestartGuardReason
    public let isRestartEligible: Bool

    public init(
        action: MemoryRestartGuardAction,
        reason: MemoryRestartGuardReason,
        isRestartEligible: Bool
    ) {
        self.action = action
        self.reason = reason
        self.isRestartEligible = isRestartEligible
    }
}

public struct MemoryRestartGuard: Sendable {
    public init() {}

    public func evaluate(
        snapshot: MemoryFootprintSnapshot,
        state: MemoryRestartGuardState,
        policy: MemoryRestartGuardPolicy,
        context: MemoryRestartGuardContext
    ) -> MemoryRestartGuardDecision {
        if snapshot.physicalFootprintBytes < policy.warningThresholdBytes {
            return MemoryRestartGuardDecision(
                action: .none,
                reason: .belowWarningThreshold,
                isRestartEligible: false
            )
        }

        if snapshot.physicalFootprintBytes < policy.restartThresholdBytes {
            return MemoryRestartGuardDecision(
                action: .warnOnly,
                reason: .belowRestartThreshold,
                isRestartEligible: false
            )
        }

        guard policy.labsRestartOptInEnabled else {
            return MemoryRestartGuardDecision(
                action: .warnOnly,
                reason: .labsOptInDisabled,
                isRestartEligible: false
            )
        }

        guard context.isIdle, !context.hasActiveSession, !context.hasPendingApproval else {
            return MemoryRestartGuardDecision(
                action: .warnOnly,
                reason: .notIdle,
                isRestartEligible: false
            )
        }

        guard state.restartCount < policy.maxRestartAttempts else {
            return MemoryRestartGuardDecision(
                action: .warnOnly,
                reason: .restartLimitReached,
                isRestartEligible: false
            )
        }

        return MemoryRestartGuardDecision(
            action: .restartEligible,
            reason: .eligible,
            isRestartEligible: true
        )
    }
}
