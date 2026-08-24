import Foundation
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class OriginalExpandedActionRequestViewTests: XCTestCase {
    func testTerminalSubmissionStatesBlockInteractionWithoutResettingState() {
        let request = questionRequest(id: "request-1", questionIDs: ["one", "two"])
        let base = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: request,
            persistedSelection: .init(),
            observedAt: Date(timeIntervalSince1970: 100)
        ).recording(answer: "one", forQuestionID: "one")

        for terminalState in [
            OriginalExpandedActionRequestState.SubmissionState.timedOut,
            .submitted,
        ] {
            let terminal = base.withSubmissionState(terminalState)
            XCTAssertFalse(terminal.canInteract)
            XCTAssertEqual(terminal.recording(answer: "two", forQuestionID: "one"), terminal)
            XCTAssertEqual(terminal.recording(topLevelSelection: "option"), terminal)
            XCTAssertEqual(terminal.advancing(), terminal)
            XCTAssertEqual(terminal.retreating(), terminal)
            XCTAssertEqual(terminal.withSubmissionResult(false), terminal)
        }
    }

    func testSubmissionFailureAllowsRetryAndReadyControlsRemainEnabled() {
        let request = questionRequest(id: "request-1", questionIDs: ["one"])
        let failed = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: request,
            persistedSelection: .init(),
            observedAt: Date(timeIntervalSince1970: 100)
        ).withSubmissionState(.submissionFailed)

        XCTAssertTrue(failed.canInteract)
        XCTAssertEqual(failed.recording(answer: "one", forQuestionID: "one").submissionState, .ready)
        XCTAssertEqual(
            OriginalExpandedActionRequestControlDescriptor.resolve(for: failed),
            OriginalExpandedActionRequestControlDescriptor(canInteract: true)
        )
    }

    func testTerminalControlDescriptorDisablesDismissSubmitAndNavigation() {
        let request = questionRequest(id: "request-1", questionIDs: ["one"])
        let state = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: request,
            persistedSelection: .init(),
            observedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(
            OriginalExpandedActionRequestControlDescriptor.resolve(for: state.withSubmissionState(.timedOut)),
            OriginalExpandedActionRequestControlDescriptor(canInteract: false)
        )
        XCTAssertEqual(
            OriginalExpandedActionRequestControlDescriptor.resolve(for: state.withSubmissionState(.submitted)),
            OriginalExpandedActionRequestControlDescriptor(canInteract: false)
        )
    }

    func testReplacingRequestIdentityResetsTransientStateAndClampsQuestionIndex() {
        let start = Date(timeIntervalSince1970: 100)
        var state = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: questionRequest(id: "request-1", questionIDs: ["one", "two"]),
            persistedSelection: .init(answers: ["one": ["a"]]),
            observedAt: start
        )
        state = state.advancing().withSubmissionState(.submissionFailed)

        let sameRequest = OriginalExpandedActionRequestState.transition(
            from: state,
            to: questionRequest(id: "request-1", questionIDs: ["one"]),
            persistedSelection: .init(),
            observedAt: Date(timeIntervalSince1970: 200)
        )
        XCTAssertEqual(sameRequest.currentQuestionIndex, 0)
        XCTAssertEqual(sameRequest.answers, ["one": ["a"]])
        XCTAssertEqual(sameRequest.submissionState, .submissionFailed)

        let replacement = OriginalExpandedActionRequestState.transition(
            from: sameRequest,
            to: questionRequest(id: "request-2", questionIDs: ["next"]),
            persistedSelection: .init(answers: ["next": ["saved"]]),
            observedAt: Date(timeIntervalSince1970: 300)
        )
        XCTAssertEqual(replacement.requestID, "request-2")
        XCTAssertEqual(replacement.currentQuestionIndex, 0)
        XCTAssertEqual(replacement.answers, ["next": ["saved"]])
        XCTAssertEqual(replacement.submissionState, .ready)
        XCTAssertEqual(replacement.timeoutReferenceDate, Date(timeIntervalSince1970: 300))

        for transientState in [
            OriginalExpandedActionRequestState.SubmissionState.timedOut,
            .submissionFailed,
            .submitted,
        ] {
            let replaced = OriginalExpandedActionRequestState.transition(
                from: state.withSubmissionState(transientState),
                to: questionRequest(id: "replacement-\(transientState)", questionIDs: []),
                persistedSelection: .init(),
                observedAt: Date(timeIntervalSince1970: 400)
            )
            XCTAssertEqual(replaced.submissionState, .ready)
            XCTAssertTrue(replaced.answers.isEmpty)
        }
    }

    func testSameRequestAddsPersistedAnswersOnlyForNewQuestionsAndKeepsMemoryOnConflict() {
        let emptyRequest = questionRequest(id: "request-1", questionIDs: [])
        let expandedRequest = questionRequest(id: "request-1", questionIDs: ["new"])
        let emptyState = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: emptyRequest,
            persistedSelection: .init(),
            observedAt: Date(timeIntervalSince1970: 100)
        )

        let restoredNewQuestion = OriginalExpandedActionRequestState.transition(
            from: emptyState,
            to: expandedRequest,
            persistedSelection: .init(answers: ["new": ["persisted"]]),
            observedAt: Date(timeIntervalSince1970: 200)
        )
        XCTAssertEqual(restoredNewQuestion.answers, ["new": ["persisted"]])

        let memoryState = restoredNewQuestion.selectingAnswer(
            "new",
            forQuestionID: "new",
            allowsMultipleSelection: false
        )
        let conflictingUpdate = OriginalExpandedActionRequestState.transition(
            from: memoryState,
            to: expandedRequest,
            persistedSelection: .init(answers: ["new": ["other"]]),
            observedAt: Date(timeIntervalSince1970: 300)
        )
        XCTAssertEqual(conflictingUpdate.answers, ["new": ["new"]])
    }

    func testSingleQuestionSelectionWaitsForExplicitSubmitAndBuildsAnswerResolution() throws {
        let request = questionRequest(id: "request-1", questionIDs: ["only"])
        let selected = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: request,
            persistedSelection: .init(),
            observedAt: .distantPast
        ).recording(answer: "only", forQuestionID: "only")

        XCTAssertEqual(selected.submissionState, .ready)
        XCTAssertEqual(
            try XCTUnwrap(OriginalExpandedActionRequestResolution.answer(for: request, state: selected)),
            ActionResolution(
                requestId: "request-1",
                sessionId: "session-1",
                kind: .answer,
                answers: ["only": "only"]
            )
        )
    }

    func testTimeoutAndSubmissionOutcomesAreRequestScoped() {
        let state = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: questionRequest(id: "request-1", questionIDs: []),
            persistedSelection: .init(),
            observedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(state.timingOut(now: Date(timeIntervalSince1970: 3_699), timeout: 3_600).submissionState, .ready)
        XCTAssertEqual(state.timingOut(now: Date(timeIntervalSince1970: 3_700), timeout: 3_600).submissionState, .timedOut)
        XCTAssertEqual(state.withSubmissionResult(true).submissionState, .submitted)
        XCTAssertEqual(state.withSubmissionResult(false).submissionState, .submissionFailed)
    }

    func testRequestCollectionPreservesAllRequestsAndSelectedIdentityAcrossReplacement() {
        var state = OriginalExpandedActionRequestCollectionState(requestIDs: ["a", "b", "c"])
        state = state.selecting("b")
        XCTAssertEqual(state.selectedRequestID, "b")
        XCTAssertEqual(state.requestIDs, ["a", "b", "c"])

        XCTAssertEqual(state.replacingRequestIDs(["b", "c", "d"]).selectedRequestID, "b")
        XCTAssertEqual(state.replacingRequestIDs(["c", "d"]).selectedRequestID, "c")
    }

    private func questionRequest(id: String, questionIDs: [String]) -> ActionRequestPreview {
        ActionRequestPreview(request: ActionableRequest(
            requestId: id,
            sessionId: "session-1",
            source: "opencode",
            kind: .question,
            toolName: "question",
            details: ActionRequestDetails(questions: questionIDs.map {
                ActionRequestQuestion(
                    id: $0,
                    header: $0,
                    prompt: $0,
                    options: [ActionRequestOption(id: $0, label: $0)]
                )
            })
        ))
    }
}
