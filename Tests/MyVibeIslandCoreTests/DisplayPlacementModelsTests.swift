import XCTest
@testable import MyVibeIslandCore

final class DisplayPlacementModelsTests: XCTestCase {
    func testVisiblePlacementUsesOneFixedPanelFrameForEveryIslandState() {
        let plan = DisplayPlacementResolver().resolve(DisplayPlacementInput(
            screenFrame: DisplayFrame(x: 100, y: 50, width: 1920, height: 1080),
            closedSize: DisplaySize(width: 220, height: 36),
            expandedSize: DisplaySize(width: 640, height: 420)
        ))

        let expected = DisplayFrame(x: 720, y: 550, width: 680, height: 580)
        XCTAssertEqual(plan.closedFrame, expected)
        XCTAssertEqual(plan.expandedFrame, expected)
    }

    func testDisplayPlacementMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DisplayPlacementMatrixFixture.self,
            from: try FixtureLoader.data("settings/display-placement-matrix")
        )
        let resolver = DisplayPlacementResolver()
        let cases = [
            DisplayPlacementCase(
                name: "default-safe-area-centered",
                input: DisplayPlacementInput(
                    screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
                    safeAreaTopInset: 24,
                    closedSize: DisplaySize(width: 220, height: 36),
                    expandedSize: DisplaySize(width: 640, height: 420)
                )
            ),
            DisplayPlacementCase(
                name: "clamped-expanded-panel",
                input: DisplayPlacementInput(
                    screenFrame: DisplayFrame(x: 100, y: 50, width: 500, height: 600),
                    safeAreaTopInset: 10,
                    closedSize: DisplaySize(width: 180, height: 32),
                    expandedSize: DisplaySize(width: 900, height: 700),
                    maximumExpandedSize: DisplaySize(width: 720, height: 520),
                    horizontalMargin: 24,
                    verticalMargin: 32
                )
            ),
            DisplayPlacementCase(
                name: "fullscreen-hidden",
                input: DisplayPlacementInput(
                    screenFrame: DisplayFrame(x: 0, y: 0, width: 1200, height: 800),
                    closedSize: DisplaySize(width: 200, height: 36),
                    expandedSize: DisplaySize(width: 600, height: 400),
                    hideInFullscreen: true,
                    activeAppIsFullscreen: true
                )
            ),
            DisplayPlacementCase(
                name: "fullscreen-blocking-action-visible",
                input: DisplayPlacementInput(
                    screenFrame: DisplayFrame(x: 0, y: 0, width: 1200, height: 800),
                    closedSize: DisplaySize(width: 200, height: 36),
                    expandedSize: DisplaySize(width: 600, height: 400),
                    hideInFullscreen: true,
                    activeAppIsFullscreen: true,
                    blockingActionVisible: true
                )
            ),
            DisplayPlacementCase(
                name: "onboarding-fullscreen",
                input: DisplayPlacementInput(
                    screenFrame: DisplayFrame(x: 0, y: 0, width: 1200, height: 800),
                    closedSize: DisplaySize(width: 200, height: 36),
                    expandedSize: DisplaySize(width: 600, height: 400),
                    onboardingFullscreenActive: true
                )
            )
        ].map { testCase in
            DisplayPlacementCase(
                name: testCase.name,
                input: testCase.input,
                plan: resolver.resolve(testCase.input)
            )
        }

        XCTAssertEqual(cases, expected.cases)
    }

    func testClosedPillIsCenteredBelowSafeArea() {
        let resolver = DisplayPlacementResolver()
        let input = DisplayPlacementInput(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
            safeAreaTopInset: 24,
            closedSize: DisplaySize(width: 220, height: 36),
            expandedSize: DisplaySize(width: 640, height: 420)
        )

        let plan = resolver.resolve(input)

        XCTAssertEqual(plan.closedFrame, DisplayFrame(x: 416, y: 402, width: 680, height: 580))
        XCTAssertEqual(plan.anchor, DisplayPoint(x: 756, y: 982))
        XCTAssertEqual(plan.safeAreaAdjustment, 24)
        XCTAssertNil(plan.collapseReason)
    }

    func testFixedPanelRemainsCenteredEvenWhenScreenIsNarrower() {
        let resolver = DisplayPlacementResolver()
        let input = DisplayPlacementInput(
            screenFrame: DisplayFrame(x: 100, y: 50, width: 500, height: 600),
            safeAreaTopInset: 10,
            closedSize: DisplaySize(width: 180, height: 32),
            expandedSize: DisplaySize(width: 900, height: 700),
            maximumExpandedSize: DisplaySize(width: 720, height: 520),
            horizontalMargin: 24,
            verticalMargin: 32
        )

        let plan = resolver.resolve(input)

        XCTAssertEqual(plan.expandedFrame, DisplayFrame(x: 10, y: 70, width: 680, height: 580))
        XCTAssertEqual(plan.anchor, DisplayPoint(x: 350, y: 650))
    }

    func testFullscreenHiddenCollapsesFramesUnlessBlockingActionIsVisible() {
        let resolver = DisplayPlacementResolver()
        let base = DisplayPlacementInput(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1200, height: 800),
            closedSize: DisplaySize(width: 200, height: 36),
            expandedSize: DisplaySize(width: 600, height: 400),
            hideInFullscreen: true,
            activeAppIsFullscreen: true
        )

        let hidden = resolver.resolve(base)
        XCTAssertEqual(hidden.closedFrame, .zero)
        XCTAssertEqual(hidden.expandedFrame, .zero)
        XCTAssertEqual(hidden.collapseReason, .fullscreenHidden)

        let visible = resolver.resolve(base.replacing(blockingActionVisible: true))
        XCTAssertNotEqual(visible.closedFrame, .zero)
        XCTAssertNil(visible.collapseReason)
    }

    func testOnboardingFullscreenOwnsVisibility() {
        let resolver = DisplayPlacementResolver()
        let input = DisplayPlacementInput(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1200, height: 800),
            closedSize: DisplaySize(width: 200, height: 36),
            expandedSize: DisplaySize(width: 600, height: 400),
            onboardingFullscreenActive: true
        )

        let plan = resolver.resolve(input)

        XCTAssertEqual(plan.collapseReason, .onboardingFullscreen)
        XCTAssertEqual(plan.closedFrame, .zero)
    }

    func testPlacementPlanRoundTripsThroughJSON() throws {
        let plan = DisplayPlacementPlan(
            closedFrame: DisplayFrame(x: 10, y: 20, width: 30, height: 40),
            expandedFrame: DisplayFrame(x: 1, y: 2, width: 3, height: 4),
            anchor: DisplayPoint(x: 25, y: 20),
            safeAreaAdjustment: 12,
            collapseReason: .fullscreenHidden
        )

        let decoded = try JSONDecoder().decode(
            DisplayPlacementPlan.self,
            from: try JSONEncoder().encode(plan)
        )

        XCTAssertEqual(decoded, plan)
    }

    private struct DisplayPlacementMatrixFixture: Codable, Equatable {
        let cases: [DisplayPlacementCase]
    }

    private struct DisplayPlacementCase: Codable, Equatable {
        let name: String
        let input: DisplayPlacementInput
        let plan: DisplayPlacementPlan?

        init(name: String, input: DisplayPlacementInput, plan: DisplayPlacementPlan? = nil) {
            self.name = name
            self.input = input
            self.plan = plan
        }
    }
}
