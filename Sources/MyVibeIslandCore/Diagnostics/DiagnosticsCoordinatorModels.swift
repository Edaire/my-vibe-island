import Foundation

public struct DiagnosticsCoordinatorSnapshot: Codable, Equatable, Sendable {
    public let capturedAt: String?
    public let environment: EnvironmentScanResult?
    public let provenance: ProvenanceAssessment?
    public let memory: MemoryFootprintSnapshot?
    public let displaySleep: DisplaySleepSnapshot?
    public let hangSamples: [MainThreadHangSnapshot]
    public let logEntries: [DiagnosticLogEntry]

    public init(
        capturedAt: String? = nil,
        environment: EnvironmentScanResult? = nil,
        provenance: ProvenanceAssessment? = nil,
        memory: MemoryFootprintSnapshot? = nil,
        displaySleep: DisplaySleepSnapshot? = nil,
        hangSamples: [MainThreadHangSnapshot] = [],
        logEntries: [DiagnosticLogEntry] = []
    ) {
        self.capturedAt = capturedAt
        self.environment = environment
        self.provenance = provenance
        self.memory = memory
        self.displaySleep = displaySleep
        self.hangSamples = hangSamples
        self.logEntries = logEntries
    }
}

public struct DiagnosticsCoordinator: Sendable {
    public let exportBuilder: DiagnosticExportBuilder
    public let exportWriter: DiagnosticExportWriter

    public init(
        exportBuilder: DiagnosticExportBuilder = DiagnosticExportBuilder(),
        exportWriter: DiagnosticExportWriter = DiagnosticExportWriter()
    ) {
        self.exportBuilder = exportBuilder
        self.exportWriter = exportWriter
    }

    public func exportPlan(from inputs: [DiagnosticExportSectionInput]) -> DiagnosticExportWritePlan {
        let sections = exportBuilder.buildSections(from: inputs)
        return exportWriter.planWrite(sections: sections)
    }

    public func readinessSummary(
        for snapshot: DiagnosticsCoordinatorSnapshot,
        repairHints: [DiagnosticRepairHint] = []
    ) -> DiagnosticReadinessSummary {
        if repairHints.contains(where: { $0.severity == .blocking }) {
            return DiagnosticReadinessSummary(outcome: .blocked, repairHints: repairHints)
        }

        if !repairHints.isEmpty {
            return DiagnosticReadinessSummary(outcome: .partial, repairHints: repairHints)
        }

        let hasDetectedAgent = snapshot.environment?.agents.contains(where: \.isDetected) ?? false
        if !hasDetectedAgent {
            return DiagnosticReadinessSummary(outcome: .demoOnly)
        }

        return DiagnosticReadinessSummary(outcome: .ready)
    }
}
