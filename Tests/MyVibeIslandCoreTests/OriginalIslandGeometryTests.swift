import XCTest
@testable import MyVibeIslandCore

final class OriginalIslandGeometryTests: XCTestCase {
    func testExpandedWidthLeavesTheV3FortyPointScreenMargin() {
        let geometry = OriginalIslandGeometryResolver().resolve(
            OriginalIslandGeometryInput(
                screenFrame: DisplayFrame(x: 0, y: 0, width: 680, height: 900),
                visibleFrame: DisplayFrame(x: 0, y: 0, width: 680, height: 876),
                displayState: .expanded,
                compactIntrinsicWidth: 120,
                maxExpandedWidth: 700
            )
        )

        XCTAssertEqual(geometry.surfaceFrame.width, 640)
    }

    private let resolver = OriginalIslandGeometryResolver()

    func testFixedPanelIsCenteredAtScreenTop() {
        let geometry = resolver.resolve(.init(
            screenFrame: DisplayFrame(x: 100, y: 50, width: 1920, height: 1080),
            visibleFrame: DisplayFrame(x: 100, y: 50, width: 1920, height: 1056),
            displayState: .compact,
            compactIntrinsicWidth: 180
        ))

        XCTAssertEqual(geometry.panelFrame, DisplayFrame(x: 720, y: 550, width: 680, height: 580))
    }

    func testNonNotchedCompactUsesIntrinsicWidthAndMenuBarHeight() {
        let geometry = resolver.resolve(.init(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1056),
            displayState: .compact,
            compactIntrinsicWidth: 176
        ))

        XCTAssertEqual(geometry.surfaceSize, DisplaySize(width: 176, height: 24))
        XCTAssertEqual(geometry.surfaceFrame, DisplayFrame(x: 252, y: 556, width: 176, height: 24))
    }

    func testNotchedCompactUsesPhysicalNotchAndStatusSlots() {
        let geometry = resolver.resolve(.init(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 947),
            safeAreaTopInset: 35,
            auxiliaryNotchGap: 182,
            displayState: .compact,
            compactIntrinsicWidth: 120,
            leftStatusSlotWidth: 36,
            rightStatusSlotWidth: 36
        ))

        XCTAssertEqual(geometry.surfaceSize, DisplaySize(width: 254, height: 35))
    }

    func testPeekAddsRecoveredWidthAndHeight() {
        let geometry = resolver.resolve(.init(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1056),
            displayState: .peek,
            compactIntrinsicWidth: 176
        ))

        XCTAssertEqual(geometry.surfaceSize, DisplaySize(width: 264, height: 62))
    }

    func testExpandedClampsMeasuredContentToRecoveredMaxima() {
        let geometry = resolver.resolve(.init(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1056),
            displayState: .expanded,
            compactIntrinsicWidth: 100,
            measuredContentHeight: 700
        ))

        XCTAssertEqual(geometry.surfaceSize, DisplaySize(width: 640, height: 560))
    }

    func testExpandedFallbackHeightsMatchRecoveredCases() {
        XCTAssertEqual(resolveFallback(sessionCount: 0), 124)
        XCTAssertEqual(resolveFallback(sessionCount: 1, focusedSpecialSession: true), 160)
        XCTAssertEqual(resolveFallback(sessionCount: 1), 160)
        XCTAssertEqual(resolveFallback(sessionCount: 3), 400)
        XCTAssertEqual(resolveFallback(sessionCount: 8), 520)
    }

    private func resolveFallback(
        sessionCount: Int,
        focusedSpecialSession: Bool = false
    ) -> Double {
        resolver.resolve(.init(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1056),
            displayState: .expanded,
            compactIntrinsicWidth: 100,
            measuredContentHeight: 0,
            sessionCount: sessionCount,
            focusedSpecialSession: focusedSpecialSession
        )).surfaceSize.height
    }
}
