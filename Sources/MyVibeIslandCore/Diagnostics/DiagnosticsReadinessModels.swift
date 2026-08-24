import Foundation

public enum DiagnosticRepairability: String, Codable, Equatable, Sendable {
    case none
    case manualOnly
    case appCanRepairManagedBlock
    case appCanReinstallHelper
    case userActionRequired
    case unsupported
}

public enum DiagnosticRepairHintSeverity: String, Codable, Equatable, Sendable {
    case repairable
    case blocking
}

public struct DiagnosticRepairHint: Codable, Equatable, Sendable {
    public let source: String
    public let message: String
    public let repairability: DiagnosticRepairability
    public let severity: DiagnosticRepairHintSeverity

    public init(
        source: String,
        message: String,
        repairability: DiagnosticRepairability,
        severity: DiagnosticRepairHintSeverity
    ) {
        self.source = source
        self.message = message
        self.repairability = repairability
        self.severity = severity
    }
}

public enum DiagnosticReadinessOutcome: String, Codable, Equatable, Sendable {
    case ready
    case partial
    case demoOnly
    case blocked
}

public struct DiagnosticReadinessSummary: Codable, Equatable, Sendable {
    public let outcome: DiagnosticReadinessOutcome
    public let repairHints: [DiagnosticRepairHint]

    public init(
        outcome: DiagnosticReadinessOutcome,
        repairHints: [DiagnosticRepairHint] = []
    ) {
        self.outcome = outcome
        self.repairHints = repairHints
    }
}
