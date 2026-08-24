import XCTest
@testable import MyVibeIslandCore

final class NotchContentDimensionsRegressionTests: XCTestCase {
    func testContentDimensionsPreservePlacementSizesAndSelectActiveDisplaySize() {
        let placement = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 636, y: 949, width: 239, height: 33),
            expandedFrame: DisplayFrame(x: 436, y: 562, width: 640, height: 420),
            anchor: DisplayPoint(x: 756, y: 982),
            safeAreaAdjustment: 32
        )
        let closed = NotchContentDimensions(placementPlan: placement, displayStatus: .closed)
        let expanded = NotchContentDimensions(placementPlan: placement, displayStatus: .expanded)

        XCTAssertEqual(closed.closedSize, DisplaySize(width: 239, height: 33))
        XCTAssertEqual(closed.expandedSize, DisplaySize(width: 640, height: 420))
        XCTAssertEqual(closed.activeContentSize, closed.closedSize)
        XCTAssertEqual(expanded.closedSize, closed.closedSize)
        XCTAssertEqual(expanded.expandedSize, closed.expandedSize)
        XCTAssertEqual(expanded.activeContentSize, expanded.expandedSize)
    }
}
