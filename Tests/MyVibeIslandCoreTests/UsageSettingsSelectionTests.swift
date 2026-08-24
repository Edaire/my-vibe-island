import XCTest
@testable import MyVibeIslandCore

final class UsageSettingsSelectionTests: XCTestCase {
    func testUsageSettingsSelectionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsageSettingsSelectionMatrixFixture.self,
            from: try FixtureLoader.data("usage/settings-selection-matrix")
        )

        let actual = UsageSettingsSelectionMatrixFixture(rows: [
            UsageSettingsSelectionMatrixRow(
                id: "preferred",
                selection: UsageCoordinator(providers: [
                    SettingsSelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits)),
                    SettingsSelectionUsageProvider(descriptor: descriptor(id: .kimiUsage)),
                ])
                .selectedProvider(settings: UsageSettingsSnapshot(preferredProviderId: .kimiUsage))
            ),
            UsageSettingsSelectionMatrixRow(
                id: "transient-over-preferred",
                selection: UsageCoordinator(providers: [
                    SettingsSelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits)),
                    SettingsSelectionUsageProvider(descriptor: descriptor(id: .kimiUsage)),
                    SettingsSelectionUsageProvider(descriptor: descriptor(id: .localParsedUsage)),
                ])
                .selectedProvider(
                    settings: UsageSettingsSnapshot(preferredProviderId: .kimiUsage),
                    transientProviderId: .localParsedUsage
                )
            ),
            UsageSettingsSelectionMatrixRow(
                id: "focused-without-preferred",
                selection: UsageCoordinator(providers: [
                    SettingsSelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits)),
                    SettingsSelectionUsageProvider(descriptor: descriptor(id: .localParsedUsage)),
                ])
                .selectedProvider(
                    settings: UsageSettingsSnapshot(),
                    focusedProviderId: .localParsedUsage
                )
            ),
            UsageSettingsSelectionMatrixRow(
                id: "rejected-preferred-fallback",
                selection: UsageCoordinator(providers: [
                    SettingsSelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits)),
                ])
                .selectedProvider(settings: UsageSettingsSnapshot(preferredProviderId: .zaiQuota))
            ),
            UsageSettingsSelectionMatrixRow(
                id: "unavailable-transient-uses-preferred",
                selection: UsageCoordinator(providers: [
                    SettingsSelectionUsageProvider(
                        descriptor: descriptor(id: .zaiQuota, availability: .disabled)
                    ),
                    SettingsSelectionUsageProvider(descriptor: descriptor(id: .kimiUsage)),
                ])
                .selectedProvider(
                    settings: UsageSettingsSnapshot(preferredProviderId: .kimiUsage),
                    transientProviderId: .zaiQuota
                )
            ),
            UsageSettingsSelectionMatrixRow(
                id: "none",
                selection: UsageCoordinator().selectedProvider(settings: UsageSettingsSnapshot())
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testSettingsPreferredProviderIsSelectedWhenValid() {
        let coordinator = UsageCoordinator(providers: [
            SettingsSelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits)),
            SettingsSelectionUsageProvider(descriptor: descriptor(id: .kimiUsage))
        ])
        let settings = UsageSettingsSnapshot(preferredProviderId: .kimiUsage)

        let selection = coordinator.selectedProvider(settings: settings)

        XCTAssertEqual(selection.descriptor?.id, .kimiUsage)
        XCTAssertEqual(selection.reason, .preferred)
    }

    func testTransientProviderWinsOverSettingsPreferredProvider() {
        let coordinator = UsageCoordinator(providers: [
            SettingsSelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits)),
            SettingsSelectionUsageProvider(descriptor: descriptor(id: .kimiUsage)),
            SettingsSelectionUsageProvider(descriptor: descriptor(id: .localParsedUsage))
        ])
        let settings = UsageSettingsSnapshot(preferredProviderId: .kimiUsage)

        let selection = coordinator.selectedProvider(
            settings: settings,
            transientProviderId: .localParsedUsage
        )

        XCTAssertEqual(selection.descriptor?.id, .localParsedUsage)
        XCTAssertEqual(selection.reason, .transient)
    }

    func testFocusedProviderIsSelectedWhenSettingsHasNoPreferredProvider() {
        let coordinator = UsageCoordinator(providers: [
            SettingsSelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits)),
            SettingsSelectionUsageProvider(descriptor: descriptor(id: .localParsedUsage))
        ])

        let selection = coordinator.selectedProvider(
            settings: UsageSettingsSnapshot(),
            focusedProviderId: .localParsedUsage
        )

        XCTAssertEqual(selection.descriptor?.id, .localParsedUsage)
        XCTAssertEqual(selection.reason, .focused)
    }

    func testUnknownSettingsPreferredProviderIsRejectedAndFallbackIsUsed() {
        let coordinator = UsageCoordinator(providers: [
            SettingsSelectionUsageProvider(descriptor: descriptor(id: .codexRateLimits))
        ])
        let settings = UsageSettingsSnapshot(preferredProviderId: .zaiQuota)

        let selection = coordinator.selectedProvider(settings: settings)

        XCTAssertEqual(selection.descriptor?.id, .codexRateLimits)
        XCTAssertEqual(selection.reason, .fallback)
        XCTAssertEqual(
            selection.rejectedHints,
            [
                UsageProviderSelectionRejectedHint(
                    providerId: .zaiQuota,
                    source: .preferred,
                    reason: .notRegistered
                )
            ]
        )
    }
}

private final class SettingsSelectionUsageProvider: UsageProvider, @unchecked Sendable {
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
    availability: UsageProviderAvailability = .available
) -> UsageProviderDescriptor {
    UsageProviderDescriptor(
        id: id,
        displayName: id.rawValue,
        capabilities: [.normalizedSnapshotOnly],
        minimumRefreshIntervalSeconds: 60,
        availability: availability
    )
}

private struct UsageSettingsSelectionMatrixFixture: Codable, Equatable {
    let rows: [UsageSettingsSelectionMatrixRow]
}

private struct UsageSettingsSelectionMatrixRow: Codable, Equatable {
    let id: String
    let selectedProviderId: UsageProviderIdentifier?
    let reason: UsageProviderSelectionReason
    let rejectedHints: [UsageProviderSelectionRejectedHint]

    init(id: String, selection: UsageProviderSelection) {
        self.id = id
        self.selectedProviderId = selection.descriptor?.id
        self.reason = selection.reason
        self.rejectedHints = selection.rejectedHints
    }
}
