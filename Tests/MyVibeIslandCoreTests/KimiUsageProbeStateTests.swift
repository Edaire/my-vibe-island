import XCTest
@testable import MyVibeIslandCore

final class KimiUsageProbeStateTests: XCTestCase {
    func testKimiUsageProbeStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            KimiUsageProbeStateMatrixFixture.self,
            from: try FixtureLoader.data("usage/kimi-probe-state-matrix")
        )
        let cachedResult = KimiCodingUsageResponse(
            usage: KimiUsageDetail(limit: 100, used: 40, remaining: 60),
            totalQuota: KimiUsageDetail(limit: 1000, used: 100, remaining: 900),
            subType: "coding"
        )

        let actual = KimiUsageProbeStateMatrixFixture(rows: [
            KimiUsageProbeStateMatrixRow(id: "default", state: KimiUsageProbeState()),
            KimiUsageProbeStateMatrixRow(
                id: "cache-update-preserves-probing",
                state: KimiUsageProbeState(isProbing: true).updatingCachedResult(cachedResult)
            ),
            KimiUsageProbeStateMatrixRow(
                id: "probe-update-preserves-cache",
                state: KimiUsageProbeState(cachedResult: cachedResult).updatingProbeStatus(isProbing: true)
            ),
            KimiUsageProbeStateMatrixRow(
                id: "clear-cache-preserves-probing",
                state: KimiUsageProbeState(cachedResult: cachedResult, isProbing: true)
                    .updatingCachedResult(nil)
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testDefaultStateHasNoCachedResultAndIsNotProbing() {
        let state = KimiUsageProbeState()

        XCTAssertNil(state.cachedResult)
        XCTAssertFalse(state.isProbing)
    }

    func testUpdatingCachedResultPreservesProbeStatus() {
        let cachedResult = KimiCodingUsageResponse(
            usage: KimiUsageDetail(limit: 100, used: 40, remaining: 60),
            totalQuota: KimiUsageDetail(limit: 1000, used: 100, remaining: 900)
        )
        let state = KimiUsageProbeState(isProbing: true)

        let updated = state.updatingCachedResult(cachedResult)

        XCTAssertEqual(updated.cachedResult, cachedResult)
        XCTAssertTrue(updated.isProbing)
    }

    func testUpdatingProbeStatusPreservesCachedResult() {
        let cachedResult = KimiCodingUsageResponse(
            usage: KimiUsageDetail(limit: 100, used: 10, remaining: 90)
        )
        let state = KimiUsageProbeState(cachedResult: cachedResult)

        let updated = state.updatingProbeStatus(isProbing: true)

        XCTAssertEqual(updated.cachedResult, cachedResult)
        XCTAssertTrue(updated.isProbing)
    }

    func testStateRoundTripsThroughJSON() throws {
        let state = KimiUsageProbeState(
            cachedResult: KimiCodingUsageResponse(
                usage: KimiUsageDetail(limit: 100, used: 25, remaining: 75),
                limits: [
                    KimiRateLimit(
                        window: KimiUsageWindow(duration: 1, timeUnit: "day"),
                        detail: KimiUsageDetail(limit: 100, used: 25, remaining: 75)
                    )
                ],
                subType: "coding"
            ),
            isProbing: true
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(KimiUsageProbeState.self, from: data)

        XCTAssertEqual(decoded, state)
    }
}

private struct KimiUsageProbeStateMatrixFixture: Codable, Equatable {
    let rows: [KimiUsageProbeStateMatrixRow]
}

private struct KimiUsageProbeStateMatrixRow: Codable, Equatable {
    let id: String
    let isProbing: Bool
    let hasCachedResult: Bool
    let cachedUsed: Double?
    let cachedTotalLimit: Double?
    let cachedSubType: String?

    init(id: String, state: KimiUsageProbeState) {
        self.id = id
        self.isProbing = state.isProbing
        self.hasCachedResult = state.cachedResult != nil
        self.cachedUsed = state.cachedResult?.usage?.used
        self.cachedTotalLimit = state.cachedResult?.totalQuota?.limit
        self.cachedSubType = state.cachedResult?.subType
    }
}
