import Foundation

public struct EnvironmentScanResult: Codable, Equatable, Sendable {
    public typealias AgentInfo = EnvironmentAgentInfo
    public typealias TerminalInfo = EnvironmentTerminalInfo

    public let scannedAt: String?
    public let agents: [EnvironmentAgentInfo]
    public let terminals: [EnvironmentTerminalInfo]

    public init(
        scannedAt: String? = nil,
        agents: [EnvironmentAgentInfo] = [],
        terminals: [EnvironmentTerminalInfo] = []
    ) {
        self.scannedAt = scannedAt
        self.agents = agents
        self.terminals = terminals
    }
}

public enum EnvironmentAgentAuthorizationState: String, Codable, Equatable, Sendable {
    case authorized
    case needsUserApproval
    case denied
    case unknown
}

public enum EnvironmentAgentRepairability: String, Codable, Equatable, Sendable {
    case notNeeded
    case repairable
    case manual
    case unknown
}

public struct EnvironmentAgentInfo: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isDetected: Bool
    public let supportLevel: AgentSupportLevel
    public let isInstalled: Bool
    public let isConfigured: Bool
    public let authorizationState: EnvironmentAgentAuthorizationState
    public let repairability: EnvironmentAgentRepairability
    public let lastCheckedAt: String?

    public init(
        id: String,
        name: String,
        isDetected: Bool,
        supportLevel: AgentSupportLevel = .unknown,
        isInstalled: Bool? = nil,
        isConfigured: Bool = false,
        authorizationState: EnvironmentAgentAuthorizationState = .unknown,
        repairability: EnvironmentAgentRepairability = .unknown,
        lastCheckedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isDetected = isDetected
        self.supportLevel = supportLevel
        self.isInstalled = isInstalled ?? isDetected
        self.isConfigured = isConfigured
        self.authorizationState = authorizationState
        self.repairability = repairability
        self.lastCheckedAt = lastCheckedAt
    }

    public var isReady: Bool {
        isDetected && isInstalled && isConfigured && authorizationState == .authorized
    }

    public var canRepair: Bool {
        repairability == .repairable
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case isDetected
        case supportLevel
        case isInstalled
        case isConfigured
        case authorizationState
        case repairability
        case lastCheckedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let isDetected = try container.decode(Bool.self, forKey: .isDetected)

        self.init(
            id: id,
            name: name,
            isDetected: isDetected,
            supportLevel: try container.decodeIfPresent(AgentSupportLevel.self, forKey: .supportLevel) ?? .unknown,
            isInstalled: try container.decodeIfPresent(Bool.self, forKey: .isInstalled),
            isConfigured: try container.decodeIfPresent(Bool.self, forKey: .isConfigured) ?? false,
            authorizationState: try container.decodeIfPresent(
                EnvironmentAgentAuthorizationState.self,
                forKey: .authorizationState
            ) ?? .unknown,
            repairability: try container.decodeIfPresent(
                EnvironmentAgentRepairability.self,
                forKey: .repairability
            ) ?? .unknown,
            lastCheckedAt: try container.decodeIfPresent(String.self, forKey: .lastCheckedAt)
        )
    }
}

public struct EnvironmentTerminalInfo: Codable, Equatable, Sendable {
    public let name: String
    public let isDetected: Bool

    public init(
        name: String,
        isDetected: Bool
    ) {
        self.name = name
        self.isDetected = isDetected
    }
}
