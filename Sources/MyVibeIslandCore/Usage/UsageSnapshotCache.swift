import Foundation

public actor UsageSnapshotCache {
    private var snapshotsByKey: [UsageSnapshotCacheKey: UsageSnapshot]

    public init(snapshots: [UsageSnapshot] = []) {
        snapshotsByKey = Dictionary(
            uniqueKeysWithValues: snapshots.map {
                (UsageSnapshotCacheKey(providerId: $0.providerId, accountId: $0.accountId), $0)
            }
        )
    }

    public func snapshot(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) -> UsageSnapshot? {
        snapshotsByKey[UsageSnapshotCacheKey(providerId: providerId, accountId: accountId)]
    }

    public func store(_ snapshot: UsageSnapshot) {
        snapshotsByKey[UsageSnapshotCacheKey(providerId: snapshot.providerId, accountId: snapshot.accountId)] = snapshot
    }

    @discardableResult
    public func markStale(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) -> UsageSnapshot? {
        let key = UsageSnapshotCacheKey(providerId: providerId, accountId: accountId)
        guard let current = snapshotsByKey[key] else {
            return nil
        }

        let stale = current.withFreshness(.stale)
        snapshotsByKey[key] = stale
        return stale
    }

    @discardableResult
    public func remove(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) -> Bool {
        let key = UsageSnapshotCacheKey(providerId: providerId, accountId: accountId)
        return snapshotsByKey.removeValue(forKey: key) != nil
    }

    public func clear() {
        snapshotsByKey.removeAll()
    }
}

private struct UsageSnapshotCacheKey: Hashable {
    let providerId: UsageProviderIdentifier
    let accountIdRawValue: String?

    init(providerId: UsageProviderIdentifier, accountId: UsageAccountID?) {
        self.providerId = providerId
        accountIdRawValue = accountId?.rawValue
    }
}

private extension UsageSnapshot {
    func withFreshness(_ freshness: UsageSnapshotFreshness) -> UsageSnapshot {
        UsageSnapshot(
            providerId: providerId,
            accountId: accountId,
            source: source,
            collectedAt: collectedAt,
            freshness: freshness,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            extraWindows: extraWindows,
            extraUsage: extraUsage,
            bridgeHint: bridgeHint,
            waitingHint: waitingHint,
            error: error,
            privacyLevel: privacyLevel
        )
    }
}
