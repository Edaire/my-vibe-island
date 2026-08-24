import Foundation

public struct LabsToolAvailability: Codable, Equatable, Sendable {
    public let hasClaude: Bool
    public let hasCodex: Bool
    public let hasCursor: Bool
    public let hasKiro: Bool

    public init(
        hasClaude: Bool = false,
        hasCodex: Bool = false,
        hasCursor: Bool = false,
        hasKiro: Bool = false
    ) {
        self.hasClaude = hasClaude
        self.hasCodex = hasCodex
        self.hasCursor = hasCursor
        self.hasKiro = hasKiro
    }
}

public enum LabsToolId: String, Codable, Equatable, CaseIterable, Sendable {
    case claude
    case codex
    case cursor
    case kiro
}

public enum LabsAvailabilityStatus: String, Codable, Equatable, Sendable {
    case available
    case unavailable
}

public enum LabsUnavailableReason: String, Codable, Equatable, Sendable {
    case toolNotDetected
    case userDisabled
}

public enum LabsGateId: String, Codable, Equatable, Sendable {
    case autoPermissionBypass
    case codexExperimentalUsage
    case experimentalKiroSupport
}

public struct LabsGate: Codable, Equatable, Sendable {
    public let toolId: LabsToolId
    public let isEnabled: Bool
    public let reason: LabsUnavailableReason?

    public init(
        toolId: LabsToolId,
        isEnabled: Bool = true,
        reason: LabsUnavailableReason? = nil
    ) {
        self.toolId = toolId
        self.isEnabled = isEnabled
        self.reason = reason
    }
}

public struct LabsAvailabilityDiagnosticSummary: Codable, Equatable, Sendable {
    public let availableToolCount: Int
    public let unavailableToolCount: Int
    public let disabledGateCount: Int
    public let includesCommunityRegistry: Bool

    public init(
        availableToolCount: Int,
        unavailableToolCount: Int,
        disabledGateCount: Int,
        includesCommunityRegistry: Bool = false
    ) {
        self.availableToolCount = availableToolCount
        self.unavailableToolCount = unavailableToolCount
        self.disabledGateCount = disabledGateCount
        self.includesCommunityRegistry = includesCommunityRegistry
    }
}

public struct LabsToolAvailabilityRow: Codable, Equatable, Sendable {
    public let toolId: LabsToolId
    public let status: LabsAvailabilityStatus
    public let reason: LabsUnavailableReason?
    public let lastCheckedAt: String?

    public init(
        toolId: LabsToolId,
        status: LabsAvailabilityStatus,
        reason: LabsUnavailableReason? = nil,
        lastCheckedAt: String? = nil
    ) {
        self.toolId = toolId
        self.status = status
        self.reason = reason
        self.lastCheckedAt = lastCheckedAt
    }
}

public struct LabsAvailability: Codable, Equatable, Sendable {
    public let toolAvailability: LabsToolAvailability
    public let gates: [LabsGateId: LabsGate]
    public let lastCheckedAt: String?

    public var availableToolIds: [LabsToolId] {
        LabsToolId.allCases.filter { status(for: $0) == .available }
    }

    public var toolRows: [LabsToolAvailabilityRow] {
        LabsToolId.allCases.map { toolId in
            LabsToolAvailabilityRow(
                toolId: toolId,
                status: status(for: toolId),
                reason: reason(for: toolId),
                lastCheckedAt: lastCheckedAt
            )
        }
    }

    public var diagnosticSummary: LabsAvailabilityDiagnosticSummary {
        LabsAvailabilityDiagnosticSummary(
            availableToolCount: availableToolIds.count,
            unavailableToolCount: LabsToolId.allCases.count - availableToolIds.count,
            disabledGateCount: gates.values.filter { !$0.isEnabled }.count,
            includesCommunityRegistry: false
        )
    }

    public init(
        toolAvailability: LabsToolAvailability = LabsToolAvailability(),
        gates: [LabsGateId: LabsGate] = [:],
        lastCheckedAt: String? = nil
    ) {
        self.toolAvailability = toolAvailability
        self.gates = gates
        self.lastCheckedAt = lastCheckedAt
    }

    public func status(for toolId: LabsToolId) -> LabsAvailabilityStatus {
        switch toolId {
        case .claude:
            return toolAvailability.hasClaude ? .available : .unavailable
        case .codex:
            return toolAvailability.hasCodex ? .available : .unavailable
        case .cursor:
            return toolAvailability.hasCursor ? .available : .unavailable
        case .kiro:
            return toolAvailability.hasKiro ? .available : .unavailable
        }
    }

    public func reason(for toolId: LabsToolId) -> LabsUnavailableReason? {
        status(for: toolId) == .available ? nil : .toolNotDetected
    }

    public func isGateAvailable(_ gateId: LabsGateId) -> Bool {
        let gate = gates[gateId] ?? defaultGate(for: gateId)
        guard gate.isEnabled else {
            return false
        }
        return status(for: gate.toolId) == .available
    }

    private func defaultGate(for gateId: LabsGateId) -> LabsGate {
        switch gateId {
        case .autoPermissionBypass:
            return LabsGate(toolId: .claude)
        case .codexExperimentalUsage:
            return LabsGate(toolId: .codex)
        case .experimentalKiroSupport:
            return LabsGate(toolId: .kiro)
        }
    }
}
