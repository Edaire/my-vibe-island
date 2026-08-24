import XCTest
@testable import MyVibeIslandCore

final class SessionContentTests: XCTestCase {
    func testSessionContentMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SessionContentMatrixFixture.self,
            from: try FixtureLoader.data("runtime/session-content-matrix")
        )

        let taskState = stateAfterTaskUpdates()
        let todoState = stateAfterTodoUpdates()
        let groupingState = stateAfterTeamGroupingReplacement()
        let normalizedGrouping = TeamGrouping(rootSessionId: "root", parentToChildren: [
            "root": ["child-2", "child-1", "child-2"]
        ])

        let actual = SessionContentMatrixFixture(rows: [
            SessionContentMatrixRow(
                id: "task-upsert-keeps-order",
                taskIds: taskState.tasks.map(\.id),
                taskSubjects: taskState.tasks.map(\.subject),
                taskStatuses: taskState.tasks.map(\.status.rawValue),
                todoIds: [],
                todoStatuses: [],
                teamRootSessionId: nil,
                teamMemberSessionIds: [],
                teamChildToParent: [:],
                teamParentToChildren: [:]
            ),
            SessionContentMatrixRow(
                id: "todo-upsert-keeps-order",
                taskIds: [],
                taskSubjects: [],
                taskStatuses: [],
                todoIds: todoState.todos.map(\.id),
                todoStatuses: todoState.todos.map(\.status.rawValue),
                teamRootSessionId: nil,
                teamMemberSessionIds: [],
                teamChildToParent: [:],
                teamParentToChildren: [:]
            ),
            SessionContentMatrixRow(
                id: "team-grouping-replacement",
                taskIds: [],
                taskSubjects: [],
                taskStatuses: [],
                todoIds: [],
                todoStatuses: [],
                teamRootSessionId: groupingState.teamGrouping?.rootSessionId,
                teamMemberSessionIds: groupingState.teamGrouping?.memberSessionIds ?? [],
                teamChildToParent: groupingState.teamGrouping?.childToParent ?? [:],
                teamParentToChildren: groupingState.teamGrouping?.parentToChildren ?? [:]
            ),
            SessionContentMatrixRow(
                id: "team-grouping-normalizes-duplicate-children",
                taskIds: [],
                taskSubjects: [],
                taskStatuses: [],
                todoIds: [],
                todoStatuses: [],
                teamRootSessionId: normalizedGrouping.rootSessionId,
                teamMemberSessionIds: normalizedGrouping.memberSessionIds,
                teamChildToParent: normalizedGrouping.childToParent,
                teamParentToChildren: normalizedGrouping.parentToChildren
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testSessionStateInsertsAndUpdatesTasksByIdWithoutReordering() {
        let updatedFirst = TaskItem(id: "t1", subject: "Plan", description: "Plan accepted", status: .completed)
        let state = stateAfterTaskUpdates()

        XCTAssertEqual(state.tasks.map(\.id), ["t1", "t2"])
        XCTAssertEqual(state.tasks[0], updatedFirst)
        XCTAssertEqual(state.tasks[1], TaskItem(id: "t2", subject: "Implement", status: .active))
    }

    func testSessionStateInsertsAndUpdatesTodosByIdWithoutReordering() {
        let updatedFirst = TodoItem(id: "todo-1", content: "Check fixtures", status: .completed)
        let state = stateAfterTodoUpdates()

        XCTAssertEqual(state.todos.map(\.id), ["todo-1", "todo-2"])
        XCTAssertEqual(state.todos[0], updatedFirst)
        XCTAssertEqual(state.todos[1], TodoItem(id: "todo-2", content: "Run tests", status: .active))
    }

    func testSessionStateReplacesTeamGrouping() {
        let replacement = TeamGrouping(rootSessionId: "root", childToParent: ["child-2": "root"])
        let state = stateAfterTeamGroupingReplacement()

        XCTAssertEqual(state.teamGrouping, replacement)
    }

    func testTeamGroupingNormalizesDuplicateChildren() {
        let grouping = TeamGrouping(rootSessionId: "root", parentToChildren: [
            "root": ["child-2", "child-1", "child-2"]
        ])

        XCTAssertEqual(grouping.parentToChildren["root"], ["child-1", "child-2"])
        XCTAssertEqual(grouping.childToParent, ["child-1": "root", "child-2": "root"])
    }

    private func stateAfterTaskUpdates() -> SessionState {
        var state = SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project")
        state.apply(.taskUpdated(
            source: "codex",
            sessionId: "s1",
            task: TaskItem(id: "t1", subject: "Plan", description: "Draft plan", status: .pending)
        ))
        state.apply(.taskUpdated(
            source: "codex",
            sessionId: "s1",
            task: TaskItem(id: "t2", subject: "Implement", status: .active)
        ))
        state.apply(.taskUpdated(
            source: "codex",
            sessionId: "s1",
            task: TaskItem(id: "t1", subject: "Plan", description: "Plan accepted", status: .completed)
        ))
        return state
    }

    private func stateAfterTodoUpdates() -> SessionState {
        var state = SessionState(sessionId: "s1", source: "claude", cwd: "/tmp/project")
        state.apply(.todoUpdated(
            source: "claude",
            sessionId: "s1",
            todo: TodoItem(id: "todo-1", content: "Check fixtures", status: .pending)
        ))
        state.apply(.todoUpdated(
            source: "claude",
            sessionId: "s1",
            todo: TodoItem(id: "todo-2", content: "Run tests", status: .active)
        ))
        state.apply(.todoUpdated(
            source: "claude",
            sessionId: "s1",
            todo: TodoItem(id: "todo-1", content: "Check fixtures", status: .completed)
        ))
        return state
    }

    private func stateAfterTeamGroupingReplacement() -> SessionState {
        var state = SessionState(sessionId: "root", source: "codex", cwd: "/tmp/project")
        state.apply(.teamGroupingUpdated(
            source: "codex",
            sessionId: "root",
            grouping: TeamGrouping(rootSessionId: "root", childToParent: ["child-1": "root"])
        ))
        state.apply(.teamGroupingUpdated(
            source: "codex",
            sessionId: "root",
            grouping: TeamGrouping(rootSessionId: "root", childToParent: ["child-2": "root"])
        ))
        return state
    }

    private struct SessionContentMatrixFixture: Codable, Equatable {
        let rows: [SessionContentMatrixRow]
    }

    private struct SessionContentMatrixRow: Codable, Equatable {
        let id: String
        let taskIds: [String]
        let taskSubjects: [String]
        let taskStatuses: [String]
        let todoIds: [String]
        let todoStatuses: [String]
        let teamRootSessionId: String?
        let teamMemberSessionIds: [String]
        let teamChildToParent: [String: String]
        let teamParentToChildren: [String: [String]]
    }
}
