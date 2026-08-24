import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactRightCountTests: XCTestCase {
    func testMixedStatusesPreferActionableCount() {
        XCTAssertEqual(
            OriginalCompactRightCount.resolve(eligibleStatuses: [.processing, .question, .ended]),
            .init(count: 1, source: .actionable)
        )
    }

    func testOnlyApprovalIsActionable() {
        XCTAssertEqual(
            OriginalCompactRightCount.resolve(eligibleStatuses: [.waitingForApproval]),
            .init(count: 1, source: .actionable)
        )
    }

    func testOnlyQuestionIsActionable() {
        XCTAssertEqual(
            OriginalCompactRightCount.resolve(eligibleStatuses: [.question]),
            .init(count: 1, source: .actionable)
        )
    }

    func testStatusesWithoutActionableUseSessionCount() {
        XCTAssertEqual(
            OriginalCompactRightCount.resolve(eligibleStatuses: [.waitingForInput, .thinking, .compacting]),
            .init(count: 3, source: .sessions)
        )
    }

    func testEmptyStatusesRenderNothing() {
        XCTAssertNil(OriginalCompactRightCount.resolve(eligibleStatuses: []))
    }

    func testMultipleActionableStatusesAreSummed() {
        XCTAssertEqual(
            OriginalCompactRightCount.resolve(
                eligibleStatuses: [.waitingForApproval, .question, .question, .runningTool]
            ),
            .init(count: 3, source: .actionable)
        )
    }
}
