import Foundation

public actor UsageAccountStore {
    private var records: [UsageAccountRecord]

    public init(snapshot: UsageAccountStoreSnapshot = UsageAccountStoreSnapshot()) {
        records = snapshot.accounts
    }

    public var snapshot: UsageAccountStoreSnapshot {
        UsageAccountStoreSnapshot(accounts: records)
    }

    public func accounts(for providerId: UsageProviderIdentifier) -> [UsageAccountRecord] {
        records.filter { $0.providerId == providerId }
    }

    public func account(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID
    ) -> UsageAccountRecord? {
        records.first { matches($0, providerId: providerId, accountId: accountId) }
    }

    public func upsert(_ record: UsageAccountRecord) {
        if let index = records.firstIndex(where: {
            matches($0, providerId: record.providerId, accountId: record.accountId)
        }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }

    @discardableResult
    public func remove(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID
    ) -> Bool {
        guard let index = records.firstIndex(where: {
            matches($0, providerId: providerId, accountId: accountId)
        }) else {
            return false
        }

        records.remove(at: index)
        return true
    }

    @discardableResult
    public func select(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID,
        selectedAt: String
    ) -> UsageAccountRecord? {
        guard let index = records.firstIndex(where: {
            matches($0, providerId: providerId, accountId: accountId)
        }) else {
            return nil
        }

        let current = records[index]
        let selected = UsageAccountRecord(
            accountId: current.accountId,
            providerId: current.providerId,
            category: current.category,
            origin: current.origin,
            displayLabel: current.displayLabel,
            lastSelectedAt: selectedAt,
            lastSnapshotSummary: current.lastSnapshotSummary
        )
        records[index] = selected
        return selected
    }

    public func clear() {
        records.removeAll()
    }

    private func matches(
        _ record: UsageAccountRecord,
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID
    ) -> Bool {
        record.providerId == providerId && record.accountId == accountId
    }
}
