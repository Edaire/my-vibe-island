import Foundation
import XCTest
@testable import MyVibeIslandCore

final class ClaudeCoworkAuditModelsTests: XCTestCase {
    func testAuditRowDecodesStringMessageContent() throws {
        let row = try ClaudeCoworkAuditRow.decode(
            from: Data("""
            {"type":"user","message":{"role":"user","content":"Please fix it"},"auditTimestamp":"2026-07-20T01:02:03Z"}
            """.utf8)
        )

        XCTAssertEqual(row.type, "user")
        XCTAssertEqual(row.message?.role, "user")
        XCTAssertEqual(row.message?.content.text, "Please fix it")
        XCTAssertNil(row.message?.content.askQuestionInput)
        XCTAssertEqual(row.auditTimestamp, "2026-07-20T01:02:03Z")
    }

    func testAuditContentExtractsAskUserQuestionInputFromBlocks() throws {
        let row = try ClaudeCoworkAuditRow.decode(
            from: Data("""
            {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Choose one"},{"type":"tool_use","name":"AskUserQuestion","input":{"question":"Which?","options":["A","B"]}}]}}
            """.utf8)
        )

        XCTAssertEqual(row.message?.content.text, "Choose one")
        XCTAssertEqual(
            row.message?.content.askQuestionInput,
            .object([
                "question": BridgeJSONValue.string("Which?"),
                "options": BridgeJSONValue.array([.string("A"), .string("B")]),
            ])
        )
    }

    func testAuditRowDecodesResultAndOptionalError() throws {
        let row = try ClaudeCoworkAuditRow.decode(
            from: Data(#"{"type":"result","result":"failed","isError":true}"#.utf8)
        )

        XCTAssertEqual(row.result, "failed")
        XCTAssertEqual(row.isError, true)
        XCTAssertNil(row.message)
    }
}
