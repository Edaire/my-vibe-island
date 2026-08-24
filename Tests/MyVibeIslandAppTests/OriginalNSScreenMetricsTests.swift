import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class OriginalNSScreenMetricsTests: XCTestCase {
    private let resolver = OriginalNSScreenMetricsResolver()

    func testCompactPhysicalSurfaceHeightMatrix() {
        let cases: [(safeTop: Double, gap: Double?, offset: Double, expected: Double)] = [
            (32, 33, 0, 33),
            (32, 32, 0, 32),
            (32, 40, 0, 32),
            (32, 33, 4, 37),
            (32, 33, -30, 8),
            (0, 30, 0, 30),
            (32, nil, 0, 32),
        ]

        for testCase in cases {
            let screenFrame = testCase.gap.map { _ in
                DisplayFrame(x: 0, y: 0, width: 1512, height: 982)
            }
            let visibleFrame = testCase.gap.map {
                DisplayFrame(x: 0, y: 0, width: 1512, height: 982 - $0)
            }
            let input = OriginalNSScreenMetricsInput(
                safeAreaTopInset: testCase.safeTop,
                frameWidth: 1512,
                auxiliaryTopLeftWidth: 663,
                auxiliaryTopRightWidth: 664,
                screenFrame: screenFrame,
                visibleFrame: visibleFrame
            )

            XCTAssertEqual(
                resolver.compactPhysicalSurfaceHeight(
                    for: input,
                    notchHeightOffset: testCase.offset
                ),
                testCase.expected,
                "safeTop=\(testCase.safeTop), gap=\(String(describing: testCase.gap)), offset=\(testCase.offset)"
            )
        }
    }

    func testNonNotchedScreenUses224Fallback() {
        let metrics = resolver.resolve(.init(
            safeAreaTopInset: 0,
            frameWidth: 1512,
            auxiliaryTopLeftWidth: 663,
            auxiliaryTopRightWidth: 664
        ))

        XCTAssertEqual(metrics.notchWidth, 224)
    }

    func testNegativeSafeAreaTopInsetUses224Fallback() {
        let metrics = resolver.resolve(.init(
            safeAreaTopInset: -1,
            frameWidth: 1512,
            auxiliaryTopLeftWidth: 663,
            auxiliaryTopRightWidth: 664
        ))

        XCTAssertEqual(metrics.notchWidth, 224)
    }

    func testCurrentNotchedScreenUsesGapBetweenAuxiliaryAreas() {
        let metrics = resolver.resolve(.init(
            safeAreaTopInset: 35,
            frameWidth: 1512,
            auxiliaryTopLeftWidth: 663,
            auxiliaryTopRightWidth: 664
        ))

        XCTAssertEqual(metrics.notchWidth, 185)
    }

    func testNotchedScreenWithoutBothPositiveAuxiliaryWidthsUses180Fallback() {
        for widths in [(0.0, 664.0), (663.0, 0.0), (-1.0, 664.0), (663.0, -1.0)] {
            let metrics = resolver.resolve(.init(
                safeAreaTopInset: 35,
                frameWidth: 1512,
                auxiliaryTopLeftWidth: widths.0,
                auxiliaryTopRightWidth: widths.1
            ))

            XCTAssertEqual(metrics.notchWidth, 180)
        }
    }
}
