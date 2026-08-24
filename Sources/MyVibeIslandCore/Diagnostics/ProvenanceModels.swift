import Foundation

public struct BinaryProvenanceSnapshot: Codable, Equatable, Sendable {
    public let integrityStatus: String?
    public let executableLoadStatus: String?
    public let externalHelperStatus: String?
    public let bundleIDMatchesOfficial: Bool?
    public let helperBinaryPresent: Bool?
    public let signingTeamMatchesOfficial: Bool?
    public let hardenedRuntimeEnabled: Bool?
    public let codeUniqueHash: String?

    public init(
        integrityStatus: String? = nil,
        executableLoadStatus: String? = nil,
        externalHelperStatus: String? = nil,
        bundleIDMatchesOfficial: Bool? = nil,
        helperBinaryPresent: Bool? = nil,
        signingTeamMatchesOfficial: Bool? = nil,
        hardenedRuntimeEnabled: Bool? = nil,
        codeUniqueHash: String? = nil
    ) {
        self.integrityStatus = integrityStatus
        self.executableLoadStatus = executableLoadStatus
        self.externalHelperStatus = externalHelperStatus
        self.bundleIDMatchesOfficial = bundleIDMatchesOfficial
        self.helperBinaryPresent = helperBinaryPresent
        self.signingTeamMatchesOfficial = signingTeamMatchesOfficial
        self.hardenedRuntimeEnabled = hardenedRuntimeEnabled
        self.codeUniqueHash = codeUniqueHash
    }
}

public struct ClientProvenancePayload: Codable, Equatable, Sendable {
    public let appVersion: String?
    public let platform: String?
    public let bundleId: String?
    public let binary: String?

    public init(
        appVersion: String? = nil,
        platform: String? = nil,
        bundleId: String? = nil,
        binary: String? = nil
    ) {
        self.appVersion = appVersion
        self.platform = platform
        self.bundleId = bundleId
        self.binary = binary
    }
}

public enum ProvenanceAssessmentStatus: String, Codable, Equatable, Sendable {
    case trustedManaged
    case trustedUnmanaged
    case staleHelper
    case pathMismatch
    case hashMismatch
    case bundleMismatch
    case missingMarker
    case unknown
}

public struct ProvenanceAssessment: Codable, Equatable, Sendable {
    public let status: ProvenanceAssessmentStatus
    public let binarySnapshot: BinaryProvenanceSnapshot?
    public let clientPayload: ClientProvenancePayload?
    public let redactionLevel: DiagnosticRedactionLevel
    public let reason: String?

    public init(
        status: ProvenanceAssessmentStatus,
        binarySnapshot: BinaryProvenanceSnapshot? = nil,
        clientPayload: ClientProvenancePayload? = nil,
        redactionLevel: DiagnosticRedactionLevel = .redacted,
        reason: String? = nil
    ) {
        self.status = status
        self.binarySnapshot = binarySnapshot
        self.clientPayload = clientPayload
        self.redactionLevel = redactionLevel
        self.reason = reason
    }
}
