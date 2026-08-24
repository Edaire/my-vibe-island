import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactRightPresentationPlanTests: XCTestCase {
    func testNilRightCountRendersNothing() {
        XCTAssertEqual(
            resolve(
                rightCount: nil,
                usesCompactArrangement: true,
                showsUnreadCompletionOverview: true
            ),
            .none
        )
    }

    func testActionableCompactPlanWinsOverUnreadCompletion() {
        XCTAssertEqual(
            resolve(
                rightCount: .init(count: 2, source: .actionable),
                usesCompactArrangement: true,
                showsUnreadCompletionOverview: true
            ),
            .actionable(.init(
                countText: nil,
                foregroundColor: orange,
                backgroundColor: orangeBackground,
                symbolName: "bell.fill",
                symbolSystemSize: 9,
                countFont: nil,
                horizontalPadding: 2,
                verticalPadding: 3,
                capsuleStyle: .continuous
            ))
        )
    }

    func testActionableNormalPlanWinsOverUnreadCompletion() {
        XCTAssertEqual(
            resolve(
                rightCount: .init(count: 12, source: .actionable),
                usesCompactArrangement: false,
                showsUnreadCompletionOverview: true
            ),
            .actionable(.init(
                countText: "12",
                foregroundColor: orange,
                backgroundColor: orangeBackground,
                symbolName: "bell.fill",
                symbolSystemSize: 10,
                countFont: .init(size: 10, weight: .medium, design: .monospaced),
                horizontalPadding: 7,
                verticalPadding: 3,
                capsuleStyle: .continuous
            ))
        )
    }

    func testCompactSessionsRenderOnlySingularCount() {
        XCTAssertEqual(
            resolve(
                rightCount: .init(count: 1, source: .sessions),
                usesCompactArrangement: true
            ),
            .sessions(.init(
                countText: "1",
                countFont: sessionCountFont,
                countColor: white,
                label: nil
            ))
        )
    }

    func testCompactSessionsRenderOnlyPluralCount() {
        XCTAssertEqual(
            resolve(
                rightCount: .init(count: 4, source: .sessions),
                usesCompactArrangement: true
            ),
            .sessions(.init(
                countText: "4",
                countFont: sessionCountFont,
                countColor: white,
                label: nil
            ))
        )
    }

    func testNormalSingularSessionsIncludeLocalizedLabel() {
        XCTAssertEqual(
            resolve(rightCount: .init(count: 1, source: .sessions)),
            .sessions(.init(
                countText: "1",
                countFont: sessionCountFont,
                countColor: white,
                label: .init(
                    key: "content.session",
                    englishFallback: "session",
                    font: sessionLabelFont,
                    color: translucentWhite
                )
            ))
        )
    }

    func testNormalPluralSessionsIncludeLocalizedLabel() {
        XCTAssertEqual(
            resolve(rightCount: .init(count: 3, source: .sessions)),
            .sessions(.init(
                countText: "3",
                countFont: sessionCountFont,
                countColor: white,
                label: .init(
                    key: "content.sessions",
                    englishFallback: "sessions",
                    font: sessionLabelFont,
                    color: translucentWhite
                )
            ))
        )
    }

    func testUnreadCompletionReplacesSessions() {
        XCTAssertEqual(
            resolve(
                rightCount: .init(count: 3, source: .sessions),
                usesCompactArrangement: true,
                showsUnreadCompletionOverview: true
            ),
            .completionIndicator(.init(
                color: green,
                frame: .init(width: 7, height: 7),
                glow: .init(color: translucentGreen, radius: 3),
                transition: .init(
                    scaleAnchor: .center,
                    initialScale: 0.00001,
                    combinesOpacity: true
                )
            ))
        )
    }

    func testEveryPlanUsesCenteredHorizontalSpacingThree() {
        let plans = [
            resolve(rightCount: nil),
            resolve(rightCount: .init(count: 1, source: .actionable)),
            resolve(rightCount: .init(count: 1, source: .sessions)),
            resolve(
                rightCount: .init(count: 1, source: .sessions),
                showsUnreadCompletionOverview: true
            ),
        ]

        for plan in plans {
            XCTAssertEqual(plan.horizontalAlignment, .center)
            XCTAssertEqual(plan.horizontalSpacing, 3)
        }
    }

    private let orange = OriginalCompactRightPresentationPlan.Color(
        red: 0.98,
        green: 0.45,
        blue: 0.09,
        opacity: 1
    )
    private let green = OriginalCompactRightPresentationPlan.Color(
        red: 0.13,
        green: 0.77,
        blue: 0.37,
        opacity: 1
    )
    private let white = OriginalCompactRightPresentationPlan.Color(
        red: 1,
        green: 1,
        blue: 1,
        opacity: 1
    )
    private let orangeBackground = OriginalCompactRightPresentationPlan.Color(
        red: 0.98,
        green: 0.45,
        blue: 0.09,
        opacity: 0.2
    )
    private let translucentGreen = OriginalCompactRightPresentationPlan.Color(
        red: 0.13,
        green: 0.77,
        blue: 0.37,
        opacity: 0.6
    )
    private let translucentWhite = OriginalCompactRightPresentationPlan.Color(
        red: 1,
        green: 1,
        blue: 1,
        opacity: 0.7
    )
    private let sessionCountFont = OriginalCompactRightPresentationPlan.Font(
        size: 11,
        weight: .semibold,
        design: .monospaced
    )
    private let sessionLabelFont = OriginalCompactRightPresentationPlan.Font(
        size: 9,
        weight: .medium,
        design: .monospaced
    )

    private func resolve(
        rightCount: OriginalCompactRightCount?,
        usesCompactArrangement: Bool = false,
        showsUnreadCompletionOverview: Bool = false
    ) -> OriginalCompactRightPresentationPlan {
        OriginalCompactRightPresentationPlan.resolve(
            rightCount: rightCount,
            usesCompactArrangement: usesCompactArrangement,
            showsUnreadCompletionOverview: showsUnreadCompletionOverview
        )
    }
}
