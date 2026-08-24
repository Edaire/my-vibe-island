import Foundation

public enum OnboardingInstalledState: String, Codable, Equatable, Sendable {
    case installed
    case missing
    case unknown
}

public enum OnboardingHookConfiguredState: String, Codable, Equatable, Sendable {
    case configured
    case missing
    case unknown
}

public enum OnboardingAvailabilityState: String, Codable, Equatable, Sendable {
    case available
    case unavailable
    case unknown
}

public enum OnboardingPermissionState: String, Codable, Equatable, Sendable {
    case granted
    case denied
    case notDetermined
    case notRequired
    case unknown
}

public struct AgentReadiness: Codable, Equatable, Sendable {
    public let agentId: String
    public let supportLevel: AgentSupportLevel
    public let installedState: OnboardingInstalledState
    public let hookConfiguredState: OnboardingHookConfiguredState
    public let watcherAvailableState: OnboardingAvailabilityState
    public let repairAction: String?
    public let blockingIssue: String?
    public let lastCheckedAt: String?

    public var isReady: Bool {
        installedState == .installed
            && hookConfiguredState == .configured
            && watcherAvailableState == .available
            && blockingIssue == nil
    }

    public init(
        agentId: String,
        supportLevel: AgentSupportLevel,
        installedState: OnboardingInstalledState,
        hookConfiguredState: OnboardingHookConfiguredState,
        watcherAvailableState: OnboardingAvailabilityState,
        repairAction: String? = nil,
        blockingIssue: String? = nil,
        lastCheckedAt: String? = nil
    ) {
        self.agentId = agentId
        self.supportLevel = supportLevel
        self.installedState = installedState
        self.hookConfiguredState = hookConfiguredState
        self.watcherAvailableState = watcherAvailableState
        self.repairAction = repairAction
        self.blockingIssue = blockingIssue
        self.lastCheckedAt = lastCheckedAt
    }
}

public struct TerminalReadiness: Codable, Equatable, Sendable {
    public let terminalId: String
    public let installedState: OnboardingInstalledState
    public let permissionState: OnboardingPermissionState
    public let jumpCapabilityState: OnboardingAvailabilityState
    public let repairAction: String?
    public let lastCheckedAt: String?

    public var isReady: Bool {
        installedState == .installed
            && (permissionState == .granted || permissionState == .notRequired)
            && jumpCapabilityState == .available
    }

    public init(
        terminalId: String,
        installedState: OnboardingInstalledState,
        permissionState: OnboardingPermissionState,
        jumpCapabilityState: OnboardingAvailabilityState,
        repairAction: String? = nil,
        lastCheckedAt: String? = nil
    ) {
        self.terminalId = terminalId
        self.installedState = installedState
        self.permissionState = permissionState
        self.jumpCapabilityState = jumpCapabilityState
        self.repairAction = repairAction
        self.lastCheckedAt = lastCheckedAt
    }
}

public struct PermissionReadiness: Codable, Equatable, Sendable {
    public let permissionKind: TerminalPermissionRequirement
    public let status: OnboardingPermissionState
    public let requiredByFeature: String
    public let repairInstructions: String?
    public let lastCheckedAt: String?

    public var isBlocking: Bool {
        status == .denied || status == .notDetermined
    }

    public var blockingIssue: String? {
        guard isBlocking else {
            return nil
        }
        return "\(permissionKind.rawValue) permission \(status.rawValue) for \(requiredByFeature)"
    }

    public init(
        permissionKind: TerminalPermissionRequirement,
        status: OnboardingPermissionState,
        requiredByFeature: String,
        repairInstructions: String? = nil,
        lastCheckedAt: String? = nil
    ) {
        self.permissionKind = permissionKind
        self.status = status
        self.requiredByFeature = requiredByFeature
        self.repairInstructions = repairInstructions
        self.lastCheckedAt = lastCheckedAt
    }
}

public struct ReadinessScanResult: Codable, Equatable, Sendable {
    public let generatedAt: String?
    public let agents: [AgentReadiness]
    public let terminals: [TerminalReadiness]
    public let permissions: [PermissionReadiness]
    public let environmentScanSummary: DiagnosticReadinessSummary?
    public let blockingIssues: [String]
    public let repairActions: [String]
    public let outcome: DiagnosticReadinessOutcome

    public init(
        generatedAt: String? = nil,
        agents: [AgentReadiness] = [],
        terminals: [TerminalReadiness] = [],
        permissions: [PermissionReadiness] = [],
        environmentScanSummary: DiagnosticReadinessSummary? = nil
    ) {
        self.generatedAt = generatedAt
        self.agents = agents
        self.terminals = terminals
        self.permissions = permissions
        self.environmentScanSummary = environmentScanSummary

        let blockingIssues = Self.deriveBlockingIssues(
            agents: agents,
            permissions: permissions,
            environmentScanSummary: environmentScanSummary
        )
        let repairActions = Self.deriveRepairActions(
            agents: agents,
            terminals: terminals,
            permissions: permissions,
            environmentScanSummary: environmentScanSummary
        )
        self.blockingIssues = blockingIssues
        self.repairActions = repairActions
        self.outcome = Self.deriveOutcome(
            agents: agents,
            terminals: terminals,
            blockingIssues: blockingIssues,
            repairActions: repairActions,
            environmentScanSummary: environmentScanSummary
        )
    }

    private static func deriveBlockingIssues(
        agents: [AgentReadiness],
        permissions: [PermissionReadiness],
        environmentScanSummary: DiagnosticReadinessSummary?
    ) -> [String] {
        let agentIssues = agents.compactMap(\.blockingIssue)
        let permissionIssues = permissions.compactMap(\.blockingIssue)
        let scanIssues = environmentScanSummary?.repairHints
            .filter { $0.severity == .blocking }
            .map(\.message) ?? []
        return unique(agentIssues + permissionIssues + scanIssues)
    }

    private static func deriveRepairActions(
        agents: [AgentReadiness],
        terminals: [TerminalReadiness],
        permissions: [PermissionReadiness],
        environmentScanSummary: DiagnosticReadinessSummary?
    ) -> [String] {
        let scanRepairs = environmentScanSummary?.repairHints.map(\.message) ?? []
        return unique(
            agents.compactMap(\.repairAction)
                + terminals.compactMap(\.repairAction)
                + permissions.compactMap(\.repairInstructions)
                + scanRepairs
        )
    }

    private static func deriveOutcome(
        agents: [AgentReadiness],
        terminals: [TerminalReadiness],
        blockingIssues: [String],
        repairActions: [String],
        environmentScanSummary: DiagnosticReadinessSummary?
    ) -> DiagnosticReadinessOutcome {
        if !blockingIssues.isEmpty || environmentScanSummary?.outcome == .blocked {
            return .blocked
        }

        if !repairActions.isEmpty || environmentScanSummary?.outcome == .partial {
            return .partial
        }

        if agents.contains(where: \.isReady) || terminals.contains(where: \.isReady) {
            return .ready
        }

        return .demoOnly
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values where !value.isEmpty && !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}
