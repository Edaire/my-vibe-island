import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactPhysicalTitlePlanTests: XCTestCase {
    func testDefaultResolutionCoversEveryStatus() {
        let expected: [OriginalPixelStatusCompact: OriginalCompactTitlePlan] = [
            .thinking: localized("tool.thinkingEllipsis", "Thinking..."),
            .compacting: localized("status.compacting", "Compacting"),
            .processing: localized("tool.workingEllipsis", "Working..."),
            .runningTool: localized("tool.workingEllipsis", "Working..."),
            .waitingForApproval: verbatim("Unknown", transform: .physicalCompact),
            .waitingForInput: verbatim("Unknown", transform: .physicalCompact),
            .question: verbatim("Unknown", transform: .physicalCompact),
            .ended: verbatim("Unknown", transform: .physicalCompact),
            .unknown: verbatim("Unknown", transform: .physicalCompact),
        ]

        XCTAssertEqual(Set(expected.keys), Set(OriginalPixelStatusCompact.allCases))
        for status in OriginalPixelStatusCompact.allCases {
            XCTAssertEqual(resolve(status: status), expected[status], "status: \(status)")
        }
    }

    func testCurrentToolResolutionPreservesLocalizedAndVerbatimContent() {
        XCTAssertEqual(
            resolve(status: .processing, currentTool: "Read"),
            localized("tool.reading", "Reading", transform: .physicalCompact)
        )
        XCTAssertEqual(
            resolve(status: .runningTool, currentTool: "Deploy"),
            verbatim("Deploy", transform: .physicalCompact)
        )
    }

    func testPhysicalTransformIsDeferredForLongCurrentToolTitle() {
        let longTool = "abcdefghijklmnopqrstuvwxyz"
        let plan = resolve(status: .processing, currentTool: longTool)

        XCTAssertEqual(plan.content, .verbatim(longTool))
        XCTAssertEqual(plan.transform, .physicalCompact)
    }

    func testWorkingTitleIsNeverAssignedPhysicalTruncation() {
        for status in [OriginalPixelStatusCompact.processing, .runningTool] {
            let plan = resolve(status: status)

            XCTAssertEqual(plan.content, .localized(
                key: "tool.workingEllipsis",
                englishFallback: "Working...",
                formatArgument: nil
            ))
            XCTAssertEqual(plan.transform, .none)
        }
    }

    func testWaitingForApprovalPreservesLocalizedFormatArgument() {
        XCTAssertEqual(
            resolve(
                status: .waitingForApproval,
                currentTool: "Skill",
                toolInput: ["skill": .string("release")]
            ),
            localized(
                "tool.allowPrefix",
                "Allow %@",
                argument: "/release",
                transform: .physicalCompact
            )
        )
    }

    func testWaitingForApprovalWithoutToolUsesActiveWorkThenSessionFallback() {
        XCTAssertEqual(
            resolve(
                status: .waitingForApproval,
                tasks: [activeTask(subject: "Ship", activeForm: "Shipping")],
                repoName: "Repo"
            ),
            verbatim("Shipping", transform: .physicalCompact)
        )
        XCTAssertEqual(
            resolve(status: .waitingForApproval, repoName: "Repo"),
            verbatim("Repo", transform: .physicalCompact)
        )
    }

    func testConversationStatusesUseTaskTodoAndSessionFallbackPriority() {
        XCTAssertEqual(
            resolve(
                status: .waitingForInput,
                tasks: [activeTask(subject: "Task subject", activeForm: nil)],
                todos: [activeTodo("Doing todo")],
                repoName: "Repo"
            ),
            verbatim("Task subject", transform: .physicalCompact)
        )
        XCTAssertEqual(
            resolve(status: .question, todos: [activeTodo("Doing todo")], repoName: "Repo"),
            verbatim("Doing todo", transform: .physicalCompact)
        )
        XCTAssertEqual(
            resolve(status: .ended, cwd: "/tmp/Project"),
            verbatim("Project", transform: .physicalCompact)
        )
        XCTAssertEqual(
            resolve(status: .unknown, source: "cursor"),
            verbatim("Cursor", transform: .physicalCompact)
        )
    }

    func testPhysicalFallbackTitleIsNotTruncatedBeforeLocalizationStage() {
        let longTitle = "12345678901234567890123456"
        let plan = resolve(
            status: .waitingForInput,
            tasks: [activeTask(subject: longTitle, activeForm: nil)]
        )

        XCTAssertEqual(plan.content, .verbatim(longTitle))
        XCTAssertEqual(plan.transform, .physicalCompact)
    }

    private func resolve(
        status: OriginalPixelStatusCompact,
        currentTool: String? = nil,
        toolInput: [String: BridgeJSONValue]? = nil,
        tasks: [TaskItem] = [],
        todos: [TodoItem] = [],
        repoName: String? = nil,
        cwd: String? = nil,
        source: String? = nil
    ) -> OriginalCompactTitlePlan {
        OriginalCompactPhysicalTitlePlan.resolve(
            status: status,
            currentTool: currentTool,
            toolInput: toolInput,
            tasks: tasks,
            todos: todos,
            repoName: repoName,
            cwd: cwd,
            source: source
        )
    }

    private func localized(
        _ key: String,
        _ englishFallback: String,
        argument: String? = nil,
        transform: OriginalCompactTitlePlan.PostLocalizationTransform = .none
    ) -> OriginalCompactTitlePlan {
        OriginalCompactTitlePlan(
            content: .localized(
                key: key,
                englishFallback: englishFallback,
                formatArgument: argument
            ),
            transform: transform
        )
    }

    private func verbatim(
        _ title: String,
        transform: OriginalCompactTitlePlan.PostLocalizationTransform = .none
    ) -> OriginalCompactTitlePlan {
        OriginalCompactTitlePlan(content: .verbatim(title), transform: transform)
    }

    private func activeTask(subject: String, activeForm: String?) -> TaskItem {
        TaskItem(id: "task", subject: subject, status: .active, activeForm: activeForm)
    }

    private func activeTodo(_ activeForm: String) -> TodoItem {
        TodoItem(id: "todo", content: "Todo", status: .active, activeForm: activeForm)
    }
}
