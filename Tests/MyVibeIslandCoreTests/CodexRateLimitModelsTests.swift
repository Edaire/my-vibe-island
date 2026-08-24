import XCTest
@testable import MyVibeIslandCore

final class CodexRateLimitModelsTests: XCTestCase {
    func testCodexRateLimitNormalizationMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CodexRateLimitMatrixFixture.self,
            from: try FixtureLoader.data("usage/codex-rate-limit-matrix")
        )

        let rows = [
            CodexRateLimitMatrixRow(
                id: "full-primary-secondary-credits",
                rateLimits: CodexRateLimits(
                    limitId: "codex-pro",
                    limitName: "Codex Pro",
                    planType: "provider-plan",
                    primary: CodexRateLimit(
                        usedPercent: 64.5,
                        windowMinutes: 300,
                        resetsAt: "2026-07-08T18:00:00Z",
                        resetsInSeconds: 3600
                    ),
                    secondary: CodexRateLimit(
                        usedPercent: 12,
                        windowMinutes: 10_080,
                        resetsAt: "2026-07-15T00:00:00Z",
                        resetsInSeconds: 604_800
                    ),
                    credits: CodexRateLimitCredits(
                        hasCredits: true,
                        unlimited: false,
                        balance: 42.25
                    ),
                    rateLimitReachedType: .primary
                )
            ),
            CodexRateLimitMatrixRow(
                id: "missing-windows",
                rateLimits: CodexRateLimits(
                    limitId: "codex-empty",
                    credits: CodexRateLimitCredits(hasCredits: false, unlimited: true),
                    rateLimitReachedType: .unknown
                )
            ),
            CodexRateLimitMatrixRow(
                id: "provider-specific-window",
                rateLimits: CodexRateLimits(
                    limitId: "codex-custom",
                    primary: CodexRateLimit(
                        usedPercent: 77,
                        windowMinutes: 60,
                        resetsInSeconds: 900
                    ),
                    credits: CodexRateLimitCredits(hasCredits: true)
                )
            ),
            CodexRateLimitMatrixRow(
                id: "secondary-limit-reached",
                rateLimits: CodexRateLimits(
                    limitName: "Codex Team",
                    secondary: CodexRateLimit(
                        usedPercent: 99,
                        windowMinutes: 10_080,
                        resetsAt: "2026-07-16T00:00:00Z"
                    ),
                    rateLimitReachedType: .secondary
                )
            ),
        ]

        let actual = CodexRateLimitMatrixFixture(rows: rows)

        XCTAssertEqual(actual, expected)
    }

    func testCodexRateLimitsDecodeSnakeCaseProviderJSON() throws {
        let json = """
        {
          "limit_id": "codex-pro",
          "limit_name": "Codex Pro",
          "plan_type": "provider-plan",
          "primary": {
            "used_percent": 64.5,
            "window_minutes": 300,
            "resets_at": "2026-07-08T18:00:00Z",
            "resets_in_seconds": 3600
          },
          "secondary": {
            "used_percent": 12,
            "window_minutes": 10080,
            "resets_at": "2026-07-15T00:00:00Z",
            "resets_in_seconds": 604800
          },
          "credits": {
            "has_credits": true,
            "unlimited": false,
            "balance": 42.25
          },
          "rate_limit_reached_type": "primary"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CodexRateLimits.self, from: json)

        XCTAssertEqual(decoded.limitId, "codex-pro")
        XCTAssertEqual(decoded.limitName, "Codex Pro")
        XCTAssertEqual(decoded.planType, "provider-plan")
        XCTAssertEqual(decoded.primary?.usedPercent, 64.5)
        XCTAssertEqual(decoded.primary?.windowMinutes, 300)
        XCTAssertEqual(decoded.primary?.resetsAt, "2026-07-08T18:00:00Z")
        XCTAssertEqual(decoded.primary?.resetsInSeconds, 3600)
        XCTAssertEqual(decoded.secondary?.windowMinutes, 10080)
        XCTAssertEqual(decoded.credits?.hasCredits, true)
        XCTAssertEqual(decoded.credits?.unlimited, false)
        XCTAssertEqual(decoded.credits?.balance, 42.25)
        XCTAssertEqual(decoded.rateLimitReachedType, .primary)
    }

    func testCodexRateLimitsRoundTripThroughJSON() throws {
        let rateLimits = CodexRateLimits(
            limitId: "codex-local",
            limitName: "Codex Local",
            planType: "provider-local",
            primary: CodexRateLimit(
                usedPercent: 10,
                windowMinutes: 300,
                resetsAt: "2026-07-08T18:00:00Z",
                resetsInSeconds: 1800
            ),
            secondary: CodexRateLimit(
                usedPercent: 20,
                windowMinutes: 10080,
                resetsAt: "2026-07-15T00:00:00Z",
                resetsInSeconds: 604800
            ),
            credits: CodexRateLimitCredits(
                hasCredits: true,
                unlimited: false,
                balance: 12
            ),
            rateLimitReachedType: .secondary
        )

        let data = try JSONEncoder().encode(rateLimits)
        let decoded = try JSONDecoder().decode(CodexRateLimits.self, from: data)

        XCTAssertEqual(decoded, rateLimits)
    }

    func testCodexRateLimitsAllowMissingSecondaryAndCredits() throws {
        let json = """
        {
          "limit_id": "codex-lite",
          "primary": {
            "used_percent": 5
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CodexRateLimits.self, from: json)

        XCTAssertEqual(decoded.limitId, "codex-lite")
        XCTAssertEqual(decoded.primary?.usedPercent, 5)
        XCTAssertNil(decoded.secondary)
        XCTAssertNil(decoded.credits)
        XCTAssertNil(decoded.rateLimitReachedType)
    }

    func testCodexRateLimitsNormalizeToProviderQuotaSnapshot() {
        let rateLimits = CodexRateLimits(
            limitId: "codex-local",
            limitName: "Codex Local",
            planType: "provider-local",
            primary: CodexRateLimit(
                usedPercent: 64.5,
                windowMinutes: 300,
                resetsAt: "2026-07-08T18:00:00Z",
                resetsInSeconds: 3600
            ),
            secondary: CodexRateLimit(
                usedPercent: 12,
                windowMinutes: 10080,
                resetsAt: "2026-07-15T00:00:00Z",
                resetsInSeconds: 604800
            ),
            credits: CodexRateLimitCredits(
                hasCredits: true,
                unlimited: false,
                balance: 42.25
            ),
            rateLimitReachedType: .primary
        )
        let account = UsageAccountID(rawValue: "codex-local")

        let snapshot = ProviderQuotaSnapshot(
            codexRateLimits: rateLimits,
            accountId: account,
            collectedAt: "2026-07-08T12:30:00Z"
        )

        XCTAssertEqual(snapshot.providerId, .codexRateLimits)
        XCTAssertEqual(snapshot.accountId, account)
        XCTAssertEqual(snapshot.source, .providerReported)
        XCTAssertEqual(snapshot.collectedAt, "2026-07-08T12:30:00Z")
        XCTAssertEqual(snapshot.freshness, .fresh)
        XCTAssertEqual(snapshot.primaryWindow?.id, "primary")
        XCTAssertEqual(snapshot.primaryWindow?.label, "Codex Local primary")
        XCTAssertEqual(snapshot.primaryWindow?.kind, .fiveHour)
        XCTAssertEqual(snapshot.primaryWindow?.usedPercent, 64.5)
        XCTAssertEqual(snapshot.primaryWindow?.resetAt, "2026-07-08T18:00:00Z")
        XCTAssertEqual(snapshot.primaryWindow?.resetInSeconds, 3600)
        XCTAssertEqual(snapshot.secondaryWindow?.kind, .sevenDay)
        XCTAssertEqual(snapshot.secondaryWindow?.usedPercent, 12)
        XCTAssertEqual(snapshot.extraUsage.first?.key, "credits")
        XCTAssertEqual(snapshot.extraUsage.first?.value, "42.25")
        XCTAssertEqual(snapshot.extraUsage.first?.isEnabled, true)
        XCTAssertEqual(snapshot.bridgeHint?.severity, .warning)
        XCTAssertEqual(snapshot.bridgeHint?.title, "Codex primary limit reached")
        XCTAssertEqual(snapshot.privacyLevel, .redacted)
    }

    func testCodexRateLimitsNormalizeMissingWindowsAsUnavailable() {
        let snapshot = ProviderQuotaSnapshot(
            codexRateLimits: CodexRateLimits(limitId: "empty"),
            collectedAt: "2026-07-08T12:30:00Z"
        )

        XCTAssertEqual(snapshot.providerId, .codexRateLimits)
        XCTAssertEqual(snapshot.freshness, .unavailable)
        XCTAssertEqual(snapshot.failure, .noUsageWindows)
        XCTAssertNil(snapshot.primaryWindow)
        XCTAssertNil(snapshot.secondaryWindow)
        XCTAssertEqual(snapshot.extraUsage, [])
    }
}

