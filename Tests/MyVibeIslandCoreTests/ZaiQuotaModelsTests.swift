import XCTest
@testable import MyVibeIslandCore

final class ZaiQuotaModelsTests: XCTestCase {
    func testZaiQuotaNormalizationMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ZaiQuotaMatrixFixture.self,
            from: try FixtureLoader.data("usage/zai-quota-matrix")
        )

        let actual = ZaiQuotaMatrixFixture(rows: [
            ZaiQuotaMatrixRow(
                id: "daily-monthly-metadata",
                response: ZaiQuotaResponse(
                    code: 200,
                    success: true,
                    data: ZaiQuotaData(
                        limits: [
                            ZaiLimit(
                                type: "daily",
                                percentage: 42.5,
                                usage: 425,
                                currentValue: 420,
                                remaining: 575,
                                nextResetTime: "2026-07-09T00:00:00Z",
                                unit: "requests",
                                number: 1000
                            ),
                            ZaiLimit(
                                type: "monthly",
                                percentage: 10,
                                usage: 50,
                                remaining: 450,
                                nextResetTime: "2026-08-01T00:00:00Z",
                                unit: "credits",
                                number: 500
                            ),
                        ],
                        planName: "provider-plan"
                    )
                )
            ),
            ZaiQuotaMatrixRow(
                id: "total-quota-kind",
                response: ZaiQuotaResponse(
                    code: 200,
                    success: true,
                    data: ZaiQuotaData(
                        limits: [
                            ZaiLimit(
                                type: "total_quota",
                                percentage: 25,
                                usage: 250,
                                remaining: 750,
                                unit: "credits",
                                number: 1000
                            ),
                        ]
                    )
                )
            ),
            ZaiQuotaMatrixRow(
                id: "unknown-type-default-unit",
                response: ZaiQuotaResponse(
                    code: 200,
                    success: false,
                    data: ZaiQuotaData(
                        limits: [
                            ZaiLimit(
                                type: "burst",
                                usage: 7,
                                remaining: 3,
                                number: 10
                            ),
                        ],
                        planName: "provider-burst"
                    )
                )
            ),
            ZaiQuotaMatrixRow(
                id: "missing-limits",
                response: ZaiQuotaResponse(
                    code: 204,
                    success: true,
                    data: ZaiQuotaData(planName: "provider-empty")
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testZaiQuotaResponseDecodeSnakeCaseProviderJSON() throws {
        let json = """
        {
          "code": 200,
          "success": true,
          "data": {
            "plan_name": "provider-plan",
            "limits": [
              {
                "type": "daily",
                "percentage": 42.5,
                "usage": 425,
                "current_value": 425,
                "remaining": 575,
                "next_reset_time": "2026-07-09T00:00:00Z",
                "unit": "requests",
                "number": 1000
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ZaiQuotaResponse.self, from: json)

        XCTAssertEqual(decoded.code, 200)
        XCTAssertEqual(decoded.success, true)
        XCTAssertEqual(decoded.data?.planName, "provider-plan")
        XCTAssertEqual(decoded.data?.limits?.first?.type, "daily")
        XCTAssertEqual(decoded.data?.limits?.first?.percentage, 42.5)
        XCTAssertEqual(decoded.data?.limits?.first?.usage, 425)
        XCTAssertEqual(decoded.data?.limits?.first?.currentValue, 425)
        XCTAssertEqual(decoded.data?.limits?.first?.remaining, 575)
        XCTAssertEqual(decoded.data?.limits?.first?.nextResetTime, "2026-07-09T00:00:00Z")
        XCTAssertEqual(decoded.data?.limits?.first?.unit, "requests")
        XCTAssertEqual(decoded.data?.limits?.first?.number, 1000)
    }

    func testZaiQuotaResponseRoundTripsThroughJSON() throws {
        let response = ZaiQuotaResponse(
            code: 200,
            success: true,
            data: ZaiQuotaData(
                limits: [
                    ZaiLimit(
                        type: "monthly",
                        percentage: 10,
                        usage: 50,
                        currentValue: 50,
                        remaining: 450,
                        nextResetTime: "2026-08-01T00:00:00Z",
                        unit: "credits",
                        number: 500
                    )
                ],
                planName: "provider-local"
            )
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ZaiQuotaResponse.self, from: data)

        XCTAssertEqual(decoded, response)
    }

    func testZaiQuotaResponseAllowMissingDataAndLimits() throws {
        let json = """
        {
          "code": 204,
          "success": true,
          "data": {
            "plan_name": "provider-empty"
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ZaiQuotaResponse.self, from: json)

        XCTAssertEqual(decoded.code, 204)
        XCTAssertEqual(decoded.success, true)
        XCTAssertEqual(decoded.data?.planName, "provider-empty")
        XCTAssertNil(decoded.data?.limits)

        let empty = try JSONDecoder().decode(ZaiQuotaResponse.self, from: "{}".data(using: .utf8)!)
        XCTAssertNil(empty.code)
        XCTAssertNil(empty.success)
        XCTAssertNil(empty.data)
    }

    func testZaiQuotaResponseNormalizesToProviderQuotaSnapshot() {
        let response = ZaiQuotaResponse(
            code: 200,
            success: true,
            data: ZaiQuotaData(
                limits: [
                    ZaiLimit(
                        type: "daily",
                        percentage: 42.5,
                        usage: 425,
                        currentValue: 420,
                        remaining: 575,
                        nextResetTime: "2026-07-09T00:00:00Z",
                        unit: "requests",
                        number: 1000
                    ),
                    ZaiLimit(
                        type: "monthly",
                        percentage: 10,
                        usage: 50,
                        remaining: 450,
                        nextResetTime: "2026-08-01T00:00:00Z",
                        unit: "credits",
                        number: 500
                    )
                ],
                planName: "provider-plan"
            )
        )
        let account = UsageAccountID(rawValue: "zai-local")

        let snapshot = ProviderQuotaSnapshot(
            zaiQuotaResponse: response,
            accountId: account,
            collectedAt: "2026-07-08T12:30:00Z"
        )

        XCTAssertEqual(snapshot.providerId, .zaiQuota)
        XCTAssertEqual(snapshot.accountId, account)
        XCTAssertEqual(snapshot.source, .providerReported)
        XCTAssertEqual(snapshot.collectedAt, "2026-07-08T12:30:00Z")
        XCTAssertEqual(snapshot.freshness, .fresh)
        XCTAssertEqual(snapshot.primaryWindow?.id, "daily")
        XCTAssertEqual(snapshot.primaryWindow?.kind, .daily)
        XCTAssertEqual(snapshot.primaryWindow?.used?.value, 420)
        XCTAssertEqual(snapshot.primaryWindow?.limit?.value, 1000)
        XCTAssertEqual(snapshot.primaryWindow?.remaining?.value, 575)
        XCTAssertEqual(snapshot.primaryWindow?.usedPercent, 42.5)
        XCTAssertEqual(snapshot.primaryWindow?.resetAt, "2026-07-09T00:00:00Z")
        XCTAssertEqual(snapshot.extraWindows.first?.id, "monthly")
        XCTAssertEqual(snapshot.extraWindows.first?.kind, .monthly)
        XCTAssertEqual(snapshot.extraWindows.first?.used?.value, 50)
        XCTAssertEqual(snapshot.extraWindows.first?.limit?.value, 500)
        XCTAssertEqual(snapshot.extraUsage.map(\.key), ["planName", "code", "success"])
        XCTAssertEqual(snapshot.extraUsage.map(\.value), ["provider-plan", "200", "true"])
        XCTAssertEqual(snapshot.privacyLevel, .redacted)
    }

    func testZaiQuotaResponseNormalizesMissingLimitsAsUnavailable() {
        let snapshot = ProviderQuotaSnapshot(
            zaiQuotaResponse: ZaiQuotaResponse(code: 204, success: true, data: ZaiQuotaData(planName: "provider-empty")),
            collectedAt: "2026-07-08T12:30:00Z"
        )

        XCTAssertEqual(snapshot.providerId, .zaiQuota)
        XCTAssertEqual(snapshot.freshness, .unavailable)
        XCTAssertEqual(snapshot.failure, .noUsageWindows)
        XCTAssertNil(snapshot.primaryWindow)
        XCTAssertEqual(snapshot.extraWindows, [])
        XCTAssertEqual(snapshot.extraUsage.map(\.key), ["planName", "code", "success"])
        XCTAssertEqual(snapshot.extraUsage.map(\.value), ["provider-empty", "204", "true"])
    }
}

private struct ZaiQuotaMatrixFixture: Codable, Equatable {
    let rows: [ZaiQuotaMatrixRow]
}

private struct ZaiQuotaMatrixRow: Codable, Equatable {
    let id: String
    let freshness: UsageSnapshotFreshness
    let primaryWindow: ZaiQuotaWindowSummary?
    let extraWindows: [ZaiQuotaWindowSummary]
    let extraUsage: [String]
    let failure: UsageFailureCategory?

    init(id: String, response: ZaiQuotaResponse) {
        let snapshot = ProviderQuotaSnapshot(
            zaiQuotaResponse: response,
            accountId: UsageAccountID(rawValue: "\(id)-account"),
            collectedAt: "2026-07-08T12:30:00Z"
        )

        self.id = id
        self.freshness = snapshot.freshness
        self.primaryWindow = snapshot.primaryWindow.map(ZaiQuotaWindowSummary.init(window:))
        self.extraWindows = snapshot.extraWindows.map(ZaiQuotaWindowSummary.init(window:))
        self.extraUsage = snapshot.extraUsage.map { "\($0.key):\($0.value)" }
        self.failure = snapshot.failure
    }
}

private struct ZaiQuotaWindowSummary: Codable, Equatable {
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
