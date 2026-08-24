import XCTest
@testable import MyVibeIslandCore

final class UsageCoordinatorRefreshPlanTests: XCTestCase {
    func testUsageRefreshPlanMatrixMatchesFixtureSnapshot() async throws {
        let expected = try JSONDecoder().decode(
            UsageRefreshPlanMatrixFixture.self,
            from: try FixtureLoader.data("usage/refresh-plan-matrix")
        )
        let codex = PlanUsageProvider(
            descriptor: descriptor(id: .codexRateLimits, displayName: "Codex", minimumRefreshIntervalSeconds: 60)
        )
        let kimi = PlanUsageProvider(
            descriptor: descriptor(id: .kimiUsage, displayName: "Kimi", minimumRefreshIntervalSeconds: 0)
        )
        let zai = PlanUsageProvider(
            descriptor: descriptor(
                id: .zaiQuota,
                displayName: "Z.ai",
                minimumRefreshIntervalSeconds: 300,
                availability: .needsConfiguration
            )
        )
        let coordinator = UsageCoordinator(providers: [codex, kimi, zai])
        let codexA = UsageAccountRecord(
            accountId: UsageAccountID(rawValue: "codex-a"),
            providerId: .codexRateLimits,
            category: .providerAccount,
            origin: .manual,
            displayLabel: "Codex A"
        )
        let codexB = UsageAccountRecord(
            accountId: UsageAccountID(rawValue: "codex-b"),
            providerId: .codexRateLimits,
            category: .providerAccount,
            origin: .manual,
            displayLabel: "Codex B"
        )

        _ = try await coordinator.refreshIfAllowed(
            providerId: .codexRateLimits,
            accountId: codexA.accountId,
            nowSeconds: 100,
            minimumRefreshIntervalSeconds: 60
        )
        let plan = await coordinator.refreshPlan(accountRecords: [codexA, codexB], nowSeconds: 120)

        let actual = UsageRefreshPlanMatrixFixture(
            entries: plan.entries.map {
                UsageRefreshPlanMatrixEntry(
                    providerId: $0.providerId,
                    accountId: $0.accountId,
                    accountDisplayLabel: $0.accountDisplayLabel,
                    providerAvailability: $0.providerAvailability,
                    minimumRefreshIntervalSeconds: $0.minimumRefreshIntervalSeconds,
                    decision: $0.decision,
                    isRefreshAllowed: $0.isRefreshAllowed
                )
            },
            refreshableProviderIds: plan.refreshableEntries.map(\.providerId)
        )

        XCTAssertEqual(actual, expected)
    }

    func testRefreshPlanPreservesProviderOrderAndExpandsAccounts() async {
        let codex = PlanUsageProvider(
            descriptor: descriptor(id: .codexRateLimits, displayName: "Codex", minimumRefreshIntervalSeconds: 60)
        )
        let kimi = PlanUsageProvider(
            descriptor: descriptor(id: .kimiUsage, displayName: "Kimi", minimumRefreshIntervalSeconds: 300)
        )
        let coordinator = UsageCoordinator(providers: [codex, kimi])
        let accountA = UsageAccountRecord(
            accountId: UsageAccountID(rawValue: "codex-a"),
            providerId: .codexRateLimits,
            category: .providerAccount,
            origin: .manual,
            displayLabel: "Codex A"
        )
        let accountB = UsageAccountRecord(
            accountId: UsageAccountID(rawValue: "codex-b"),
            providerId: .codexRateLimits,
            category: .providerAccount,
            origin: .manual,
            displayLabel: "Codex B"
        )

        let plan = await coordinator.refreshPlan(accountRecords: [accountA, accountB], nowSeconds: 100)

        XCTAssertEqual(plan.entries.map(\.providerId), [.codexRateLimits, .codexRateLimits, .kimiUsage])
        XCTAssertEqual(plan.entries.map(\.accountId), [accountA.accountId, accountB.accountId, nil])
        XCTAssertEqual(plan.entries.map(\.accountDisplayLabel), ["Codex A", "Codex B", nil])
        XCTAssertEqual(plan.entries.map(\.minimumRefreshIntervalSeconds), [60, 60, 300])
    }

