import XCTest
@testable import MyVibeIslandApp

@MainActor
final class OriginalSwitcherSurfaceViewTests: XCTestCase {
    func testNilHighlightProducesNoScrollDecision() {
        XCTAssertEqual(
            OriginalSessionsListScrollDecision.resolve(highlightedID: nil),
            .none
        )
    }

    func testHighlightedIDScrollsToCenterWithAcceptedEaseOutDuration() {
        XCTAssertEqual(
            OriginalSessionsListScrollDecision.resolve(highlightedID: "session-2"),
            .center(id: "session-2", duration: 0.18)
        )
    }
}
