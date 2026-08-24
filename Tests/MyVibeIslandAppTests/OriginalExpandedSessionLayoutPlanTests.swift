import XCTest
@testable import MyVibeIslandApp

final class OriginalExpandedSessionLayoutPlanTests: XCTestCase {
    func testOriginalExpandedSessionMetrics() {
        let plan = OriginalExpandedSessionLayoutPlan.original

        XCTAssertEqual(plan.statusWidth, 43)
        XCTAssertEqual(plan.statusHeight, 20)
        XCTAssertEqual(plan.columnSpacing, 8)
        XCTAssertEqual(plan.contentSpacing, 4)
        XCTAssertEqual(plan.controlFrame, 24)
        XCTAssertEqual(plan.controlGlyph, 14)
        XCTAssertEqual(plan.controlSpacing, 8)
        XCTAssertEqual(plan.defaultContentFontSize, 11)
        XCTAssertEqual(plan.defaultCompletionMaximumHeight, 90)
    }
}
