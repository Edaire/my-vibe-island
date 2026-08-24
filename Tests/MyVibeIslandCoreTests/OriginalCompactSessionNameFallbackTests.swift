import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactSessionNameFallbackTests: XCTestCase {
    func testNonEmptyRepoNameTakesPriorityWithoutModification() {
        XCTAssertEqual(
            OriginalCompactSessionNameFallback.resolve(
                repoName: "  My Repo  ",
                cwd: "/ignored/path",
                source: "cursor"
            ),
            "  My Repo  "
        )
    }

    func testEmptyRepoNameFallsBackToCwd() {
        XCTAssertEqual(
            OriginalCompactSessionNameFallback.resolve(
                repoName: "",
                cwd: "/work/project",
                source: "cursor"
            ),
            "project"
        )
    }

    func testCwdUsesNSStringLastPathComponent() {
        XCTAssertEqual(
            OriginalCompactSessionNameFallback.resolve(
                repoName: nil,
                cwd: "/Users/example/my-project",
                source: nil
            ),
            "my-project"
        )
    }

    func testRootCwdReturnsRootPathComponent() {
        XCTAssertEqual(
            OriginalCompactSessionNameFallback.resolve(
                repoName: nil,
                cwd: "/",
                source: "cursor"
            ),
            "/"
        )
    }

    func testTrailingSlashCwdReturnsLastPathComponent() {
        XCTAssertEqual(
            OriginalCompactSessionNameFallback.resolve(
                repoName: nil,
                cwd: "/Users/example/my-project/",
                source: nil
            ),
            "my-project"
        )
    }

    func testEmptyCwdReturnsEmptyStringWithoutSourceFallback() {
        XCTAssertEqual(
            OriginalCompactSessionNameFallback.resolve(
                repoName: nil,
                cwd: "",
                source: "cursor"
            ),
            ""
        )
    }

    func testExactLowercaseCursorSourceReturnsCursor() {
        XCTAssertEqual(
            OriginalCompactSessionNameFallback.resolve(
                repoName: nil,
                cwd: nil,
                source: "cursor"
            ),
            "Cursor"
        )
    }

    func testCapitalizedCursorSourceReturnsUnknown() {
        XCTAssertEqual(
            OriginalCompactSessionNameFallback.resolve(
                repoName: nil,
                cwd: nil,
                source: "Cursor"
            ),
            "Unknown"
        )
    }

    func testWhitespaceSourceReturnsUnknown() {
        XCTAssertEqual(
            OriginalCompactSessionNameFallback.resolve(
                repoName: nil,
                cwd: nil,
                source: "   "
            ),
            "Unknown"
        )
    }

    func testOtherSourceReturnsUnknown() {
        XCTAssertEqual(
            OriginalCompactSessionNameFallback.resolve(
                repoName: nil,
                cwd: nil,
                source: "codex"
            ),
            "Unknown"
        )
    }

    func testNilSourceReturnsUnknown() {
        XCTAssertEqual(
            OriginalCompactSessionNameFallback.resolve(
                repoName: nil,
                cwd: nil,
                source: nil
            ),
            "Unknown"
        )
    }
}
