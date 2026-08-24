import Foundation

public enum DiagnosticExportWritePlanStatus: String, Codable, Equatable, Sendable {
    case ready
    case failedClosed
}

public struct DiagnosticExportWriteEntry: Codable, Equatable, Sendable {
    public let sectionName: String
    public let path: String
    public let redactionLevel: DiagnosticRedactionLevel
    public let fields: [String: String]

    public init(
        sectionName: String,
        path: String,
        redactionLevel: DiagnosticRedactionLevel,
        fields: [String: String]
    ) {
        self.sectionName = sectionName
        self.path = path
        self.redactionLevel = redactionLevel
        self.fields = fields
    }
}

public struct DiagnosticExportWriteFailure: Codable, Equatable, Sendable {
    public let sectionName: String
    public let error: DiagnosticBundle.DiagnosticError

    public init(sectionName: String, error: DiagnosticBundle.DiagnosticError) {
        self.sectionName = sectionName
        self.error = error
    }
}

public struct DiagnosticExportWritePlan: Codable, Equatable, Sendable {
    public let status: DiagnosticExportWritePlanStatus
    public let entries: [DiagnosticExportWriteEntry]
    public let failures: [DiagnosticExportWriteFailure]

    public init(
        status: DiagnosticExportWritePlanStatus,
        entries: [DiagnosticExportWriteEntry],
        failures: [DiagnosticExportWriteFailure]
    ) {
        self.status = status
        self.entries = entries
        self.failures = failures
    }
}

public struct DiagnosticExportWriter: Sendable {
    public let redactor: DiagnosticRedactor

    public init(redactor: DiagnosticRedactor = DiagnosticRedactor()) {
        self.redactor = redactor
    }

    public func planWrite(sections: [DiagnosticExportSection]) -> DiagnosticExportWritePlan {
        var entries: [DiagnosticExportWriteEntry] = []
        var failures: [DiagnosticExportWriteFailure] = []

        for section in sections {
            if section.isRequired && section.fields.isEmpty {
                failures.append(DiagnosticExportWriteFailure(
                    sectionName: section.name,
                    error: .sectionGenerationFailed
                ))
                continue
            }

            entries.append(DiagnosticExportWriteEntry(
                sectionName: section.name,
                path: stablePath(for: section.name),
                redactionLevel: section.redactionLevel,
                fields: redactor.redactFields(section.fields, forbiddenFields: section.forbiddenFields)
            ))
        }

        if failures.isEmpty {
            return DiagnosticExportWritePlan(status: .ready, entries: entries, failures: [])
        }

        return DiagnosticExportWritePlan(status: .failedClosed, entries: [], failures: failures)
    }

    private func stablePath(for sectionName: String) -> String {
        if sectionName.hasSuffix("/") {
            return "\(sectionName)index.json"
        }

        return sectionName
    }
}
