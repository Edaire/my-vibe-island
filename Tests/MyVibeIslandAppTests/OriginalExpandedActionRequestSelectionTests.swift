import Foundation
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class OriginalExpandedActionRequestSelectionTests: XCTestCase {
    func testSingleSelectionReplacesAndMultipleSelectionToggles() {
        let request = request(
            id: "request-1",
            topLevelOptions: [option("one", "One"), option("two", "Two")],
            allowsMultipleSelection: false,
            questions: [question("question-1", "Question", allowsMultipleSelection: false)]
        )
        var state = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: request,
            persistedSelection: .init(),
            observedAt: Date(timeIntervalSince1970: 100)
        )

        state = state.selectingTopLevelOption("one", allowsMultipleSelection: false)
        state = state.selectingTopLevelOption("two", allowsMultipleSelection: false)
        XCTAssertEqual(state.topLevelSelection, ["two"])

        state = state.selectingAnswer("one", forQuestionID: "question-1", allowsMultipleSelection: false)
        state = state.selectingAnswer("two", forQuestionID: "question-1", allowsMultipleSelection: false)
        XCTAssertEqual(state.answers["question-1"], ["two"])

        state = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: request,
            persistedSelection: .init(),
            observedAt: Date(timeIntervalSince1970: 100)
        )
        state = state.selectingTopLevelOption("one", allowsMultipleSelection: true)
        state = state.selectingTopLevelOption("two", allowsMultipleSelection: true)
        state = state.selectingTopLevelOption("one", allowsMultipleSelection: true)
        XCTAssertEqual(state.topLevelSelection, ["two"])

        state = state.selectingAnswer("one", forQuestionID: "question-1", allowsMultipleSelection: true)
        state = state.selectingAnswer("two", forQuestionID: "question-1", allowsMultipleSelection: true)
        state = state.selectingAnswer("one", forQuestionID: "question-1", allowsMultipleSelection: true)
        XCTAssertEqual(state.answers["question-1"], ["two"])
    }

    func testSelectionStorePersistsCodableArraysByExactRequestAndQuestion() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Task7.ArraySelection.\(UUID().uuidString)"))
        let first = OriginalExpandedActionSelectionStore(defaults: defaults)
        _ = first.recordingTopLevelSelection(["one", "two"], requestID: "request-1")
        _ = first.recordingQuestionAnswers(["red", "blue"], requestID: "request-1", questionID: "question-1")

        let restored = OriginalExpandedActionSelectionStore(defaults: defaults)
        XCTAssertEqual(restored.topLevelSelections(forRequestID: "request-1"), ["one", "two"])
        XCTAssertEqual(
            restored.questionAnswers(forRequestID: "request-1", questionID: "question-1"),
            ["red", "blue"]
        )
    }

    func testAnswerResolutionUsesOptionLabelsAndQuestionHeaders() throws {
        let request = request(
            id: "request-1",
            topLevelOptions: [option("one", "One"), option("two", "Two")],
            allowsMultipleSelection: true,
            questions: [question(
                "question-1",
                "Question Header",
                options: [option("red", "Red"), option("blue", "Blue")],
                allowsMultipleSelection: true
            )]
        )
        var state = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: request,
            persistedSelection: .init(),
            observedAt: Date(timeIntervalSince1970: 100)
        )
        state = state.selectingTopLevelOption("two", allowsMultipleSelection: true)
        state = state.selectingTopLevelOption("one", allowsMultipleSelection: true)
        state = state.selectingAnswer("blue", forQuestionID: "question-1", allowsMultipleSelection: true)
        state = state.selectingAnswer("red", forQuestionID: "question-1", allowsMultipleSelection: true)

        XCTAssertEqual(
            try XCTUnwrap(OriginalExpandedActionRequestResolution.answer(for: request, state: state)),
            ActionResolution(
                requestId: "request-1",
                sessionId: "session-1",
                kind: .answer,
                selection: "One, Two",
                answers: ["Question Header": "Blue, Red"]
            )
        )
    }

    private func request(
        id: String,
        topLevelOptions: [ActionRequestOption],
        allowsMultipleSelection: Bool,
        questions: [ActionRequestQuestion]
    ) -> ActionRequestPreview {
        ActionRequestPreview(request: ActionableRequest(
            requestId: id,
            sessionId: "session-1",
            source: "opencode",
            kind: .question,
            toolName: "question",
            details: ActionRequestDetails(
                options: topLevelOptions,
                allowsMultipleSelection: allowsMultipleSelection,
                questions: questions
            )
        ))
    }

    private func question(
        _ id: String,
        _ header: String,
        options: [ActionRequestOption]? = nil,
        allowsMultipleSelection: Bool
    ) -> ActionRequestQuestion {
        ActionRequestQuestion(
            id: id,
            header: header,
            prompt: header,
            options: options ?? [option("one", "One"), option("two", "Two")],
            allowsMultipleSelection: allowsMultipleSelection
        )
    }

    private func option(_ id: String, _ label: String) -> ActionRequestOption {
        ActionRequestOption(id: id, label: label)
    }
}
