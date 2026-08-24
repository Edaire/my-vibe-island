import XCTest
@testable import MyVibeIslandCore

final class UsageModelsTests: XCTestCase {
    func testUsageCoreModelsMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsageCoreModelsMatrixFixture.self,
            from: try FixtureLoader.data("usage/core-models-matrix")
        )

        let actual = UsageCoreModelsMatrixFixture(
            amountRows: [
                UsageAmountPercentRow(
                    id: "normal-percent",
                    used: UsageAmount(value: 25, unit: "requests"),
                    limit: UsageAmount(value: 100, unit: "requests")
                ),
                UsageAmountPercentRow(
                    id: "zero-limit",
                    used: UsageAmount(value: 25, unit: "requests"),
                    limit: UsageAmount(value: 0, unit: "requests")
                ),
                UsageAmountPercentRow(
                    id: "over-limit",
                    used: UsageAmount(value: 125, unit: "requests"),
                    limit: UsageAmount(value: 100, unit: "requests")
                ),
                UsageAmountPercentRow(
                    id: "missing-limit",
                    used: UsageAmount(value: 25, unit: "requests"),
                    limit: nil
                ),
            ],
            snapshotRows: [
                UsageSnapshotProjectionRow(
                    id: "provider-quota-full-projection",
                    providerSnapshot: providerQuotaSnapshot()
                ),
                UsageSnapshotProjectionRow(
                    id: "provider-quota-failure-projection",
                    providerSnapshot: ProviderQuotaSnapshot(
                        providerId: .kimiUsage,
                        source: .unknown,
                        freshness: .unavailable,
                        failure: .credentialMissing,
                        privacyLevel: .redacted
                    )
                ),
            ],
            waitingRows: [
                try UsageWaitingHintRow(
                    id: "structured-waiting-hint",
                    data: JSONEncoder().encode(
                        UsageWaitingHint(
                            providerId: .kimiUsage,
                            reason: .minimumIntervalActive,
                            severity: .warning,
                            text: "Refresh available soon",
                            retryAfterSeconds: 45,
                            action: .retry,
                            redactedDetail: "minimum interval active"
                        )
                    )
                ),
                try UsageWaitingHintRow(
                    id: "legacy-string-waiting-hint",
                    data: JSONEncoder().encode("Authorize provider")
                ),
            ]
        )

        XCTAssertEqual(actual, expected)
    }

    func testUsageAmountCalculatesUsedPercentDeterministically() {
        XCTAssertEqual(UsageAmount(value: 25, unit: "requests").usedPercent(of: UsageAmount(value: 100, unit: "requests")), 25)
        XCTAssertEqual(UsageAmount(value: 0, unit: "requests").usedPercent(of: UsageAmount(value: 100, unit: "requests")), 0)
        XCTAssertEqual(UsageAmount(value: 25, unit: "requests").usedPercent(of: UsageAmount(value: 0, unit: "requests")), nil)
        XCTAssertEqual(UsageAmount(value: 125, unit: "requests").usedPercent(of: UsageAmount(value: 100, unit: "requests")), 125)
        XCTAssertEqual(UsageAmount(value: 25, unit: "requests").usedPercent(of: nil), nil)
    }

    func testUsageLimitWindowRoundTripsThroughJSON() throws {
        let window = UsageLimitWindow(
            id: "primary",
            label: "Primary",
            kind: .fiveHour,
            used: UsageAmount(value: 80, unit: "percent", precision: .approximate, displayBucket: .high),
            limit: UsageAmount(value: 100, unit: "percent"),
            remaining: UsageAmount(value: 20, unit: "percent"),
            usedPercent: 80,
            resetAt: "2026-07-08T12:00:00Z",
            resetInSeconds: 3600,
            isUnlimited: false,
            sourceConfidence: .providerReported
        )

        let data = try JSONEncoder().encode(window)
        let decoded = try JSONDecoder().decode(UsageLimitWindow.self, from: data)

        XCTAssertEqual(decoded, window)
    }

    func testUsageLimitWindowSlotUsesStableRawValues() {
        XCTAssertEqual(UsageLimitWindowSlot.primary.rawValue, "primary")
        XCTAssertEqual(UsageLimitWindowSlot.secondary.rawValue, "secondary")
        XCTAssertEqual(UsageLimitWindowSlot.extra.rawValue, "extra")
    }

    func testUsageLimitWindowSlotRoundTripsThroughJSON() throws {
        let slots: [UsageLimitWindowSlot] = [.primary, .secondary, .extra]

        let data = try JSONEncoder().encode(slots)
        let decoded = try JSONDecoder().decode([UsageLimitWindowSlot].self, from: data)

        XCTAssertEqual(decoded, slots)
    }

    func testUsageLimitSourceRoundTripsThroughJSON() throws {
        let source = UsageLimitSource(
            providerId: .codexRateLimits,
            confidence: .providerReported,
            accountId: UsageAccountID(rawValue: "codex-local"),
            collectedAt: "2026-07-08T14:10:00Z",
            redactedDetail: "local provider metadata"
        )

        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(UsageLimitSource.self, from: data)

        XCTAssertEqual(decoded, source)
        XCTAssertEqual(decoded.providerId, .codexRateLimits)
        XCTAssertEqual(decoded.confidence, .providerReported)
        XCTAssertEqual(decoded.accountId?.rawValue, "codex-local")
    }

    func testUsageLimitSourceDefaultsOptionalMetadataToNil() {
        let source = UsageLimitSource(
            providerId: .localParsedUsage,
            confidence: .parsed
        )

        XCTAssertEqual(source.providerId, .localParsedUsage)
        XCTAssertEqual(source.confidence, .parsed)
        XCTAssertNil(source.accountId)
        XCTAssertNil(source.collectedAt)
        XCTAssertNil(source.redactedDetail)
    }

    func testUsageRefreshTriggerUsesStableRawValues() {
        XCTAssertEqual(UsageRefreshTrigger.usageDisplayOpened.rawValue, "usageDisplayOpened")
        XCTAssertEqual(UsageRefreshTrigger.focusedSessionChanged.rawValue, "focusedSessionChanged")
        XCTAssertEqual(UsageRefreshTrigger.providerPreferenceChanged.rawValue, "providerPreferenceChanged")
        XCTAssertEqual(UsageRefreshTrigger.providerRateLimitUpdated.rawValue, "providerRateLimitUpdated")
        XCTAssertEqual(UsageRefreshTrigger.resetTimerFired.rawValue, "resetTimerFired")
        XCTAssertEqual(UsageRefreshTrigger.manualRefresh.rawValue, "manualRefresh")
    }

    func testUsageRefreshTriggerRoundTripsThroughJSON() throws {
        let triggers: [UsageRefreshTrigger] = [
            .usageDisplayOpened,
            .focusedSessionChanged,
            .providerPreferenceChanged,
            .providerRateLimitUpdated,
            .resetTimerFired,
            .manualRefresh
        ]

        let data = try JSONEncoder().encode(triggers)
        let decoded = try JSONDecoder().decode([UsageRefreshTrigger].self, from: data)

        XCTAssertEqual(decoded, triggers)
    }

    func testUsageExtraUsageItemRoundTripsStructuredProviderMetadata() throws {
        let item = UsageExtraUsageItem(
            key: "credits",
            value: "42 of 100 credits",
            isEnabled: true,
            utilization: 0.42,
            monthlyLimit: UsageAmount(value: 100, unit: "credits"),
            usedCredits: UsageAmount(value: 42, unit: "credits"),
            currency: "USD"
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(UsageExtraUsageItem.self, from: data)

        XCTAssertEqual(decoded, item)
        XCTAssertEqual(decoded.monthlyLimit?.value, 100)
        XCTAssertEqual(decoded.usedCredits?.value, 42)
        XCTAssertEqual(decoded.currency, "USD")
    }

    func testProviderQuotaSnapshotRoundTripsThroughJSON() throws {
        let snapshot = ProviderQuotaSnapshot(
            providerId: .zaiQuota,
            accountId: UsageAccountID(rawValue: "zai-local"),
            source: .providerReported,
            collectedAt: "2026-07-08T12:30:00Z",
            freshness: .fresh,
            primaryWindow: UsageLimitWindow(
                id: "monthly",
                label: "Monthly quota",
                kind: .monthly,
                used: UsageAmount(value: 42, unit: "credits"),
                limit: UsageAmount(value: 100, unit: "credits"),
                remaining: UsageAmount(value: 58, unit: "credits"),
                usedPercent: 42,
                resetAt: "2026-08-01T00:00:00Z",
                resetInSeconds: 2_030_400,
                sourceConfidence: .providerReported
            ),
            secondaryWindow: UsageLimitWindow(
                id: "parallel",
                label: "Parallel quota",
                kind: .parallelQuota,
                usedPercent: 25,
                sourceConfidence: .providerReported
            ),
            extraWindows: [
                UsageLimitWindow(
                    id: "provider-specific",
                    label: "Provider specific",
                    kind: .providerSpecific,
                    usedPercent: 10,
                    sourceConfidence: .providerReported
                )
            ],
            extraUsage: [
                UsageExtraUsageItem(
                    key: "credits",
                    value: "42 of 100 credits",
                    isEnabled: true,
                    utilization: 0.42,
                    monthlyLimit: UsageAmount(value: 100, unit: "credits"),
                    usedCredits: UsageAmount(value: 42, unit: "credits"),
                    currency: "USD"
                )
            ],
            bridgeHint: UsageBridgeHint(
                providerId: .zaiQuota,
                severity: .info,
                title: "Z.ai quota available",
                action: .none,
                redactedDetail: "provider quota metadata"
            ),
            waitingHint: UsageWaitingHint(
                providerId: .zaiQuota,
                reason: .minimumIntervalActive,
                severity: .info,
                text: "Refresh available soon",
                retryAfterSeconds: 30,
                action: .retry,
                redactedDetail: "minimum interval active"
            ),
            failure: nil,
            privacyLevel: .redacted
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ProviderQuotaSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.primaryWindow?.usedPercent, 42)
        XCTAssertEqual(decoded.extraWindows.count, 1)
        XCTAssertEqual(decoded.extraUsage.first?.usedCredits?.value, 42)
        XCTAssertEqual(decoded.waitingHint?.text, "Refresh available soon")
    }

    func testProviderQuotaSnapshotPreservesFailureAndPrivacy() throws {
        let snapshot = ProviderQuotaSnapshot(
            providerId: .kimiUsage,
            source: .unknown,
            freshness: .unavailable,
            failure: .credentialMissing,
            privacyLevel: .redacted
        )

        XCTAssertEqual(snapshot.failure, .credentialMissing)
        XCTAssertEqual(snapshot.privacyLevel, .redacted)
        XCTAssertNil(snapshot.primaryWindow)
        XCTAssertEqual(snapshot.extraWindows, [])
        XCTAssertEqual(snapshot.extraUsage, [])
    }

    func testUsageSnapshotCanNormalizeProviderQuotaSnapshot() {
        let providerSnapshot = ProviderQuotaSnapshot(
            providerId: .zaiQuota,
            accountId: UsageAccountID(rawValue: "zai-local"),
            source: .providerReported,
            collectedAt: "2026-07-08T12:30:00Z",
            freshness: .stale,
            primaryWindow: UsageLimitWindow(
                id: "daily",
                label: "Daily quota",
                kind: .daily,
                used: UsageAmount(value: 75, unit: "requests"),
                limit: UsageAmount(value: 100, unit: "requests"),
                remaining: UsageAmount(value: 25, unit: "requests"),
                usedPercent: 75,
                resetAt: "2026-07-09T00:00:00Z",
                sourceConfidence: .providerReported
            ),
            extraUsage: [
                UsageExtraUsageItem(
                    key: "plan",
                    value: "provider-plan",
                    isEnabled: true
                )
            ],
            bridgeHint: UsageBridgeHint(
                providerId: .zaiQuota,
                severity: .warning,
                title: "Provider quota stale",
                action: .retry,
                redactedDetail: "provider metadata only"
            ),
            failure: .staleResetTime,
            privacyLevel: .redacted
        )

        let normalized = UsageSnapshot(providerQuotaSnapshot: providerSnapshot)

        XCTAssertEqual(normalized.providerId, .zaiQuota)
        XCTAssertEqual(normalized.accountId, UsageAccountID(rawValue: "zai-local"))
        XCTAssertEqual(normalized.source, .providerReported)
        XCTAssertEqual(normalized.collectedAt, "2026-07-08T12:30:00Z")
        XCTAssertEqual(normalized.freshness, .stale)
        XCTAssertEqual(normalized.primaryWindow?.usedPercent, 75)
        XCTAssertEqual(normalized.extraUsage.first?.value, "provider-plan")
        XCTAssertEqual(normalized.bridgeHint?.title, "Provider quota stale")
        XCTAssertEqual(normalized.error, .staleResetTime)
        XCTAssertEqual(normalized.privacyLevel, .redacted)
    }

    func testUsageSnapshotCarriesNormalizedDisplayState() {
        let waitingHint = UsageWaitingHint(
            providerId: .codexRateLimits,
            reason: .refreshInProgress,
            severity: .info,
            text: "Refresh in progress",
            retryAfterSeconds: 30,
            action: .retry,
            redactedDetail: "local provider refresh"
        )
        let snapshot = UsageSnapshot(
            providerId: .codexRateLimits,
            accountId: UsageAccountID(rawValue: "codex-local"),
            source: .providerReported,
            collectedAt: "2026-07-08T11:00:00Z",
            freshness: .fresh,
            primaryWindow: UsageLimitWindow(
                id: "primary",
                label: "Primary",
                kind: .fiveHour,
                used: UsageAmount(value: 50, unit: "percent"),
                limit: UsageAmount(value: 100, unit: "percent"),
                remaining: UsageAmount(value: 50, unit: "percent"),
                usedPercent: 50,
                resetAt: nil,
                resetInSeconds: nil,
                isUnlimited: false,
                sourceConfidence: .providerReported
            ),
            secondaryWindow: nil,
            extraWindows: [],
            extraUsage: [
                UsageExtraUsageItem(
                    key: "credits",
                    value: "42 of 100 credits",
                    isEnabled: true,
                    utilization: 0.42,
                    monthlyLimit: UsageAmount(value: 100, unit: "credits"),
                    usedCredits: UsageAmount(value: 42, unit: "credits"),
                    currency: "USD"
                )
            ],
            bridgeHint: UsageBridgeHint(
                providerId: .codexRateLimits,
                severity: .info,
                title: "Codex rate limits available",
                action: .none,
                redactedDetail: "local app-server"
            ),
            waitingHint: waitingHint,
            error: nil,
            privacyLevel: .redacted
        )

        XCTAssertEqual(snapshot.providerId, .codexRateLimits)
        XCTAssertEqual(snapshot.primaryWindow?.usedPercent, 50)
        XCTAssertEqual(snapshot.extraUsage.first?.key, "credits")
        XCTAssertEqual(snapshot.extraUsage.first?.monthlyLimit?.value, 100)
        XCTAssertEqual(snapshot.extraUsage.first?.usedCredits?.value, 42)
        XCTAssertEqual(snapshot.bridgeHint?.redactedDetail, "local app-server")
        XCTAssertEqual(snapshot.waitingHint, waitingHint)
        XCTAssertEqual(snapshot.privacyLevel, .redacted)
    }

    func testUsageWaitingHintRoundTripsThroughJSON() throws {
        let hint = UsageWaitingHint(
            providerId: .kimiUsage,
            reason: .minimumIntervalActive,
            severity: .warning,
            text: "Refresh available soon",
            retryAfterSeconds: 45,
            action: .retry,
            redactedDetail: "minimum interval active"
        )

        let data = try JSONEncoder().encode(hint)
        let decoded = try JSONDecoder().decode(UsageWaitingHint.self, from: data)

        XCTAssertEqual(decoded, hint)
    }

    func testUsageWaitingHintDecodesLegacyString() throws {
        let data = try JSONEncoder().encode("Authorize provider")

        let decoded = try JSONDecoder().decode(UsageWaitingHint.self, from: data)

        XCTAssertEqual(decoded.providerId, .localParsedUsage)
        XCTAssertEqual(decoded.reason, .providerUnavailable)
        XCTAssertEqual(decoded.severity, .info)
        XCTAssertEqual(decoded.text, "Authorize provider")
        XCTAssertNil(decoded.retryAfterSeconds)
        XCTAssertEqual(decoded.action, .none)
        XCTAssertNil(decoded.redactedDetail)
    }

    func testUsageAccountIDRedactionIsStableAndDoesNotExposeRawValue() {
        let first = UsageAccountID.redacted(rawValue: "secret-token-value")
        let second = UsageAccountID.redacted(rawValue: "secret-token-value")

        XCTAssertEqual(first, second)
        XCTAssertTrue(first.rawValue.hasPrefix("redacted-"))
        XCTAssertFalse(first.rawValue.contains("secret"))
        XCTAssertFalse(first.rawValue.contains("token"))
    }

    private func providerQuotaSnapshot() -> ProviderQuotaSnapshot {
        ProviderQuotaSnapshot(
            providerId: .zaiQuota,
            accountId: UsageAccountID(rawValue: "zai-local"),
            source: .providerReported,
            collectedAt: "2026-07-08T12:30:00Z",
            freshness: .stale,
            primaryWindow: UsageLimitWindow(
                id: "daily",
                label: "Daily quota",
                kind: .daily,
                used: UsageAmount(value: 75, unit: "requests"),
                limit: UsageAmount(value: 100, unit: "requests"),
                remaining: UsageAmount(value: 25, unit: "requests"),
                usedPercent: 75,
                resetAt: "2026-07-09T00:00:00Z",
                sourceConfidence: .providerReported
            ),
            secondaryWindow: UsageLimitWindow(
                id: "parallel",
                label: "Parallel quota",
                kind: .parallelQuota,
                usedPercent: 25,
                sourceConfidence: .providerReported
            ),
            extraWindows: [
                UsageLimitWindow(
                    id: "provider-specific",
                    label: "Provider specific",
                    kind: .providerSpecific,
                    usedPercent: 10,
                    sourceConfidence: .providerReported
                )
            ],
            extraUsage: [
                UsageExtraUsageItem(key: "plan", value: "provider-plan")
            ],
            bridgeHint: UsageBridgeHint(
                providerId: .zaiQuota,
                severity: .warning,
                title: "Provider quota stale",
                action: .retry,
                redactedDetail: "provider metadata only"
            ),
            waitingHint: UsageWaitingHint(
                providerId: .zaiQuota,
                reason: .minimumIntervalActive,
                severity: .info,
                text: "Refresh available soon",
                retryAfterSeconds: 30,
                action: .retry,
                redactedDetail: "minimum interval active"
            ),
            failure: .staleResetTime,
            privacyLevel: .redacted
        )
    }
}

