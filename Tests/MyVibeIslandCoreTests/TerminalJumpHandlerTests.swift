import XCTest
@testable import MyVibeIslandCore

final class TerminalJumpHandlerTests: XCTestCase {
    func testTerminalJumpHandlerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            TerminalJumpHandlerMatrixFixture.self,
            from: try FixtureLoader.data("terminal/jump-handler-matrix")
        )
        let handler = RecordingTerminalJumpHandler(
            handlerId: "workspace-test",
            handledSessionId: "session-1"
        )
        let handledInput = JumpInput(sessionId: "session-1", source: "codex", cwd: "/tmp/project")
        let missingCwdInput = JumpInput(sessionId: "session-1", source: "codex")
        let unhandledInput = JumpInput(sessionId: "session-2", source: "codex", cwd: "/tmp/project")

        let actual = TerminalJumpHandlerMatrixFixture(rows: [
            row(id: "handled-workspace-input", handler: handler, input: handledInput),
            row(id: "missing-cwd-input", handler: handler, input: missingCwdInput),
            row(id: "unhandled-session-input", handler: handler, input: unhandledInput),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testTerminalJumpHandlerProtocolEvaluatesAndExecutesJumpInput() {
        let handler = RecordingTerminalJumpHandler(
            handlerId: "workspace-test",
            handledSessionId: "session-1"
        )
        let handledInput = JumpInput(sessionId: "session-1", source: "codex", cwd: "/tmp/project")
        let unhandledInput = JumpInput(sessionId: "session-2", source: "codex", cwd: "/tmp/project")

        XCTAssertTrue(handler.canHandle(handledInput))
        XCTAssertFalse(handler.canHandle(unhandledInput))

        let result = handler.execute(handledInput)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.precision, .workspace)
        XCTAssertEqual(result.handlerId, "workspace-test")
        XCTAssertEqual(result.diagnosticSummary, "workspace-test: workspace")
    }

    private struct RecordingTerminalJumpHandler: TerminalJumpHandler {
        let handlerId: String
        let handledSessionId: String

        func canHandle(_ input: JumpInput) -> Bool {
            input.sessionId == handledSessionId && input.cwd != nil
        }

        func execute(_ input: JumpInput) -> JumpResult {
            JumpResult(
                precision: .workspace,
                succeeded: canHandle(input),
                handlerId: handlerId,
                attemptedMechanism: handlerId,
                failureReason: canHandle(input) ? nil : .missingTarget,
                repairAction: nil,
                diagnosticSummary: "\(handlerId): workspace"
            )
        }
    }

    private func row(
        id: String,
        handler: RecordingTerminalJumpHandler,
        input: JumpInput
    ) -> TerminalJumpHandlerRowFixture {
        let result = handler.execute(input)
        return TerminalJumpHandlerRowFixture(
            id: id,
            handlerId: handler.handlerId,
            sessionId: input.sessionId,
            hasCwd: input.cwd != nil,
            canHandle: handler.canHandle(input),
            resultSucceeded: result.succeeded,
            precision: result.precision.rawValue,
            failureReason: result.failureReason?.rawValue,
            diagnosticSummary: result.diagnosticSummary
        )
    }

    private struct TerminalJumpHandlerMatrixFixture: Codable, Equatable {
        let rows: [TerminalJumpHandlerRowFixture]
    }

    private struct TerminalJumpHandlerRowFixture: Codable, Equatable {
        let id: String
        let handlerId: String
        let sessionId: String
        let hasCwd: Bool
        let canHandle: Bool
        let resultSucceeded: Bool
        let precision: String
        let failureReason: String?
        let diagnosticSummary: String
    }
}
