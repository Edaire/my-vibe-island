import XCTest
@testable import MyVibeIslandCore

final class KimiUsageModelsTests: XCTestCase {
    func testKimiCodingUsageNormalizationMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            KimiCodingUsageMatrixFixture.self,
            from: try FixtureLoader.data("usage/kimi-coding-usage-matrix")
        )

        let actual = KimiCodingUsageMatrixFixture(rows: [
            KimiCodingUsageMatrixRow(
                id: "full-coding-usage",
                response: KimiCodingUsageResponse(
                    usage: KimiUsageDetail(limit: 100, used: 40, remaining: 60, resetTime: "2026-07-09T00:00:00Z"),
                    limits: [
                        KimiRateLimit(
                            window: KimiUsageWindow(duration: 1, timeUnit: "day"),
                            detail: KimiUsageDetail(limit: 100, used: 40, remaining: 60, resetTime: "2026-07-09T00:00:00Z")
                        ),
                        KimiRateLimit(
                            window: KimiUsageWindow(duration: 7, timeUnit: "day"),
                            detail: KimiUsageDetail(limit: 700, used: 140, remaining: 560)
                        ),
                    ],
                    totalQuota: KimiUsageDetail(limit: 1000, used: 250, remaining: 750, resetTime: "2026-08-01T00:00:00Z"),
                    parallel: KimiParallelQuota(limit: 4, used: 1, remaining: 3),
                    subType: "coding",
                    authentication: "provider-owned"
                )
            ),
            KimiCodingUsageMatrixRow(
                id: "provider-specific-window",
                response: KimiCodingUsageResponse(
                    limits: [
                        KimiRateLimit(
                            window: KimiUsageWindow(duration: 30, timeUnit: "day"),
                            detail: KimiUsageDetail(limit: 500, used: 125, remaining: 375)
                        ),
                    ],
                    subType: "coding"
                )
            ),
            KimiCodingUsageMatrixRow(
                id: "parallel-only",
                response: KimiCodingUsageResponse(
                    parallel: KimiParallelQuota(limit: 8, used: 2, remaining: 6, resetTime: "2026-07-09T00:00:00Z")
                )
            ),
            KimiCodingUsageMatrixRow(
                id: "missing-windows",
                response: KimiCodingUsageResponse(subType: "coding")
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testKimiCodingUsageResponseDecodeSnakeCaseProviderJSON() throws {
        let json = """
        {
          "usage": {
            "limit": 100000,
            "used": 25000,
            "remaining": 75000,
            "reset_time": "2026-07-09T00:00:00Z"
          },
          "limits": [
            {
              "window": {
                "duration": 1,
                "time_unit": "day"
              },
              "detail": {
                "limit": 100000,
                "used": 25000,
                "remaining": 75000,
                "reset_time": "2026-07-09T00:00:00Z"
              }
            }
          ],
          "total_quota": {
            "limit": 1000000,
            "used": 100000,
            "remaining": 900000
          },
          "parallel": {
            "limit": 8,
            "used": 2,
            "remaining": 6
          },
          "sub_type": "coding",
          "authentication": "provider-owned"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(KimiCodingUsageResponse.self, from: json)

        XCTAssertEqual(decoded.usage?.limit, 100000)
        XCTAssertEqual(decoded.usage?.used, 25000)
        XCTAssertEqual(decoded.usage?.remaining, 75000)
        XCTAssertEqual(decoded.usage?.resetTime, "2026-07-09T00:00:00Z")
        XCTAssertEqual(decoded.limits?.first?.window?.duration, 1)
        XCTAssertEqual(decoded.limits?.first?.window?.timeUnit, "day")
        XCTAssertEqual(decoded.limits?.first?.detail?.remaining, 75000)
        XCTAssertEqual(decoded.totalQuota?.limit, 1000000)
        XCTAssertEqual(decoded.parallel?.limit, 8)
        XCTAssertEqual(decoded.parallel?.used, 2)
        XCTAssertEqual(decoded.parallel?.remaining, 6)
        XCTAssertEqual(decoded.subType, "coding")
        XCTAssertEqual(decoded.authentication, "provider-owned")
    }

    func testKimiCodingUsageResponseRoundTripsThroughJSON() throws {
        let response = KimiCodingUsageResponse(
            usage: KimiUsageDetail(
                limit: 100,
                used: 40,
                remaining: 60,
                resetTime: "2026-07-09T00:00:00Z"
            ),
            limits: [
                KimiRateLimit(
                    window: KimiUsageWindow(duration: 7, timeUnit: "day"),
                    detail: KimiUsageDetail(limit: 700, used: 140, remaining: 560)
                )
            ],
            totalQuota: KimiUsageDetail(limit: 1000, used: 250, remaining: 750),
            parallel: KimiParallelQuota(limit: 4, used: 1, remaining: 3),
            subType: "coding",
            authentication: "provider-owned"
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(KimiCodingUsageResponse.self, from: data)

        XCTAssertEqual(decoded, response)
    }

    func testKimiParallelQuotaDecodesProviderJSON() throws {
        let json = """
        {
          "limit": 8,
          "used": 2,
          "remaining": 6,
          "reset_time": "2026-07-09T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(KimiParallelQuota.self, from: json)

        XCTAssertEqual(decoded.limit, 8)
        XCTAssertEqual(decoded.used, 2)
        XCTAssertEqual(decoded.remaining, 6)
        XCTAssertEqual(decoded.resetTime, "2026-07-09T00:00:00Z")
    }

    func testKimiCodingUsageResponseAllowMissingLimitsAndParallel() throws {
        let json = """
        {
          "usage": {
            "remaining": 12
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(KimiCodingUsageResponse.self, from: json)

        XCTAssertEqual(decoded.usage?.remaining, 12)
        XCTAssertNil(decoded.limits)
        XCTAssertNil(decoded.totalQuota)
        XCTAssertNil(decoded.parallel)
        XCTAssertNil(decoded.subType)
        XCTAssertNil(decoded.authentication)
    }

    func testKimiCodingUsageNormalizesToProviderQuotaSnapshot() {
        let response = KimiCodingUsageResponse(
            usage: KimiUsageDetail(limit: 100, used: 40, remaining: 60, resetTime: "2026-07-09T00:00:00Z"),
            limits: [
                KimiRateLimit(
                    window: KimiUsageWindow(duration: 1, timeUnit: "day"),
                    detail: KimiUsageDetail(limit: 100, used: 40, remaining: 60, resetTime: "2026-07-09T00:00:00Z")
                )
            ],
            totalQuota: KimiUsageDetail(limit: 1000, used: 250, remaining: 750, resetTime: "2026-08-01T00:00:00Z"),
            parallel: KimiParallelQuota(limit: 4, used: 1, remaining: 3),
            subType: "coding",
            authentication: "provider-owned"
        )
        let account = UsageAccountID(rawValue: "kimi-local")

        let snapshot = ProviderQuotaSnapshot(
            kimiCodingUsage: response,
            accountId: account,
            collectedAt: "2026-07-08T12:30:00Z"
        )

        XCTAssertEqual(snapshot.providerId, .kimiUsage)
        XCTAssertEqual(snapshot.accountId, account)
        XCTAssertEqual(snapshot.source, .providerReported)
        XCTAssertEqual(snapshot.collectedAt, "2026-07-08T12:30:00Z")
        XCTAssertEqual(snapshot.freshness, .fresh)
        XCTAssertEqual(snapshot.primaryWindow?.id, "total-quota")
        XCTAssertEqual(snapshot.primaryWindow?.kind, .totalQuota)
        XCTAssertEqual(snapshot.primaryWindow?.used?.value, 250)
        XCTAssertEqual(snapshot.primaryWindow?.limit?.value, 1000)
        XCTAssertEqual(snapshot.primaryWindow?.remaining?.value, 750)
        XCTAssertEqual(snapshot.primaryWindow?.usedPercent, 25)
        XCTAssertEqual(snapshot.primaryWindow?.resetAt, "2026-08-01T00:00:00Z")
        XCTAssertEqual(snapshot.secondaryWindow?.id, "parallel")
        XCTAssertEqual(snapshot.secondaryWindow?.kind, .parallelQuota)
        XCTAssertEqual(snapshot.secondaryWindow?.used?.value, 1)
        XCTAssertEqual(snapshot.secondaryWindow?.limit?.value, 4)
        XCTAssertEqual(snapshot.secondaryWindow?.remaining?.value, 3)
        XCTAssertEqual(snapshot.secondaryWindow?.usedPercent, 25)
        XCTAssertEqual(snapshot.extraWindows.first?.kind, .daily)
        XCTAssertEqual(snapshot.extraWindows.first?.usedPercent, 40)
        XCTAssertEqual(snapshot.extraUsage.map(\.key), ["subType", "authentication"])
        XCTAssertEqual(snapshot.extraUsage.map(\.value), ["coding", "provider-owned"])
        XCTAssertEqual(snapshot.privacyLevel, .redacted)
    }

    func testKimiCodingUsageNormalizesMissingWindowsAsUnavailable() {
        let snapshot = ProviderQuotaSnapshot(
            kimiCodingUsage: KimiCodingUsageResponse(subType: "coding"),
            collectedAt: "2026-07-08T12:30:00Z"
        )

        XCTAssertEqual(snapshot.providerId, .kimiUsage)
        XCTAssertEqual(snapshot.freshness, .unavailable)
        XCTAssertEqual(snapshot.failure, .noUsageWindows)
        XCTAssertNil(snapshot.primaryWindow)
        XCTAssertNil(snapshot.secondaryWindow)
        XCTAssertEqual(snapshot.extraWindows, [])
        XCTAssertEqual(snapshot.extraUsage.first?.key, "subType")
        XCTAssertEqual(snapshot.extraUsage.first?.value, "coding")
    }

    func testKimiBillingUsageResponseDecodeProviderJSON() throws {
        let json = """
        {
          "usages": [
            {
              "scope": "provider-scope",
              "detail": {
                "limit": 500,
                "used": 125,
                "remaining": 375,
                "reset_time": "2026-07-09T00:00:00Z"
              },
              "limits": [
                {
                  "window": {
                    "duration": 30,
                    "time_unit": "day"
                  },
                  "detail": {
                    "limit": 500,
                    "used": 125,
                    "remaining": 375
                  }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(KimiBillingUsageResponse.self, from: json)

        XCTAssertEqual(decoded.usages?.first?.scope, "provider-scope")
        XCTAssertEqual(decoded.usages?.first?.detail?.limit, 500)
        XCTAssertEqual(decoded.usages?.first?.detail?.used, 125)
        XCTAssertEqual(decoded.usages?.first?.detail?.remaining, 375)
        XCTAssertEqual(decoded.usages?.first?.detail?.resetTime, "2026-07-09T00:00:00Z")
        XCTAssertEqual(decoded.usages?.first?.limits?.first?.window?.duration, 30)
        XCTAssertEqual(decoded.usages?.first?.limits?.first?.window?.timeUnit, "day")
        XCTAssertEqual(decoded.usages?.first?.limits?.first?.detail?.remaining, 375)
    }

    func testKimiBillingUsageResponseRoundTripsThroughJSON() throws {
        let response = KimiBillingUsageResponse(
            usages: [
                KimiBillingUsage(
                    scope: "provider-local",
                    detail: KimiUsageDetail(limit: 100, used: 10, remaining: 90),
                    limits: [
                        KimiRateLimit(
                            window: KimiUsageWindow(duration: 1, timeUnit: "month"),
                            detail: KimiUsageDetail(limit: 100, used: 10, remaining: 90)
                        )
                    ]
                )
            ]
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(KimiBillingUsageResponse.self, from: data)

        XCTAssertEqual(decoded, response)
    }

    func testKimiBillingUsageResponseAllowMissingUsagesAndLimits() throws {
        let empty = try JSONDecoder().decode(KimiBillingUsageResponse.self, from: "{}".data(using: .utf8)!)
        XCTAssertNil(empty.usages)

        let json = """
        {
          "usages": [
            {
              "scope": "provider-empty"
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(KimiBillingUsageResponse.self, from: json)

        XCTAssertEqual(decoded.usages?.first?.scope, "provider-empty")
        XCTAssertNil(decoded.usages?.first?.detail)
        XCTAssertNil(decoded.usages?.first?.limits)
    }

    func testKimiBillingUsageResponseAddsProviderUsageMetadataToQuotaSnapshot() {
        let codingSnapshot = ProviderQuotaSnapshot(
            kimiCodingUsage: KimiCodingUsageResponse(
                totalQuota: KimiUsageDetail(limit: 1000, used: 200, remaining: 800),
                subType: "coding",
                authentication: "provider-owned"
            ),
            accountId: UsageAccountID(rawValue: "kimi-local"),
            collectedAt: "2026-07-08T12:30:00Z"
        )
        let providerUsage = KimiBillingUsageResponse(
            usages: [
                KimiBillingUsage(
                    scope: "provider-monthly",
                    detail: KimiUsageDetail(
                        limit: 500,
                        used: 125,
                        remaining: 375,
                        resetTime: "2026-08-01T00:00:00Z"
                    ),
                    limits: [
                        KimiRateLimit(
                            window: KimiUsageWindow(duration: 30, timeUnit: "day"),
                            detail: KimiUsageDetail(limit: 500, used: 125, remaining: 375)
                        )
                    ]
                )
            ]
        )

        let merged = codingSnapshot.addingKimiProviderUsageMetadata(providerUsage)

        XCTAssertEqual(merged.providerId, .kimiUsage)
        XCTAssertEqual(merged.accountId, UsageAccountID(rawValue: "kimi-local"))
        XCTAssertEqual(merged.primaryWindow, codingSnapshot.primaryWindow)
        XCTAssertEqual(merged.secondaryWindow, codingSnapshot.secondaryWindow)
        XCTAssertEqual(merged.extraUsage.map(\.key), ["subType", "authentication", "providerUsageScope"])
        XCTAssertEqual(merged.extraUsage.map(\.value), ["coding", "provider-owned", "provider-monthly"])
        XCTAssertEqual(merged.extraWindows.map(\.id), ["provider-usage-0", "provider-usage-0-limit-0"])
        XCTAssertEqual(merged.extraWindows.first?.label, "Kimi provider usage provider-monthly")
        XCTAssertEqual(merged.extraWindows.first?.kind, .providerSpecific)
        XCTAssertEqual(merged.extraWindows.first?.used?.value, 125)
        XCTAssertEqual(merged.extraWindows.first?.limit?.value, 500)
        XCTAssertEqual(merged.extraWindows.first?.remaining?.value, 375)
        XCTAssertEqual(merged.extraWindows.first?.usedPercent, 25)
        XCTAssertEqual(merged.extraWindows.first?.resetAt, "2026-08-01T00:00:00Z")
        XCTAssertEqual(merged.extraWindows.last?.label, "Kimi 30 day limit")
        XCTAssertEqual(merged.extraWindows.last?.kind, .providerSpecific)
        XCTAssertEqual(merged.privacyLevel, .redacted)
    }
}

private struct KimiCodingUsageMatrixFixture: Codable, Equatable {
    let rows: [KimiCodingUsageMatrixRow]
}

private struct KimiCodingUsageMatrixRow: Codable, Equatable {
    let id: String
    let freshness: UsageSnapshotFreshness
    let primaryWindow: KimiUsageWindowSummary?
    let secondaryWindow: KimiUsageWindowSummary?
    let extraWindows: [KimiUsageWindowSummary]
    let extraUsage: [String]
    let failure: UsageFailureCategory?

    init(id: String, response: KimiCodingUsageResponse) {
        let snapshot = ProviderQuotaSnapshot(
            kimiCodingUsage: response,
            accountId: UsageAccountID(rawValue: "\(id)-account"),
            collectedAt: "2026-07-08T12:30:00Z"
        )

        self.id = id
        self.freshness = snapshot.freshness
        self.primaryWindow = snapshot.primaryWindow.map(KimiUsageWindowSummary.init(window:))
        self.secondaryWindow = snapshot.secondaryWindow.map(KimiUsageWindowSummary.init(window:))
        self.extraWindows = snapshot.extraWindows.map(KimiUsageWindowSummary.init(window:))
        self.extraUsage = snapshot.extraUsage.map { "\($0.key):\($0.value)" }
        self.failure = snapshot.failure
    }
}

private struct KimiUsageWindowSummary: Codable, Equatable {
    let id: String
    let label: String
    let kind: UsageWindowKind
    let usedValue: Double?
    let limitValue: Double?
    let remainingValue: Double?
    let usedPercent: Double?
    let resetAt: String?

    init(window: UsageLimitWindow) {
        self.id = window.id
        self.label = window.label
        self.kind = window.kind
        self.usedValue = window.used?.value
        self.limitValue = window.limit?.value
        self.remainingValue = window.remaining?.value
        self.usedPercent = window.usedPercent
        self.resetAt = window.resetAt
    }
}
