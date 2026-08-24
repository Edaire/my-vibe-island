import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitUsageCoordinatorControllerTests: XCTestCase {
    @MainActor
    func testUsageCoordinatorControllerMatrixMatchesFixtureSnapshot() async throws {
        let expected = try JSONDecoder().decode(
            UsageCoordinatorControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/usage-coordinator-controller-matrix")
        )

        let actualRows = try await [
            row(
                id: "plan-and-presentation",
                settings: UsageSettingsSnapshot(displayStyle: .ringBadge),
                actions: [
                    .refreshPlan(nowSeconds: 100),
                    .presentation(refreshPlanNowSeconds: 100)
                ]
            ),
            row(
                id: "allowed-refresh-then-minimum-interval-skip",
                settings: UsageSettingsSnapshot(displayStyle: .ringBadge),
                actions: [
                    .refreshIfAllowed(nowSeconds: 100, minimumRefreshIntervalSeconds: 60),
                    .refreshIfAllowed(nowSeconds: 120, minimumRefreshIntervalSeconds: 60)
                ]
            )
        ]

        XCTAssertEqual(UsageCoordinatorControllerMatrixFixture(rows: actualRows), expected)
    }

    @MainActor
    func testControllerBuildsRefreshPlanAndPublishesPresentationSnapshot() async {
        var events: [String] = []
        let coordinator = UsageCoordinator(providers: [
            FakeAppKitUsageProvider(providerId: .codexRateLimits)
        ])
        let controller = MyVibeIslandAppKitUsageCoordinatorController(
            coordinator: coordinator,
            settings: UsageSettingsSnapshot(displayStyle: .ringBadge),
            publishRefreshPlan: { plan in
                events.append("plan:\(plan.entries.map(\.providerId.rawValue).joined(separator: ","))")
            },
            publishPresentation: { snapshot in
                events.append("presentation:\(snapshot.displayState.displayStyle.rawValue):\(snapshot.selection.descriptor?.id.rawValue ?? "none")")
            }
        )

        let plan = await controller.refreshPlan(nowSeconds: 100)
        let presentation = await controller.presentationSnapshot(refreshPlanNowSeconds: 100)

        XCTAssertEqual(plan.entries.map(\.providerId), [UsageProviderIdentifier.codexRateLimits])
        XCTAssertEqual(presentation.selection.descriptor?.id, .codexRateLimits)
        XCTAssertEqual(controller.lastRefreshPlan, plan)
        XCTAssertEqual(controller.lastPresentationSnapshot, presentation)
        XCTAssertEqual(events, [
            "plan:codexRateLimits",
            "presentation:ringBadge:codexRateLimits"
        ])
    }

    @MainActor
    func testControllerRefreshesAllowedProviderAndPublishesResult() async throws {
        var events: [String] = []
        let provider = FakeAppKitUsageProvider(providerId: .codexRateLimits)
        let coordinator = UsageCoordinator(providers: [provider])
        let controller = MyVibeIslandAppKitUsageCoordinatorController(
            coordinator: coordinator,
            settings: UsageSettingsSnapshot(displayStyle: .ringBadge),
            publishRefreshResult: { result in
                switch result {
                case let .refreshed(snapshot):
                    events.append("refreshed:\(snapshot.providerId.rawValue)")
                case let .skipped(decision):
                    events.append("skipped:\(decision)")
                }
            }
        )

        let result = try await controller.refreshIfAllowed(
            providerId: .codexRateLimits,
            nowSeconds: 100,
            minimumRefreshIntervalSeconds: 60
        )

        XCTAssertEqual(provider.refreshCount, 1)
        XCTAssertEqual(controller.lastRefreshResult, result)
        XCTAssertEqual(events, ["refreshed:codexRateLimits"])
    }

    @MainActor
    func testControllerPublishesSkippedRefreshWhenGateBlocksRefresh() async throws {
        var events: [String] = []
        let provider = FakeAppKitUsageProvider(providerId: .codexRateLimits)
        let coordinator = UsageCoordinator(providers: [provider])
        let controller = MyVibeIslandAppKitUsageCoordinatorController(
            coordinator: coordinator,
            settings: UsageSettingsSnapshot(displayStyle: .ringBadge),
            publishRefreshResult: { result in
                if case let .skipped(decision) = result {
                    events.append("skipped:\(decision)")
                }
            }
        )

        _ = try await controller.refreshIfAllowed(
            providerId: .codexRateLimits,
            nowSeconds: 100,
            minimumRefreshIntervalSeconds: 60
        )
        let skipped = try await controller.refreshIfAllowed(
            providerId: .codexRateLimits,
            nowSeconds: 120,
            minimumRefreshIntervalSeconds: 60
        )

        XCTAssertEqual(provider.refreshCount, 1)
        XCTAssertEqual(controller.lastRefreshResult, skipped)
        XCTAssertEqual(events, ["skipped:minimumIntervalActive(remainingSeconds: 40)"])
    }

    @MainActor
    private func row(
        id: String,
        settings: UsageSettingsSnapshot,
        actions: [UsageCoordinatorControllerFixtureAction]
    ) async throws -> UsageCoordinatorControllerMatrixRow {
        var events: [String] = []
        let provider = FakeAppKitUsageProvider(providerId: .codexRateLimits)
        let coordinator = UsageCoordinator(providers: [provider])
        let controller = MyVibeIslandAppKitUsageCoordinatorController(
            coordinator: coordinator,
            settings: settings,
            publishRefreshPlan: { plan in
                events.append("plan:\(plan.entries.map(\.providerId.rawValue).joined(separator: ","))")
            },
            publishRefreshResult: { result in
                events.append("result:\(UsageRefreshResultSummary(result).summary)")
            },
            publishPresentation: { snapshot in
                events.append(
                    "presentation:\(snapshot.displayState.displayStyle.rawValue):"
                    + "\(snapshot.selection.descriptor?.id.rawValue ?? "none")"
                )
            }
        )
        var actionResults: [String] = []

        for action in actions {
            switch action {
            case let .refreshPlan(nowSeconds):
                let plan = await controller.refreshPlan(nowSeconds: nowSeconds)
                actionResults.append("plan:\(plan.entries.map(\.providerId.rawValue).joined(separator: ","))")
            case let .presentation(refreshPlanNowSeconds):
                let snapshot = await controller.presentationSnapshot(
                    refreshPlanNowSeconds: refreshPlanNowSeconds
                )
                actionResults.append(
                    "presentation:\(snapshot.displayState.status.rawValue):"
                    + "\(snapshot.selection.descriptor?.id.rawValue ?? "none")"
                )
            case let .refreshIfAllowed(nowSeconds, minimumRefreshIntervalSeconds):
                let result = try await controller.refreshIfAllowed(
                    providerId: .codexRateLimits,
                    nowSeconds: nowSeconds,
                    minimumRefreshIntervalSeconds: minimumRefreshIntervalSeconds
                )
                actionResults.append("refresh:\(UsageRefreshResultSummary(result).summary)")
            }
        }

        return UsageCoordinatorControllerMatrixRow(
            id: id,
            settings: UsageSettingsSummary(settings),
            actions: actions.map(\.summary),
            actionResults: actionResults,
            lastRefreshPlanProviders: controller.lastRefreshPlan?.entries.map(\.providerId.rawValue) ?? [],
            lastRefreshResult: controller.lastRefreshResult.map(UsageRefreshResultSummary.init),
            lastPresentation: controller.lastPresentationSnapshot.map(UsagePresentationSnapshotSummary.init),
            providerRefreshCount: provider.refreshCount,
            events: events
        )
    }
}

