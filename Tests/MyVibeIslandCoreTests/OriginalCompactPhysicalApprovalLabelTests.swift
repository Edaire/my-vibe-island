import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactPhysicalApprovalLabelTests: XCTestCase {
    func testMissingCurrentToolReturnsNil() {
        XCTAssertNil(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .waitingForApproval,
                currentTool: nil,
                toolInput: ["skill": .string("ignored")]
            )
        )
    }

    func testMCPToolUsesOriginalCompactMCPLabel() {
        XCTAssertEqual(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .runningTool,
                currentTool: "mcp__plugin_alpha_beta__run__ignored",
                toolInput: nil
            ),
            .verbatim("beta: run")
        )
    }

    func testBareMCPPrefixUsesMCPFallbackLabel() {
        XCTAssertEqual(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .runningTool,
                currentTool: "mcp__",
                toolInput: nil
            ),
            .verbatim("MCP: mcp__")
        )
    }

    func testSkillProjectsPresentValueWithSlashPrefix() {
        XCTAssertEqual(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .processing,
                currentTool: "Skill",
                toolInput: ["skill": .array([.string("deploy"), .integer(2)])]
            ),
            .verbatim("/deploy, 2")
        )
    }

    func testSkillWithEmptyStringProjectsToSlash() {
        XCTAssertEqual(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .processing,
                currentTool: "Skill",
                toolInput: ["skill": .string("")]
            ),
            .verbatim("/")
        )
    }

    func testSkillWithNullProjectsToSlash() {
        XCTAssertEqual(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .processing,
                currentTool: "Skill",
                toolInput: ["skill": .null]
            ),
            .verbatim("/")
        )
    }

    func testSkillWithoutInputUsesToolName() {
        XCTAssertEqual(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .processing,
                currentTool: "Skill",
                toolInput: nil
            ),
            .verbatim("Skill")
        )
    }

    func testSkillWithoutSkillKeyUsesToolName() {
        XCTAssertEqual(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .processing,
                currentTool: "Skill",
                toolInput: ["other": .string("deploy")]
            ),
            .verbatim("Skill")
        )
    }

    func testOrdinaryToolUsesRawNameInsteadOfStandardVerb() {
        XCTAssertEqual(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .runningTool,
                currentTool: "Edit",
                toolInput: nil
            ),
            .verbatim("Edit")
        )
    }

    func testToolMatchingDoesNotTrimOrFoldCase() {
        XCTAssertEqual(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .runningTool,
                currentTool: " Skill ",
                toolInput: ["skill": .string("deploy")]
            ),
            .verbatim(" Skill ")
        )
        XCTAssertEqual(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .runningTool,
                currentTool: "MCP__server__tool",
                toolInput: nil
            ),
            .verbatim("MCP__server__tool")
        )
    }

    func testEveryNonApprovalStatusReturnsPreparedLabelVerbatim() {
        for status in OriginalPixelStatusCompact.allCases where status != .waitingForApproval {
            XCTAssertEqual(
                OriginalCompactPhysicalApprovalLabel.resolve(
                    status: status,
                    currentTool: "Skill",
                    toolInput: ["skill": .string("deploy")]
                ),
                .verbatim("/deploy"),
                "status: \(status)"
            )
        }
    }

    func testWaitingForApprovalReturnsLocalizedAllowPrefixWithPreparedLabel() {
        XCTAssertEqual(
            OriginalCompactPhysicalApprovalLabel.resolve(
                status: .waitingForApproval,
                currentTool: "mcp__filesystem__read_file",
                toolInput: nil
            ),
            .localized(
                key: "tool.allowPrefix",
                englishFallback: "Allow %@",
                formatArgument: "filesystem: read_file"
            )
        )
    }
}
