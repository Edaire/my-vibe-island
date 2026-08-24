import XCTest
@testable import MyVibeIslandCore

final class LocalParsedUsageModelsTests: XCTestCase {
    func testLocalParsedUsageNormalizationMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            LocalParsedUsageMatrixFixture.self,
            from: try FixtureLoader.data("usage/local-parsed-usage-matrix")
        )

        let actual = LocalParsedUsageMatrixFixture(rows: [
            LocalParsedUsageMatrixRow(
                id: "primary-window-with-source",
                payload: LocalParsedUsagePayload(
                    sourceName: "fixture-cache",
                    snapshot: snapshot()
                )
            ),
            LocalParsedUsageMatrixRow(
                id: "secondary-and-extra-windows",
                payload: LocalParsedUsagePayload(
                    sourceName: "statusline-cache",
                    snapshot: LocalParsedUsageSnapshot(
                        accountId: UsageAccountID(rawValue: "statusline-local"),
                        collectedAt: "2026-07-08T12:31:00Z",
                        secondaryWindow: UsageLimitWindow(
                            id: "parallel",
                            label: "Parsed parallel",
                            kind: .parallelQuota,
                            used: UsageAmount(value: 1, unit: "slots"),
                            limit: UsageAmount(value: 4, unit: "slots"),
                            remaining: UsageAmount(value: 3, unit: "slots"),
                            usedPercent: 25,
                            sourceConfidence: .parsed
                        ),
                        extraWindows: [
                            UsageLimitWindow(
                                id: "daily",
                                label: "Parsed daily",
                                kind: .daily,
                                used: UsageAmount(value: 40, unit: "requests"),
                                limit: UsageAmount(value: 100, unit: "requests"),
                                remaining: UsageAmount(value: 60, unit: "requests"),
                                usedPercent: 40,
                                resetAt: "2026-07-09T00:00:00Z",
                                sourceConfidence: .parsed
                            ),
                        ],
                        extraUsage: [
                            UsageExtraUsageItem(key: "origin", value: "statusline")
                        ]
                    )
                )
            ),
            LocalParsedUsageMatrixRow(
                id: "missing-windows",
                payload: LocalParsedUsagePayload(
                    snapshot: LocalParsedUsageSnapshot(
                        collectedAt: "2026-07-08T12:30:00Z"
                    )
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testLocalParsedUsagePayloadRoundTripsThroughJSON() throws {
        let payload = LocalParsedUsagePayload(
            sourceName: "fixture-cache",
            snapshot: snapshot()
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(LocalParsedUsagePayload.self, from: data)

        XCTAssertEqual(decoded, payload)
    }

    func testLocalParsedUsagePayloadNormalizesToProviderQuotaSnapshot() {
        let payload = LocalParsedUsagePayload(
            sourceName: "fixture-cache",
            snapshot: snapshot()
        )

        let normalized = ProviderQuotaSnapshot(localParsedUsage: payload)

        XCTAssertEqual(normalized.providerId, .localParsedUsage)
        XCTAssertEqual(normalized.accountId, UsageAccountID(rawValue: "local-cache"))
        XCTAssertEqual(normalized.source, .parsed)
        XCTAssertEqual(normalized.collectedAt, "2026-07-08T12:30:00Z")
        XCTAssertEqual(normalized.freshness, .fresh)
        XCTAssertEqual(normalized.primaryWindow?.id, "context")
        XCTAssertEqual(normalized.primaryWindow?.kind, .providerSpecific)
        XCTAssertEqual(normalized.primaryWindow?.used?.value, 25)
        XCTAssertEqual(normalized.primaryWindow?.limit?.value, 100)
        XCTAssertEqual(normalized.primaryWindow?.remaining?.value, 75)
        XCTAssertEqual(normalized.extraUsage.map(\.key), ["sourceName"])
        XCTAssertEqual(normalized.extraUsage.map(\.value), ["fixture-cache"])
        XCTAssertEqual(normalized.privacyLevel, .redacted)
    }

    func testLocalParsedUsagePayloadWithoutWindowIsUnavailable() {
        let payload = LocalParsedUsagePayload(
            sourceName: nil,
            snapshot: LocalParsedUsageSnapshot(
                accountId: nil,
                collectedAt: "2026-07-08T12:30:00Z",
                primaryWindow: nil
            )
        )

        let normalized = ProviderQuotaSnapshot(localParsedUsage: payload)

        XCTAssertEqual(normalized.providerId, .localParsedUsage)
        XCTAssertEqual(normalized.freshness, .unavailable)
        XCTAssertEqual(normalized.failure, .noUsageWindows)
        XCTAssertNil(normalized.primaryWindow)
        XCTAssertEqual(normalized.extraUsage, [])
    }

    private func snapshot() -> LocalParsedUsageSnapshot {
        LocalParsedUsageSnapshot(
            accountId: UsageAccountID(rawValue: "local-cache"),
            collectedAt: "2026-07-08T12:30:00Z",
            primaryWindow: UsageLimitWindow(
                id: "context",
                label: "Parsed context",
                kind: .providerSpecific,
                used: UsageAmount(value: 25, unit: "tokens"),
                limit: UsageAmount(value: 100, unit: "tokens"),
                remaining: UsageAmount(value: 75, unit: "tokens"),
                usedPercent: 25,
                sourceConfidence: .parsed
            )
        )
    }
}

private struct LocalParsedUsageMatrixFixture: Codable, Equatable {
    let rows: [LocalParsedUsageMatrixRow]
}

private struct LocalParsedUsageMatrixRow: Codable, Equatable {
    let id: String
    let accountId: UsageAccountID?
    let collectedAt: String?
    let freshness: UsageSnapshotFreshness
    let primaryWindow: LocalParsedUsageWindowSummary?
    let secondaryWindow: LocalParsedUsageWindowSummary?
    let extraWindows: [LocalParsedUsageWindowSummary]
    let extraUsage: [String]
    let failure: UsageFailureCategory?

    init(id: String, payload: LocalParsedUsagePayload) {
        let snapshot = ProviderQuotaSnapshot(localParsedUsage: payload)

        self.id = id
        self.accountId = snapshot.accountId
        self.collectedAt = snapshot.collectedAt
        self.freshness = snapshot.freshness
        self.primaryWindow = snapshot.primaryWindow.map(LocalParsedUsageWindowSummary.init(window:))
        self.secondaryWindow = snapshot.secondaryWindow.map(LocalParsedUsageWindowSummary.init(window:))
        self.extraWindows = snapshot.extraWindows.map(LocalParsedUsageWindowSummary.init(window:))
        self.extraUsage = snapshot.extraUsage.map { "\($0.key):\($0.value)" }
        self.failure = snapshot.failure
    }
}

private struct LocalParsedUsageWindowSummary: Codable, Equatable {
    let id: String
    let label: String
    let kind: UsageWindowKind
    let usedValue: Double?
    let usedUnit: String?
    let limitValue: Double?
    let limitUnit: String?
    let remainingValue: Double?
    let remainingUnit: String?
    let usedPercent: Double?
    let resetAt: String?

    init(window: UsageLimitWindow) {
        self.id = window.id
        self.label = window.label
        self.kind = window.kind
        self.usedValue = window.used?.value
        self.usedUnit = window.used?.unit
        self.limitValue = window.limit?.value
        self.limitUnit = window.limit?.unit
        self.remainingValue = window.remaining?.value
        self.remainingUnit = window.remaining?.unit
        self.usedPercent = window.usedPercent
        self.resetAt = window.resetAt
    }
}
