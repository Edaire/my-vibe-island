import Foundation
import XCTest
@testable import MyVibeIslandCore

final class ClaudeCoworkAuditReducerTests: XCTestCase {
    func testUserTurnRecordsLastUserMessageAndClearsPendingQuestion() throws {
        var result = ClaudeCoworkAuditResult(
            pendingQuestionInput: .object(["question": .string("old")])
        )

        ClaudeCoworkAuditReducer.apply(
            row: try row("""
            {"type":"user","message":{"role":"user","content":"Fix the parser"},"auditTimestamp":"2026-07-20T01:02:03Z"}
            """),
            to: &result
        )

        XCTAssertEqual(result.lastTurnType, "user")
        XCTAssertEqual(result.lastUserMessage, "Fix the parser")
        XCTAssertNil(result.pendingQuestionInput)
        XCTAssertTrue(result.hasAnyTurn)
        XCTAssertEqual(result.latestTimestamp, date("2026-07-20T01:02:03Z"))
    }

    func testAssistantTurnRecordsTextAndAskQuestionInput() throws {
        var result = ClaudeCoworkAuditResult()

        ClaudeCoworkAuditReducer.apply(
            row: try row("""
            {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Choose one"},{"type":"tool_use","name":"AskUserQuestion","input":{"question":"Which?","options":["A","B"]}}]}}
            """),
            to: &result
        )

        XCTAssertEqual(result.lastTurnType, "assistant")
        XCTAssertEqual(result.lastAssistantMessage, "Choose one")
        XCTAssertEqual(
            result.pendingQuestionInput,
            .object([
                "question": .string("Which?"),
                "options": .array([.string("A"), .string("B")]),
            ])
        )
        XCTAssertTrue(result.hasAnyTurn)
    }

    func testResultTurnUsesResultTextAndOnlyNewerTimestamp() throws {
        var result = ClaudeCoworkAuditResult(latestTimestamp: date("2026-07-20T01:02:03Z"))

        ClaudeCoworkAuditReducer.apply(
            row: try row("""
            {"type":"result","result":"failed","isError":true,"auditTimestamp":"2026-07-20T01:02:02Z"}
            """),
            to: &result
        )

        XCTAssertEqual(result.lastTurnType, "result")
        XCTAssertEqual(result.lastAssistantMessage, "failed")
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.latestTimestamp, date("2026-07-20T01:02:03Z"))
        XCTAssertTrue(result.hasAnyTurn)
    }

    private func row(_ json: String) throws -> ClaudeCoworkAuditRow {
        try ClaudeCoworkAuditRow.decode(from: Data(json.utf8))
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
