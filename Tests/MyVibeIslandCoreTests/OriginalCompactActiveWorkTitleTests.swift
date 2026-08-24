import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactActiveWorkTitleTests: XCTestCase {
    func testActiveTaskTakesPriorityOverActiveTodo() {
        XCTAssertEqual(
            OriginalCompactActiveWorkTitle.resolve(
                tasks: [task(id: "task", subject: "Task subject", status: .active)],
                todos: [todo(id: "todo", content: "Todo content", status: .active, activeForm: "Todo active")]
            ),
            "Task subject"
        )
    }

    func testFirstActiveTaskWinsInArrayOrder() {
        XCTAssertEqual(
            OriginalCompactActiveWorkTitle.resolve(
                tasks: [
                    task(id: "first", subject: "First", status: .active),
                    task(id: "second", subject: "Second", status: .active),
                ],
                todos: []
            ),
            "First"
        )
    }

    func testTaskActiveFormTakesPriorityAndEmptyStringIsValid() {
        XCTAssertEqual(
            OriginalCompactActiveWorkTitle.resolve(
                tasks: [task(id: "task", subject: "Subject", status: .active, activeForm: "")],
                todos: []
            ),
            ""
        )
    }

    func testActiveTaskFallsBackToSubjectWhenActiveFormIsNil() {
        XCTAssertEqual(
            OriginalCompactActiveWorkTitle.resolve(
                tasks: [task(id: "task", subject: "Subject fallback", status: .active)],
                todos: []
            ),
            "Subject fallback"
        )
    }

    func testFirstActiveTodoReturnsItsActiveForm() {
        XCTAssertEqual(
            OriginalCompactActiveWorkTitle.resolve(
                tasks: [],
                todos: [
                    todo(id: "pending", content: "Pending", status: .pending, activeForm: "Ignored"),
                    todo(id: "active", content: "Active content", status: .active, activeForm: "Active form"),
                ]
            ),
            "Active form"
        )
    }

    func testNilActiveFormOnFirstActiveTodoBlocksLaterTodos() {
        XCTAssertNil(
            OriginalCompactActiveWorkTitle.resolve(
                tasks: [],
                todos: [
                    todo(id: "first", content: "First content", status: .active),
                    todo(id: "second", content: "Second content", status: .active, activeForm: "Second active"),
                ]
            )
        )
    }

    func testNonActiveItemsAreIgnored() {
        XCTAssertNil(
            OriginalCompactActiveWorkTitle.resolve(
                tasks: [task(id: "task", subject: "Task subject", status: .completed, activeForm: "Task active")],
                todos: [todo(id: "todo", content: "Todo content", status: .pending, activeForm: "Todo active")]
            )
        )
    }

    func testEmptyCollectionsReturnNil() {
        XCTAssertNil(OriginalCompactActiveWorkTitle.resolve(tasks: [], todos: []))
    }

    private func task(
        id: String,
        subject: String,
        status: TaskStatus,
        activeForm: String? = nil
    ) -> TaskItem {
        TaskItem(id: id, subject: subject, status: status, activeForm: activeForm)
    }

    private func todo(
        id: String,
        content: String,
        status: TodoStatus,
        activeForm: String? = nil
    ) -> TodoItem {
        TodoItem(id: id, content: content, status: status, activeForm: activeForm)
    }
}
