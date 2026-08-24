import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactTitlePlanTests: XCTestCase {
    func testLocalizedContentPreservesAllFieldsAndDefaultsToNoTransform() {
        let plan = OriginalCompactTitlePlan(
            content: .localized(
                key: "compact.sessions",
                englishFallback: "%@ sessions",
                formatArgument: "3"
            )
        )

        guard case let .localized(key, englishFallback, formatArgument) = plan.content else {
            return XCTFail("Expected localized content")
        }

        XCTAssertEqual(key, "compact.sessions")
        XCTAssertEqual(englishFallback, "%@ sessions")
        XCTAssertEqual(formatArgument, "3")
        XCTAssertEqual(plan.transform, .none)
    }

    func testLocalizedContentAcceptsNilFormatArgument() {
        XCTAssertEqual(
            OriginalCompactTitlePlan.Content.localized(
                key: "compact.ready",
                englishFallback: "Ready",
                formatArgument: nil
            ),
            .localized(
                key: "compact.ready",
                englishFallback: "Ready",
                formatArgument: nil
            )
        )
    }

    func testVerbatimContentAndExplicitTransformArePreserved() {
        let plan = OriginalCompactTitlePlan(
            content: .verbatim("Exact title"),
            transform: .physicalCompact
        )

        XCTAssertEqual(plan.content, .verbatim("Exact title"))
        XCTAssertEqual(plan.transform, .physicalCompact)
    }

    func testModelsAreSendable() async {
        let plan = OriginalCompactTitlePlan(
            content: .localized(
                key: "compact.sessions",
                englishFallback: "%@ sessions",
                formatArgument: "3"
            ),
            transform: .physicalCompact
        )

        let transferred = await Task { @Sendable in plan }.value

        XCTAssertEqual(transferred, plan)
    }

    func testNoneReturnsConcreteStringUnchanged() {
        XCTAssertEqual(
            OriginalCompactTitlePlan.PostLocalizationTransform.none.apply(to: "abcdefghijklmnopqrstuvwxyz"),
            "abcdefghijklmnopqrstuvwxyz"
        )
    }

    func testPhysicalCompactLeavesZeroCharactersUnchanged() {
        XCTAssertEqual(
            OriginalCompactTitlePlan.PostLocalizationTransform.physicalCompact.apply(to: ""),
            ""
        )
    }

    func testPhysicalCompactLeavesTwentyTwoCharactersUnchanged() {
        let concrete = String(repeating: "a", count: 22)

        XCTAssertEqual(
            OriginalCompactTitlePlan.PostLocalizationTransform.physicalCompact.apply(to: concrete),
            concrete
        )
    }

    func testPhysicalCompactLeavesTwentyFiveCharactersUnchanged() {
        let concrete = String(repeating: "a", count: 25)

        XCTAssertEqual(
            OriginalCompactTitlePlan.PostLocalizationTransform.physicalCompact.apply(to: concrete),
            concrete
        )
    }

    func testPhysicalCompactTruncatesTwentySixCharactersToTwentyTwoPlusEllipsis() {
        XCTAssertEqual(
            OriginalCompactTitlePlan.PostLocalizationTransform.physicalCompact.apply(
                to: "abcdefghijklmnopqrstuvwxyz"
            ),
            "abcdefghijklmnopqrstuv..."
        )
    }

    func testPhysicalCompactTruncatesLongStringToTwentyTwoPlusEllipsis() {
        XCTAssertEqual(
            OriginalCompactTitlePlan.PostLocalizationTransform.physicalCompact.apply(
                to: "The quick brown fox jumps over the lazy dog"
            ),
            "The quick brown fox ju..."
        )
    }

    func testPhysicalCompactCountsExtendedGraphemeClustersAsCharacters() {
        let concrete = String(repeating: "👨‍👩‍👧‍👦", count: 25) + "e\u{301}"

        XCTAssertEqual(concrete.count, 26)
        XCTAssertEqual(
            OriginalCompactTitlePlan.PostLocalizationTransform.physicalCompact.apply(to: concrete),
            String(repeating: "👨‍👩‍👧‍👦", count: 22) + "..."
        )
    }
}