private struct CodexRateLimitMatrixFixture: Codable, Equatable {
    let rows: [CodexRateLimitMatrixRow]
}

private struct CodexRateLimitMatrixRow: Codable, Equatable {
    let id: String
    let status: String
    let displayWindows: [CodexRateLimitWindowSummary]
    let extraUsage: [CodexRateLimitExtraUsageSummary]
    let bridgeHintTitle: String?
    let failure: UsageFailureCategory?

    init(id: String, rateLimits: CodexRateLimits) {
        let snapshot = ProviderQuotaSnapshot(
            codexRateLimits: rateLimits,
            accountId: UsageAccountID(rawValue: "\(id)-account"),
            collectedAt: "2026-07-08T12:30:00Z"
        )

        self.id = id
        self.status = snapshot.freshness.rawValue
        self.displayWindows = [
            snapshot.primaryWindow,
            snapshot.secondaryWindow,
        ]
        .compactMap { $0 }
        .map(CodexRateLimitWindowSummary.init(window:))
        self.extraUsage = snapshot.extraUsage.map(CodexRateLimitExtraUsageSummary.init(extraUsage:))
        self.bridgeHintTitle = snapshot.bridgeHint?.title
        self.failure = snapshot.failure
    }
}

private struct CodexRateLimitWindowSummary: Codable, Equatable {
    let id: String
    let label: String
    let kind: UsageWindowKind
    let usedPercent: Double?
    let resetAt: String?
    let resetInSeconds: Int?

    init(window: UsageLimitWindow) {
        self.id = window.id
        self.label = window.label
        self.kind = window.kind
        self.usedPercent = window.usedPercent
        self.resetAt = window.resetAt
        self.resetInSeconds = window.resetInSeconds
    }
}

private struct CodexRateLimitExtraUsageSummary: Codable, Equatable {
    let key: String
    let value: String
    let isEnabled: Bool
    let usedCreditsValue: Double?
    let usedCreditsUnit: String?

    init(extraUsage: UsageExtraUsageItem) {
        self.key = extraUsage.key
        self.value = extraUsage.value
        self.isEnabled = extraUsage.isEnabled
        self.usedCreditsValue = extraUsage.usedCredits?.value
        self.usedCreditsUnit = extraUsage.usedCredits?.unit
    }
}
