import Foundation

public struct UsageRefreshPlanEntry: Codable, Equatable, Sendable {
    public let providerId: UsageProviderIdentifier
    public let providerDisplayName: String
    public let accountId: UsageAccountID?
    public let accountDisplayLabel: String?
    public let providerAvailability: UsageProviderAvailability
    public let minimumRefreshIntervalSeconds: Int
    public let state: UsageRefreshState
    public let decision: UsageRefreshDecision

    public init(
        providerId: UsageProviderIdentifier,
        providerDisplayName: String,
        accountId: UsageAccountID? = nil,
        accountDisplayLabel: String? = nil,
        providerAvailability: UsageProviderAvailability,
        minimumRefreshIntervalSeconds: Int,
        state: UsageRefreshState,
        decision: UsageRefreshDecision
    ) {
        self.providerId = providerId
        self.providerDisplayName = providerDisplayName
        self.accountId = accountId
        self.accountDisplayLabel = accountDisplayLabel
        self.providerAvailability = providerAvailability
        self.minimumRefreshIntervalSeconds = minimumRefreshIntervalSeconds
        self.state = state
        self.decision = decision
    }

    public var isRefreshAllowed: Bool {
        decision == .allowed
    }
}

public struct UsageRefreshPlan: Codable, Equatable, Sendable {
    public let entries: [UsageRefreshPlanEntry]

    public init(entries: [UsageRefreshPlanEntry]) {
        self.entries = entries
    }

    public var refreshableEntries: [UsageRefreshPlanEntry] {
        entries.filter(\.isRefreshAllowed)
    }

    public func entry(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) -> UsageRefreshPlanEntry? {
        entries.first {
            $0.providerId == providerId && $0.accountId == accountId
        }
    }
}