private struct UsageCoreModelsMatrixFixture: Codable, Equatable {
    let amountRows: [UsageAmountPercentRow]
    let snapshotRows: [UsageSnapshotProjectionRow]
    let waitingRows: [UsageWaitingHintRow]
}

private struct UsageAmountPercentRow: Codable, Equatable {
    let id: String
    let usedValue: Double
    let limitValue: Double?
    let usedPercent: Double?

    init(id: String, used: UsageAmount, limit: UsageAmount?) {
        self.id = id
        self.usedValue = used.value
        self.limitValue = limit?.value
        self.usedPercent = used.usedPercent(of: limit)
    }
}

private struct UsageSnapshotProjectionRow: Codable, Equatable {
    let id: String
    let providerId: UsageProviderIdentifier
    let accountId: UsageAccountID?
    let source: UsageSourceConfidence
    let freshness: UsageSnapshotFreshness
    let primaryWindowId: String?
    let secondaryWindowId: String?
    let extraWindowIds: [String]
    let extraUsage: [String]
    let bridgeHintTitle: String?
    let waitingHintText: String?
    let error: UsageFailureCategory?
    let privacyLevel: UsagePrivacyLevel

    init(id: String, providerSnapshot: ProviderQuotaSnapshot) {
        let snapshot = UsageSnapshot(providerQuotaSnapshot: providerSnapshot)

        self.id = id
        self.providerId = snapshot.providerId
        self.accountId = snapshot.accountId
        self.source = snapshot.source
        self.freshness = snapshot.freshness
        self.primaryWindowId = snapshot.primaryWindow?.id
        self.secondaryWindowId = snapshot.secondaryWindow?.id
        self.extraWindowIds = snapshot.extraWindows.map(\.id)
        self.extraUsage = snapshot.extraUsage.map { "\($0.key):\($0.value)" }
        self.bridgeHintTitle = snapshot.bridgeHint?.title
        self.waitingHintText = snapshot.waitingHint?.text
        self.error = snapshot.error
        self.privacyLevel = snapshot.privacyLevel
    }
}

private struct UsageWaitingHintRow: Codable, Equatable {
    let id: String
    let providerId: UsageProviderIdentifier
    let reason: UsageWaitingHintReason
    let severity: UsageBridgeHintSeverity
    let text: String
    let retryAfterSeconds: Int?
    let action: UsageBridgeHintAction
    let redactedDetail: String?

    init(id: String, data: Data) throws {
        let hint = try JSONDecoder().decode(UsageWaitingHint.self, from: data)

        self.id = id
        self.providerId = hint.providerId
        self.reason = hint.reason
        self.severity = hint.severity
        self.text = hint.text
        self.retryAfterSeconds = hint.retryAfterSeconds
        self.action = hint.action
        self.redactedDetail = hint.redactedDetail
    }
}
