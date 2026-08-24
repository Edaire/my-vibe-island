import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitUsageCoordinatorController {
    public private(set) var settings: UsageSettingsSnapshot
    public private(set) var lastRefreshPlan: UsageRefreshPlan?
    public private(set) var lastRefreshResult: UsageRefreshResult?
    public private(set) var lastPresentationSnapshot: UsagePresentationSnapshot?

    private let coordinator: UsageCoordinator
    private let publishRefreshPlan: @MainActor (UsageRefreshPlan) -> Void
    private let publishRefreshResult: @MainActor (UsageRefreshResult) -> Void
    private let publishPresentation: @MainActor (UsagePresentationSnapshot) -> Void

    public init(
        coordinator: UsageCoordinator = UsageCoordinator(),
        settings: UsageSettingsSnapshot = UsageSettingsSnapshot(),
        publishRefreshPlan: @escaping @MainActor (UsageRefreshPlan) -> Void = { _ in },
        publishRefreshResult: @escaping @MainActor (UsageRefreshResult) -> Void = { _ in },
        publishPresentation: @escaping @MainActor (UsagePresentationSnapshot) -> Void = { _ in }
    ) {
        self.coordinator = coordinator
        self.settings = settings
        self.publishRefreshPlan = publishRefreshPlan
        self.publishRefreshResult = publishRefreshResult
        self.publishPresentation = publishPresentation
    }

    @discardableResult
    public func refreshPlan(
        accountRecords: [UsageAccountRecord] = [],
        nowSeconds: Int
    ) async -> UsageRefreshPlan {
        let plan = await coordinator.refreshPlan(
            accountRecords: accountRecords,
            nowSeconds: nowSeconds
        )
        lastRefreshPlan = plan
        publishRefreshPlan(plan)
        return plan
    }

    @discardableResult
    public func refreshIfAllowed(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil,
        nowSeconds: Int,
        minimumRefreshIntervalSeconds: Int
    ) async throws -> UsageRefreshResult {
        let result = try await coordinator.refreshIfAllowed(
            providerId: providerId,
            accountId: accountId,
            nowSeconds: nowSeconds,
            minimumRefreshIntervalSeconds: minimumRefreshIntervalSeconds
        )
        lastRefreshResult = result
        publishRefreshResult(result)
        return result
    }

    @discardableResult
    public func presentationSnapshot(
        accountId: UsageAccountID? = nil,
        accountRecords: [UsageAccountRecord] = [],
        focusedProviderId: UsageProviderIdentifier? = nil,
        transientProviderId: UsageProviderIdentifier? = nil,
        revealStore: UsagePeekRevealStore? = nil,
        scheduledResetKeys: Set<String> = [],
        usageSoundEnabled: Bool? = nil,
        deliveredNotificationKeys: Set<String> = [],
        usageNotificationsEnabled: Bool? = nil,
        refreshPlanNowSeconds: Int? = nil
    ) async -> UsagePresentationSnapshot {
        let snapshot = await coordinator.presentationSnapshot(
            settings: settings,
            accountId: accountId,
            accountRecords: accountRecords,
            focusedProviderId: focusedProviderId,
            transientProviderId: transientProviderId,
            revealStore: revealStore,
            scheduledResetKeys: scheduledResetKeys,
            usageSoundEnabled: usageSoundEnabled,
            deliveredNotificationKeys: deliveredNotificationKeys,
            usageNotificationsEnabled: usageNotificationsEnabled,
            refreshPlanNowSeconds: refreshPlanNowSeconds
        )
        lastPresentationSnapshot = snapshot
        publishPresentation(snapshot)
        return snapshot
    }
}
