import Foundation

public struct DiagnosticExportSection: Codable, Equatable, Sendable {
    public let name: String
    public let producer: String
    public let allowedFields: [String]
    public let forbiddenFields: [String]
    public let redactionLevel: DiagnosticRedactionLevel
    public let isRequired: Bool
    public let fields: [String: String]

    public init(
        name: String,
        producer: String,
        allowedFields: [String],
        forbiddenFields: [String],
        redactionLevel: DiagnosticRedactionLevel,
        isRequired: Bool,
        fields: [String: String] = [:]
    ) {
        self.name = name
        self.producer = producer
        self.allowedFields = allowedFields
        self.forbiddenFields = forbiddenFields
        self.redactionLevel = redactionLevel
        self.isRequired = isRequired
        self.fields = fields
    }
}

public struct DiagnosticExportSectionInput: Codable, Equatable, Sendable {
    public let name: String
    public let producer: String
    public let allowedFields: [String]
    public let forbiddenFields: [String]
    public let fields: [String: String]

    public init(
        name: String,
        producer: String,
        allowedFields: [String],
        forbiddenFields: [String],
        fields: [String: String] = [:]
    ) {
        self.name = name
        self.producer = producer
        self.allowedFields = allowedFields
        self.forbiddenFields = forbiddenFields
        self.fields = fields
    }
}

public struct DiagnosticExportBuilder: Sendable {
    public let manifest: DiagnosticBundleManifest

    public init(manifest: DiagnosticBundleManifest = .default) {
        self.manifest = manifest
    }

    public func buildSections(from inputs: [DiagnosticExportSectionInput]) -> [DiagnosticExportSection] {
        let inputsByName = Dictionary(uniqueKeysWithValues: inputs.map { ($0.name, $0) })

        return manifest.sections.map { manifestSection in
            guard let input = inputsByName[manifestSection.name] else {
                return DiagnosticExportSection(
                    name: manifestSection.name,
                    producer: "missing",
                    allowedFields: [],
                    forbiddenFields: [],
                    redactionLevel: manifestSection.redactionLevel,
                    isRequired: manifestSection.isRequired
                )
            }

            let allowed = Set(input.allowedFields)
            let forbidden = Set(input.forbiddenFields)
            let filteredFields = input.fields.filter { key, _ in
                allowed.contains(key) && !forbidden.contains(key)
            }

            return DiagnosticExportSection(
                name: manifestSection.name,
                producer: input.producer,
                allowedFields: input.allowedFields,
                forbiddenFields: input.forbiddenFields,
                redactionLevel: manifestSection.redactionLevel,
                isRequired: manifestSection.isRequired,
                fields: filteredFields
            )
        }
    }
}
