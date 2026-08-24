import MyVibeIslandCore
@testable import MyVibeIslandApp
import XCTest

final class OriginalRootAnimationContractTests: XCTestCase {
    func testRootHoverUsesTheV3SpringContract() {
        XCTAssertEqual(
            OriginalRootAnimationContract.rootHoverSpring,
            .init(response: 0.25, dampingFraction: 0.7)
        )
    }

    func testExpandedDisplayStatusUsesExpandedGeometrySpring() {
        let contract = OriginalRootAnimationContract.resolve(
            displayState: .expanded,
            fittingWidth: 640,
            fittingHeight: 212,
            visibleSurfaceHeight: 212
        )

        XCTAssertEqual(contract.displayStatusTarget, .expanded)
        XCTAssertEqual(contract.displayStatusCurve, .expanded)
        XCTAssertEqual(contract.expandedWidthTarget, 640)
        XCTAssertEqual(contract.expandedHeightTarget, 212)
        XCTAssertEqual(contract.visibleSurfaceHeightTarget, 212)
    }

    func testClosedAndPeekDisplayStatusUseTheNonExpandedGeometrySpring() {
        let closed = OriginalRootAnimationContract.resolve(
            displayState: .compact,
            fittingWidth: 176,
            fittingHeight: 42,
            visibleSurfaceHeight: 42
        )
        let peek = OriginalRootAnimationContract.resolve(
            displayState: .peek,
            fittingWidth: 264,
            fittingHeight: 80,
            visibleSurfaceHeight: 80
        )

        XCTAssertEqual(closed.displayStatusTarget, .compact)
        XCTAssertEqual(peek.displayStatusTarget, .peek)
        XCTAssertEqual(closed.displayStatusCurve, .nonExpanded)
        XCTAssertEqual(peek.displayStatusCurve, .nonExpanded)
    }

}
