public enum IntegrationInstallState: String, Codable, Equatable, Sendable {
    case notInstalled
    case installed
    case needsRepair
    case unsupported
}

public enum IntegrationHealthState: String, Codable, Equatable, Sendable {
    case unknown
    case healthy
    case warning
    case failed
}

public struct IntegrationStatusRow: Codable, Equatable, Sendable {
    public let sourceId: String
    public let displayName: String
    public let supportLevel: AgentSupportLevel
    public let installState: IntegrationInstallState
    public let healthState: IntegrationHealthState
    public let repairAction: String?
    public let diagnostics: [String]

    public init(
        sourceId: String,
        displayName: String,
        supportLevel: AgentSupportLevel,
        installState: IntegrationInstallState,
        healthState: IntegrationHealthState,
        repairAction: String? = nil,
        diagnostics: [String] = []
    ) {
        self.sourceId = sourceId
        self.displayName = displayName
        self.supportLevel = supportLevel
        self.installState = installState
        self.healthState = healthState
        self.repairAction = repairAction
        self.diagnostics = diagnostics
    }
}

public struct IntegrationCoordinatorState: Codable, Equatable, Sendable {
    public let rows: [IntegrationStatusRow]
    public let lastCheckedAt: String?

    public init(
        rows: [IntegrationStatusRow] = [],
        lastCheckedAt: String? = nil
    ) {
        self.rows = rows.sorted { lhs, rhs in
            if lhs.sourceId == rhs.sourceId {
                return lhs.displayName < rhs.displayName
            }
            return lhs.sourceId < rhs.sourceId
        }
        self.lastCheckedAt = lastCheckedAt
    }
}

public enum IntegrationCoordinatorCommand: Equatable, Sendable {
    case refresh(at: String)
    case install(sourceId: String)
    case repair(sourceId: String)
    case uninstall(sourceId: String)
}

public enum IntegrationCoordinatorPlanAction: String, Codable, Equatable, Sendable {
    case refresh
    case install
    case repair
    case uninstall
    case ignoreUnknownSource
}

public struct IntegrationCoordinatorPlan: Codable, Equatable, Sendable {
    public let action: IntegrationCoordinatorPlanAction
    public let sourceId: String?
    public let nextState: IntegrationCoordinatorState

    public init(
        action: IntegrationCoordinatorPlanAction,
        sourceId: String? = nil,
        nextState: IntegrationCoordinatorState
    ) {
        self.action = action
        self.sourceId = sourceId
        self.nextState = nextState
    }
}

public struct IntegrationCoordinator: Sendable {
    public let registry: AgentRegistry

    public init(registry: AgentRegistry = .default) {
        self.registry = registry
    }

    public func initialState(lastCheckedAt: String? = nil) -> IntegrationCoordinatorState {
        IntegrationCoordinatorState(
            rows: registry.descriptors.map { descriptor in
                IntegrationStatusRow(
                    sourceId: descriptor.id,
                    displayName: descriptor.displayName,
                    supportLevel: descriptor.supportLevel,
                    installState: descriptor.supportLevel == .planned ? .unsupported : .notInstalled,
                    healthState: .unknown
                )
            },
            lastCheckedAt: lastCheckedAt
        )
    }

    public func plan(
        _ command: IntegrationCoordinatorCommand,
        from state: IntegrationCoordinatorState
    ) -> IntegrationCoordinatorPlan {
        switch command {
        case let .refresh(at):
            return IntegrationCoordinatorPlan(
                action: .refresh,
                nextState: IntegrationCoordinatorState(rows: state.rows, lastCheckedAt: at)
            )
        case let .install(sourceId):
            return sourcePlan(action: .install, sourceId: sourceId, state: state)
        case let .repair(sourceId):
            return sourcePlan(action: .repair, sourceId: sourceId, state: state)
        case let .uninstall(sourceId):
            return sourcePlan(action: .uninstall, sourceId: sourceId, state: state)
        }
    }

    private func sourcePlan(
        action: IntegrationCoordinatorPlanAction,
        sourceId: String,
        state: IntegrationCoordinatorState
    ) -> IntegrationCoordinatorPlan {
        guard registry.descriptor(for: sourceId) != nil else {
            return IntegrationCoordinatorPlan(action: .ignoreUnknownSource, nextState: state)
        }

        return IntegrationCoordinatorPlan(action: action, sourceId: sourceId, nextState: state)
    }
}
