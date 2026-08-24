import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactPhysicalCurrentToolLabelTests: XCTestCase {
    func testMCPToolUsesAcceptedLabelVerbatim() {
        XCTAssertEqual(
            OriginalCompactPhysicalCurrentToolLabel.resolve(
                currentTool: "mcp__filesystem__read_file",
                toolInput: ["skill": .string("ignored")]
            ),
            .verbatim("filesystem: read_file")
        )
    }

    func testMalformedMCPToolUsesAcceptedFallbackVerbatim() {
        XCTAssertEqual(
            OriginalCompactPhysicalCurrentToolLabel.resolve(
                currentTool: "mcp__",
                toolInput: nil
            ),
            .verbatim("MCP: mcp__")
        )
    }

    func testUppercaseMCPPrefixIsNotRecognized() {
        XCTAssertEqual(
            OriginalCompactPhysicalCurrentToolLabel.resolve(
                currentTool: "MCP__filesystem__read_file",
                toolInput: nil
            ),
            .verbatim("MCP__filesystem__read_file")
        )
    }

    func testSkillProjectsPresentValue() {
        XCTAssertEqual(
            OriginalCompactPhysicalCurrentToolLabel.resolve(
                currentTool: "Skill",
                toolInput: ["skill": .array([.string("review"), .integer(2)])]
            ),
            .verbatim("Skill: review, 2")
        )
    }

    func testSkillAcceptsEmptyProjection() {
        XCTAssertEqual(
            OriginalCompactPhysicalCurrentToolLabel.resolve(
                currentTool: "Skill",
                toolInput: ["skill": .string("")]
            ),
            .verbatim("Skill: ")
        )
    }

    func testSkillAcceptsNullProjection() {
        XCTAssertEqual(
            OriginalCompactPhysicalCurrentToolLabel.resolve(
                currentTool: "Skill",
                toolInput: ["skill": .null]
            ),
            .verbatim("Skill: ")
        )
    }

    func testSkillWithoutSkillKeyUsesRunningSkillLocalization() {
        XCTAssertEqual(
            OriginalCompactPhysicalCurrentToolLabel.resolve(
                currentTool: "Skill",
                toolInput: ["other": .string("review")]
            ),
            .localized(key: "tool.runningSkill", englishFallback: "Running Skill")
        )
    }

    func testSkillWithNilInputUsesRunningSkillLocalization() {
        XCTAssertEqual(
            OriginalCompactPhysicalCurrentToolLabel.resolve(
                currentTool: "Skill",
                toolInput: nil
            ),
            .localized(key: "tool.runningSkill", englishFallback: "Running Skill")
        )
    }

    func testSkillInputKeyIsCaseSensitive() {
        XCTAssertEqual(
            OriginalCompactPhysicalCurrentToolLabel.resolve(
                currentTool: "Skill",
                toolInput: ["Skill": .string("review")]
            ),
            .localized(key: "tool.runningSkill", englishFallback: "Running Skill")
        )
    }

    func testSkillToolNameIsCaseSensitive() {
        XCTAssertEqual(
            OriginalCompactPhysicalCurrentToolLabel.resolve(
                currentTool: "skill",
                toolInput: ["skill": .string("review")]
            ),
            .verbatim("skill")
        )
    }

    func testStandardToolsReuseAcceptedToolVerb() {
        let tools = [
            "Edit", "Read", "Write", "Bash", "Grep", "Glob", "Task", "WebFetch", "WebSearch",
        ]

        for tool in tools {
            XCTAssertEqual(
                OriginalCompactPhysicalCurrentToolLabel.resolve(
                    currentTool: tool,
                    toolInput: ["skill": .string("ignored")]
                ),
                OriginalCompactToolVerb.resolve(tool),
                tool
            )
        }
    }

    func testUnknownToolIsReturnedUnchanged() {
        XCTAssertEqual(
            OriginalCompactPhysicalCurrentToolLabel.resolve(
                currentTool: "  CustomTool  ",
                toolInput: nil
            ),
            .verbatim("  CustomTool  ")
        )
    }
}
