import XCTest
@testable import MyVibeIslandCore

final class ZaiAccountPeriodModelsTests: XCTestCase {
    func testZaiAccountPeriodMetadataMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ZaiAccountPeriodMatrixFixture.self,
            from: try FixtureLoader.data("usage/zai-account-period-matrix")
        )

        let baseSnapshot = ProviderQuotaSnapshot(
            zaiQuotaResponse: ZaiQuotaResponse(
                code: 200,
                success: true,
                data: ZaiQuotaData(
                    limits: [
                        ZaiLimit(
                            type: "monthly",
                            percentage: 10,
                            usage: 50,
                            remaining: 450,
                            unit: "credits",
                            number: 500
                        )
                    ],
                    planName: "provider-plan"
                )
            ),
            accountId: UsageAccountID(rawValue: "zai-local"),
            collectedAt: "2026-07-08T12:30:00Z"
        )
        let actual = ZaiAccountPeriodMatrixFixture(rows: [
            ZaiAccountPeriodMatrixRow(
                id: "full-current-period",
                baseSnapshot: baseSnapshot,
                response: ZaiAccountPeriodResponse(
                    code: 0,
                    success: true,
                    data: [
                        ZaiAccountPeriodEntry(
                            productName: "provider-period",
                            nextRenewTime: "2026-08-01T00:00:00Z",
                            inCurrentPeriod: true
                        ),
                    ]
                )
            ),
            ZaiAccountPeriodMatrixRow(
                id: "multiple-partial-periods",
                baseSnapshot: baseSnapshot,
                response: ZaiAccountPeriodResponse(
                    code: 0,
                    success: true,
                    data: [
                        ZaiAccountPeriodEntry(productName: "provider-one"),
                        ZaiAccountPeriodEntry(
                            nextRenewTime: "2026-09-01T00:00:00Z",
                            inCurrentPeriod: false
                        ),
                    ]
                )
            ),
            ZaiAccountPeriodMatrixRow(
                id: "missing-period-data",
                baseSnapshot: baseSnapshot,
                response: ZaiAccountPeriodResponse(code: 404, success: false)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testZaiAccountPeriodResponseDecodeSnakeCaseProviderJSON() throws {
        let json = """
        {
          "code": 0,
          "success": true,
          "data": [
            {
              "product_name": "provider-period",
              "next_renew_time": "2026-08-01T00:00:00Z",
              "in_current_period": true
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ZaiAccountPeriodResponse.self, from: json)

        XCTAssertEqual(decoded.code, 0)
        XCTAssertEqual(decoded.success, true)
        XCTAssertEqual(decoded.data?.first?.productName, "provider-period")
        XCTAssertEqual(decoded.data?.first?.nextRenewTime, "2026-08-01T00:00:00Z")
        XCTAssertEqual(decoded.data?.first?.inCurrentPeriod, true)
    }

    func testZaiAccountPeriodResponseAllowsMissingData() throws {
        let json = """
        {
          "code": 404,
          "success": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ZaiAccountPeriodResponse.self, from: json)

        XCTAssertEqual(decoded.code, 404)
        XCTAssertEqual(decoded.success, false)
        XCTAssertNil(decoded.data)
    }

    func testZaiAccountPeriodResponseRoundTripsThroughJSON() throws {
        let response = ZaiAccountPeriodResponse(
            code: 0,
            success: true,
            data: [
                ZaiAccountPeriodEntry(
                    productName: "provider-period",
                    nextRenewTime: "2026-08-01T00:00:00Z",
                    inCurrentPeriod: true
                )
            ]
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ZaiAccountPeriodResponse.self, from: data)

        XCTAssertEqual(decoded, response)
    }

    func testZaiAccountPeriodResponseAddsProviderMetadataToQuotaSnapshot() {
        let quotaSnapshot = ProviderQuotaSnapshot(
            zaiQuotaResponse: ZaiQuotaResponse(
                code: 200,
                success: true,
                data: ZaiQuotaData(
                    limits: [
                        ZaiLimit(
                            type: "monthly",
                            percentage: 10,
                            usage: 50,
                            remaining: 450,
                            unit: "credits",
                            number: 500
                        )
                    ],
                    planName: "provider-plan"
                )
            ),
            accountId: UsageAccountID(rawValue: "zai-local"),
            collectedAt: "2026-07-08T12:30:00Z"
        )
        let periodResponse = ZaiAccountPeriodResponse(
            code: 0,
            success: true,
            data: [
                ZaiAccountPeriodEntry(
                    productName: "provider-period",
                    nextRenewTime: "2026-08-01T00:00:00Z",
                    inCurrentPeriod: true
                )
            ]
        )

        let merged = quotaSnapshot.addingZaiAccountPeriodMetadata(periodResponse)

        XCTAssertEqual(merged.providerId, .zaiQuota)
        XCTAssertEqual(merged.accountId, UsageAccountID(rawValue: "zai-local"))
        XCTAssertEqual(merged.primaryWindow, quotaSnapshot.primaryWindow)
        XCTAssertEqual(merged.freshness, .fresh)
        XCTAssertEqual(
            merged.extraUsage.map(\.key),
            [
                "planName",
                "code",
                "success",
                "accountPeriodCode",
                "accountPeriodSuccess",
                "accountPeriodProductName",
                "accountPeriodNextTime",
                "accountPeriodCurrent"
            ]
        )
        XCTAssertEqual(
            merged.extraUsage.map(\.value),
            [
                "provider-plan",
                "200",
                "true",
                "0",
                "true",
                "provider-period",
                "2026-08-01T00:00:00Z",
                "true"
            ]
        )
    }
}

private struct ZaiAccountPeriodMatrixFixture: Codable, Equatable {
    let rows: [ZaiAccountPeriodMatrixRow]
}

private struct ZaiAccountPeriodMatrixRow: Codable, Equatable {
    let id: String
    let providerId: UsageProviderIdentifier
    let accountId: UsageAccountID?
    let primaryWindowId: String?
    let freshness: UsageSnapshotFreshness
    let extraUsage: [String]
    let failure: UsageFailureCategory?
    let privacyLevel: UsagePrivacyLevel

    init(
        id: String,
        baseSnapshot: ProviderQuotaSnapshot,
        response: ZaiAccountPeriodResponse
    ) {
        let merged = baseSnapshot.addingZaiAccountPeriodMetadata(response)

        self.id = id
        self.providerId = merged.providerId
        self.accountId = merged.accountId
        self.primaryWindowId = merged.primaryWindow?.id
        self.freshness = merged.freshness
        self.extraUsage = merged.extraUsage.map { "\($0.key):\($0.value)" }
        self.failure = merged.failure
        self.privacyLevel = merged.privacyLevel
    }
}
