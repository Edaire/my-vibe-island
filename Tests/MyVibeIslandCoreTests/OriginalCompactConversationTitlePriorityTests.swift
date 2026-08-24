import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactConversationTitlePriorityTests: XCTestCase {
    func testCustomTitleHasHighestPriority() {
        XCTAssertEqual(
            resolve(
                customTitle: "Custom",
                desktopTitle: "Desktop",
                aiTitle: "AI",
                summary: "Summary",
                normalizedFirstUserMessage: "First",
                normalizedLastUserMessage: "Last"
            ),
            "Custom"
        )
    }

    func testDesktopTitleIsSecondPriority() {
        XCTAssertEqual(
            resolve(
                customTitle: nil,
                desktopTitle: "Desktop",
                aiTitle: "AI",
                summary: "Summary",
                normalizedFirstUserMessage: "First",
                normalizedLastUserMessage: "Last"
            ),
            "Desktop"
        )
    }

    func testAITitleIsThirdPriority() {
        XCTAssertEqual(
            resolve(
                customTitle: "",
                desktopTitle: nil,
                aiTitle: "AI",
                summary: "Summary",
                normalizedFirstUserMessage: "First",
                normalizedLastUserMessage: "Last"
            ),
            "AI"
        )
    }

    func testSummaryIsFourthPriority() {
        XCTAssertEqual(
            resolve(
                customTitle: nil,
                desktopTitle: "",
                aiTitle: nil,
                summary: "Summary",
                normalizedFirstUserMessage: "First",
                normalizedLastUserMessage: "Last"
            ),
            "Summary"
        )
    }

    func testNormalizedFirstUserMessageIsFifthPriority() {
        XCTAssertEqual(
            resolve(
                customTitle: "",
                desktopTitle: nil,
                aiTitle: "",
                summary: nil,
                normalizedFirstUserMessage: "First",
                normalizedLastUserMessage: "Last"
            ),
            "First"
        )
    }

    func testNormalizedLastUserMessageIsFinalPriority() {
        XCTAssertEqual(
            resolve(
                customTitle: nil,
                desktopTitle: "",
                aiTitle: nil,
                summary: "",
                normalizedFirstUserMessage: nil,
                normalizedLastUserMessage: "Last"
            ),
            "Last"
        )
    }

    func testWhitespaceOnlyStringIsReturnedWithoutTrimming() {
        XCTAssertEqual(
            resolve(
                customTitle: " \n ",
                desktopTitle: "Desktop",
                aiTitle: nil,
                summary: nil,
                normalizedFirstUserMessage: nil,
                normalizedLastUserMessage: nil
            ),
            " \n "
        )
    }

    func testAllNilAndEmptyValuesReturnNil() {
        XCTAssertNil(
            resolve(
                customTitle: nil,
                desktopTitle: "",
                aiTitle: nil,
                summary: "",
                normalizedFirstUserMessage: nil,
                normalizedLastUserMessage: ""
            )
        )
    }

    func testUnicodeStringCountsAsNonEmptyAndIsReturnedUnchanged() {
        XCTAssertEqual(
            resolve(
                customTitle: nil,
                desktopTitle: nil,
                aiTitle: "👩🏽‍💻",
                summary: nil,
                normalizedFirstUserMessage: nil,
                normalizedLastUserMessage: nil
            ),
            "👩🏽‍💻"
        )
    }

    private func resolve(
        customTitle: String?,
        desktopTitle: String?,
        aiTitle: String?,
        summary: String?,
        normalizedFirstUserMessage: String?,
        normalizedLastUserMessage: String?
    ) -> String? {
        OriginalCompactConversationTitlePriority.resolve(
            customTitle: customTitle,
            desktopTitle: desktopTitle,
            aiTitle: aiTitle,
            summary: summary,
            normalizedFirstUserMessage: normalizedFirstUserMessage,
            normalizedLastUserMessage: normalizedLastUserMessage
        )
    }
}
