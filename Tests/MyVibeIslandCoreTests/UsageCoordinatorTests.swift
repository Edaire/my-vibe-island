import XCTest
@testable import MyVibeIslandCore

final class UsageCoordinatorTests: XCTestCase {
    func testUsageCoordinatorMatrixMatchesFixtureSnapshot() async throws {
        let expected = try JSONDecoder().decode(
            UsageCoordinatorMatrixFixture.self,
            from: try FixtureLoader.data("usage/coordinator-matrix")
        )
        let accountId = UsageAccountID(rawValue: "local-account")

        let actual = UsageCoordinatorMatrixFixture(rows: [
            await UsageCoordinatorMatrixRow(
                id: "registered-descriptor",
                coordinator: UsageCoordinator(providers: [
                    FakeUsageProvider(providerId: .codexRateLimits),
                ]),
                action: .descriptor(providerId: .codexRateLimits)
            ),
            try await UsageCoordinatorMatrixRow(
                id: "refresh-caches-snapshot",
                coordinator: UsageCoordinator(providers: [
                    FakeUsageProvider(providerId: .codexRateLimits),
                ]),
                action: .refreshAndCache(providerId: .codexRateLimits, accountId: accountId)
            ),
            try await UsageCoordinatorMatrixRow(
                id: "missing-provider-refresh",
                coordinator: UsageCoordinator(providers: []),
                action: .refreshAndCache(providerId: .kimiUsage, accountId: nil)
            ),
            await UsageCoordinatorMatrixRow(
                id: "provider-diagnostic",
                coordinator: UsageCoordinator(providers: [
                    FakeUsageProvider(providerId: .localParsedUsage),
                ]),
                action: .diagnostic(providerId: .localParsedUsage)
            ),
            await UsageCoordinatorMatrixRow(
                id: "missing-provider-diagnostic",
                coordinator: UsageCoordinator(providers: []),
                action: .diagnostic(providerId: .zaiQuota)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCoordinatorExposesRegisteredProviderDescriptors() async {
        let provider = FakeUsageProvider(providerId: .codexRateLimits)
        let coordinator = UsageCoordinator(providers: [provider])

        let descriptors = await coordinator.descriptors
        let codexDescriptor = await coordinator.descriptor(for: .codexRateLimits)
        let kimiDescriptor = await coordinator.descriptor(for: .kimiUsage)

        XCTAssertEqual(descriptors.map(\.id), [.codexRateLimits])
        XCTAssertEqual(codexDescriptor?.id, .codexRateLimits)
        XCTAssertNil(kimiDescriptor)
    }

    func testRefreshCachesNormalizedSnapshot() async throws {
        let accountId = UsageAccountID(rawValue: "local-account")
        let provider = FakeUsageProvider(providerId: .codexRateLimits)
        let coordinator = UsageCoordinator(providers: [provider])

        let refreshed = try await coordinator.refresh(providerId: .codexRateLimits, accountId: accountId)
        let cached = await coordinator.cachedSnapshot(providerId: .codexRateLimits, accountId: accountId)

        XCTAssertEqual(cached, refreshed)
        XCTAssertEqual(refreshed.providerId, .codexRateLimits)
        XCTAssertEqual(refreshed.primaryWindow?.usedPercent, 25)
    }

    func testMissingProviderReturnsUnavailableSnapshot() async throws {
        let coordinator = UsageCoordinator(providers: [])

        let snapshot = try await coordinator.refresh(providerId: .kimiUsage, accountId: nil)

        XCTAssertEqual(snapshot.providerId, .kimiUsage)
        XCTAssertEqual(snapshot.freshness, .unavailable)
        XCTAssertEqual(snapshot.error, .providerUnavailable)
        XCTAssertEqual(snapshot.privacyLevel, .redacted)
    }

    func testDiagnosticSummaryRoutesToProviderAndRedactsMissingProvider() async {
        let provider = FakeUsageProvider(providerId: .localParsedUsage)
        let coordinator = UsageCoordinator(providers: [provider])

        let providerSummary = await coordinator.diagnosticSummary(providerId: .localParsedUsage, accountId: nil)
        let missingSummary = await coordinator.diagnosticSummary(providerId: .zaiQuota, accountId: nil)

        XCTAssertEqual(providerSummary.providerId, .localParsedUsage)
        XCTAssertEqual(providerSummary.availability, .available)
        XCTAssertEqual(providerSummary.redactedDetail, "fake provider")
        XCTAssertEqual(missingSummary.providerId, .zaiQuota)
        XCTAssertEqual(missingSummary.availability, .unavailable)
        XCTAssertEqual(missingSummary.failure, .providerUnavailable)
        XCTAssertNil(missingSummary.redactedDetail)
    }
}

private struct UsageCoordinatorMatrixFixture: Codable, Equatable {
    let rows: [UsageCoordinatorMatrixRow]
}

private enum UsageCoordinatorMatrixAction {
    case descriptor(providerId: UsageProviderIdentifier)
    case refreshAndCache(providerId: UsageProviderIdentifier, accountId: UsageAccountID?)
    case diagnostic(providerId: UsageProviderIdentifier)
}

private struct UsageCoordinatorMatrixRow: Codable, Equatable {
    let id: String
    let descriptorIds: [UsageProviderIdentifier]
    let descriptorId: UsageProviderIdentifier?
    let refreshedProviderId: UsageProviderIdentifier?
    let refreshedFreshness: UsageSnapshotFreshness?
    let refreshedError: UsageFailureCategory?
    let cachedProviderId: UsageProviderIdentifier?
    let cachedUsedPercent: Double?
    let diagnosticProviderId: UsageProviderIdentifier?
    let diagnosticAvailability: UsageProviderAvailability?
    let diagnosticFailure: UsageFailureCategory?
    let diagnosticRedactedDetail: String?

    init(
        id: String,
        coordinator: UsageCoordinator,
        action: UsageCoordinatorMatrixAction
    ) async {
        self.id = id
        descriptorIds = await coordinator.descriptors.map(\.id)

        switch action {
        case let .descriptor(providerId):
            descriptorId = await coordinator.descriptor(for: providerId)?.id
            refreshedProviderId = nil
            refreshedFreshness = nil
            refreshedError = nil
            cachedProviderId = nil
            cachedUsedPercent = nil
            diagnosticProviderId = nil
            diagnosticAvailability = nil
            diagnosticFailure = nil
            diagnosticRedactedDetail = nil
        case let .refreshAndCache(providerId, accountId):
            let refreshed = (try? await coordinator.refresh(providerId: providerId, accountId: accountId))
            let cached = await coordinator.cachedSnapshot(providerId: providerId, accountId: accountId)

            descriptorId = nil
            refreshedProviderId = refreshed?.providerId
            refreshedFreshness = refreshed?.freshness
            refreshedError = refreshed?.error
            cachedProviderId = cached?.providerId
            cachedUsedPercent = cached?.primaryWindow?.usedPercent
            diagnosticProviderId = nil
            diagnosticAvailability = nil
            diagnosticFailure = nil
            diagnosticRedactedDetail = nil
        case let .diagnostic(providerId):
            let summary = await coordinator.diagnosticSummary(providerId: providerId, accountId: nil)

            descriptorId = nil
            refreshedProviderId = nil
            refreshedFreshness = nil
            refreshedError = nil
            cachedProviderId = nil
            cachedUsedPercent = nil
            diagnosticProviderId = summary.providerId
            diagnosticAvailability = summary.availability
            diagnosticFailure = summary.failure
            diagnosticRedactedDetail = summary.redactedDetail
        }
    }
}

private final class FakeUsageProvider: UsageProvider, @unchecked Sendable {
    let descriptor: UsageProviderDescriptor

    init(providerId: UsageProviderIdentifier) {
        descriptor = UsageProviderDescriptor(
            id: providerId,
            displayName: "Fake Provider",
            capabilities: [.normalizedSnapshotOnly],
            minimumRefreshIntervalSeconds: 1,
            availability: .available
        )
    }

    func status(for accountId: UsageAccountID?) -> UsageProviderAvailability {
        .available
    }

    func cachedSnapshot(for accountId: UsageAccountID?) -> UsageSnapshot? {
        snapshot(accountId: accountId)
    }

    func diagnosticSummary(for accountId: UsageAccountID?) -> UsageProviderDiagnosticSummary {
        UsageProviderDiagnosticSummary(
            providerId: descriptor.id,
            availability: .available,
            freshness: .fresh,
            windowCount: 1,
            redactedDetail: "fake provider"
        )
    }

    func refresh(accountId: UsageAccountID?) async throws -> UsageSnapshot {
        snapshot(accountId: accountId)
    }

    private func snapshot(accountId: UsageAccountID?) -> UsageSnapshot {
        UsageSnapshot(
            providerId: descriptor.id,
            accountId: accountId,
            source: .providerReported,
            collectedAt: "2026-07-08T12:00:00Z",
            freshness: .fresh,
            primaryWindow: UsageLimitWindow(
                id: "primary",
                label: "Primary",
                kind: .fiveHour,
                used: UsageAmount(value: 25, unit: "percent"),
                limit: UsageAmount(value: 100, unit: "percent"),
                remaining: UsageAmount(value: 75, unit: "percent"),
                usedPercent: 25,
                sourceConfidence: .providerReported
            ),
            privacyLevel: .redacted
        )
    }
}
