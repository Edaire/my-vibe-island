import XCTest
@testable import MyVibeIslandCore

final class SwitcherRuntimeStateTests: XCTestCase {
    func testOpenPreservesSessionOrderAndHighlightsExistingID() {
        var state = SwitcherRuntimeState()

        state.open(sessionIDs: ["first", "second", "third"], highlightedID: "second")

        XCTAssertEqual(state.sessionIDs, ["first", "second", "third"])
        XCTAssertEqual(state.highlightedID, "second")
        XCTAssertTrue(state.isOpen)
    }

    func testDuplicateSessionIDsRemainOrderedAndNavigateByOccurrenceIndex() {
        var state = SwitcherRuntimeState()

        state.open(sessionIDs: ["same", "middle", "same"], highlightedID: "same")

        XCTAssertEqual(state.sessionIDs, ["same", "middle", "same"])
        XCTAssertEqual(state.highlightedIndex, 0)
        XCTAssertEqual(state.navigate(.up), "same")
        XCTAssertEqual(state.highlightedIndex, 2)
        XCTAssertEqual(state.navigate(.down), "same")
        XCTAssertEqual(state.highlightedIndex, 0)
    }

    func testOpenFallsBackToFirstSessionWhenHighlightIsMissing() {
        var state = SwitcherRuntimeState()

        state.open(sessionIDs: ["first", "second"], highlightedID: "missing")

        XCTAssertEqual(state.highlightedID, "first")
    }

    func testNavigateDownAndUpWrapInAcceptedOrder() {
        var state = SwitcherRuntimeState()
        state.open(sessionIDs: ["first", "second", "third"], highlightedID: "third")

        XCTAssertEqual(state.navigate(.down), "first")
        XCTAssertEqual(state.navigate(.up), "third")
    }

    func testReverseNavigationReversesDirection() {
        var state = SwitcherRuntimeState()
        state.open(sessionIDs: ["first", "second", "third"], highlightedID: "first")

        XCTAssertEqual(state.navigate(.down, reversed: true), "third")
        XCTAssertEqual(state.navigate(.up, reversed: true), "first")
    }

    func testEnterReturnsExactHighlightedIDAndCollapses() {
        var state = SwitcherRuntimeState()
        state.open(sessionIDs: ["session-exact"], highlightedID: "session-exact")

        XCTAssertEqual(state.selectHighlighted(), "session-exact")
        XCTAssertFalse(state.isOpen)
        XCTAssertNil(state.highlightedID)
    }

    func testModifierReleaseAndOutsideInteractionCollapseWithoutSelection() {
        var state = SwitcherRuntimeState()
        state.open(sessionIDs: ["session"], highlightedID: "session")

        state.collapseForModifierRelease()
        XCTAssertFalse(state.isOpen)

        state.open(sessionIDs: ["session"], highlightedID: "session")
        state.collapseForOutsideInteraction()
        XCTAssertFalse(state.isOpen)
        XCTAssertNil(state.selectHighlighted())
    }

    func testEmptySwitcherDoesNotJumpOrNavigate() {
        var state = SwitcherRuntimeState()

        state.open(sessionIDs: [], highlightedID: "ignored")

        XCTAssertNil(state.highlightedID)
        XCTAssertNil(state.navigate(.down))
        XCTAssertNil(state.selectHighlighted())
        XCTAssertFalse(state.isOpen)
    }
}
