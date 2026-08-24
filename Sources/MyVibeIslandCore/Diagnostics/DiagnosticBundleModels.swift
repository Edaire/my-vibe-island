import Foundation

public enum DiagnosticSectionEvidence: String, Codable, Equatable, Sendable {
    case idaString
    case privacyNote
    case privacyDesign
}

public enum DiagnosticRedactionLevel: String, Codable, Equatable, Sendable {
    case redacted
    case localOnly
    case sensitive
}

public struct DiagnosticBundleSection: Codable, Equatable, Sendable {
    public let name: String
    public let evidence: DiagnosticSectionEvidence
    public let isRequired: Bool
    public let redactionLevel: DiagnosticRedactionLevel

    public init(
        name: String,
        evidence: DiagnosticSectionEvidence,
        isRequired: Bool,
        redactionLevel: DiagnosticRedactionLevel = .redacted
    ) {
        self.name = name
        self.evidence = evidence
        self.isRequired = isRequired
        self.redactionLevel = redactionLevel
    }
}

public struct DiagnosticBundleManifest: Codable, Equatable, Sendable {
    public let sections: [DiagnosticBundleSection]

    public init(sections: [DiagnosticBundleSection]) {
        self.sections = sections
    }

    public static let `default` = DiagnosticBundleManifest(
        sections: [
            DiagnosticBundleSection(name: "system-info.txt", evidence: .idaString, isRequired: true),
            DiagnosticBundleSection(name: "config-snapshot.txt", evidence: .idaString, isRequired: true),
            DiagnosticBundleSection(name: "hooks-dump.txt", evidence: .privacyNote, isRequired: true),
            DiagnosticBundleSection(name: "environment-snapshot.txt", evidence: .idaString, isRequired: true),
            DiagnosticBundleSection(name: "codex-rollout-inventory.txt", evidence: .idaString, isRequired: true),
            DiagnosticBundleSection(name: "sessions-snapshot.txt", evidence: .idaString, isRequired: true),
            DiagnosticBundleSection(name: "logs/", evidence: .privacyNote, isRequired: true),
            DiagnosticBundleSection(name: "hang-samples/", evidence: .privacyNote, isRequired: false),
            DiagnosticBundleSection(name: "crash-reports/", evidence: .privacyNote, isRequired: false),
            DiagnosticBundleSection(name: "README-privacy.txt", evidence: .privacyDesign, isRequired: true)
        ]
    )
}

public enum DiagnosticExcludedData: String, Codable, Equatable, Sendable {
    case prompts
    case transcripts
    case sourceCode
    case toolInput
    case providerTokens
    case environmentValues
    case commercialState
}

public struct DiagnosticReportPrivacyNote: Codable, Equatable, Sendable {
    public let includedSections: [String]
    public let excludedData: [DiagnosticExcludedData]
    public let redactionLevel: DiagnosticRedactionLevel

    public init(
        includedSections: [String],
        excludedData: [DiagnosticExcludedData],
        redactionLevel: DiagnosticRedactionLevel
    ) {
        self.includedSections = includedSections
        self.excludedData = excludedData
        self.redactionLevel = redactionLevel
    }

    public static let `default` = DiagnosticReportPrivacyNote(
        includedSections: DiagnosticBundleManifest.default.sections.map(\.name),
        excludedData: [
            .prompts,
            .transcripts,
            .sourceCode,
            .toolInput,
            .providerTokens,
            .environmentValues,
            .commercialState
        ],
        redactionLevel: .redacted
    )
}
