import XCTest
@testable import MyVibeIslandCore

final class UsagePresentationSnapshotTests: XCTestCase {
    func testUsagePresentationSnapshotSummaryMatrixMatchesFixtureSnapshot() async throws {
        let expected = try JSONDecoder().decode(
            UsagePresentationSnapshotSummaryMatrixFixture.self,
            from: try FixtureLoader.data("usage/presentation-snapshot-summary-matrix")
        )

        let noProviderPresentation = await UsageCoordinator(providers: []).presentationSnapshot(
            settings: UsageSettingsSnapshot(displayStyle: .compactHint),
            scheduledResetKeys: ["usageReset:codexRateLimits:2026-07-08T13:00:00Z"]
        )

        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(
            snapshot(
                providerId: .codexRateLimits,
                accountId: UsageAccountID(rawValue: "primary"),
                usedPercent: 85,
                resetAt: "2026-07-08T13:00:00Z"
            )
        )
        let availablePresentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .ringBadge,
                thresholdPeeksEnabled: true,
                thresholdPercent: 80,
                usageSoundEnabled: true
            ),
            accountId: UsageAccountID(rawValue: "primary"),
            accountRecords: [
                UsageAccountRecord(
                    accountId: UsageAccountID(rawValue: "primary"),
                    providerId: .codexRateLimits,
                    origin: .manual,
                    displayLabel: "Primary Codex"
                )
            ],
            deliveredNotificationKeys: ["usageThreshold:codexRateLimits:primary:80"],
            refreshPlanNowSeconds: 100
        )

        let actual = UsagePresentationSnapshotSummaryMatrixFixture(rows: [
            summaryRow(id: "no-provider", presentation: noProviderPresentation),
            summaryRow(id: "available-with-peeks", presentation: availablePresentation),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testNoSelectedProviderReturnsUnavailableDisplayWithoutPeeks() async {
        let coordinator = UsageCoordinator(providers: [])

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(displayStyle: .compactHint)
        )

        XCTAssertNil(presentation.selection.descriptor)
        XCTAssertEqual(presentation.selection.reason, .none)
        XCTAssertEqual(presentation.displayState.status, .unavailable)
        XCTAssertEqual(presentation.displayState.primaryText, "Usage unavailable")
        XCTAssertNil(presentation.cachedSnapshot)
        XCTAssertEqual(presentation.peekIntents, [])
        XCTAssertEqual(presentation.notificationPayloads, [])
        XCTAssertEqual(presentation.notificationDeliveryPlan.actions, [])
        XCTAssertNil(presentation.diagnosticSummary)
        XCTAssertNil(presentation.selectedRefreshPlanEntry)
    }

    func testCachedSelectedProviderSnapshotBecomesDisplayState() async throws {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 64))

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .ringBadge,
                valueMode: .used
            )
        )

        XCTAssertEqual(presentation.selection.descriptor?.id, .codexRateLimits)
        XCTAssertEqual(presentation.displayState.status, .available)
        XCTAssertEqual(presentation.displayState.title, "Codex")
        XCTAssertEqual(presentation.displayState.primaryText, "64% used")
        XCTAssertEqual(presentation.cachedSnapshot?.primaryWindow?.usedPercent, 64)
    }

    func testPresentationIncludesSelectedProviderDiagnosticSummary() async throws {
        let diagnostic = UsageProviderDiagnosticSummary(
            providerId: .codexRateLimits,
            availability: .available,
            freshness: .fresh,
            windowCount: 1,
            failure: .localBridgeUnavailable,
            redactedDetail: "rate limit cache unavailable"
        )
        let provider = PresentationUsageProvider(
            descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"),
            diagnosticSummary: diagnostic
        )
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 64))

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .ringBadge
            )
        )

        XCTAssertEqual(presentation.diagnosticSummary, diagnostic)
    }

    func testPresentationDiagnosticSummaryUsesAccountId() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let coordinator = UsageCoordinator(providers: [provider])
        let accountId = UsageAccountID(rawValue: "primary")

        _ = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint
            ),
            accountId: accountId
        )

        XCTAssertEqual(provider.diagnosticAccountIds, [accountId])
    }

    func testPresentationRefreshPlanEntryIsNilWithoutTimestamp() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let coordinator = UsageCoordinator(providers: [provider])

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint
            )
        )

        XCTAssertNil(presentation.selectedRefreshPlanEntry)
    }

    func testPresentationIncludesAllowedSelectedRefreshPlanEntryWhenTimestampIsProvided() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let coordinator = UsageCoordinator(providers: [provider])
        let accountId = UsageAccountID(rawValue: "primary")

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint
            ),
            accountId: accountId,
            refreshPlanNowSeconds: 100
        )

        XCTAssertEqual(presentation.selectedRefreshPlanEntry?.providerId, .codexRateLimits)
        XCTAssertEqual(presentation.selectedRefreshPlanEntry?.providerDisplayName, "Codex")
        XCTAssertEqual(presentation.selectedRefreshPlanEntry?.accountId, accountId)
        XCTAssertEqual(presentation.selectedRefreshPlanEntry?.providerAvailability, .available)
        XCTAssertEqual(presentation.selectedRefreshPlanEntry?.minimumRefreshIntervalSeconds, 60)
        XCTAssertEqual(presentation.selectedRefreshPlanEntry?.decision, .allowed)
        XCTAssertNil(presentation.selectedRefreshPlanEntry?.accountDisplayLabel)
    }

    func testPresentationRefreshPlanEntryPreservesMatchingAccountDisplayLabel() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let coordinator = UsageCoordinator(providers: [provider])
        let accountId = UsageAccountID(rawValue: "primary")
        let account = UsageAccountRecord(
            accountId: accountId,
            providerId: .codexRateLimits,
            origin: .manual,
            displayLabel: "Primary Codex"
        )

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint
            ),
            accountId: accountId,
            accountRecords: [account],
            refreshPlanNowSeconds: 100
        )

        XCTAssertEqual(presentation.selectedRefreshPlanEntry?.accountDisplayLabel, "Primary Codex")
    }

    func testPresentationIncludesSelectedAccountRecord() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let coordinator = UsageCoordinator(providers: [provider])
        let accountId = UsageAccountID(rawValue: "primary")
        let account = UsageAccountRecord(
            accountId: accountId,
            providerId: .codexRateLimits,
            origin: .manual,
            displayLabel: "Primary Codex",
            lastSelectedAt: "2026-07-08T13:00:00Z",
            lastSnapshotSummary: "64% used"
        )

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint
            ),
            accountId: accountId,
            accountRecords: [account]
        )

        XCTAssertEqual(presentation.selectedAccountRecord, account)
    }

    func testPresentationSelectedAccountRecordIgnoresUnmatchedRecord() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let coordinator = UsageCoordinator(providers: [provider])
        let accountId = UsageAccountID(rawValue: "primary")
        let unrelated = UsageAccountRecord(
            accountId: UsageAccountID(rawValue: "other"),
            providerId: .codexRateLimits,
            origin: .manual,
            displayLabel: "Other Codex"
        )

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint
            ),
            accountId: accountId,
            accountRecords: [unrelated]
        )

        XCTAssertNil(presentation.selectedAccountRecord)
    }

    func testPresentationSelectedAccountRecordIsNilWithoutAccountId() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let coordinator = UsageCoordinator(providers: [provider])
        let account = UsageAccountRecord(
            accountId: UsageAccountID(rawValue: "primary"),
            providerId: .codexRateLimits,
            origin: .manual,
            displayLabel: "Primary Codex"
        )

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint
            ),
            accountRecords: [account]
        )

        XCTAssertNil(presentation.selectedAccountRecord)
    }

    func testPresentationRefreshPlanEntryIgnoresUnmatchedAccountRecord() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let coordinator = UsageCoordinator(providers: [provider])
        let accountId = UsageAccountID(rawValue: "primary")
        let unrelated = UsageAccountRecord(
            accountId: UsageAccountID(rawValue: "other"),
            providerId: .codexRateLimits,
            origin: .manual,
            displayLabel: "Other Codex"
        )

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint
            ),
            accountId: accountId,
            accountRecords: [unrelated],
            refreshPlanNowSeconds: 100
        )

        XCTAssertNil(presentation.selectedRefreshPlanEntry?.accountDisplayLabel)
    }

    func testPresentationRefreshPlanEntryReflectsRefreshGateState() async throws {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let coordinator = UsageCoordinator(providers: [provider])

        _ = try await coordinator.refreshIfAllowed(
            providerId: .codexRateLimits,
            nowSeconds: 100,
            minimumRefreshIntervalSeconds: 60
        )
        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint
            ),
            refreshPlanNowSeconds: 120
        )

        XCTAssertEqual(presentation.selectedRefreshPlanEntry?.decision, .minimumIntervalActive(remainingSeconds: 40))
        XCTAssertEqual(presentation.selectedRefreshPlanEntry?.state.lastFetchAttemptSeconds, 100)
        XCTAssertEqual(provider.refreshCount, 1)
    }

    func testPresentationGeneratesThresholdPeekFromCachedSnapshot() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 85))

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint,
                thresholdPeeksEnabled: true,
                thresholdPercent: 80
            )
        )

        XCTAssertEqual(presentation.peekIntents.map(\.dedupeKey), ["usageThreshold:codexRateLimits:primary:80"])
    }

    func testPresentationIncludesNotificationPayloadsFromPeekIntents() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 85))

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint,
                thresholdPeeksEnabled: true,
                thresholdPercent: 80
            )
        )

        XCTAssertEqual(presentation.notificationPayloads.map(\.category), [.usageThreshold])
        XCTAssertEqual(presentation.notificationPayloads.map(\.severity), [.warning])
        XCTAssertEqual(presentation.notificationPayloads.map(\.dedupeKey), ["usageThreshold:codexRateLimits:primary:80"])
        XCTAssertEqual(presentation.notificationDeliveryPlan.deliverablePayloads.map(\.dedupeKey), ["usageThreshold:codexRateLimits:primary:80"])
    }

    func testPresentationNotificationPayloadsRespectUsageSoundFlag() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 100))
        let settings = UsageSettingsSnapshot(
            preferredProviderId: .codexRateLimits,
            displayStyle: .compactHint,
            thresholdPeeksEnabled: true,
            thresholdPercent: 80
        )

        let silent = await coordinator.presentationSnapshot(settings: settings)
        let audible = await coordinator.presentationSnapshot(settings: settings, usageSoundEnabled: true)

        XCTAssertTrue(silent.notificationPayloads.allSatisfy { $0.soundCategory == nil })
        XCTAssertTrue(audible.notificationPayloads.allSatisfy { $0.soundCategory == .usage })
    }

    func testPresentationNotificationPayloadsUseSettingsSoundToggleByDefault() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 100))

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint,
                thresholdPeeksEnabled: true,
                thresholdPercent: 80,
                usageSoundEnabled: true
            )
        )

        XCTAssertTrue(presentation.notificationPayloads.allSatisfy { $0.soundCategory == .usage })
    }

    func testPresentationSoundOverrideWinsOverSettingsToggle() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 100))

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint,
                thresholdPeeksEnabled: true,
                thresholdPercent: 80,
                usageSoundEnabled: true
            ),
            usageSoundEnabled: false
        )

        XCTAssertTrue(presentation.notificationPayloads.allSatisfy { $0.soundCategory == nil })
    }

    func testPresentationDeliveryPlanSuppressesAlreadyDeliveredNotificationKey() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 85))

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint,
                thresholdPeeksEnabled: true,
                thresholdPercent: 80
            ),
            deliveredNotificationKeys: ["usageThreshold:codexRateLimits:primary:80"]
        )

        XCTAssertEqual(
            presentation.notificationDeliveryPlan.actions,
            [.suppress(dedupeKey: "usageThreshold:codexRateLimits:primary:80", reason: .alreadyDelivered)]
        )
    }

    func testPresentationDeliveryPlanSuppressesWhenUsageNotificationsAreDisabled() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 85))

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint,
                thresholdPeeksEnabled: true,
                thresholdPercent: 80
            ),
            usageNotificationsEnabled: false
        )

        XCTAssertEqual(
            presentation.notificationDeliveryPlan.actions,
            [.suppress(dedupeKey: "usageThreshold:codexRateLimits:primary:80", reason: .notificationsDisabled)]
        )
    }

    func testPresentationDeliveryPlanUsesSettingsNotificationToggleByDefault() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 85))

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint,
                thresholdPeeksEnabled: true,
                thresholdPercent: 80,
                usageNotificationsEnabled: false
            )
        )

        XCTAssertEqual(
            presentation.notificationDeliveryPlan.actions,
            [.suppress(dedupeKey: "usageThreshold:codexRateLimits:primary:80", reason: .notificationsDisabled)]
        )
    }

    func testPresentationNotificationOverrideWinsOverSettingsToggle() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 85))

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint,
                thresholdPeeksEnabled: true,
                thresholdPercent: 80,
                usageNotificationsEnabled: false
            ),
            usageNotificationsEnabled: true
        )

        XCTAssertEqual(
            presentation.notificationDeliveryPlan.deliverablePayloads.map(\.dedupeKey),
            ["usageThreshold:codexRateLimits:primary:80"]
        )
    }

    func testPresentationIncludesResetSchedulePlanFromCachedSnapshot() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(
            snapshot(
                providerId: .codexRateLimits,
                usedPercent: 20,
                resetAt: "2026-07-08T13:00:00Z"
            )
        )

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint,
                thresholdPeeksEnabled: true
            )
        )

        XCTAssertEqual(
            presentation.resetPeekSchedulePlan.scheduledIntents.map(\.dedupeKey),
            ["usageReset:codexRateLimits:2026-07-08T13:00:00Z"]
        )
        XCTAssertEqual(presentation.resetPeekSchedulePlan.canceledKeys, [])
    }

    func testPresentationDoesNotRescheduleExistingResetKey() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(
            snapshot(
                providerId: .codexRateLimits,
                usedPercent: 20,
                resetAt: "2026-07-08T13:00:00Z"
            )
        )

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint,
                thresholdPeeksEnabled: true
            ),
            scheduledResetKeys: ["usageReset:codexRateLimits:2026-07-08T13:00:00Z"]
        )

        XCTAssertEqual(presentation.resetPeekSchedulePlan.actions, [])
    }

    func testPresentationCancelsScheduledResetWhenNoResetIntentRemains() async {
        let coordinator = UsageCoordinator(providers: [])

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(displayStyle: .compactHint),
            scheduledResetKeys: [
                "usageReset:codexRateLimits:2026-07-08T13:00:00Z"
            ]
        )

        XCTAssertEqual(
            presentation.resetPeekSchedulePlan.canceledKeys,
            ["usageReset:codexRateLimits:2026-07-08T13:00:00Z"]
        )
    }

    func testPresentationSnapshotRoundTripsWithResetSchedulePlan() async throws {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(
            snapshot(
                providerId: .codexRateLimits,
                accountId: UsageAccountID(rawValue: "primary"),
                usedPercent: 20,
                resetAt: "2026-07-08T13:00:00Z"
            )
        )

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .compactHint,
                thresholdPeeksEnabled: true
            ),
            accountId: UsageAccountID(rawValue: "primary"),
            accountRecords: [
                UsageAccountRecord(
                    accountId: UsageAccountID(rawValue: "primary"),
                    providerId: .codexRateLimits,
                    origin: .manual,
                    displayLabel: "Primary Codex"
                )
            ],
            refreshPlanNowSeconds: 100
        )
        let data = try JSONEncoder().encode(presentation)
        let decoded = try JSONDecoder().decode(UsagePresentationSnapshot.self, from: data)

        XCTAssertEqual(decoded, presentation)
        XCTAssertEqual(decoded.resetPeekSchedulePlan.scheduledIntents.count, 1)
        XCTAssertNotNil(decoded.diagnosticSummary)
        XCTAssertNotNil(decoded.selectedRefreshPlanEntry)
        XCTAssertNotNil(decoded.selectedAccountRecord)
    }

    func testRevealStoreFiltersRepeatedPresentationPeekIntents() async {
        let provider = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let cache = UsageSnapshotCache()
        let revealStore = UsagePeekRevealStore()
        let coordinator = UsageCoordinator(providers: [provider], snapshotCache: cache)
        await cache.store(snapshot(providerId: .codexRateLimits, usedPercent: 85))
        let settings = UsageSettingsSnapshot(
            preferredProviderId: .codexRateLimits,
            displayStyle: .compactHint,
            thresholdPeeksEnabled: true,
            thresholdPercent: 80
        )

        let first = await coordinator.presentationSnapshot(settings: settings, revealStore: revealStore)
        let second = await coordinator.presentationSnapshot(settings: settings, revealStore: revealStore)

        XCTAssertEqual(first.peekIntents.count, 1)
        XCTAssertEqual(second.peekIntents, [])
        XCTAssertEqual(first.notificationPayloads.count, 1)
        XCTAssertEqual(second.notificationPayloads, [])
        XCTAssertEqual(first.notificationDeliveryPlan.deliverablePayloads.count, 1)
        XCTAssertEqual(second.notificationDeliveryPlan.actions, [])
    }

    func testFocusedProviderHintIsHonoredWhenSettingsHasNoPreferredProvider() async {
        let codex = PresentationUsageProvider(descriptor: descriptor(id: .codexRateLimits, displayName: "Codex"))
        let local = PresentationUsageProvider(descriptor: descriptor(id: .localParsedUsage, displayName: "Local"))
        let cache = UsageSnapshotCache()
        let coordinator = UsageCoordinator(providers: [codex, local], snapshotCache: cache)
        await cache.store(snapshot(providerId: .localParsedUsage, usedPercent: 25))

        let presentation = await coordinator.presentationSnapshot(
            settings: UsageSettingsSnapshot(displayStyle: .infoBar),
            focusedProviderId: .localParsedUsage
        )

        XCTAssertEqual(presentation.selection.descriptor?.id, .localParsedUsage)
        XCTAssertEqual(presentation.selection.reason, .focused)
        XCTAssertEqual(presentation.displayState.title, "Local")
        XCTAssertEqual(presentation.displayState.primaryText, "25% used")
    }

    private func snapshot(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil,
        usedPercent: Double,
        resetAt: String? = nil
    ) -> UsageSnapshot {
        UsageSnapshot(
            providerId: providerId,
            accountId: accountId,
            source: .providerReported,
            freshness: .fresh,
            primaryWindow: UsageLimitWindow(
                id: "primary",
                label: "Primary",
                kind: .fiveHour,
                usedPercent: usedPercent,
                resetAt: resetAt,
                sourceConfidence: .providerReported
            ),
            privacyLevel: .redacted
        )
    }

    private func summaryRow(
        id: String,
        presentation: UsagePresentationSnapshot
    ) -> UsagePresentationSnapshotSummaryRow {
        UsagePresentationSnapshotSummaryRow(
            id: id,
            selectedProviderId: presentation.selection.descriptor?.id.rawValue,
            selectionReason: "\(presentation.selection.reason)",
            displayStatus: presentation.displayState.status.rawValue,
            displayStyle: presentation.displayState.displayStyle.rawValue,
            primaryText: presentation.displayState.primaryText,
            cachedProviderId: presentation.cachedSnapshot?.providerId.rawValue,
            cachedAccountId: presentation.cachedSnapshot?.accountId?.rawValue,
            peekKeys: presentation.peekIntents.map(\.dedupeKey),
            notificationKeys: presentation.notificationPayloads.map(\.dedupeKey),
            deliveryActions: presentation.notificationDeliveryPlan.actions.map(deliveryActionSummary),
            resetScheduleActions: presentation.resetPeekSchedulePlan.actions.map(resetScheduleActionSummary),
            diagnosticProviderId: presentation.diagnosticSummary?.providerId.rawValue,
            refreshDecision: presentation.selectedRefreshPlanEntry.map { "\($0.decision)" },
            accountDisplayLabel: presentation.selectedAccountRecord?.displayLabel
        )
    }

    private func deliveryActionSummary(_ action: UsageNotificationDeliveryAction) -> String {
        switch action {
        case let .deliver(payload):
            return "deliver:\(payload.dedupeKey)"
        case let .suppress(dedupeKey, reason):
            return "suppress:\(dedupeKey):\(reason.rawValue)"
        }
    }

    private func resetScheduleActionSummary(_ action: UsageResetPeekScheduleAction) -> String {
        switch action {
        case let .schedule(intent):
            return "schedule:\(intent.dedupeKey)"
        case let .cancel(dedupeKey):
            return "cancel:\(dedupeKey)"
        }
    }

    private struct UsagePresentationSnapshotSummaryMatrixFixture: Codable, Equatable {
        let rows: [UsagePresentationSnapshotSummaryRow]
    }

    private struct UsagePresentationSnapshotSummaryRow: Codable, Equatable {
        let id: String
        let selectedProviderId: String?
        let selectionReason: String
        let displayStatus: String
        let displayStyle: String
        let primaryText: String?
        let cachedProviderId: String?
        let cachedAccountId: String?
        let peekKeys: [String]
        let notificationKeys: [String]
        let deliveryActions: [String]
        let resetScheduleActions: [String]
        let diagnosticProviderId: String?
        let refreshDecision: String?
        let accountDisplayLabel: String?
    }
}