    func testRefreshPlanUsesStateDecisionFromGatedRefresh() async throws {
        let provider = PlanUsageProvider(
            descriptor: descriptor(id: .codexRateLimits, displayName: "Codex", minimumRefreshIntervalSeconds: 60)
        )
        let coordinator = UsageCoordinator(providers: [provider])
        let accountId = UsageAccountID(rawValue: "local")
        let account = UsageAccountRecord(
            accountId: accountId,
            providerId: .codexRateLimits,
            category: .providerAccount,
            origin: .manual,
            displayLabel: "Local"
        )

        _ = try await coordinator.refreshIfAllowed(
            providerId: .codexRateLimits,
            accountId: accountId,
            nowSeconds: 100,
            minimumRefreshIntervalSeconds: 60
        )
        let plan = await coordinator.refreshPlan(accountRecords: [account], nowSeconds: 120)

        XCTAssertEqual(plan.entries.count, 1)
        XCTAssertEqual(plan.entries.first?.decision, .minimumIntervalActive(remainingSeconds: 40))
        XCTAssertEqual(plan.refreshableEntries, [])
        XCTAssertEqual(provider.refreshCount, 1)
    }

    func testRefreshPlanFiltersAllowedEntries() async {
        let codex = PlanUsageProvider(
            descriptor: descriptor(id: .codexRateLimits, displayName: "Codex", minimumRefreshIntervalSeconds: 60)
        )
        let kimi = PlanUsageProvider(
            descriptor: descriptor(id: .kimiUsage, displayName: "Kimi", minimumRefreshIntervalSeconds: 0)
        )
        let coordinator = UsageCoordinator(providers: [codex, kimi])

        _ = try? await coordinator.refreshIfAllowed(
            providerId: .codexRateLimits,
            nowSeconds: 100,
            minimumRefreshIntervalSeconds: 60
        )
        let plan = await coordinator.refreshPlan(nowSeconds: 120)

        XCTAssertEqual(plan.entries.map(\.decision), [.minimumIntervalActive(remainingSeconds: 40), .allowed])
        XCTAssertEqual(plan.refreshableEntries.map(\.providerId), [.kimiUsage])
    }

    private struct UsageRefreshPlanMatrixFixture: Codable, Equatable {
        let entries: [UsageRefreshPlanMatrixEntry]
        let refreshableProviderIds: [UsageProviderIdentifier]
    }

    private struct UsageRefreshPlanMatrixEntry: Codable, Equatable {
        let providerId: UsageProviderIdentifier
        let accountId: UsageAccountID?
        let accountDisplayLabel: String?
        let providerAvailability: UsageProviderAvailability
        let minimumRefreshIntervalSeconds: Int
        let decision: UsageRefreshDecision
        let isRefreshAllowed: Bool
    }
}

private final class PlanUsageProvider: UsageProvider, @unchecked Sendable {
    let descriptor: UsageProviderDescriptor
    private(set) var refreshCount = 0

    init(descriptor: UsageProviderDescriptor) {
        self.descriptor = descriptor
    }

    func status(for accountId: UsageAccountID?) -> UsageProviderAvailability {
        descriptor.availability
    }

    func cachedSnapshot(for accountId: UsageAccountID?) -> UsageSnapshot? {
        nil
    }

    func diagnosticSummary(for accountId: UsageAccountID?) -> UsageProviderDiagnosticSummary {
        UsageProviderDiagnosticSummary(
            providerId: descriptor.id,
            availability: descriptor.availability,
            freshness: .fresh,
            windowCount: 1
        )
    }

    func refresh(accountId: UsageAccountID?) async throws -> UsageSnapshot {
        refreshCount += 1
        return UsageSnapshot(
            providerId: descriptor.id,
            accountId: accountId,
            source: .providerReported,
            freshness: .fresh,
            privacyLevel: .redacted
        )
    }
}

private func descriptor(
    id: UsageProviderIdentifier,
    displayName: String,
    minimumRefreshIntervalSeconds: Int,
    availability: UsageProviderAvailability = .available
) -> UsageProviderDescriptor {
    UsageProviderDescriptor(
        id: id,
        displayName: displayName,
        capabilities: [.normalizedSnapshotOnly],
        minimumRefreshIntervalSeconds: minimumRefreshIntervalSeconds,
        availability: availability
    )
}
