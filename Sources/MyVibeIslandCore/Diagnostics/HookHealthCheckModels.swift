import Foundation

public enum HookHealthStatus: String, Codable, Equatable, Sendable {
    case trusted
    case unknown
    case mismatched
    case unmanaged
    case blocked
}

public struct HookHealthCheck: Codable, Equatable, Sendable {
    public let sourceID: String
    public let status: HookHealthStatus
    public let observedAt: String?
    public let provenance: ProvenanceAssessment?
    public let redactedConfigPath: String?

    public init(
        sourceID: String,
        status: HookHealthStatus,
        observedAt: String? = nil,
        provenance: ProvenanceAssessment? = nil,
        redactedConfigPath: String? = nil
    ) {
        self.sourceID = sourceID
        self.status = status
        self.observedAt = observedAt
        self.provenance = provenance
        self.redactedConfigPath = redactedConfigPath
    }

    public var repairHint: DiagnosticRepairHint? {
        switch status {
        case .mismatched:
            return DiagnosticRepairHint(
                source: sourceID,
                message: "Managed hook command differs from the expected helper.",
                repairability: .appCanRepairManagedBlock,
                severity: .repairable
            )
        case .blocked:
            return DiagnosticRepairHint(
                source: sourceID,
                message: "Hook integration is disabled for this source.",
                repairability: .userActionRequired,
                severity: .blocking
            )
        case .trusted, .unknown, .unmanaged:
            return nil
        }
    }
}
