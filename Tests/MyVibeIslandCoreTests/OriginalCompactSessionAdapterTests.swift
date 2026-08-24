import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactSessionAdapterTests: XCTestCase {
    func testMapsEveryAuthoritativeFieldDirectly() {
        let tasks = [TaskItem(id: "task-1", subject: "Implement", status: .active)]
        let todos = [TodoItem(id: "todo-1", content: "Verify", status: .pending)]
        let toolInput: [String: BridgeJSONValue] = [
            "command": .string("swift test"),
            "count": .integer(2),
            "ratio": .number(1.5),
        ]
        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/my-vibe-island",
            activeTool: "Bash",
            originalStatus: .runningTool,
            toolInput: toolInput,
            toolTarget: "Tests",
            lastAssistantMessage: "Focused tests passed.",
            currentCommandPreview: "swift test --filter SessionTests",
            repoName: "my-vibe-island",
            customTitle: "Custom",
            desktopTitle: "Desktop",
            aiTitle: "AI",
            summary: "Summary",
            firstUserMessage: "First",
            lastUserMessage: "Last",
            tasks: tasks,
            todos: todos
        )

        XCTAssertEqual(
            OriginalCompactSessionAdapter.resolve(session),
            OriginalCompactContentPlan.SessionInput(
                status: .runningTool,
                currentTool: "Bash",
                toolInput: toolInput,
                toolTarget: "Tests",
                lastAssistantMessage: "Focused tests passed.",
                currentCommandPreview: "swift test --filter SessionTests",
                activitySummary: nil,
                tasks: tasks,
                todos: todos,
                repoName: "my-vibe-island",
                cwd: "/tmp/my-vibe-island",
                source: "codex",
                customTitle: "Custom",
                desktopTitle: "Desktop",
                aiTitle: "AI",
                summary: "Summary",
                firstUserMessage: "First",
                lastUserMessage: "Last"
            )
        )
    }

    func testCompactPlanKeepsCommandAndLatestActivitySeparateFromTitle() {
        let input = OriginalCompactSessionAdapter.resolve(AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activeTool: "exec",
            activitySummary: "Codex is running a tool.",
            originalStatus: .runningTool,
            currentCommandPreview: "swift test --filter SessionTests"
        ))

        let plan = OriginalCompactContentPlan.resolve(displayClass: .physicalNotch, sessions: [input])

        XCTAssertEqual(plan.activityLine, "swift test --filter SessionTests")
        XCTAssertEqual(input.activitySummary, "Codex is running a tool.")
    }

    func testUsesOnlyDocumentedCompatibilityFallbacks() {
        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activitySummary: "Compatibility summary",
            safeTitle: "Compatibility title"
        )

        let input = OriginalCompactSessionAdapter.resolve(session)

        XCTAssertEqual(input.status, .waitingForInput)
        XCTAssertEqual(input.customTitle, "Compatibility title")
        XCTAssertEqual(input.summary, "Compatibility summary")
    }

    func testDoesNotParseStructuredValuesFromRenderedStrings() {
        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activeTool: "Bash: swift test",
            activitySummary: #"toolInput={"command":"swift test"} target=Tests"#,
            safeTitle: "3/4 active tasks"
        )

        let input = OriginalCompactSessionAdapter.resolve(session)

        XCTAssertEqual(input.currentTool, "Bash: swift test")
        XCTAssertNil(input.toolInput)
        XCTAssertNil(input.toolTarget)
        XCTAssertNil(input.repoName)
        XCTAssertEqual(input.customTitle, "3/4 active tasks")
        XCTAssertEqual(input.summary, #"toolInput={"command":"swift test"} target=Tests"#)
    }

    func testCodableRoundTripPreservesOriginalCompactFields() throws {
        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            originalStatus: .thinking,
            toolInput: [
                "integer": .integer(7),
                "number": .number(7.25),
                "nested": .object(["enabled": .bool(true)]),
            ],
            toolTarget: "target",
            repoName: "repo",
            customTitle: "",
            desktopTitle: "desktop",
            aiTitle: "ai",
            summary: "summary",
            firstUserMessage: "first",
            lastUserMessage: "last"
        )

        let decoded = try JSONDecoder().decode(
            AgentSession.self,
            from: JSONEncoder().encode(session)
        )

        XCTAssertEqual(decoded, session)
        XCTAssertEqual(decoded.toolInput?["integer"], .integer(7))
        XCTAssertEqual(decoded.toolInput?["number"], .number(7.25))
        XCTAssertEqual(decoded.customTitle, "")
    }

    func testOlderPayloadDecodesWithOriginalCompactDefaults() throws {
        let data = Data(#"""
        {
            "id":"session-1",
            "source":"codex",
            "cwd":"/tmp/project",
            "tasks":[],
            "todos":[],
            "subagents":[],
            "pendingRequestIds":[],
            "isRestored":false,
            "isRemote":false,
            "hasUnreadCompletion":false,
            "redactionLevel":"metadataOnly"
        }
        """#.utf8)

        let session = try JSONDecoder().decode(AgentSession.self, from: data)

        XCTAssertEqual(session.originalStatus, .waitingForInput)
        XCTAssertNil(session.toolInput)
        XCTAssertNil(session.toolTarget)
        XCTAssertNil(session.repoName)
        XCTAssertNil(session.customTitle)
        XCTAssertNil(session.desktopTitle)
        XCTAssertNil(session.aiTitle)
        XCTAssertNil(session.summary)
        XCTAssertNil(session.firstUserMessage)
        XCTAssertNil(session.lastUserMessage)
    }

    func testSessionStateRestoreAndExportPreservesCompactData() {
        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            activeTool: "Bash",
            activitySummary: "Compatibility summary",
            safeTitle: "Compatibility title",
            originalStatus: .compacting,
            toolInput: ["count": .integer(3)],
            toolTarget: "target",
            repoName: "repo",
            customTitle: "custom",
            desktopTitle: "desktop",
            aiTitle: "ai",
            summary: "summary",
            firstUserMessage: "first",
            lastUserMessage: "last",
            isRestored: true
        )

        let exported = SessionState(agentSession: session).agentSession()

        XCTAssertEqual(
            OriginalCompactSessionAdapter.resolve(exported),
            OriginalCompactSessionAdapter.resolve(session)
        )
    }

    func testSessionStateRoundTripPreservesSafeTitleCompatibilityFallback() {
        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            safeTitle: "Compatibility title"
        )

        let exported = SessionState(agentSession: session).agentSession()

        XCTAssertEqual(
            OriginalCompactSessionAdapter.resolve(exported).customTitle,
            "Compatibility title"
        )
    }

    func testSessionStateEqualityIncludesSafeTitleCompatibilityFallback() {
        let first = SessionState(
            sessionId: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            safeTitle: "First title"
        )
        let second = SessionState(
            sessionId: "session-1",
            source: "codex",
            cwd: "/tmp/project",
            safeTitle: "Second title"
        )

        XCTAssertNotEqual(first, second)
    }
}
