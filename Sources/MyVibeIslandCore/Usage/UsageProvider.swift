import Foundation

public protocol UsageProvider: Sendable {
    var descriptor: UsageProviderDescriptor { get }

    func status(for accountId: UsageAccountID?) -> UsageProviderAvailability
    func cachedSnapshot(for accountId: UsageAccountID?) -> UsageSnapshot?
    func diagnosticSummary(for accountId: UsageAccountID?) -> UsageProviderDiagnosticSummary
    func refresh(accountId: UsageAccountID?) async throws -> UsageSnapshot
}

public struct UsageProviderDiagnosticSummary: Codable, Equatable, Sendable {
    public let providerId: UsageProviderIdentifier
    public let availability: UsageProviderAvailability
    public let freshness: UsageSnapshotFreshness
    public let windowCount: Int
    public let failure: UsageFailureCategory?
    public let redactedDetail: String?

    public init(
        providerId: UsageProviderIdentifier,
        availability: UsageProviderAvailability,
        freshness: UsageSnapshotFreshness,
        windowCount: Int,
        failure: UsageFailureCategory? = nil,
        redactedDetail: String? = nil
    ) {
        self.providerId = providerId
        self.availability = availability
        self.freshness = freshness
        self.windowCount = windowCount
        self.failure = failure
        self.redactedDetail = redactedDetail
    }
}

public struct NormalizedSnapshotUsageProvider: UsageProvider {
    public let descriptor: UsageProviderDescriptor
    public let snapshot: UsageSnapshot

    public init(
        descriptor: UsageProviderDescriptor,
        snapshot: UsageSnapshot
    ) {
        self.descriptor = descriptor
        self.snapshot = snapshot
    }

    public func status(for accountId: UsageAccountID?) -> UsageProviderAvailability {
        guard matches(accountId: accountId) else {
            return .unavailable
        }
        return descriptor.availability
    }

    public func cachedSnapshot(for accountId: UsageAccountID?) -> UsageSnapshot? {
        guard matches(accountId: accountId) else {
            return nil
        }
        return snapshot
    }

    public func diagnosticSummary(for accountId: UsageAccountID?) -> UsageProviderDiagnosticSummary {
        guard matches(accountId: accountId) else {
            return UsageProviderDiagnosticSummary(
                providerId: descriptor.id,
                availability: .unavailable,
                freshness: .unavailable,
                windowCount: 0,
                failure: .providerUnavailable,
                redactedDetail: "normalized snapshot account mismatch"
            )
        }

        return UsageProviderDiagnosticSummary(
            providerId: descriptor.id,
            availability: descriptor.availability,
            freshness: snapshot.freshness,
            windowCount: snapshot.windowCount,
            failure: snapshot.error,
            redactedDetail: "normalized snapshot"
        )
    }

    public func refresh(accountId: UsageAccountID?) async throws -> UsageSnapshot {
        guard matches(accountId: accountId) else {
            throw UsageProviderSnapshotError.accountMismatch
        }
        return snapshot
    }

    private func matches(accountId: UsageAccountID?) -> Bool {
        snapshot.accountId == nil || snapshot.accountId == accountId
    }
}

public enum UsageProviderSnapshotError: Error, Equatable, Sendable {
    case accountMismatch
}

public enum UsageProviderCatalog {
    public static let defaultDescriptors: [UsageProviderDescriptor] = [
        UsageProviderDescriptor(
            id: .codexRateLimits,
            displayName: "Codex Rate Limits",
            capabilities: [.localAppServer, .localCache, .normalizedSnapshotOnly],
            minimumRefreshIntervalSeconds: 60,
            availability: .needsPermission
        ),
        UsageProviderDescriptor(
            id: .kimiUsage,
            displayName: "Kimi Usage",
            capabilities: [.userOwnedCredential, .normalizedSnapshotOnly],
            minimumRefreshIntervalSeconds: 300,
            availability: .needsConfiguration
        ),
        UsageProviderDescriptor(
            id: .zaiQuota,
            displayName: "Z.ai Quota",
            capabilities: [.userOwnedCredential, .normalizedSnapshotOnly],
            minimumRefreshIntervalSeconds: 300,
            availability: .needsConfiguration
        ),
        UsageProviderDescriptor(
            id: .claudeStatusLine,
            displayName: "Claude Status Line",
            capabilities: [.statusLinePayload, .normalizedSnapshotOnly],
            minimumRefreshIntervalSeconds: 30,
            availability: .available
        ),
        UsageProviderDescriptor(
            id: .localParsedUsage,
            displayName: "Local Parsed Usage",
            capabilities: [.localCache, .normalizedSnapshotOnly],
            minimumRefreshIntervalSeconds: 30,
            availability: .available
        )
    ]

    public static func descriptor(for id: UsageProviderIdentifier) -> UsageProviderDescriptor? {
        defaultDescriptors.first { $0.id == id }
    }
}

private extension UsageSnapshot {
    var windowCount: Int {
        [primaryWindow, secondaryWindow].compactMap { $0 }.count + extraWindows.count
    }
}
