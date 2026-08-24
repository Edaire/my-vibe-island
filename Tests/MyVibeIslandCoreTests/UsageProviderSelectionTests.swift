import XCTest
@testable import MyVibeIslandCore

final class UsageProviderSelectionTests: XCTestCase {
    func testUsageProviderSelectionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsageProviderSelectionMatrixFixture.self,
            from: try FixtureLoader.data("usage/provider-selection-matrix")
        )
        let coordinator = UsageCoordinator(providers: [
            SelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits, availability: .available)),
            SelectionUsageProvider(descriptor: descriptor(id: .kimiUsage, availability: .available)),
            SelectionUsageProvider(descriptor: descriptor(id: .localParsedUsage, availability: .available)),
            SelectionUsageProvider(descriptor: descriptor(id: .zaiQuota, availability: .disabled)),
        ])
        let unavailableCoordinator = UsageCoordinator(providers: [
            SelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits, availability: .disabled)),
            SelectionUsageProvider(descriptor: descriptor(id: .kimiUsage, availability: .unavailable)),
        ])

        let actual = UsageProviderSelectionMatrixFixture(rows: [
            row(
                id: "transient-wins",
                coordinator.selectedProvider(
                    preferredProviderId: .codexRateLimits,
                    focusedProviderId: .kimiUsage,
                    transientProviderId: .localParsedUsage
                )
            ),
            row(
                id: "preferred-after-missing-transient",
                coordinator.selectedProvider(
                    preferredProviderId: .codexRateLimits,
                    focusedProviderId: .kimiUsage,
                    transientProviderId: .kimiBillingUsage
                )
            ),
            row(
                id: "focused-after-unavailable-preferred",
                coordinator.selectedProvider(
                    preferredProviderId: .zaiQuota,
                    focusedProviderId: .kimiUsage
                )
            ),
            row(
                id: "fallback-skips-disabled",
                UsageCoordinator(providers: [
                    SelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits, availability: .disabled)),
                    SelectionUsageProvider(descriptor: descriptor(id: .localParsedUsage, availability: .available)),
                ]).selectedProvider()
            ),
            row(
                id: "none-when-all-unavailable",
                unavailableCoordinator.selectedProvider(preferredProviderId: .zaiQuota)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testTransientProviderWinsOverPreferredAndFocusedHints() {
        let coordinator = UsageCoordinator(providers: [
            SelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits, availability: .available)),
            SelectionUsageProvider(descriptor: descriptor(id: .kimiUsage, availability: .available)),
            SelectionUsageProvider(descriptor: descriptor(id: .localParsedUsage, availability: .available))
        ])

        let selection = coordinator.selectedProvider(
            preferredProviderId: .codexRateLimits,
            focusedProviderId: .kimiUsage,
            transientProviderId: .localParsedUsage
        )

        XCTAssertEqual(selection.descriptor?.id, .localParsedUsage)
        XCTAssertEqual(selection.reason, .transient)
        XCTAssertEqual(selection.rejectedHints, [])
    }

    func testPreferredProviderWinsOverFocusedHintWhenNoTransientProviderIsValid() {
        let coordinator = UsageCoordinator(providers: [
            SelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits, availability: .available)),
            SelectionUsageProvider(descriptor: descriptor(id: .kimiUsage, availability: .available))
        ])

        let selection = coordinator.selectedProvider(
            preferredProviderId: .codexRateLimits,
            focusedProviderId: .kimiUsage,
            transientProviderId: .zaiQuota
        )

        XCTAssertEqual(selection.descriptor?.id, .codexRateLimits)
        XCTAssertEqual(selection.reason, .preferred)
        XCTAssertEqual(
            selection.rejectedHints,
            [
                UsageProviderSelectionRejectedHint(
                    providerId: .zaiQuota,
                    source: .transient,
                    reason: .notRegistered
                )
            ]
        )
    }

    func testFocusedProviderIsUsedWhenTransientAndPreferredAreMissing() {
        let coordinator = UsageCoordinator(providers: [
            SelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits, availability: .available)),
            SelectionUsageProvider(descriptor: descriptor(id: .kimiUsage, availability: .available))
        ])

        let selection = coordinator.selectedProvider(focusedProviderId: .kimiUsage)

        XCTAssertEqual(selection.descriptor?.id, .kimiUsage)
        XCTAssertEqual(selection.reason, .focused)
    }

    func testFallbackSkipsUnavailableRegisteredProviders() {
        let coordinator = UsageCoordinator(providers: [
            SelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits, availability: .disabled)),
            SelectionUsageProvider(descriptor: descriptor(id: .kimiUsage, availability: .unavailable)),
            SelectionUsageProvider(descriptor: descriptor(id: .localParsedUsage, availability: .available))
        ])

        let selection = coordinator.selectedProvider()

        XCTAssertEqual(selection.descriptor?.id, .localParsedUsage)
        XCTAssertEqual(selection.reason, .fallback)
    }

    func testSelectionReportsNoProviderWhenAllRegisteredProvidersAreUnavailable() {
        let coordinator = UsageCoordinator(providers: [
            SelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits, availability: .disabled)),
            SelectionUsageProvider(descriptor: descriptor(id: .kimiUsage, availability: .unavailable))
        ])

        let selection = coordinator.selectedProvider(preferredProviderId: .zaiQuota)

        XCTAssertNil(selection.descriptor)
        XCTAssertEqual(selection.reason, .none)
        XCTAssertEqual(selection.rejectedHints.first?.providerId, .zaiQuota)
        XCTAssertEqual(selection.rejectedHints.first?.reason, .notRegistered)
    }

    private func row(
        id: String,
        _ selection: UsageProviderSelection
    ) -> UsageProviderSelectionMatrixRow {
        UsageProviderSelectionMatrixRow(
            id: id,
            selectedProviderId: selection.descriptor?.id,
            reason: selection.reason,
            rejectedHints: selection.rejectedHints
        )
    }

    private struct UsageProviderSelectionMatrixFixture: Codable, Equatable {
        let rows: [UsageProviderSelectionMatrixRow]
    }

    private struct UsageProviderSelectionMatrixRow: Codable, Equatable {
        let id: String
        let selectedProviderId: UsageProviderIdentifier?
        let reason: UsageProviderSelectionReason
        let rejectedHints: [UsageProviderSelectionRejectedHint]
    }
}

private final class SelectionUsageProvider: UsageProvider, @unchecked Sendable {
    let descriptor: UsageProviderDescriptor

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
            freshness: .unavailable,
            windowCount: 0
        )
    }

    func refresh(accountId: UsageAccountID?) async throws -> UsageSnapshot {
        UsageSnapshot(
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
    availability: UsageProviderAvailability
) -> UsageProviderDescriptor {
    UsageProviderDescriptor(
        id: id,
        displayName: "\(id.rawValue)",
        capabilities: [.normalizedSnapshotOnly],
        minimumRefreshIntervalSeconds: 60,
        availability: availability
    )
}
