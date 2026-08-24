import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactToolDetailTests: XCTestCase {
    func testNilToolInputReturnsTargetDirectly() {
        XCTAssertEqual(
            OriginalCompactToolDetail.resolve(
                currentTool: "Bash",
                toolInput: nil,
                toolTarget: "target"
            ),
            "target"
        )
        XCTAssertNil(
            OriginalCompactToolDetail.resolve(
                currentTool: nil,
                toolInput: nil,
                toolTarget: nil
            )
        )
    }

    func testBashProjectsCommandAndTruncatesAfterThirtyCharacters() {
        XCTAssertEqual(resolve(tool: "Bash", input: ["command": .integer(42)]), "42")
        XCTAssertEqual(
            resolve(tool: "Bash", input: ["command": .string(String(repeating: "a", count: 30))]),
            String(repeating: "a", count: 30)
        )
        XCTAssertEqual(
            resolve(tool: "Bash", input: ["command": .string(String(repeating: "a", count: 31))]),
            String(repeating: "a", count: 30) + "..."
        )
    }

    func testWebSearchProjectsQueryAndTruncatesAfterThirtyFiveCharacters() {
        XCTAssertEqual(resolve(tool: "WebSearch", input: ["query": .bool(true)]), "true")
        XCTAssertEqual(
            resolve(tool: "WebSearch", input: ["query": .string(String(repeating: "q", count: 35))]),
            String(repeating: "q", count: 35)
        )
        XCTAssertEqual(
            resolve(tool: "WebSearch", input: ["query": .string(String(repeating: "q", count: 36))]),
            String(repeating: "q", count: 35) + "..."
        )
    }

    func testWebFetchUsesOnlyHostAndNonRootPath() {
        XCTAssertEqual(
            resolve(
                tool: "WebFetch",
                input: ["url": .string("https://example.com:8443/docs/page?q=swift#section")]
            ),
            "example.com/docs/page"
        )
        XCTAssertEqual(
            resolve(tool: "WebFetch", input: ["url": .string("https://example.com/")]),
            "example.com"
        )
    }

    func testWebFetchHandlesHostlessAndQueryOnlyURLs() {
        XCTAssertEqual(
            resolve(tool: "WebFetch", input: ["url": .string("file:///tmp/report.txt")]),
            "/tmp/report.txt"
        )
        XCTAssertEqual(
            resolve(tool: "WebFetch", input: ["url": .string("?query=ignored")]),
            ""
        )
    }

    func testWebFetchFallsBackToOriginalProjectionWhenURLIsInvalid() {
        let invalid = "http://exa mple.com/" + String(repeating: "x", count: 40)

        XCTAssertEqual(
            resolve(tool: "WebFetch", input: ["url": .string(invalid)]),
            String(invalid.prefix(35)) + "..."
        )
    }

    func testWebFetchTruncatesResolvedHostAndPathAfterThirtyFiveCharacters() {
        let detail = "example.com/" + String(repeating: "p", count: 30)

        XCTAssertEqual(
            resolve(tool: "WebFetch", input: ["url": .string("https://\(detail)")]),
            String(detail.prefix(35)) + "..."
        )
    }

    func testSkillPrefixesProjectedValueWithoutTruncation() {
        let value = String(repeating: "s", count: 50)

        XCTAssertEqual(resolve(tool: "Skill", input: ["skill": .string(value)]), "/" + value)
        XCTAssertEqual(
            resolve(tool: "Skill", input: ["skill": .array([.string("one"), .integer(2)])]),
            "/one, 2"
        )
    }

    func testDedicatedKeysWithEmptyProjectionRemainValidResults() {
        XCTAssertEqual(resolve(tool: "Bash", input: ["command": .null, "pattern": .string("fallback")]), "")
        XCTAssertEqual(resolve(tool: "WebSearch", input: ["query": .string(""), "pattern": .string("fallback")]), "")
        XCTAssertEqual(resolve(tool: "WebFetch", input: ["url": .null, "pattern": .string("fallback")]), "")
        XCTAssertEqual(resolve(tool: "Skill", input: ["skill": .string(""), "pattern": .string("fallback")]), "/")
    }

    func testMissingDedicatedKeysUseGenericFallback() {
        for tool in ["Bash", "WebSearch", "WebFetch", "Skill"] {
            XCTAssertEqual(
                resolve(tool: tool, input: ["pattern": .string("fallback")], target: "target"),
                "fallback",
                tool
            )
        }
    }

    func testGenericKeysUseFilePathPathPatternAndTargetPriority() {
        XCTAssertEqual(
            resolve(
                tool: "Custom",
                input: [
                    "file_path": .string("/tmp/first/file.swift"),
                    "path": .string("/tmp/second/path.swift"),
                    "pattern": .string("pattern"),
                ],
                target: "target"
            ),
            "file.swift"
        )
        XCTAssertEqual(
            resolve(
                tool: nil,
                input: ["path": .string("/tmp/folder/"), "pattern": .string("pattern")],
                target: "target"
            ),
            "folder"
        )
        XCTAssertEqual(
            resolve(tool: "Custom", input: ["pattern": .string("pattern")], target: "target"),
            "pattern"
        )
        XCTAssertEqual(resolve(tool: "Custom", input: [:], target: "target"), "target")
        XCTAssertNil(resolve(tool: "Custom", input: [:], target: nil))
    }

    func testPresentEmptyGenericKeyDoesNotContinueFallback() {
        XCTAssertEqual(
            resolve(
                tool: "Custom",
                input: ["file_path": .null, "path": .string("/tmp/path.swift")],
                target: "target"
            ),
            ""
        )
        XCTAssertEqual(
            resolve(
                tool: "Custom",
                input: ["path": .string(""), "pattern": .string("pattern")],
                target: "target"
            ),
            ""
        )
        XCTAssertEqual(
            resolve(tool: "Custom", input: ["pattern": .null], target: "target"),
            ""
        )
    }

    func testTruncationCountsExtendedGraphemeClusters() {
        let thirtyEmoji = String(repeating: "👩🏽‍💻", count: 30)
        let thirtyFiveEmoji = String(repeating: "👩🏽‍💻", count: 35)

        XCTAssertEqual(resolve(tool: "Bash", input: ["command": .string(thirtyEmoji + "x")]), thirtyEmoji + "...")
        XCTAssertEqual(resolve(tool: "WebSearch", input: ["query": .string(thirtyFiveEmoji + "x")]), thirtyFiveEmoji + "...")
    }

    func testToolMatchingIsCaseSensitiveAndDoesNotTrimWhitespace() {
        let input: [String: BridgeJSONValue] = [
            "command": .string("special"),
            "pattern": .string("generic"),
        ]

        XCTAssertEqual(resolve(tool: "bash", input: input), "generic")
        XCTAssertEqual(resolve(tool: " Bash", input: input), "generic")
    }

    private func resolve(
        tool: String?,
        input: [String: BridgeJSONValue],
        target: String? = nil
    ) -> String? {
        OriginalCompactToolDetail.resolve(
            currentTool: tool,
            toolInput: input,
            toolTarget: target
        )
    }
}
