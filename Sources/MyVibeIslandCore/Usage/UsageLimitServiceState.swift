import Foundation

public struct UsageLimitServiceCacheKey: Codable, Equatable, Hashable, Sendable {
    public let providerId: UsageProviderIdentifier
    public let accountId: UsageAccountID?

    public init(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) {
        self.providerId = providerId
        self.accountId = accountId
    }
}

public struct UsageLimitServiceSnapshotEntry: Codable, Equatable, Sendable {
    public let key: UsageLimitServiceCacheKey
    public let snapshot: UsageSnapshot

    public init(
        key: UsageLimitServiceCacheKey,
        snapshot: UsageSnapshot
    ) {
        self.key = key
        self.snapshot = snapshot
    }
}

public struct UsageLimitServiceRefreshEntry: Codable, Equatable, Sendable {
    public let key: UsageLimitServiceCacheKey
    public let state: UsageRefreshState

    public init(
        key: UsageLimitServiceCacheKey,
        state: UsageRefreshState
    ) {
        self.key = key
        self.state = state
    }
}

public struct UsageLimitServiceState: Codable, Equatable, Sendable {
    public let cachedSnapshotsByProvider: [UsageLimitServiceSnapshotEntry]
    public let refreshStates: [UsageLimitServiceRefreshEntry]
    public let zaiQuotaConfigState: ZaiQuotaConfigState

    public init(
        cachedSnapshotsByProvider: [UsageLimitServiceSnapshotEntry] = [],
        refreshStates: [UsageLimitServiceRefreshEntry] = [],
        zaiQuotaConfigState: ZaiQuotaConfigState = ZaiQuotaConfigState()
    ) {
        self.cachedSnapshotsByProvider = cachedSnapshotsByProvider
        self.refreshStates = refreshStates
        self.zaiQuotaConfigState = zaiQuotaConfigState
    }

    public func cachedSnapshot(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) -> UsageSnapshot? {
        let key = UsageLimitServiceCacheKey(providerId: providerId, accountId: accountId)
        return cachedSnapshotsByProvider.first { $0.key == key }?.snapshot
    }

    public func refreshState(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) -> UsageRefreshState {
        let key = UsageLimitServiceCacheKey(providerId: providerId, accountId: accountId)
        return refreshStates.first { $0.key == key }?.state ?? UsageRefreshState()
    }

    public func storingCachedSnapshot(_ snapshot: UsageSnapshot) -> UsageLimitServiceState {
        let key = UsageLimitServiceCacheKey(providerId: snapshot.providerId, accountId: snapshot.accountId)
        let entry = UsageLimitServiceSnapshotEntry(key: key, snapshot: snapshot)

        return UsageLimitServiceState(
            cachedSnapshotsByProvider: replacingSnapshotEntry(entry),
            refreshStates: refreshStates,
            zaiQuotaConfigState: zaiQuotaConfigState
        )
    }

    public func storingRefreshState(
        _ state: UsageRefreshState,
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) -> UsageLimitServiceState {
        let key = UsageLimitServiceCacheKey(providerId: providerId, accountId: accountId)
        let entry = UsageLimitServiceRefreshEntry(key: key, state: state)

        return UsageLimitServiceState(
            cachedSnapshotsByProvider: cachedSnapshotsByProvider,
            refreshStates: replacingRefreshEntry(entry),
            zaiQuotaConfigState: zaiQuotaConfigState
        )
    }

    public func storingZaiQuotaConfigState(_ state: ZaiQuotaConfigState) -> UsageLimitServiceState {
        UsageLimitServiceState(
            cachedSnapshotsByProvider: cachedSnapshotsByProvider,
            refreshStates: refreshStates,
            zaiQuotaConfigState: state
        )
    }

    private func replacingSnapshotEntry(
        _ replacement: UsageLimitServiceSnapshotEntry
    ) -> [UsageLimitServiceSnapshotEntry] {
        cachedSnapshotsByProvider
            .filter { $0.key != replacement.key }
            + [replacement]
    }

    private func replacingRefreshEntry(
        _ replacement: UsageLimitServiceRefreshEntry
    ) -> [UsageLimitServiceRefreshEntry] {
        refreshStates
            .filter { $0.key != replacement.key }
            + [replacement]
    }
}
