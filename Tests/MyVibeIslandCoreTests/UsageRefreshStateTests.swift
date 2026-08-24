import XCTest
@testable import MyVibeIslandCore

final class UsageRefreshStateTests: XCTestCase {
    func testUsageRefreshStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsageRefreshStateMatrixFixture.self,
            from: try FixtureLoader.data("usage/refresh-state-matrix")
        )
        let failureState = UsageRefreshState(backoffMultiplier: 7)
            .recordingFailure(nowSeconds: 100, baseBackoffSeconds: 30, maximumBackoffMultiplier: 8)
        let successState = UsageRefreshState(
            backoffMultiplier: 4,
            backoffUntilSeconds: 240,
            isRefreshing: true
        )
            .recordingSuccess(nowSeconds: 200)

        let actual = UsageRefreshStateMatrixFixture(rows: [
            row(
                id: "initial",
                state: UsageRefreshState(),
                nowSeconds: 100,
                minimumRefreshIntervalSeconds: 60
            ),
            row(
                id: "minimum-interval",
                state: UsageRefreshState(lastFetchAttemptSeconds: 100),
                nowSeconds: 120,
                minimumRefreshIntervalSeconds: 60
            ),
            row(
                id: "refresh-in-progress",
                state: UsageRefreshState(isRefreshing: true),
                nowSeconds: 100,
                minimumRefreshIntervalSeconds: 60
            ),
            row(
                id: "failure-backoff",
                state: failureState,
                nowSeconds: 200,
                minimumRefreshIntervalSeconds: 0
            ),
            row(
                id: "success-reset",
                state: successState,
                nowSeconds: 261,
                minimumRefreshIntervalSeconds: 60
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testInitialStateAllowsRefresh() {
        let state = UsageRefreshState()

        XCTAssertEqual(
            state.decision(nowSeconds: 100, minimumRefreshIntervalSeconds: 60),
            UsageRefreshDecision.allowed
        )
    }

    func testMinimumIntervalBlocksRecentAttempts() {
        let state = UsageRefreshState(lastFetchAttemptSeconds: 100)

        XCTAssertEqual(
            state.decision(nowSeconds: 120, minimumRefreshIntervalSeconds: 60),
            UsageRefreshDecision.minimumIntervalActive(remainingSeconds: 40)
        )
    }

    func testRefreshInProgressBlocksRefresh() {
        let state = UsageRefreshState(isRefreshing: true)

        XCTAssertEqual(
            state.decision(nowSeconds: 100, minimumRefreshIntervalSeconds: 60),
            UsageRefreshDecision.refreshInProgress
        )
    }

    func testFailureAppliesBoundedBackoff() {
        let state = UsageRefreshState(backoffMultiplier: 7)
            .recordingFailure(nowSeconds: 100, baseBackoffSeconds: 30, maximumBackoffMultiplier: 8)

        XCTAssertEqual(state.lastFetchAttemptSeconds, 100)
        XCTAssertEqual(state.backoffMultiplier, 8)
        XCTAssertEqual(state.backoffUntilSeconds, 340)
        XCTAssertEqual(
            state.decision(nowSeconds: 200, minimumRefreshIntervalSeconds: 0),
            UsageRefreshDecision.backoffActive(remainingSeconds: 140)
        )
    }

    func testSuccessResetsBackoffAndMarksRefreshComplete() {
        let failed = UsageRefreshState(backoffMultiplier: 4, backoffUntilSeconds: 240, isRefreshing: true)
        let succeeded = failed.recordingSuccess(nowSeconds: 200)

        XCTAssertEqual(succeeded.lastFetchAttemptSeconds, 200)
        XCTAssertEqual(succeeded.lastSuccessfulFetchSeconds, 200)
        XCTAssertEqual(succeeded.backoffMultiplier, 1)
        XCTAssertNil(succeeded.backoffUntilSeconds)
        XCTAssertFalse(succeeded.isRefreshing)
        XCTAssertEqual(
            succeeded.decision(nowSeconds: 261, minimumRefreshIntervalSeconds: 60),
            UsageRefreshDecision.allowed
        )
    }

    private func row(
        id: String,
        state: UsageRefreshState,
        nowSeconds: Int,
        minimumRefreshIntervalSeconds: Int
    ) -> UsageRefreshStateMatrixRow {
        UsageRefreshStateMatrixRow(
            id: id,
            state: state,
            nowSeconds: nowSeconds,
            minimumRefreshIntervalSeconds: minimumRefreshIntervalSeconds,
            decision: state.decision(
                nowSeconds: nowSeconds,
                minimumRefreshIntervalSeconds: minimumRefreshIntervalSeconds
            )
        )
    }

    private struct UsageRefreshStateMatrixFixture: Codable, Equatable {
        let rows: [UsageRefreshStateMatrixRow]
    }

    private struct UsageRefreshStateMatrixRow: Codable, Equatable {
        let id: String
        let state: UsageRefreshState
        let nowSeconds: Int
        let minimumRefreshIntervalSeconds: Int
        let decision: UsageRefreshDecision
    }
}
