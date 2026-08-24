import Foundation

public struct LocalParsedUsagePayload: Codable, Equatable, Sendable {
    public let sourceName: String?
    public let snapshot: LocalParsedUsageSnapshot

    public init(
        sourceName: String? = nil,
        snapshot: LocalParsedUsageSnapshot
    ) {
        self.sourceName = sourceName
        self.snapshot = snapshot
    }
}

public struct LocalParsedUsageSnapshot: Codable, Equatable, Sendable {
    public let accountId: UsageAccountID?
    public let collectedAt: String?
    public let primaryWindow: UsageLimitWindow?
    public let secondaryWindow: UsageLimitWindow?
    public let extraWindows: [UsageLimitWindow]
    public let extraUsage: [UsageExtraUsageItem]

    public init(
        accountId: UsageAccountID? = nil,
        collectedAt: String? = nil,
        primaryWindow: UsageLimitWindow? = nil,
        secondaryWindow: UsageLimitWindow? = nil,
        extraWindows: [UsageLimitWindow] = [],
        extraUsage: [UsageExtraUsageItem] = []
    ) {
        self.accountId = accountId
        self.collectedAt = collectedAt
        self.primaryWindow = primaryWindow
        self.secondaryWindow = secondaryWindow
        self.extraWindows = extraWindows
        self.extraUsage = extraUsage
    }
}

public extension ProviderQuotaSnapshot {
    init(
        localParsedUsage payload: LocalParsedUsagePayload,
        freshness: UsageSnapshotFreshness = .fresh
    ) {
        let snapshot = payload.snapshot
        let hasUsageWindows = snapshot.primaryWindow != nil
            || snapshot.secondaryWindow != nil
            || !snapshot.extraWindows.isEmpty

        self.init(
            providerId: .localParsedUsage,
            accountId: snapshot.accountId,
            source: .parsed,
            collectedAt: snapshot.collectedAt,
            freshness: hasUsageWindows ? freshness : .unavailable,
            primaryWindow: snapshot.primaryWindow,
            secondaryWindow: snapshot.secondaryWindow,
            extraWindows: snapshot.extraWindows,
            extraUsage: snapshot.extraUsage + payload.providerMetadataItems,
            failure: hasUsageWindows ? nil : .noUsageWindows,
            privacyLevel: .redacted
        )
    }
}

private extension LocalParsedUsagePayload {
    var providerMetadataItems: [UsageExtraUsageItem] {
        [
            sourceName.map { UsageExtraUsageItem(key: "sourceName", value: $0) }
        ].compactMap { $0 }
    }
}
