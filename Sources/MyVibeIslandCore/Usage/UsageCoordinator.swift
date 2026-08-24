import Foundation

public enum UsageRefreshResult: Equatable, Sendable {
    case refreshed(UsageSnapshot)
    case skipped(UsageRefreshDecision)
}

public actor UsageCoordinator {
    private let providersById: [UsageProviderIdentifier: any UsageProvider]
    private let orderedDescriptors: [UsageProviderDescriptor]
    private let snapshotCache: UsageSnapshotCache
    private var refreshStatesByKey: [UsageRefreshStateKey: UsageRefreshState]

    public init(
        providers: [any UsageProvider] = [],
        snapshotCache: UsageSnapshotCache = UsageSnapshotCache()
    ) {
        var providersById: [UsageProviderIdentifier: any UsageProvider] = [:]
        var orderedDescriptors: [UsageProviderDescriptor] = []

        for provider in providers {
            let descriptor = provider.descriptor
            providersById[descriptor.id] = provider
            orderedDescriptors.append(descriptor)
        }

        self.providersById = providersById
        self.orderedDescriptors = orderedDescriptors
        self.snapshotCache = snapshotCache
        refreshStatesByKey = [:]
    }

    public var descriptors: [UsageProviderDescriptor] {
        orderedDescriptors
    }

    public func descriptor(for providerId: UsageProviderIdentifier) -> UsageProviderDescriptor? {
        providersById[providerId]?.descriptor
    }

    public nonisolated func selectedProvider(
        preferredProviderId: UsageProviderIdentifier? = nil,
        focusedProviderId: UsageProviderIdentifier? = nil,
        transientProviderId: UsageProviderIdentifier? = nil
    ) -> UsageProviderSelection {
        var rejectedHints: [UsageProviderSelectionRejectedHint] = []

        let candidates: [(UsageProviderIdentifier?, UsageProviderSelectionHintSource, UsageProviderSelectionReason)] = [
            (transientProviderId, .transient, .transient),
            (preferredProviderId, .preferred, .preferred),
            (focusedProviderId, .focused, .focused)
        ]

        for (providerId, source, reason) in candidates {
            guard let providerId else {
                continue
            }

            guard let descriptor = descriptorFromOrderedDescriptors(for: providerId) else {
                rejectedHints.append(
                    UsageProviderSelectionRejectedHint(
                        providerId: providerId,
                        source: source,
                        reason: .notRegistered
                    )
                )
                continue
            }

            guard descriptor.isSelectableUsageProvider else {
                rejectedHints.append(
                    UsageProviderSelectionRejectedHint(
                        providerId: providerId,
                        source: source,
                        reason: .unavailable
                    )
                )
                continue
            }

            return UsageProviderSelection(
                descriptor: descriptor,
                reason: reason,
                rejectedHints: rejectedHints
            )
        }

        if let fallback = orderedDescriptors.first(where: \.isSelectableUsageProvider) {
            return UsageProviderSelection(
                descriptor: fallback,
                reason: .fallback,
                rejectedHints: rejectedHints
            )
        }

        return UsageProviderSelection(
            descriptor: nil,
            reason: .none,
            rejectedHints: rejectedHints
        )
    }

    public nonisolated func selectedProvider(
        settings: UsageSettingsSnapshot,
        focusedProviderId: UsageProviderIdentifier? = nil,
        transientProviderId: UsageProviderIdentifier? = nil
    ) -> UsageProviderSelection {
        selectedProvider(
            preferredProviderId: settings.preferredProviderId,
            focusedProviderId: focusedProviderId,
            transientProviderId: transientProviderId
        )
    }

    public func refresh(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) async throws -> UsageSnapshot {
        guard let provider = providersById[providerId] else {
            return unavailableSnapshot(providerId: providerId, accountId: accountId)
        }

        let snapshot = try await provider.refresh(accountId: accountId)
        await snapshotCache.store(snapshot)
        return snapshot
    }

    public func refreshState(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) -> UsageRefreshState {
        refreshStatesByKey[UsageRefreshStateKey(providerId: providerId, accountId: accountId)] ?? UsageRefreshState()
    }

    public func refreshDecision(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil,
        nowSeconds: Int,
        minimumRefreshIntervalSeconds: Int
    ) -> UsageRefreshDecision {
        refreshState(providerId: providerId, accountId: accountId).decision(
            nowSeconds: nowSeconds,
            minimumRefreshIntervalSeconds: minimumRefreshIntervalSeconds
        )
    }

    public func refreshIfAllowed(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil,
        nowSeconds: Int,
        minimumRefreshIntervalSeconds: Int,
        baseBackoffSeconds: Int = 30,
        maximumBackoffMultiplier: Int = 8
    ) async throws -> UsageRefreshResult {
        let key = UsageRefreshStateKey(providerId: providerId, accountId: accountId)
        let state = refreshStatesByKey[key] ?? UsageRefreshState()
        let decision = state.decision(
            nowSeconds: nowSeconds,
            minimumRefreshIntervalSeconds: minimumRefreshIntervalSeconds
        )

        guard decision == .allowed else {
            return .skipped(decision)
        }

        refreshStatesByKey[key] = state.recordingRefreshStart(nowSeconds: nowSeconds)

        do {
            let snapshot = try await refresh(providerId: providerId, accountId: accountId)
            let currentState = refreshStatesByKey[key] ?? UsageRefreshState()
            refreshStatesByKey[key] = currentState.recordingSuccess(nowSeconds: nowSeconds)
            return .refreshed(snapshot)
        } catch {
            let currentState = refreshStatesByKey[key] ?? UsageRefreshState()
            refreshStatesByKey[key] = currentState.recordingFailure(
                nowSeconds: nowSeconds,
                baseBackoffSeconds: baseBackoffSeconds,
                maximumBackoffMultiplier: maximumBackoffMultiplier
            )
            throw error
        }
    }

    public func refreshPlan(
        accountRecords: [UsageAccountRecord] = [],
        nowSeconds: Int
    ) -> UsageRefreshPlan {
        let entries = orderedDescriptors.flatMap { descriptor in
            let matchingRecords = accountRecords.filter { $0.providerId == descriptor.id }
            if matchingRecords.isEmpty {
                return [
                    refreshPlanEntry(
                        descriptor: descriptor,
                        accountRecord: nil,
                        nowSeconds: nowSeconds
                    )
                ]
            }

            return matchingRecords.map {
                refreshPlanEntry(
                    descriptor: descriptor,
                    accountRecord: $0,
                    nowSeconds: nowSeconds
                )
            }
        }

        return UsageRefreshPlan(entries: entries)
    }

    public func presentationSnapshot(
        settings: UsageSettingsSnapshot,
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
        let selection = selectedProvider(
            settings: settings,
            focusedProviderId: focusedProviderId,
            transientProviderId: transientProviderId
        )

        guard let descriptor = selection.descriptor else {
            return UsagePresentationSnapshot(
                selection: selection,
                displayState: UsageDisplayState.make(
                    snapshot: nil,
                    settings: settings,
                    providerDisplayName: "Usage"
                ),
                resetPeekSchedulePlan: UsageResetPeekSchedulePlan.make(
                    currentIntents: [],
                    scheduledResetKeys: scheduledResetKeys
                )
            )
        }

        let snapshot = await cachedSnapshot(providerId: descriptor.id, accountId: accountId)
        let displayState = UsageDisplayState.make(
            snapshot: snapshot,
            settings: settings,
            providerDisplayName: descriptor.displayName
        )
        let generatedIntents = snapshot.map {
            UsagePeekIntent.make(snapshot: $0, settings: settings)
        } ?? []
        let peekIntents: [UsagePeekIntent]
        if let revealStore {
            peekIntents = await revealStore.unrevealedIntents(from: generatedIntents)
        } else {
            peekIntents = generatedIntents
        }
        let resetPeekSchedulePlan = UsageResetPeekSchedulePlan.make(
            currentIntents: peekIntents,
            scheduledResetKeys: scheduledResetKeys
        )
        let notificationPayloads = UsagePeekNotificationPayload.make(
            intents: peekIntents,
            soundEnabled: usageSoundEnabled ?? settings.usageSoundEnabled
        )
        let notificationDeliveryPlan = UsageNotificationDeliveryPlan.make(
            payloads: notificationPayloads,
            deliveredKeys: deliveredNotificationKeys,
            notificationsEnabled: usageNotificationsEnabled ?? settings.usageNotificationsEnabled
        )
        let diagnosticSummary = diagnosticSummary(providerId: descriptor.id, accountId: accountId)
        let selectedAccountRecord = accountRecords.first {
            $0.providerId == descriptor.id && $0.accountId == accountId
        }
        let selectedRefreshPlanEntry = refreshPlanNowSeconds.map {
            let state = refreshState(providerId: descriptor.id, accountId: accountId)
            return UsageRefreshPlanEntry(
                providerId: descriptor.id,
                providerDisplayName: descriptor.displayName,
                accountId: accountId,
                accountDisplayLabel: selectedAccountRecord?.displayLabel,
                providerAvailability: descriptor.availability,
                minimumRefreshIntervalSeconds: descriptor.minimumRefreshIntervalSeconds,
                state: state,
                decision: state.decision(
                    nowSeconds: $0,
                    minimumRefreshIntervalSeconds: descriptor.minimumRefreshIntervalSeconds
                )
            )
        }

        return UsagePresentationSnapshot(
            selection: selection,
            displayState: displayState,
            peekIntents: peekIntents,
            cachedSnapshot: snapshot,
            resetPeekSchedulePlan: resetPeekSchedulePlan,
            notificationPayloads: notificationPayloads,
            notificationDeliveryPlan: notificationDeliveryPlan,
            diagnosticSummary: diagnosticSummary,
            selectedRefreshPlanEntry: selectedRefreshPlanEntry,
            selectedAccountRecord: selectedAccountRecord
        )
    }

    public func cachedSnapshot(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) async -> UsageSnapshot? {
        if let snapshot = await snapshotCache.snapshot(providerId: providerId, accountId: accountId) {
            return snapshot
        }

        return providersById[providerId]?.cachedSnapshot(for: accountId)
    }

    public func markCachedSnapshotStale(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) async -> UsageSnapshot? {
        await snapshotCache.markStale(providerId: providerId, accountId: accountId)
    }

    public func diagnosticSummary(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil
    ) -> UsageProviderDiagnosticSummary {
        guard let provider = providersById[providerId] else {
            return UsageProviderDiagnosticSummary(
                providerId: providerId,
                availability: .unavailable,
                freshness: .unavailable,
                windowCount: 0,
                failure: .providerUnavailable
            )
        }

        return provider.diagnosticSummary(for: accountId)
    }

    private func unavailableSnapshot(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID?
    ) -> UsageSnapshot {
        UsageSnapshot(
            providerId: providerId,
            accountId: accountId,
            source: .unknown,
            freshness: .unavailable,
            error: .providerUnavailable,
            privacyLevel: .redacted
        )
    }

    private func refreshPlanEntry(
        descriptor: UsageProviderDescriptor,
        accountRecord: UsageAccountRecord?,
        nowSeconds: Int
    ) -> UsageRefreshPlanEntry {
        let state = refreshState(providerId: descriptor.id, accountId: accountRecord?.accountId)
        let decision = state.decision(
            nowSeconds: nowSeconds,
            minimumRefreshIntervalSeconds: descriptor.minimumRefreshIntervalSeconds
        )

        return UsageRefreshPlanEntry(
            providerId: descriptor.id,
            providerDisplayName: descriptor.displayName,
            accountId: accountRecord?.accountId,
            accountDisplayLabel: accountRecord?.displayLabel,
            providerAvailability: descriptor.availability,
            minimumRefreshIntervalSeconds: descriptor.minimumRefreshIntervalSeconds,
            state: state,
            decision: decision
        )
    }

    private nonisolated func descriptorFromOrderedDescriptors(
        for providerId: UsageProviderIdentifier
    ) -> UsageProviderDescriptor? {
        orderedDescriptors.first { $0.id == providerId }
    }
}

private struct UsageRefreshStateKey: Hashable {
    let providerId: UsageProviderIdentifier
    let accountIdRawValue: String?

    init(providerId: UsageProviderIdentifier, accountId: UsageAccountID?) {
        self.providerId = providerId
        accountIdRawValue = accountId?.rawValue
    }
}

private extension UsageProviderDescriptor {
    var isSelectableUsageProvider: Bool {
        availability != .disabled && availability != .unavailable
    }
}
