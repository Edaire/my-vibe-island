import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactConversationMessageNormalizerTests: XCTestCase {
    func testOrdinaryMessageIsReturnedUnchanged() {
        XCTAssertEqual(resolve("ordinary message"), "ordinary message")
    }

    func testOrdinaryMessageWhitespaceIsReturnedUnchanged() {
        XCTAssertEqual(resolve(" \nordinary message\t "), " \nordinary message\t ")
    }

    func testUnicodeLeadingWhitespaceIsSkippedOnlyForPrefixDetection() {
        let input = "\u{2003}\u{3000}codex_desktop_thread</session_state> message "

        XCTAssertEqual(resolve(input), "message")
    }

    func testMatchingPrefixWithoutClosingTagReturnsNil() {
        XCTAssertNil(resolve("codex_desktop_thread message"))
    }

    func testEachSupportedClosingTagReturnsItsTrimmedSuffix() {
        for tag in [
            "</session_state>",
            "</sources>",
            "</workspace_capabilities>",
            "</working_directory>",
            "</working_directory_context>",
        ] {
            XCTAssertEqual(resolve("codex_desktop_thread metadata\(tag) message "), "message", tag)
        }
    }

    func testRepeatedTagUsesLastOccurrence() {
        XCTAssertEqual(
            resolve("codex_desktop_thread</sources> first </sources> final"),
            "final"
        )
    }

    func testMultipleTagsUseGreatestUpperBound() {
        XCTAssertEqual(
            resolve("codex_desktop_thread</working_directory_context> first </session_state> final"),
            "final"
        )
    }

    func testContentBeforeClosingTagIsIgnored() {
        XCTAssertEqual(
            resolve("codex_desktop_thread arbitrary content before tag </sources> message"),
            "message"
        )
    }

    func testOnlySuffixIsTrimmed() {
        XCTAssertEqual(
            resolve("  codex_desktop_thread metadata </session_state> \n\t message body \t\n "),
            "message body"
        )
    }

    func testEmptyTrimmedSuffixReturnsSomeEmptyString() {
        XCTAssertEqual(resolve("codex_desktop_thread</sources> \n\t "), "")
    }

    func testPrefixMatchIsCaseSensitive() {
        let input = "Codex_desktop_thread</sources> message "

        XCTAssertEqual(resolve(input), input)
    }

    func testClosingTagMatchIsCaseSensitive() {
        XCTAssertNil(resolve("codex_desktop_thread</SOURCES> message"))
    }

    private func resolve(_ input: String) -> String? {
        OriginalCompactConversationMessageNormalizer.resolve(input)
    }
}