private struct UsageCoordinatorControllerMatrixFixture: Codable, Equatable {
    let rows: [UsageCoordinatorControllerMatrixRow]
}

private struct UsageCoordinatorControllerMatrixRow: Codable, Equatable {
    let id: String
    let settings: UsageSettingsSummary
    let actions: [String]
    let actionResults: [String]
    let lastRefreshPlanProviders: [String]
    let lastRefreshResult: UsageRefreshResultSummary?
    let lastPresentation: UsagePresentationSnapshotSummary?
    let providerRefreshCount: Int
    let events: [String]
}

private struct UsageSettingsSummary: Codable, Equatable {
    let preferredProviderId: String?
    let displayStyle: String
    let valueMode: String

    init(_ settings: UsageSettingsSnapshot) {
        self.preferredProviderId = settings.preferredProviderId?.rawValue
        self.displayStyle = settings.displayStyle.rawValue
        self.valueMode = settings.valueMode.rawValue
    }
}

private struct UsageRefreshResultSummary: Codable, Equatable {
    let kind: String
    let providerId: String?
    let decision: String?

    var summary: String {
        switch kind {
        case "refreshed":
            return "refreshed:\(providerId ?? "none")"
        case "skipped":
            return "skipped:\(decision ?? "none")"
        default:
            return kind
        }
    }

    init(_ result: UsageRefreshResult) {
        switch result {
        case let .refreshed(snapshot):
            self.kind = "refreshed"
            self.providerId = snapshot.providerId.rawValue
            self.decision = nil
        case let .skipped(decision):
            self.kind = "skipped"
            self.providerId = nil
            self.decision = "\(decision)"
        }
    }
}

private struct UsagePresentationSnapshotSummary: Codable, Equatable {
    let selectedProviderId: String?
    let selectionReason: String
    let displayStatus: String
    let displayStyle: String
    let title: String
    let selectedRefreshProviderId: String?

    init(_ snapshot: UsagePresentationSnapshot) {
        self.selectedProviderId = snapshot.selection.descriptor?.id.rawValue
        self.selectionReason = snapshot.selection.reason.rawValue
        self.displayStatus = snapshot.displayState.status.rawValue
        self.displayStyle = snapshot.displayState.displayStyle.rawValue
        self.title = snapshot.displayState.title
        self.selectedRefreshProviderId = snapshot.selectedRefreshPlanEntry?.providerId.rawValue
    }
}

private enum UsageCoordinatorControllerFixtureAction {
    case refreshPlan(nowSeconds: Int)
    case presentation(refreshPlanNowSeconds: Int)
    case refreshIfAllowed(nowSeconds: Int, minimumRefreshIntervalSeconds: Int)

    var summary: String {
        switch self {
        case let .refreshPlan(nowSeconds):
            return "refreshPlan:\(nowSeconds)"
        case let .presentation(refreshPlanNowSeconds):
            return "presentation:\(refreshPlanNowSeconds)"
        case let .refreshIfAllowed(nowSeconds, minimumRefreshIntervalSeconds):
            return "refreshIfAllowed:\(nowSeconds):\(minimumRefreshIntervalSeconds)"
        }
    }
}

private final class FakeAppKitUsageProvider: UsageProvider, @unchecked Sendable {
    let descriptor: UsageProviderDescriptor
    private(set) var refreshCount = 0

    init(providerId: UsageProviderIdentifier) {
        descriptor = UsageProviderDescriptor(
            id: providerId,
            displayName: "Codex",
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
        return UsageSnapshot(
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
