import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactContentPlanTests: XCTestCase {
    func testEmptySessionsDifferByDisplayClassAndUseWaitingStatusWithoutCount() {
        let physical = resolve(.physicalNotch, sessions: [])
        let nonNotched = resolve(.nonNotched, sessions: [])

        XCTAssertEqual(physical.status, .waitingForInput)
        XCTAssertNil(physical.title)
        XCTAssertNil(physical.rightCount)

        XCTAssertEqual(nonNotched.status, .waitingForInput)
        XCTAssertEqual(nonNotched.title, verbatim("Vibe Island"))
        XCTAssertNil(nonNotched.rightCount)
    }

    func testFirstSessionDeterminesStatusAndPhysicalTitleWhileSecondOnlyChangesCount() {
        let first = session(
            status: .processing,
            currentTool: "Read",
            firstUserMessage: "ignored first",
            lastUserMessage: "ignored last"
        )
        let oneSession = resolve(.physicalNotch, sessions: [first])
        let twoSessions = resolve(
            .physicalNotch,
            sessions: [first, session(status: .question, currentTool: "Bash")]
        )

        let expectedTitle = OriginalCompactTitlePlan(
            content: .localized(
                key: "tool.reading",
                englishFallback: "Reading",
                formatArgument: nil
            ),
            transform: .physicalCompact
        )
        XCTAssertEqual(oneSession.status, .processing)
        XCTAssertEqual(oneSession.title, expectedTitle)
        XCTAssertEqual(oneSession.rightCount, .init(count: 1, source: .sessions))

        XCTAssertEqual(twoSessions.status, oneSession.status)
        XCTAssertEqual(twoSessions.title, oneSession.title)
        XCTAssertEqual(twoSessions.rightCount, .init(count: 1, source: .actionable))
    }

    func testCommandPreviewReachesCompactTitleWhenStructuredToolInputIsAbsent() {
        let plan = resolve(
            .physicalNotch,
            sessions: [
                session(
                    status: .runningTool,
                    currentTool: "exec",
                    currentCommandPreview: "swift test --filter SessionTests"
                )
            ]
        )

        XCTAssertEqual(
            plan.title,
            verbatim("exec: swift test --filter SessionTests", transform: .physicalCompact)
        )
    }

    func testPhysicalPathDoesNotNormalizeMessagesAndUsesPhysicalPlanInputs() {
        let plan = resolve(
            .physicalNotch,
            sessions: [
                session(
                    status: .waitingForInput,
                    tasks: [
                        TaskItem(
                            id: "task",
                            subject: "Physical task",
                            status: .active,
                            activeForm: "Physical active form"
                        )
                    ],
                    repoName: "Repo",
                    firstUserMessage: "codex_desktop_thread</sources> Conversation title",
                    lastUserMessage: "Last conversation title"
                )
            ]
        )

        XCTAssertEqual(plan.title, verbatim("Physical active form", transform: .physicalCompact))
    }

    func testNonNotchedOrdinaryMessagesArePassedThroughUnchanged() {
        let plan = resolve(
            .nonNotched,
            sessions: [session(status: .waitingForInput, firstUserMessage: "  ordinary message  ")]
        )

        XCTAssertEqual(plan.title, verbatim("  ordinary message  "))
    }

    func testNonNotchedMarkerMessagesAreNormalizedBeforeTitleResolution() {
        let plan = resolve(
            .nonNotched,
            sessions: [
                session(
                    status: .waitingForInput,
                    firstUserMessage: "codex_desktop_thread metadata </sources> Marker title "
                )
            ]
        )

        XCTAssertEqual(plan.title, verbatim("Marker title"))
    }

    func testNonNotchedNormalizerNilFallsThroughToLastMessage() {
        let plan = resolve(
            .nonNotched,
            sessions: [
                session(
                    status: .waitingForInput,
                    firstUserMessage: "codex_desktop_thread without closing tag",
                    lastUserMessage: "Last title"
                )
            ]
        )

        XCTAssertEqual(plan.title, verbatim("Last title"))
    }

    func testNonNotchedNormalizerSomeEmptyStringIsPreservedForLeafPriority() {
        let plan = resolve(
            .nonNotched,
            sessions: [
                session(
                    status: .waitingForInput,
                    firstUserMessage: "codex_desktop_thread</sources> \n\t ",
                    lastUserMessage: "Last title"
                )
            ]
        )

        XCTAssertEqual(
            OriginalCompactConversationMessageNormalizer.resolve(
                "codex_desktop_thread</sources> \n\t "
            ),
            ""
        )
        XCTAssertEqual(plan.title, verbatim("Last title"))
    }

    func testActionableCountTakesPriorityOverTotalSessionCount() {
        let plan = resolve(
            .nonNotched,
            sessions: [
                session(status: .waitingForInput, customTitle: "First"),
                session(status: .waitingForApproval),
                session(status: .question),
                session(status: .ended),
            ]
        )

        XCTAssertEqual(plan.status, .waitingForInput)
        XCTAssertEqual(plan.title, verbatim("First"))
        XCTAssertEqual(plan.rightCount, .init(count: 2, source: .actionable))
    }

    private func resolve(
        _ displayClass: OriginalCompactContentPlan.DisplayClass,
        sessions: [OriginalCompactContentPlan.SessionInput]
    ) -> OriginalCompactContentPlan {
        OriginalCompactContentPlan.resolve(displayClass: displayClass, sessions: sessions)
    }

    private func session(
        status: OriginalPixelStatusCompact,
        currentTool: String? = nil,
        toolInput: [String: BridgeJSONValue]? = nil,
        toolTarget: String? = nil,
        currentCommandPreview: String? = nil,
        tasks: [TaskItem] = [],
        todos: [TodoItem] = [],
        repoName: String? = nil,
        cwd: String? = nil,
        source: String? = nil,
        customTitle: String? = nil,
        desktopTitle: String? = nil,
        aiTitle: String? = nil,
        summary: String? = nil,
        firstUserMessage: String? = nil,
        lastUserMessage: String? = nil
    ) -> OriginalCompactContentPlan.SessionInput {
        OriginalCompactContentPlan.SessionInput(
            status: status,
            currentTool: currentTool,
            toolInput: toolInput,
            toolTarget: toolTarget,
            currentCommandPreview: currentCommandPreview,
            tasks: tasks,
            todos: todos,
            repoName: repoName,
            cwd: cwd,
            source: source,
            customTitle: customTitle,
            desktopTitle: desktopTitle,
            aiTitle: aiTitle,
            summary: summary,
            firstUserMessage: firstUserMessage,
            lastUserMessage: lastUserMessage
        )
    }

    private func verbatim(
        _ title: String,
        transform: OriginalCompactTitlePlan.PostLocalizationTransform = .none
    ) -> OriginalCompactTitlePlan {
        OriginalCompactTitlePlan(content: .verbatim(title), transform: transform)
    }
}
