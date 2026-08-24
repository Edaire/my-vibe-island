import Foundation

public enum UsageProviderSelectionReason: String, Codable, Equatable, Sendable {
    case transient
    case preferred
    case focused
    case fallback
    case none
}

public enum UsageProviderSelectionHintSource: String, Codable, Equatable, Sendable {
    case transient
    case preferred
    case focused
}

public enum UsageProviderSelectionRejectionReason: String, Codable, Equatable, Sendable {
    case notRegistered
    case unavailable
}

public struct UsageProviderSelectionRejectedHint: Codable, Equatable, Sendable {
    public let providerId: UsageProviderIdentifier
    public let source: UsageProviderSelectionHintSource
    public let reason: UsageProviderSelectionRejectionReason

    public init(
        providerId: UsageProviderIdentifier,
        source: UsageProviderSelectionHintSource,
        reason: UsageProviderSelectionRejectionReason
    ) {
        self.providerId = providerId
        self.source = source
        self.reason = reason
    }
}

public struct UsageProviderSelection: Codable, Equatable, Sendable {
    public let descriptor: UsageProviderDescriptor?
    public let reason: UsageProviderSelectionReason
    public let rejectedHints: [UsageProviderSelectionRejectedHint]

    public init(
        descriptor: UsageProviderDescriptor?,
        reason: UsageProviderSelectionReason,
        rejectedHints: [UsageProviderSelectionRejectedHint] = []
    ) {
        self.descriptor = descriptor
        self.reason = reason
        self.rejectedHints = rejectedHints
    }
}
