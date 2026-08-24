import XCTest
@testable import MyVibeIslandCore

final class OriginalIslandPresentationStateTests: XCTestCase {
    func testApplicationStatesProjectOntoThreeOriginalGeometryRoles() {
        let expected: [(PanelDisplayState, OriginalIslandDisplayState)] = [
            (.closed, .compact),
            (.opening, .compact),
            (.hidden, .compact),
            (.autoHidden, .compact),
            (.notificationPeek, .peek),
            (.expanded, .expanded),
            (.switcher, .expanded),
            (.onboarding, .expanded),
        ]

        for (state, role) in expected {
            XCTAssertEqual(OriginalIslandPresentationState(state).geometryRole, role)
            XCTAssertEqual(OriginalIslandPresentationState(state).contentReason, state)
        }
    }
}
