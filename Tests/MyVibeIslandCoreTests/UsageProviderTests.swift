import XCTest
@testable import MyVibeIslandCore

final class UsageProviderTests: XCTestCase {
    func testNormalizedSnapshotUsageProviderMatrixMatchesFixtureSnapshot() async throws {
        let expected = try JSONDecoder().decode(
            NormalizedSnapshotUsageProviderMatrixFixture.self,
            from: try FixtureLoader.data("usage/normalized-snapshot-provider-matrix")
        )
        let snapshot = normalizedSnapshot(accountId: UsageAccountID(rawValue: "kimi-local"))
        let provider = NormalizedSnapshotUsageProvider(
            descriptor: UsageProviderDescriptor(
                id: .kimiUsage,
                displayName: "Kimi Usage",
                capabilities: [.normalizedSnapshotOnly],
                minimumRefreshIntervalSeconds: 300,
                availability: .available
            ),
            snapshot: snapshot
        )
        let matchingAccount = UsageAccountID(rawValue: "kimi-local")
        let mismatchedAccount = UsageAccountID(rawValue: "other")

        let matchingRefresh = try await provider.refresh(accountId: matchingAccount)
        let mismatchedRefreshFailed: Bool
        do {
            _ = try await provider.refresh(accountId: mismatchedAccount)
            mismatchedRefreshFailed = false
        } catch UsageProviderSnapshotError.accountMismatch {
            mismatchedRefreshFailed = true
        }

        let actual = NormalizedSnapshotUsageProviderMatrixFixture(rows: [
            NormalizedSnapshotUsageProviderMatrixRow(
                id: "matching-account",
                status: provider.status(for: matchingAccount).rawValue,
                cachedProviderId: provider.cachedSnapshot(for: matchingAccount)?.providerId.rawValue,
                refreshedProviderId: matchingRefresh.providerId.rawValue,
                diagnosticSummary: provider.diagnosticSummary(for: matchingAccount),
                refreshFailedWithAccountMismatch: false
            ),
            NormalizedSnapshotUsageProviderMatrixRow(
                id: "mismatched-account",
                status: provider.status(for: mismatchedAccount).rawValue,
                cachedProviderId: provider.cachedSnapshot(for: mismatchedAccount)?.providerId.rawValue,
                refreshedProviderId: nil,
                diagnosticSummary: provider.diagnosticSummary(for: mismatchedAccount),
                refreshFailedWithAccountMismatch: mismatchedRefreshFailed
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testDefaultUsageProviderCatalogMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsageProviderCatalogFixture.self,
            from: try FixtureLoader.data("usage/provider-catalog")
        )

        let actual = UsageProviderCatalogFixture(
            descriptors: UsageProviderCatalog.defaultDescriptors,
            descriptorIds: UsageProviderCatalog.defaultDescriptors.map(\.id.rawValue),
            billingProviderExcluded: !UsageProviderCatalog.defaultDescriptors.map(\.id).contains(.kimiBillingUsage),
            codexCapabilities: UsageProviderCatalog.descriptor(for: .codexRateLimits)?.capabilities.map(\.rawValue) ?? []
        )

        XCTAssertEqual(actual, expected)
    }

    func testDefaultCatalogContainsNonCommercialProvidersInStableOrder() {
        XCTAssertEqual(
            UsageProviderCatalog.defaultDescriptors.map(\.id),
            [.codexRateLimits, .kimiUsage, .zaiQuota, .claudeStatusLine, .localParsedUsage]
        )
        XCTAssertFalse(UsageProviderCatalog.defaultDescriptors.map(\.id).contains(.kimiBillingUsage))
    }

    func testCatalogFindsDescriptorByProviderID() {
        let descriptor = UsageProviderCatalog.descriptor(for: .codexRateLimits)

        XCTAssertEqual(descriptor?.id, .codexRateLimits)
        XCTAssertEqual(descriptor?.displayName, "Codex Rate Limits")
        XCTAssertEqual(descriptor?.capabilities, [.localAppServer, .localCache, .normalizedSnapshotOnly])
    }

    func testDefaultDescriptorRoundTripsThroughJSON() throws {
        let descriptor = try XCTUnwrap(UsageProviderCatalog.descriptor(for: .localParsedUsage))

        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(UsageProviderDescriptor.self, from: data)

        XCTAssertEqual(decoded, descriptor)
    }

    func testDiagnosticSummaryRoundTripsThroughJSON() throws {
        let summary = UsageProviderDiagnosticSummary(
            providerId: .codexRateLimits,
            availability: .available,
            freshness: .fresh,
            windowCount: 2,
            failure: nil,
            redactedDetail: "local cache"
        )

        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(UsageProviderDiagnosticSummary.self, from: data)

        XCTAssertEqual(decoded, summary)
    }

    func testNormalizedSnapshotProviderReturnsCachedSnapshotWithoutFetching() async throws {
        let snapshot = normalizedSnapshot(accountId: UsageAccountID(rawValue: "kimi-local"))
        let provider = NormalizedSnapshotUsageProvider(
            descriptor: UsageProviderDescriptor(
                id: .kimiUsage,
                displayName: "Kimi Usage",
                capabilities: [.normalizedSnapshotOnly],
                minimumRefreshIntervalSeconds: 300,
                availability: .available
            ),
            snapshot: snapshot
        )

        XCTAssertEqual(provider.status(for: snapshot.accountId), .available)
        XCTAssertEqual(provider.cachedSnapshot(for: snapshot.accountId), snapshot)
        XCTAssertNil(provider.cachedSnapshot(for: UsageAccountID(rawValue: "other")))

        let refreshed = try await provider.refresh(accountId: snapshot.accountId)

        XCTAssertEqual(refreshed, snapshot)
        XCTAssertEqual(
            provider.diagnosticSummary(for: snapshot.accountId),
            UsageProviderDiagnosticSummary(
                providerId: .kimiUsage,
                availability: .available,
                freshness: .fresh,
                windowCount: 1,
                failure: nil,
                redactedDetail: "normalized snapshot"
            )
        )
    }

    private func normalizedSnapshot(accountId: UsageAccountID?) -> UsageSnapshot {
        UsageSnapshot(
            providerId: .kimiUsage,
            accountId: accountId,
            source: .providerReported,
            collectedAt: "2026-07-08T12:30:00Z",
            freshness: .fresh,
            primaryWindow: UsageLimitWindow(
                id: "total-quota",
                label: "Kimi total quota",
                kind: .totalQuota,
                used: UsageAmount(value: 25, unit: "tokens"),
                limit: UsageAmount(value: 100, unit: "tokens"),
                remaining: UsageAmount(value: 75, unit: "tokens"),
                usedPercent: 25,
                sourceConfidence: .providerReported
            ),
            extraUsage: [
                UsageExtraUsageItem(key: "subType", value: "coding")
            ],
            privacyLevel: .redacted
        )
    }

    private struct UsageProviderCatalogFixture: Codable, Equatable {
        let descriptors: [UsageProviderDescriptor]
        let descriptorIds: [String]
        let billingProviderExcluded: Bool
        let codexCapabilities: [String]
    }

    private struct NormalizedSnapshotUsageProviderMatrixFixture: Codable, Equatable {
        let rows: [NormalizedSnapshotUsageProviderMatrixRow]
    }

    private struct NormalizedSnapshotUsageProviderMatrixRow: Codable, Equatable {
        let id: String
        let status: String
        let cachedProviderId: String?
        let refreshedProviderId: String?
        let diagnosticSummary: UsageProviderDiagnosticSummary
        let refreshFailedWithAccountMismatch: Bool
    }
}