private final class PresentationUsageProvider: UsageProvider, @unchecked Sendable {
    let descriptor: UsageProviderDescriptor
    let configuredDiagnosticSummary: UsageProviderDiagnosticSummary?
    private(set) var diagnosticAccountIds: [UsageAccountID?]
    private(set) var refreshCount: Int

    init(
        descriptor: UsageProviderDescriptor,
        diagnosticSummary: UsageProviderDiagnosticSummary? = nil
    ) {
        self.descriptor = descriptor
        configuredDiagnosticSummary = diagnosticSummary
        diagnosticAccountIds = []
        refreshCount = 0
    }

    func status(for accountId: UsageAccountID?) -> UsageProviderAvailability {
        descriptor.availability
    }

    func cachedSnapshot(for accountId: UsageAccountID?) -> UsageSnapshot? {
        nil
    }

    func diagnosticSummary(for accountId: UsageAccountID?) -> UsageProviderDiagnosticSummary {
        diagnosticAccountIds.append(accountId)
        return configuredDiagnosticSummary ?? UsageProviderDiagnosticSummary(
            providerId: descriptor.id,
            availability: descriptor.availability,
            freshness: .unavailable,
            windowCount: 0
        )
    }

    func refresh(accountId: UsageAccountID?) async throws -> UsageSnapshot {
        refreshCount += 1
        return UsageSnapshot(
            providerId: descriptor.id,
            accountId: accountId,
            source: .unknown,
            freshness: .unavailable,
            privacyLevel: .redacted
        )
    }
}

private func descriptor(
    id: UsageProviderIdentifier,
    displayName: String
) -> UsageProviderDescriptor {
    UsageProviderDescriptor(
        id: id,
        displayName: displayName,
        capabilities: [.normalizedSnapshotOnly],
        minimumRefreshIntervalSeconds: 60,
        availability: .available
    )
}
