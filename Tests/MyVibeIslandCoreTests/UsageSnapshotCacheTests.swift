import XCTest
@testable import MyVibeIslandCore

final class UsageSnapshotCacheTests: XCTestCase {
    func testUsageSnapshotCacheMatrixMatchesFixtureSnapshot() async throws {
        let expected = try JSONDecoder().decode(
            UsageSnapshotCacheMatrixFixture.self,
            from: try FixtureLoader.data("usage/snapshot-cache-matrix")
        )

        let storeCache = UsageSnapshotCache()
        let accountA = UsageAccountID(rawValue: "account-a")
        let accountB = UsageAccountID(rawValue: "account-b")
        await storeCache.store(snapshot(providerId: .codexRateLimits, accountId: accountA, usedPercent: 20))
        await storeCache.store(snapshot(providerId: .codexRateLimits, accountId: accountB, usedPercent: 80))

        let staleCache = UsageSnapshotCache()
        let staleAccount = UsageAccountID(rawValue: "local")
        await staleCache.store(snapshot(providerId: .localParsedUsage, accountId: staleAccount, usedPercent: 55))
        let stale = await staleCache.markStale(providerId: .localParsedUsage, accountId: staleAccount)

        let removeCache = UsageSnapshotCache()
        let codexAccount = UsageAccountID(rawValue: "codex")
        let kimiAccount = UsageAccountID(rawValue: "kimi")
        await removeCache.store(snapshot(providerId: .codexRateLimits, accountId: codexAccount, usedPercent: 10))
        await removeCache.store(snapshot(providerId: .kimiUsage, accountId: kimiAccount, usedPercent: 90))
        let removed = await removeCache.remove(providerId: .codexRateLimits, accountId: codexAccount)
        let removedSnapshot = await removeCache.snapshot(providerId: .codexRateLimits, accountId: codexAccount)
        let remainingSnapshot = await removeCache.snapshot(providerId: .kimiUsage, accountId: kimiAccount)
        await removeCache.clear()
        let afterClear = await removeCache.snapshot(providerId: .kimiUsage, accountId: kimiAccount)

        let actual = UsageSnapshotCacheMatrixFixture(rows: [
            UsageSnapshotCacheMatrixRow(
                id: "store-by-provider-account",
                snapshots: [
                    snapshotSummary(await storeCache.snapshot(providerId: .codexRateLimits, accountId: accountA)),
                    snapshotSummary(await storeCache.snapshot(providerId: .codexRateLimits, accountId: accountB)),
                    snapshotSummary(await storeCache.snapshot(providerId: .kimiUsage, accountId: accountA)),
                ],
                removed: nil,
                afterClearMissing: nil
            ),
            UsageSnapshotCacheMatrixRow(
                id: "mark-stale",
                snapshots: [
                    snapshotSummary(stale),
                    snapshotSummary(await staleCache.snapshot(providerId: .localParsedUsage, accountId: staleAccount)),
                ],
                removed: nil,
                afterClearMissing: nil
            ),
            UsageSnapshotCacheMatrixRow(
                id: "remove-and-clear",
                snapshots: [
                    snapshotSummary(removedSnapshot),
                    snapshotSummary(remainingSnapshot),
                ],
                removed: removed,
                afterClearMissing: afterClear == nil
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCacheStoresSnapshotsByProviderAndAccount() async {
        let cache = UsageSnapshotCache()
        let accountA = UsageAccountID(rawValue: "account-a")
        let accountB = UsageAccountID(rawValue: "account-b")

        await cache.store(snapshot(providerId: .codexRateLimits, accountId: accountA, usedPercent: 20))
        await cache.store(snapshot(providerId: .codexRateLimits, accountId: accountB, usedPercent: 80))

        let cachedA = await cache.snapshot(providerId: .codexRateLimits, accountId: accountA)
        let cachedB = await cache.snapshot(providerId: .codexRateLimits, accountId: accountB)
        let missing = await cache.snapshot(providerId: .kimiUsage, accountId: accountA)

        XCTAssertEqual(cachedA?.primaryWindow?.usedPercent, 20)
        XCTAssertEqual(cachedB?.primaryWindow?.usedPercent, 80)
        XCTAssertNil(missing)
    }

    func testCacheMarkStalePreservesSnapshotDetails() async {
        let cache = UsageSnapshotCache()
        let account = UsageAccountID(rawValue: "account")

        await cache.store(snapshot(providerId: .localParsedUsage, accountId: account, usedPercent: 55))
        let stale = await cache.markStale(providerId: .localParsedUsage, accountId: account)

        XCTAssertEqual(stale?.freshness, .stale)
        XCTAssertEqual(stale?.providerId, .localParsedUsage)
        XCTAssertEqual(stale?.accountId, account)
        XCTAssertEqual(stale?.primaryWindow?.usedPercent, 55)
        XCTAssertEqual(stale?.privacyLevel, .redacted)
    }

    func testCacheRemoveAndClearOnlyMutateInMemorySnapshots() async {
        let cache = UsageSnapshotCache()
        let codexAccount = UsageAccountID(rawValue: "codex")
        let kimiAccount = UsageAccountID(rawValue: "kimi")

        await cache.store(snapshot(providerId: .codexRateLimits, accountId: codexAccount, usedPercent: 10))
        await cache.store(snapshot(providerId: .kimiUsage, accountId: kimiAccount, usedPercent: 90))

        let removed = await cache.remove(providerId: .codexRateLimits, accountId: codexAccount)
        let removedSnapshot = await cache.snapshot(providerId: .codexRateLimits, accountId: codexAccount)
        let remainingSnapshot = await cache.snapshot(providerId: .kimiUsage, accountId: kimiAccount)

        XCTAssertTrue(removed)
        XCTAssertNil(removedSnapshot)
        XCTAssertNotNil(remainingSnapshot)

        await cache.clear()
        let snapshotAfterClear = await cache.snapshot(providerId: .kimiUsage, accountId: kimiAccount)

        XCTAssertNil(snapshotAfterClear)
    }

    func testCoordinatorRefreshWritesThroughSnapshotCache() async throws {
        let cache = UsageSnapshotCache()
        let provider = CacheTestUsageProvider(providerId: .codexRateLimits)
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        let account = UsageAccountID(rawValue: "local")

        let refreshed = try await coordinator.refresh(providerId: .codexRateLimits, accountId: account)
        let cached = await cache.snapshot(providerId: .codexRateLimits, accountId: account)

        XCTAssertEqual(cached, refreshed)
    }

    func testCoordinatorMarksCachedSnapshotStaleWithoutRefetching() async throws {
        let cache = UsageSnapshotCache()
        let provider = CacheTestUsageProvider(providerId: .codexRateLimits)
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        let account = UsageAccountID(rawValue: "local")

        _ = try await coordinator.refresh(providerId: .codexRateLimits, accountId: account)
        let stale = await coordinator.markCachedSnapshotStale(providerId: .codexRateLimits, accountId: account)

        XCTAssertEqual(stale?.freshness, .stale)
        XCTAssertEqual(stale?.primaryWindow?.usedPercent, 40)
        XCTAssertEqual(provider.refreshCount, 1)
    }

    private func snapshot(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID?,
        usedPercent: Double,
        freshness: UsageSnapshotFreshness = .fresh
    ) -> UsageSnapshot {
        UsageSnapshot(
            providerId: providerId,
            accountId: accountId,
            source: .providerReported,
            collectedAt: "2026-07-08T12:00:00Z",
            freshness: freshness,
            primaryWindow: UsageLimitWindow(
                id: "primary",
                label: "Primary",
                kind: .fiveHour,
                usedPercent: usedPercent,
                sourceConfidence: .providerReported
            ),
            privacyLevel: .redacted
        )
    }

    private func snapshotSummary(_ snapshot: UsageSnapshot?) -> UsageSnapshotCacheSummary? {
        guard let snapshot else {
            return nil
        }

        return UsageSnapshotCacheSummary(
            providerId: snapshot.providerId.rawValue,
            accountId: snapshot.accountId?.rawValue,
            freshness: snapshot.freshness.rawValue,
            usedPercent: snapshot.primaryWindow?.usedPercent
        )
    }

    private struct UsageSnapshotCacheMatrixFixture: Codable, Equatable {
        let rows: [UsageSnapshotCacheMatrixRow]
    }

    private struct UsageSnapshotCacheMatrixRow: Codable, Equatable {
        let id: String
        let snapshots: [UsageSnapshotCacheSummary?]
        let removed: Bool?
        let afterClearMissing: Bool?
    }

    private struct UsageSnapshotCacheSummary: Codable, Equatable {
        let providerId: String
        let accountId: String?
        let freshness: String
        let usedPercent: Double?
    }
}

private final class CacheTestUsageProvider: UsageProvider, @unchecked Sendable {
    let descriptor: UsageProviderDescriptor
    private(set) var refreshCount = 0

    init(providerId: UsageProviderIdentifier) {
        descriptor = UsageProviderDescriptor(
            id: providerId,
            displayName: "Cache Test Provider",
            capabilities: [.normalizedSnapshotOnly],
            minimumRefreshIntervalSeconds: 1,
            availability: .available
        )
    }

    func status(for accountId: UsageAccountID?) -> UsageProviderAvailability {
        .available
    }

    func cachedSnapshot(for accountId: UsageAccountID?) -> UsageSnapshot? {
        nil
    }

    func diagnosticSummary(for accountId: UsageAccountID?) -> UsageProviderDiagnosticSummary {
        UsageProviderDiagnosticSummary(
            providerId: descriptor.id,
            availability: .available,
            freshness: .fresh,
            windowCount: 1
        )
    }

    func refresh(accountId: UsageAccountID?) async throws -> UsageSnapshot {
        refreshCount += 1
        return UsageSnapshot(
            providerId: descriptor.id,
            accountId: accountId,
            source: .providerReported,
            collectedAt: "2026-07-08T12:00:00Z",
            freshness: .fresh,
            primaryWindow: UsageLimitWindow(
                id: "primary",
                label: "Primary",
                kind: .fiveHour,
                usedPercent: 40,
                sourceConfidence: .providerReported
            ),
            privacyLevel: .redacted
        )
    }
}
