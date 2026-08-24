import XCTest
@testable import MyVibeIslandCore

final class UsageAccountStoreTests: XCTestCase {
    func testUsageAccountStoreMatrixMatchesFixtureSnapshot() async throws {
        let expected = try JSONDecoder().decode(
            UsageAccountStoreMatrixFixture.self,
            from: try FixtureLoader.data("usage/account-store-matrix")
        )

        let upsertStore = UsageAccountStore()
        await upsertStore.upsert(record(
            accountId: UsageAccountID(rawValue: "codex"),
            providerId: .codexRateLimits,
            displayLabel: "First"
        ))
        await upsertStore.upsert(record(
            accountId: UsageAccountID(rawValue: "codex"),
            providerId: .codexRateLimits,
            displayLabel: "Updated",
            lastSnapshotSummary: "85% used"
        ))

        let filterStore = UsageAccountStore()
        await filterStore.upsert(record(accountId: UsageAccountID(rawValue: "codex"), providerId: .codexRateLimits))
        await filterStore.upsert(record(accountId: UsageAccountID(rawValue: "kimi"), providerId: .kimiUsage))

        let selectStore = UsageAccountStore()
        await selectStore.upsert(record(accountId: UsageAccountID(rawValue: "local"), providerId: .localParsedUsage))
        let selected = await selectStore.select(
            providerId: .localParsedUsage,
            accountId: UsageAccountID(rawValue: "local"),
            selectedAt: "2026-07-08T13:00:00Z"
        )

        let removeStore = UsageAccountStore()
        await removeStore.upsert(record(accountId: UsageAccountID(rawValue: "codex"), providerId: .codexRateLimits))
        await removeStore.upsert(record(accountId: UsageAccountID(rawValue: "kimi"), providerId: .kimiUsage))
        let removed = await removeStore.remove(
            providerId: .codexRateLimits,
            accountId: UsageAccountID(rawValue: "codex")
        )

        let actual = UsageAccountStoreMatrixFixture(rows: [
            UsageAccountStoreMatrixRow(
                id: "upsert-replaces",
                accounts: await upsertStore.snapshot.accounts,
                providerAccountIds: await upsertStore.accounts(for: .codexRateLimits).map(\.accountId.rawValue),
                selectedAccount: nil,
                removed: nil
            ),
            UsageAccountStoreMatrixRow(
                id: "filter-provider",
                accounts: await filterStore.snapshot.accounts,
                providerAccountIds: await filterStore.accounts(for: .codexRateLimits).map(\.accountId.rawValue),
                selectedAccount: nil,
                removed: nil
            ),
            UsageAccountStoreMatrixRow(
                id: "select-updates-timestamp",
                accounts: await selectStore.snapshot.accounts,
                providerAccountIds: await selectStore.accounts(for: .localParsedUsage).map(\.accountId.rawValue),
                selectedAccount: selected,
                removed: nil
            ),
            UsageAccountStoreMatrixRow(
                id: "remove-record",
                accounts: await removeStore.snapshot.accounts,
                providerAccountIds: await removeStore.accounts(for: .codexRateLimits).map(\.accountId.rawValue),
                selectedAccount: nil,
                removed: removed
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testAccountRecordRoundTripsThroughJSONWithCategory() throws {
        let record = UsageAccountRecord(
            accountId: UsageAccountID(rawValue: "redacted-local"),
            providerId: .codexRateLimits,
            category: .localCache,
            origin: .cache,
            displayLabel: "Local cache",
            lastSelectedAt: "2026-07-08T12:00:00Z",
            lastSnapshotSummary: "fresh"
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(UsageAccountRecord.self, from: data)

        XCTAssertEqual(decoded, record)
        XCTAssertEqual(decoded.category, .localCache)
    }

    func testStoreUpsertReplacesMatchingProviderAccountWithoutDuplicating() async {
        let store = UsageAccountStore()
        let accountId = UsageAccountID(rawValue: "redacted-account")

        await store.upsert(record(
            accountId: accountId,
            providerId: .codexRateLimits,
            displayLabel: "First"
        ))
        await store.upsert(record(
            accountId: accountId,
            providerId: .codexRateLimits,
            displayLabel: "Updated",
            lastSnapshotSummary: "high"
        ))

        let snapshot = await store.snapshot

        XCTAssertEqual(snapshot.accounts.count, 1)
        XCTAssertEqual(snapshot.accounts.first?.displayLabel, "Updated")
        XCTAssertEqual(snapshot.accounts.first?.lastSnapshotSummary, "high")
    }

    func testStoreFiltersAccountsByProvider() async {
        let store = UsageAccountStore()

        await store.upsert(record(accountId: UsageAccountID(rawValue: "codex"), providerId: .codexRateLimits))
        await store.upsert(record(accountId: UsageAccountID(rawValue: "kimi"), providerId: .kimiUsage))

        let codexAccounts = await store.accounts(for: .codexRateLimits)

        XCTAssertEqual(codexAccounts.map(\.accountId.rawValue), ["codex"])
    }

    func testStoreSelectUpdatesExistingRecordTimestamp() async {
        let store = UsageAccountStore()
        let accountId = UsageAccountID(rawValue: "local")

        await store.upsert(record(accountId: accountId, providerId: .localParsedUsage))
        let selected = await store.select(
            providerId: .localParsedUsage,
            accountId: accountId,
            selectedAt: "2026-07-08T13:00:00Z"
        )
        let stored = await store.account(providerId: .localParsedUsage, accountId: accountId)

        XCTAssertEqual(selected?.lastSelectedAt, "2026-07-08T13:00:00Z")
        XCTAssertEqual(stored?.lastSelectedAt, "2026-07-08T13:00:00Z")
    }

    func testStoreRemoveAndClearOnlyMutateInMemoryMetadata() async {
        let store = UsageAccountStore()
        let codexId = UsageAccountID(rawValue: "codex")
        let kimiId = UsageAccountID(rawValue: "kimi")

        await store.upsert(record(accountId: codexId, providerId: .codexRateLimits))
        await store.upsert(record(accountId: kimiId, providerId: .kimiUsage))

        let removed = await store.remove(providerId: .codexRateLimits, accountId: codexId)
        let removedRecord = await store.account(providerId: .codexRateLimits, accountId: codexId)
        let snapshotAfterRemove = await store.snapshot

        XCTAssertTrue(removed)
        XCTAssertNil(removedRecord)
        XCTAssertEqual(snapshotAfterRemove.accounts.count, 1)

        await store.clear()
        let snapshotAfterClear = await store.snapshot

        XCTAssertEqual(snapshotAfterClear.accounts, [])
    }

    private func record(
        accountId: UsageAccountID,
        providerId: UsageProviderIdentifier,
        category: UsageAccountCategory = .providerAccount,
        origin: UsageProviderAccountOrigin = .manual,
        displayLabel: String = "Account",
        lastSelectedAt: String? = nil,
        lastSnapshotSummary: String? = nil
    ) -> UsageAccountRecord {
        UsageAccountRecord(
            accountId: accountId,
            providerId: providerId,
            category: category,
            origin: origin,
            displayLabel: displayLabel,
            lastSelectedAt: lastSelectedAt,
            lastSnapshotSummary: lastSnapshotSummary
        )
    }

    private struct UsageAccountStoreMatrixFixture: Codable, Equatable {
        let rows: [UsageAccountStoreMatrixRow]
    }

    private struct UsageAccountStoreMatrixRow: Codable, Equatable {
        let id: String
        let accounts: [UsageAccountRecord]
        let providerAccountIds: [String]
        let selectedAccount: UsageAccountRecord?
        let removed: Bool?
    }
}
