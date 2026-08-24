import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactNonNotchedTitlePlanTests: XCTestCase {
    func testThinkingUsesNonNotchedOverrideWithToolTargetIncludingEmptyString() {
        XCTAssertEqual(
            resolve(status: .thinking, toolTarget: "Investigating"),
            localized("tool.thinkingDetail", "Thinking: %@", argument: "Investigating")
        )
        XCTAssertEqual(
            resolve(status: .thinking, toolTarget: ""),
            localized("tool.thinkingDetail", "Thinking: %@", argument: "")
        )
        XCTAssertEqual(
            resolve(status: .thinking),
            localized("tool.thinkingEllipsis", "Thinking...", argument: nil)
        )
    }

    func testCompactingUsesNonNotchedOverride() {
        XCTAssertEqual(
            resolve(status: .compacting, toolTarget: "ignored"),
            localized("status.compacting", "Compacting", argument: nil)
        )
    }

    func testProcessingUsesRawCurrentToolAndResolvedToolDetail() {
        XCTAssertEqual(
            resolve(
                status: .processing,
                currentTool: "Bash",
                toolInput: ["command": .string("swift test")],
                toolTarget: "ignored"
            ),
            verbatim("Bash: swift test")
        )
    }

    func testRunningToolUsesRawCurrentToolWithoutDetailWhenDetailIsNil() {
        XCTAssertEqual(
            resolve(status: .runningTool, currentTool: "mcp__server__tool"),
            verbatim("mcp__server__tool")
        )
    }

    func testComposedToolTitleIsNotTruncatedAsAWhole() {
        let tool = String(repeating: "T", count: 31)
        let target = String(repeating: "d", count: 30)

        XCTAssertEqual(
            resolve(status: .runningTool, currentTool: tool, toolTarget: target),
            verbatim("\(tool): \(target)")
        )
    }

    func testCurrentToolWithEmptyResolvedDetailStillAppendsColon() {
        XCTAssertEqual(
            resolve(
                status: .processing,
                currentTool: "",
                toolInput: [:],
                toolTarget: ""
            ),
            verbatim(": ")
        )
    }

    func testProcessingWithoutCurrentToolUsesToolTargetAndOnlyTruncatesPastThirtyCharacters() {
        let character = "👩🏽‍💻"
        let thirty = String(repeating: character, count: 30)
        let thirtyOne = thirty + "界"

        XCTAssertEqual(resolve(status: .processing, toolTarget: thirty), verbatim(thirty))
        XCTAssertEqual(resolve(status: .runningTool, toolTarget: thirtyOne), verbatim(thirty + "..."))
        XCTAssertEqual(resolve(status: .processing, toolTarget: ""), verbatim(""))
    }

    func testProcessingWithoutToolOrTargetUsesWorkingLocalization() {
        XCTAssertEqual(
            resolve(status: .processing),
            localized("tool.workingEllipsis", "Working...", argument: nil)
        )
        XCTAssertEqual(
            resolve(status: .runningTool),
            localized("tool.workingEllipsis", "Working...", argument: nil)
        )
    }

    func testWaitingForApprovalWithCurrentToolUsesSameRawToolAndDetailRule() {
        XCTAssertEqual(
            resolve(
                status: .waitingForApproval,
                currentTool: "Read",
                toolInput: ["file_path": .string("/tmp/Plan.swift")]
            ),
            verbatim("Read: Plan.swift")
        )
    }

    func testConversationPriorityIsUsedAcrossConversationStatuses() {
        XCTAssertEqual(resolve(status: .waitingForApproval, customTitle: "Custom"), verbatim("Custom"))
        XCTAssertEqual(resolve(status: .waitingForInput, desktopTitle: "Desktop"), verbatim("Desktop"))
        XCTAssertEqual(resolve(status: .question, aiTitle: "AI"), verbatim("AI"))
        XCTAssertEqual(resolve(status: .ended, summary: "Summary"), verbatim("Summary"))
        XCTAssertEqual(
            resolve(status: .unknown, normalizedFirstUserMessage: "First"),
            verbatim("First")
        )
        XCTAssertEqual(
            resolve(status: .waitingForInput, normalizedLastUserMessage: "Last"),
            verbatim("Last")
        )
    }

    func testConversationPrioritySkipsEmptyValuesWithoutNormalizingMessages() {
        XCTAssertEqual(
            resolve(
                status: .question,
                customTitle: "",
                desktopTitle: "",
                aiTitle: "",
                summary: "",
                normalizedFirstUserMessage: "  exact message  ",
                normalizedLastUserMessage: "Last"
            ),
            verbatim("  exact message  ")
        )
    }

    func testSessionNameFallbackIsUsedWhenConversationTitleIsUnavailable() {
        XCTAssertEqual(resolve(status: .waitingForApproval, repoName: "Repo"), verbatim("Repo"))
        XCTAssertEqual(resolve(status: .waitingForInput, cwd: "/tmp/Project"), verbatim("Project"))
        XCTAssertEqual(resolve(status: .question, source: "cursor"), verbatim("Cursor"))
        XCTAssertEqual(resolve(status: .ended), verbatim("Unknown"))
        XCTAssertEqual(resolve(status: .unknown, repoName: "", cwd: ""), verbatim(""))
    }

    func testEveryStatusReturnsNoPostLocalizationTransform() {
        for status in OriginalPixelStatusCompact.allCases {
            XCTAssertEqual(resolve(status: status).transform, .none, "status: \(status)")
        }
    }

    private func resolve(
        status: OriginalPixelStatusCompact,
        currentTool: String? = nil,
        toolInput: [String: BridgeJSONValue]? = nil,
        toolTarget: String? = nil,
        repoName: String? = nil,
        cwd: String? = nil,
        source: String? = nil,
        customTitle: String? = nil,
        desktopTitle: String? = nil,
        aiTitle: String? = nil,
        summary: String? = nil,
        normalizedFirstUserMessage: String? = nil,
        normalizedLastUserMessage: String? = nil
    ) -> OriginalCompactTitlePlan {
        OriginalCompactNonNotchedTitlePlan.resolve(
            status: status,
            currentTool: currentTool,
            toolInput: toolInput,
            toolTarget: toolTarget,
            repoName: repoName,
            cwd: cwd,
            source: source,
            customTitle: customTitle,
            desktopTitle: desktopTitle,
            aiTitle: aiTitle,
            summary: summary,
            normalizedFirstUserMessage: normalizedFirstUserMessage,
            normalizedLastUserMessage: normalizedLastUserMessage
        )
    }

    private func localized(
        _ key: String,
        _ englishFallback: String,
        argument: String?
    ) -> OriginalCompactTitlePlan {
        OriginalCompactTitlePlan(
            content: .localized(
                key: key,
                englishFallback: englishFallback,
                formatArgument: argument
            )
        )
    }

    private func verbatim(_ title: String) -> OriginalCompactTitlePlan {
        OriginalCompactTitlePlan(content: .verbatim(title))
    }
}
