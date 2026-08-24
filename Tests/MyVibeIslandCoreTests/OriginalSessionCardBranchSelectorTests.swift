import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalSessionCardBranchSelectorTests: XCTestCase {
    func testNormalListWriterCollapsesOnlyTheRecoveredEligibleWarningRow() {
        XCTAssertEqual(
            OriginalSessionCardBranchSelector.resolve(
                derivedCollectionCount: 4,
                manuallyExpanded: false,
                statusWarning: true,
                isFirst: false,
                dateAtOffset24: Date(timeIntervalSince1970: 99),
                now: Date(timeIntervalSince1970: 1_000),
                isCompletionPreview: false
            ),
            .horizontal
        )
    }

    func testNormalListWriterKeepsIneligibleRowsExpanded() {
        XCTAssertEqual(
            OriginalSessionCardBranchSelector.resolve(
                derivedCollectionCount: 4,
                manuallyExpanded: false,
                statusWarning: true,
                isFirst: false,
                dateAtOffset24: Date(timeIntervalSince1970: 100),
                now: Date(timeIntervalSince1970: 1_000),
                isCompletionPreview: false
            ),
            .vertical
        )
    }

    func testCompletionPreviewForcesTheExpandedBranchEvenWhenNormalWriterWouldCollapse() {
        XCTAssertEqual(
            OriginalSessionCardBranchSelector.resolve(
                derivedCollectionCount: 4,
                manuallyExpanded: false,
                statusWarning: true,
                isFirst: false,
                dateAtOffset24: Date(timeIntervalSince1970: 99),
                now: Date(timeIntervalSince1970: 1_000),
                isCompletionPreview: true
            ),
            .vertical
        )
    }
}
