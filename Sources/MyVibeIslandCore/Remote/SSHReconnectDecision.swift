public enum SSHReconnectDecisionAction: String, Codable, Equatable, Sendable {
    case observe
    case promptUser
    case attemptReconnect
    case suppressedByPolicy
    case suppressedByUserDisconnect
}

public struct SSHReconnectDecision: Codable, Equatable, Sendable {
    public let hostId: String
    public let policy: SSHReconnectPolicy
    public let healthCheckFailureCount: Int
    public let failureThreshold: Int
    public let userDisconnected: Bool
    public let tunnelStatus: TunnelStatus
    public let failureKind: SSHTunnelFailureKind
    public let action: SSHReconnectDecisionAction
    public let reconnectHint: SSHReconnectHint?
    public let diagnosticSummary: String

    public init(
        hostId: String,
        policy: SSHReconnectPolicy,
        healthCheckFailureCount: Int,
        failureThreshold: Int,
        userDisconnected: Bool,
        tunnelStatus: TunnelStatus,
        failureKind: SSHTunnelFailureKind
    ) {
        self.hostId = hostId
        self.policy = policy
        self.healthCheckFailureCount = healthCheckFailureCount
        self.failureThreshold = max(1, failureThreshold)
        self.userDisconnected = userDisconnected
        self.tunnelStatus = tunnelStatus
        self.failureKind = failureKind

        let action = Self.action(
            policy: policy,
            healthCheckFailureCount: healthCheckFailureCount,
            failureThreshold: self.failureThreshold,
            userDisconnected: userDisconnected
        )
        self.action = action
        self.reconnectHint = Self.reconnectHint(hostId: hostId, failureKind: failureKind, action: action)
        self.diagnosticSummary = Self.diagnosticSummary(hostId: hostId, action: action)
    }

    private static func action(
        policy: SSHReconnectPolicy,
        healthCheckFailureCount: Int,
        failureThreshold: Int,
        userDisconnected: Bool
    ) -> SSHReconnectDecisionAction {
        if userDisconnected {
            return .suppressedByUserDisconnect
        }

        guard healthCheckFailureCount >= failureThreshold else {
            return .observe
        }

        switch policy {
        case .automaticForKnownHost:
            return .attemptReconnect
        case .promptBeforeReconnect:
            return .promptUser
        case .manualOnly:
            return .suppressedByPolicy
        }
    }

    private static func reconnectHint(
        hostId: String,
        failureKind: SSHTunnelFailureKind,
        action: SSHReconnectDecisionAction
    ) -> SSHReconnectHint? {
        switch action {
        case .attemptReconnect, .promptUser:
            return SSHReconnectHint.fromFailureKind(failureKind, hostId: hostId)
        case .observe, .suppressedByPolicy, .suppressedByUserDisconnect:
            return nil
        }
    }

    private static func diagnosticSummary(hostId: String, action: SSHReconnectDecisionAction) -> String {
        switch action {
        case .observe:
            return "\(hostId) reconnect observing healthcheck failures"
        case .promptUser:
            return "\(hostId) reconnect requires user confirmation"
        case .attemptReconnect:
            return "\(hostId) reconnect eligible after healthcheck threshold"
        case .suppressedByPolicy:
            return "\(hostId) reconnect suppressed by manual policy"
        case .suppressedByUserDisconnect:
            return "\(hostId) reconnect suppressed after user disconnect"
        }
    }
}
