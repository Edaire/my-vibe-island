import XCTest
@testable import MyVibeIslandCore

final class UsageCoordinatorRefreshGateTests: XCTestCase {
    func testUsageCoordinatorRefreshGateMatrixMatchesFixtureSnapshot() async throws {
        let expected = try JSONDecoder().decode(
            UsageCoordinatorRefreshGateMatrixFixture.self,
            from: try FixtureLoader.data("usage/coordinator-refresh-gate-matrix")
        )

        let actual = UsageCoordinatorRefreshGateMatrixFixture(rows: [
            try await UsageCoordinatorRefreshGateMatrixRow(
                id: "initial-refresh-success",
                providerId: .codexRateLimits,
                accountId: UsageAccountID(rawValue: "local"),
                script: [.refresh(nowSeconds: 100, minimumRefreshIntervalSeconds: 60)]
            ),
            try await UsageCoordinatorRefreshGateMatrixRow(
                id: "minimum-interval-skip",
                providerId: .codexRateLimits,
                accountId: nil,
                script: [
                    .refresh(nowSeconds: 100, minimumRefreshIntervalSeconds: 60),
                    .refresh(nowSeconds: 120, minimumRefreshIntervalSeconds: 60),
                ]
            ),
            try await UsageCoordinatorRefreshGateMatrixRow(
                id: "failure-records-backoff",
                providerId: .kimiUsage,
                accountId: nil,
                failureSteps: [0],
                script: [.refresh(nowSeconds: 100, minimumRefreshIntervalSeconds: 0)]
            ),
            try await UsageCoordinatorRefreshGateMatrixRow(
                id: "backoff-skip",
                providerId: .kimiUsage,
                accountId: nil,
                failureSteps: [0],
                script: [
                    .refresh(nowSeconds: 100, minimumRefreshIntervalSeconds: 0),
                    .refresh(nowSeconds: 120, minimumRefreshIntervalSeconds: 0),
                ]
            ),
            try await UsageCoordinatorRefreshGateMatrixRow(
                id: "missing-provider-unavailable",
                providerId: .zaiQuota,
                accountId: nil,
                providerRegistered: false,
                script: [.refresh(nowSeconds: 100, minimumRefreshIntervalSeconds: 60)]
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRefreshIfAllowedRefreshesInitiallyAndRecordsSuccess() async throws {
        let provider = GateUsageProvider(providerId: .codexRateLimits)
        let coordinator = UsageCoordinator(providers: [provider])
        let accountId = UsageAccountID(rawValue: "local")

        let result = try await coordinator.refreshIfAllowed(
            providerId: .codexRateLimits,
            accountId: accountId,
            nowSeconds: 100,
            minimumRefreshIntervalSeconds: 60
        )
        let state = await coordinator.refreshState(providerId: .codexRateLimits, accountId: accountId)

        XCTAssertEqual(result, .refreshed(provider.snapshot(accountId: accountId)))
        XCTAssertEqual(provider.refreshCount, 1)
        XCTAssertEqual(state.lastFetchAttemptSeconds, 100)
        XCTAssertEqual(state.lastSuccessfulFetchSeconds, 100)
        XCTAssertFalse(state.isRefreshing)
    }

    func testRefreshIfAllowedSkipsWhenMinimumIntervalIsActive() async throws {
        let provider = GateUsageProvider(providerId: .codexRateLimits)
        let coordinator = UsageCoordinator(providers: [provider])

        _ = try await coordinator.refreshIfAllowed(
            providerId: .codexRateLimits,
            nowSeconds: 100,
            minimumRefreshIntervalSeconds: 60
        )
        let skipped = try await coordinator.refreshIfAllowed(
            providerId: .codexRateLimits,
            nowSeconds: 120,
            minimumRefreshIntervalSeconds: 60
        )

        XCTAssertEqual(skipped, .skipped(.minimumIntervalActive(remainingSeconds: 40)))
        XCTAssertEqual(provider.refreshCount, 1)
    }

    func testRefreshIfAllowedRecordsBackoffWhenProviderFails() async {
        let provider = GateUsageProvider(providerId: .kimiUsage)
        provider.failure = GateUsageProviderError.refreshFailed
        let coordinator = UsageCoordinator(providers: [provider])

        do {
            _ = try await coordinator.refreshIfAllowed(
                providerId: .kimiUsage,
                nowSeconds: 100,
                minimumRefreshIntervalSeconds: 0,
                baseBackoffSeconds: 30,
                maximumBackoffMultiplier: 4
            )
            XCTFail("Expected provider failure")
        } catch {
            let state = await coordinator.refreshState(providerId: .kimiUsage, accountId: nil)

            XCTAssertEqual(error as? GateUsageProviderError, .refreshFailed)
            XCTAssertEqual(state.lastFetchAttemptSeconds, 100)
            XCTAssertEqual(state.backoffMultiplier, 2)
            XCTAssertEqual(state.backoffUntilSeconds, 160)
            XCTAssertFalse(state.isRefreshing)
        }
    }

    func testRefreshIfAllowedSkipsWhenBackoffIsActive() async {
        let provider = GateUsageProvider(providerId: .kimiUsage)
        provider.failure = GateUsageProviderError.refreshFailed
        let coordinator = UsageCoordinator(providers: [provider])

        _ = try? await coordinator.refreshIfAllowed(
            providerId: .kimiUsage,
            nowSeconds: 100,
            minimumRefreshIntervalSeconds: 0,
            baseBackoffSeconds: 30,
            maximumBackoffMultiplier: 4
        )
        provider.failure = nil
        let skipped = try? await coordinator.refreshIfAllowed(
            providerId: .kimiUsage,
            nowSeconds: 120,
            minimumRefreshIntervalSeconds: 0,
            baseBackoffSeconds: 30,
            maximumBackoffMultiplier: 4
        )

        XCTAssertEqual(skipped, .skipped(.backoffActive(remainingSeconds: 40)))
        XCTAssertEqual(provider.refreshCount, 1)
    }

    func testRefreshIfAllowedForMissingProviderReturnsUnavailableSnapshot() async throws {
        let coordinator = UsageCoordinator(providers: [])

        let result = try await coordinator.refreshIfAllowed(
            providerId: .zaiQuota,
            nowSeconds: 100,
            minimumRefreshIntervalSeconds: 60
        )

        guard case let .refreshed(snapshot) = result else {
            XCTFail("Expected unavailable snapshot")
            return
        }

        XCTAssertEqual(snapshot.providerId, .zaiQuota)
        XCTAssertEqual(snapshot.freshness, .unavailable)
        XCTAssertEqual(snapshot.error, .providerUnavailable)
    }
}

private struct UsageCoordinatorRefreshGateMatrixFixture: Codable, Equatable {
    let rows: [UsageCoordinatorRefreshGateMatrixRow]
}

private enum UsageCoordinatorRefreshGateStep {
    case refresh(nowSeconds: Int, minimumRefreshIntervalSeconds: Int)
}

private struct UsageCoordinatorRefreshGateMatrixRow: Codable, Equatable {
    let id: String
    let providerId: UsageProviderIdentifier
    let accountId: UsageAccountID?
    let stepResults: [String]
    let refreshCount: Int
    let finalState: UsageRefreshState
    let cachedProviderId: UsageProviderIdentifier?
    let cachedUsedPercent: Double?

    init(
        id: String,
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID?,
        providerRegistered: Bool = true,
        failureSteps: Set<Int> = [],
        script: [UsageCoordinatorRefreshGateStep]
    ) async throws {
        self.id = id
        self.providerId = providerId
        self.accountId = accountId

        let provider = GateUsageProvider(providerId: providerId)
        let coordinator = UsageCoordinator(providers: providerRegistered ? [provider] : [])
        var stepResults: [String] = []

        for (index, step) in script.enumerated() {
            provider.failure = failureSteps.contains(index) ? .refreshFailed : nil
            switch step {
            case let .refresh(nowSeconds, minimumRefreshIntervalSeconds):
                do {
                    let result = try await coordinator.refreshIfAllowed(
                        providerId: providerId,
                        accountId: accountId,
                        nowSeconds: nowSeconds,
                        minimumRefreshIntervalSeconds: minimumRefreshIntervalSeconds,
                        baseBackoffSeconds: 30,
                        maximumBackoffMultiplier: 4
                    )
                    stepResults.append(Self.describe(result))
                } catch {
                    stepResults.append("threw:\(error)")
                }
            }
        }

        self.stepResults = stepResults
        refreshCount = provider.refreshCount
        finalState = await coordinator.refreshState(providerId: providerId, accountId: accountId)

        let cached = await coordinator.cachedSnapshot(providerId: providerId, accountId: accountId)
        cachedProviderId = cached?.providerId
        cachedUsedPercent = cached?.primaryWindow?.usedPercent
    }

    private static func describe(_ result: UsageRefreshResult) -> String {
        switch result {
        case let .refreshed(snapshot):
            return "refreshed:\(snapshot.providerId.rawValue):\(snapshot.freshness.rawValue):\(snapshot.error?.rawValue ?? "none")"
        case let .skipped(decision):
            return "skipped:\(describe(decision))"
        }
    }

    private static func describe(_ decision: UsageRefreshDecision) -> String {
        switch decision {
        case .allowed:
            return "allowed"
        case .refreshInProgress:
            return "refreshInProgress"
        case let .minimumIntervalActive(remainingSeconds):
            return "minimumIntervalActive:\(remainingSeconds)"
        case let .backoffActive(remainingSeconds):
            return "backoffActive:\(remainingSeconds)"
        }
    }
}

private enum GateUsageProviderError: Error, Equatable {
    case refreshFailed
}

private final class GateUsageProvider: UsageProvider, @unchecked Sendable {
    let descriptor: UsageProviderDescriptor
    var failure: GateUsageProviderError?
    private(set) var refreshCount = 0

    init(providerId: UsageProviderIdentifier) {
        descriptor = UsageProviderDescriptor(
            id: providerId,
            displayName: "Gate Provider",
            capabilities: [.normalizedSnapshotOnly],
            minimumRefreshIntervalSeconds: 60,
            availability: .available
        )
    }

    func status(for accountId: UsageAccountID?) -> UsageProviderAvailability {
        .available
    }

    func cachedSnapshot(for accountId: UsageAccountID?) -> UsageSnapshot? {
        nil
    }

    func diagnosticSummary(for accountId: UsageAccountID?) -> UsageProviderDiagnosticSummary {
        UsageProviderDiagnosticSummary(
            providerId: descriptor.id,
            availability: .available,
            freshness: .fresh,
            windowCount: 1
        )
    }

    func refresh(accountId: UsageAccountID?) async throws -> UsageSnapshot {
        refreshCount += 1
        if let failure {
            throw failure
        }
        return snapshot(accountId: accountId)
    }

    func snapshot(accountId: UsageAccountID?) -> UsageSnapshot {
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
                usedPercent: 33,
                sourceConfidence: .providerReported
            ),
            privacyLevel: .redacted
        )
    }
}
