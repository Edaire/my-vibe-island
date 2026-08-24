import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactToolVerbTests: XCTestCase {
    func testStandardToolNamesResolveToLocalizedVerbs() {
        let cases: [(tool: String, key: String, fallback: String)] = [
            ("Edit", "tool.editing", "Editing"),
            ("Read", "tool.reading", "Reading"),
            ("Write", "tool.writing", "Writing"),
            ("Bash", "tool.running", "Running"),
            ("Grep", "tool.searching", "Searching"),
            ("Glob", "tool.finding", "Finding"),
            ("Task", "tool.tasking", "Tasking"),
            ("WebFetch", "tool.fetching", "Fetching"),
            ("WebSearch", "tool.searching", "Searching"),
        ]

        for item in cases {
            XCTAssertEqual(
                OriginalCompactToolVerb.resolve(item.tool),
                .localized(key: item.key, englishFallback: item.fallback),
                item.tool
            )
        }
    }

    func testUnknownToolIsReturnedVerbatim() {
        XCTAssertEqual(
            OriginalCompactToolVerb.resolve("CustomTool"),
            .verbatim("CustomTool")
        )
    }

    func testEmptyToolIsReturnedVerbatim() {
        XCTAssertEqual(OriginalCompactToolVerb.resolve(""), .verbatim(""))
    }

    func testCaseVariantsAreNotNormalized() {
        XCTAssertEqual(OriginalCompactToolVerb.resolve("edit"), .verbatim("edit"))
        XCTAssertEqual(OriginalCompactToolVerb.resolve("EDIT"), .verbatim("EDIT"))
    }

    func testWhitespaceIsNotTrimmed() {
        XCTAssertEqual(OriginalCompactToolVerb.resolve(" Edit"), .verbatim(" Edit"))
        XCTAssertEqual(OriginalCompactToolVerb.resolve("Edit "), .verbatim("Edit "))
    }
}
