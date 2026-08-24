import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class OriginalExpandedVerticalDescriptorTests: XCTestCase {
    func testVerticalDescriptorKeepsOnlyTypedProvenContentAndExcludesGuessedChrome() {
        let row = OriginalExpandedSessionRow(
            preview: SessionCardPreview(session: AgentSession(
                id: "session-1",
                source: "codex",
                cwd: "/tmp/project",
                safeTitle: "Project",
                originalStatus: .processing,
                tasks: [TaskItem(id: "task", subject: "Build", status: .active)],
                todos: [TodoItem(id: "todo", content: "Review", status: .pending)],
                subagents: [SubagentState(id: "child", source: "codex", parentSessionId: "session-1")],
                hasUnreadCompletion: true
            )),
            status: .processing,
            taskSummary: "1/1 active tasks",
            todoSummary: "1 todos",
            childAgentSummary: "1 subagents"
        )
        let descriptor = OriginalExpandedVerticalBodyDescriptor.resolve(row: row)

        XCTAssertEqual(descriptor.status, .processing)
        XCTAssertEqual(descriptor.displayTitle, "Project")
        XCTAssertEqual(descriptor.taskSummary, "1/1 active tasks")
        XCTAssertEqual(descriptor.todoSummary, "1 todos")
        XCTAssertEqual(descriptor.childAgentSummary, "1 subagents")
        XCTAssertTrue(descriptor.hasUnreadCompletion)
        XCTAssertFalse(descriptor.rendersIdentityTag)
        XCTAssertFalse(descriptor.rendersAge)
        XCTAssertFalse(descriptor.rendersContextMenu)
        XCTAssertFalse(descriptor.rendersUsageHeader)
        XCTAssertFalse(descriptor.rendersEmptyState)
    }

    func testVerticalDescriptorDropsEmptyTypedSummaries() {
        let row = OriginalExpandedSessionRow(
            preview: SessionCardPreview(session: AgentSession(
                id: "session-1",
                source: "codex",
                cwd: "/tmp/project"
            )),
            taskSummary: "",
            todoSummary: "   ",
            childAgentSummary: "\n"
        )

        let descriptor = OriginalExpandedVerticalBodyDescriptor.resolve(row: row)

        XCTAssertNil(descriptor.taskSummary)
        XCTAssertNil(descriptor.todoSummary)
        XCTAssertNil(descriptor.childAgentSummary)
    }

    func testVerticalDescriptorUsesFirstUserMessageWhenNoStableTitleExists() {
        let row = OriginalExpandedSessionRow(session: AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            firstUserMessage: "Old session request",
            lastUserMessage: "Latest session request"
        ))

        XCTAssertEqual(
            OriginalExpandedVerticalBodyDescriptor.resolve(row: row).displayTitle,
            "Old session request"
        )
    }

    func testVerticalDescriptorExposesAuthoritativeConversationAndWorkContent() {
        let tasks = [TaskItem(id: "task", subject: "Implement", status: .active)]
        let todos = [TodoItem(id: "todo", content: "Verify", status: .pending)]
        let subagents = [SubagentState(id: "child", source: "codex", parentSessionId: "session-1")]
        let row = OriginalExpandedSessionRow(session: AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activitySummary: "Codex is running a tool.",
            safeTitle: "Session title",
            originalStatus: .runningTool,
            lastAssistantMessage: "Focused tests passed.",
            currentCommandPreview: "swift test --filter SessionTests",
            firstUserMessage: "Initial request",
            lastUserMessage: "Latest request",
            tasks: tasks,
            todos: todos,
            subagents: subagents,
            questionPrompt: "Continue?"
        ))

        let descriptor = OriginalExpandedVerticalBodyDescriptor.resolve(row: row)

        XCTAssertEqual(descriptor.latestPrompt, "Latest request")
        XCTAssertEqual(descriptor.activityToolLabel, "Bash")
        XCTAssertEqual(descriptor.activityContent, "swift test --filter SessionTests")
        XCTAssertEqual(descriptor.activityLine, "swift test --filter SessionTests")
        XCTAssertTrue(descriptor.activityLineIsCommand)
        XCTAssertEqual(descriptor.assistantMessage, "Focused tests passed.")
        XCTAssertEqual(descriptor.questionPrompt, "Continue?")
        XCTAssertEqual(descriptor.taskItems, tasks)
        XCTAssertEqual(descriptor.todoItems, todos)
        XCTAssertEqual(descriptor.childAgentItems, subagents)
    }

    func testVerticalDescriptorUsesPreviousAssistantOutputWhenWorkingHasNoCommand() {
        let row = OriginalExpandedSessionRow(session: AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activeTool: "exec_command",
            activitySummary: "Codex is working.",
            originalStatus: .runningTool,
            lastAssistantMessage: "swift test --filter OriginalExpandedSessionCardParityTests"
        ))

        let descriptor = OriginalExpandedVerticalBodyDescriptor.resolve(row: row)

        XCTAssertEqual(descriptor.activityToolLabel, "Bash")
        XCTAssertEqual(
            descriptor.activityContent,
            "swift test --filter OriginalExpandedSessionCardParityTests"
        )
    }

    func testVerticalDescriptorSuppressesSyntheticActivityPlaceholder() {
        let row = OriginalExpandedSessionRow(session: AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activitySummary: "Codex is working.",
            originalStatus: .processing
        ))

        let descriptor = OriginalExpandedVerticalBodyDescriptor.resolve(row: row)

        XCTAssertNil(descriptor.activityContent)
        XCTAssertNil(descriptor.activityLine)
    }

    func testVerticalDescriptorUsesAssistantMessageWhenActivitySummaryIsSynthetic() {
        let row = OriginalExpandedSessionRow(session: AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activitySummary: "Codex is running a tool.",
            originalStatus: .runningTool,
            lastAssistantMessage: "This should not drive the activity content"
        ))

        let descriptor = OriginalExpandedVerticalBodyDescriptor.resolve(row: row)

        XCTAssertEqual(descriptor.activityContent, "This should not drive the activity content")
    }

    func testVerticalDescriptorUsesLastAssistantMessageBeforeActivitySummaryForActivityLine() {
        let row = OriginalExpandedSessionRow(session: AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activitySummary: "Codex is working.",
            originalStatus: .runningTool,
            lastAssistantMessage: "swift test --filter OriginalExpandedSessionCardParityTests"
        ))

        let descriptor = OriginalExpandedVerticalBodyDescriptor.resolve(row: row)

        XCTAssertEqual(descriptor.activityLine, "swift test --filter OriginalExpandedSessionCardParityTests")
    }

    func testCompletedDescriptorDoesNotProjectAssistantOutputAsActivityLine() {
        let row = OriginalExpandedSessionRow(
            session: AgentSession(
                id: "completed-session",
                source: "codex",
                cwd: "/tmp/project",
                activitySummary: "Codex completed the turn.",
                originalStatus: .ended,
                lastAssistantMessage: "The implementation is complete."
            ),
            status: .ended
        )

        let descriptor = OriginalExpandedVerticalBodyDescriptor.resolve(row: row)

        XCTAssertNil(descriptor.activityToolLabel)
        XCTAssertNil(descriptor.activityContent)
        XCTAssertNil(descriptor.activityLine)
        XCTAssertEqual(descriptor.assistantMessage, "The implementation is complete.")
    }

    func testVerticalDescriptorProjectsPassiveCoworkQuestionDetailsWithoutActionableRequest() {
        let input: [String: BridgeJSONValue] = [
            "questions": .array([
                .object([
                    "header": .string("Parser"),
                    "question": .string("Which parser?"),
                    "options": .array([
                        .object([
                            "label": .string("SwiftSyntax"),
                            "description": .string("Use the Swift parser")
                        ]),
                        .object([
                            "label": .string("Tree-sitter"),
                            "description": .string("Use the generic parser")
                        ])
                    ])
                ])
            ])
        ]
        let row = OriginalExpandedSessionRow(session: AgentSession(
            id: "cowork-question",
            source: "claude",
            cwd: "/tmp/project",
            activeTool: "AskUserQuestion",
            toolInput: input,
            questionPrompt: "Which parser?"
        ))

        let descriptor = OriginalExpandedVerticalBodyDescriptor.resolve(row: row)

        XCTAssertEqual(descriptor.passiveQuestionDetails?.questions.count, 1)
        XCTAssertEqual(descriptor.passiveQuestionDetails?.questions.first?.header, "Parser")
        XCTAssertEqual(
            descriptor.passiveQuestionDetails?.questions.first?.options.map(\.label),
            ["SwiftSyntax", "Tree-sitter"]
        )
    }

    func testVerticalDescriptorExposesApprovalWithoutReplacingSessionTitle() {
        let request = ActionableRequest(
            requestId: "approval",
            sessionId: "session-1",
            source: "codex",
            kind: .permission,
            toolName: "exec"
        )
        let row = OriginalExpandedSessionRow(session: AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            safeTitle: "Stable title",
            actionableRequests: [request]
        ))

        let descriptor = OriginalExpandedVerticalBodyDescriptor.resolve(row: row)

        XCTAssertEqual(descriptor.displayTitle, "Stable title")
        XCTAssertEqual(descriptor.approvalSummary, "exec approval required")
    }
}
