import XCTest
@testable import MyVibeIslandCore

final class ZaiQuotaConfigStateTests: XCTestCase {
    func testZaiQuotaConfigStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ZaiQuotaConfigStateMatrixFixture.self,
            from: try FixtureLoader.data("usage/zai-quota-config-state-matrix")
        )

        let actual = ZaiQuotaConfigStateMatrixFixture(rows: [
            ZaiQuotaConfigStateMatrixRow(id: "default", state: ZaiQuotaConfigState()),
            ZaiQuotaConfigStateMatrixRow(
                id: "mark-available",
                state: ZaiQuotaConfigState().markingChecked(availability: .available)
            ),
            ZaiQuotaConfigStateMatrixRow(
                id: "mark-unavailable",
                state: ZaiQuotaConfigState().markingChecked(availability: .unavailable)
            ),
            ZaiQuotaConfigStateMatrixRow(
                id: "reset",
                state: ZaiQuotaConfigState(configChecked: true, cachedConfigAvailability: .unavailable)
                    .resettingCheck()
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testDefaultStateIsUncheckedWithUnknownAvailability() {
        let state = ZaiQuotaConfigState()

        XCTAssertFalse(state.configChecked)
        XCTAssertEqual(state.cachedConfigAvailability, .unknown)
    }

    func testMarkingCheckedStoresOnlyAvailability() {
        let state = ZaiQuotaConfigState()

        let checked = state.markingChecked(availability: .available)

        XCTAssertTrue(checked.configChecked)
        XCTAssertEqual(checked.cachedConfigAvailability, .available)
    }

    func testResettingCheckClearsAvailabilityToUnknown() {
        let state = ZaiQuotaConfigState(configChecked: true, cachedConfigAvailability: .unavailable)

        let reset = state.resettingCheck()

        XCTAssertFalse(reset.configChecked)
        XCTAssertEqual(reset.cachedConfigAvailability, .unknown)
    }

    func testStateRoundTripsThroughJSON() throws {
        let state = ZaiQuotaConfigState(configChecked: true, cachedConfigAvailability: .unavailable)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ZaiQuotaConfigState.self, from: data)

        XCTAssertEqual(decoded, state)
    }
}

private struct ZaiQuotaConfigStateMatrixFixture: Codable, Equatable {
    let rows: [ZaiQuotaConfigStateMatrixRow]
}

private struct ZaiQuotaConfigStateMatrixRow: Codable, Equatable {
    let id: String
    let configChecked: Bool
    let cachedConfigAvailability: ZaiQuotaConfigState.Availability

    init(id: String, state: ZaiQuotaConfigState) {
        self.id = id
        self.configChecked = state.configChecked
        self.cachedConfigAvailability = state.cachedConfigAvailability
    }
}
