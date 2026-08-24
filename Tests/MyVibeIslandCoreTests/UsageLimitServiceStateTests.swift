import XCTest
@testable import MyVibeIslandCore

final class UsageLimitServiceStateTests: XCTestCase {
    func testUsageLimitServiceStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsageLimitServiceStateMatrixFixture.self,
            from: try FixtureLoader.data("usage/limit-service-state-matrix")
        )

        let accountA = UsageAccountID(rawValue: "account-a")
        let accountB = UsageAccountID(rawValue: "account-b")
        let snapshotA = snapshot(providerId: .codexRateLimits, accountId: accountA, usedPercent: 25)
        let snapshotB = snapshot(providerId: .codexRateLimits, accountId: accountB, usedPercent: 75)
        let replacementB = snapshot(providerId: .codexRateLimits, accountId: accountB, usedPercent: 80)
        let refreshState = UsageRefreshState(lastFetchAttemptSeconds: 100, backoffMultiplier: 3)
        let zaiConfig = ZaiQuotaConfigState().markingChecked(availability: .available)

        let actual = UsageLimitServiceStateMatrixFixture(rows: [
            UsageLimitServiceStateMatrixRow(id: "empty", state: UsageLimitServiceState()),
            UsageLimitServiceStateMatrixRow(
                id: "provider-account-cache",
                state: UsageLimitServiceState()
                    .storingCachedSnapshot(snapshotA)
                    .storingCachedSnapshot(snapshotB)
                    .storingRefreshState(refreshState, providerId: .codexRateLimits, accountId: accountB)
            ),
            UsageLimitServiceStateMatrixRow(
                id: "replacement-preserves-order-boundary",
                state: UsageLimitServiceState()
                    .storingCachedSnapshot(snapshotA)
                    .storingCachedSnapshot(snapshotB)
                    .storingCachedSnapshot(replacementB)
            ),
            UsageLimitServiceStateMatrixRow(
                id: "zai-config-with-refresh",
                state: UsageLimitServiceState()
                    .storingRefreshState(UsageRefreshState(lastFetchAttemptSeconds: 200), providerId: .zaiQuota)
                    .storingZaiQuotaConfigState(zaiConfig)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testInitialStateHasNoCachedSnapshotAndDefaultRefreshState() {
        let state = UsageLimitServiceState()

        XCTAssertNil(state.cachedSnapshot(providerId: .codexRateLimits))
        XCTAssertEqual(state.refreshState(providerId: .codexRateLimits), UsageRefreshState())
        XCTAssertEqual(state.zaiQuotaConfigState, ZaiQuotaConfigState())
    }

    func testStateStoresSnapshotsAndRefreshStateByProviderAndAccount() {
        let accountA = UsageAccountID(rawValue: "account-a")
        let accountB = UsageAccountID(rawValue: "account-b")
        let snapshotA = snapshot(providerId: .codexRateLimits, accountId: accountA, usedPercent: 25)
        let snapshotB = snapshot(providerId: .codexRateLimits, accountId: accountB, usedPercent: 75)
        let refreshState = UsageRefreshState(lastFetchAttemptSeconds: 100, backoffMultiplier: 3)

        let state = UsageLimitServiceState()
            .storingCachedSnapshot(snapshotA)
            .storingCachedSnapshot(snapshotB)
            .storingRefreshState(refreshState, providerId: .codexRateLimits, accountId: accountB)

        XCTAssertEqual(state.cachedSnapshot(providerId: .codexRateLimits, accountId: accountA), snapshotA)
        XCTAssertEqual(state.cachedSnapshot(providerId: .codexRateLimits, accountId: accountB), snapshotB)
        XCTAssertEqual(state.refreshState(providerId: .codexRateLimits, accountId: accountB), refreshState)
        XCTAssertEqual(state.refreshState(providerId: .codexRateLimits, accountId: accountA), UsageRefreshState())
    }

    func testZaiConfigStateStoresOnlyAvailabilityState() {
        let checked = ZaiQuotaConfigState().markingChecked(availability: .available)

        let state = UsageLimitServiceState().storingZaiQuotaConfigState(checked)

        XCTAssertEqual(state.zaiQuotaConfigState, checked)
    }

    func testStateRoundTripsThroughJSON() throws {
        let account = UsageAccountID(rawValue: "local")
        let state = UsageLimitServiceState()
            .storingCachedSnapshot(snapshot(providerId: .kimiUsage, accountId: account, usedPercent: 60))
            .storingRefreshState(
                UsageRefreshState(lastFetchAttemptSeconds: 200, backoffMultiplier: 2),
                providerId: .kimiUsage,
                accountId: account
            )
            .storingZaiQuotaConfigState(
                ZaiQuotaConfigState(configChecked: true, cachedConfigAvailability: .unavailable)
            )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(UsageLimitServiceState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.cachedSnapshot(providerId: .kimiUsage, accountId: account)?.primaryWindow?.usedPercent, 60)
        XCTAssertEqual(decoded.refreshState(providerId: .kimiUsage, accountId: account).backoffMultiplier, 2)
    }

    private func snapshot(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID?,
        usedPercent: Double
    ) -> UsageSnapshot {
        UsageSnapshot(
            providerId: providerId,
            accountId: accountId,
            source: .providerReported,
            collectedAt: "2026-07-08T12:00:00Z",
            freshness: .fresh,
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
}

private struct UsageLimitServiceStateMatrixFixture: Codable, Equatable {
    let rows: [UsageLimitServiceStateMatrixRow]
}

private struct UsageLimitServiceStateMatrixRow: Codable, Equatable {
    let id: String
    let cachedSnapshots: [UsageLimitServiceSnapshotSummary]
    let refreshStates: [UsageLimitServiceRefreshSummary]
    let defaultCodexRefreshBackoff: Int
    let zaiQuotaConfigState: ZaiQuotaConfigState

    init(id: String, state: UsageLimitServiceState) {
        self.id = id
        self.cachedSnapshots = state.cachedSnapshotsByProvider.map(UsageLimitServiceSnapshotSummary.init(entry:))
        self.refreshStates = state.refreshStates.map(UsageLimitServiceRefreshSummary.init(entry:))
        self.defaultCodexRefreshBackoff = state.refreshState(providerId: .codexRateLimits).backoffMultiplier
        self.zaiQuotaConfigState = state.zaiQuotaConfigState
    }
}

private struct UsageLimitServiceSnapshotSummary: Codable, Equatable {
    let providerId: UsageProviderIdentifier
    let accountId: UsageAccountID?
    let usedPercent: Double?

    init(entry: UsageLimitServiceSnapshotEntry) {
        self.providerId = entry.key.providerId
        self.accountId = entry.key.accountId
        self.usedPercent = entry.snapshot.primaryWindow?.usedPercent
    }
}

private struct UsageLimitServiceRefreshSummary: Codable, Equatable {
    let providerId: UsageProviderIdentifier
    let accountId: UsageAccountID?
    let lastFetchAttemptSeconds: Int?
    let backoffMultiplier: Int

    init(entry: UsageLimitServiceRefreshEntry) {
        self.providerId = entry.key.providerId
        self.accountId = entry.key.accountId
        self.lastFetchAttemptSeconds = entry.state.lastFetchAttemptSeconds
        self.backoffMultiplier = entry.state.backoffMultiplier
    }
}
