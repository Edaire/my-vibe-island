import Foundation
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class OriginalExpandedActionRequestLifecycleTests: XCTestCase {
    func testTransitionUsesOneRequestBoundaryForTypedAndLegacyLifecycleAndScopedPersistence() {
        let observedAt = Date(timeIntervalSince1970: 500)
        let requestA = preview(id: "request-a", timestamp: Date(timeIntervalSince1970: 100))
        let requestB = preview(id: "request-b", timestamp: Date(timeIntervalSince1970: 200))
        let legacyRequestC = preview(id: "request-c", timestamp: nil)

        var state = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: requestA,
            persistedSelection: .init(
                answers: ["one": ["saved-a"]],
                topLevelSelection: ["option-a"]
            ),
            observedAt: observedAt
        )
        XCTAssertEqual(state.timeoutReferenceDate, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(state.answers, ["one": ["saved-a"]])
        XCTAssertEqual(state.topLevelSelection, ["option-a"])

        state = state.recording(answer: "typed-a", forQuestionID: "one")
        let sameA = OriginalExpandedActionRequestState.transition(
            from: state,
            to: requestA,
            persistedSelection: .init(
                answers: ["one": ["persisted-update"]],
                topLevelSelection: ["updated-option"]
            ),
            observedAt: Date(timeIntervalSince1970: 900)
        )
        XCTAssertEqual(sameA.timeoutReferenceDate, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(sameA.answers, ["one": ["typed-a"]])
        XCTAssertEqual(sameA.topLevelSelection, ["option-a"])

        let nextB = OriginalExpandedActionRequestState.transition(
            from: sameA,
            to: requestB,
            persistedSelection: .init(
                answers: ["one": ["saved-b"]],
                topLevelSelection: ["option-b"]
            ),
            observedAt: Date(timeIntervalSince1970: 901)
        )
        XCTAssertEqual(nextB.timeoutReferenceDate, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(nextB.answers, ["one": ["saved-b"]])
        XCTAssertEqual(nextB.topLevelSelection, ["option-b"])

        let firstC = OriginalExpandedActionRequestState.transition(
            from: nextB,
            to: legacyRequestC,
            persistedSelection: .init(
                answers: ["one": ["saved-c"]],
                topLevelSelection: ["option-c"]
            ),
            observedAt: Date(timeIntervalSince1970: 700)
        )
        XCTAssertEqual(firstC.timeoutReferenceDate, Date(timeIntervalSince1970: 700))
        XCTAssertEqual(firstC.answers, ["one": ["saved-c"]])
        XCTAssertEqual(firstC.topLevelSelection, ["option-c"])

        let sameC = OriginalExpandedActionRequestState.transition(
            from: firstC,
            to: legacyRequestC,
            persistedSelection: .init(
                answers: ["one": ["updated-c"]],
                topLevelSelection: ["updated-option-c"]
            ),
            observedAt: Date(timeIntervalSince1970: 999)
        )
        XCTAssertEqual(sameC.timeoutReferenceDate, Date(timeIntervalSince1970: 700))
        XCTAssertEqual(sameC.answers, ["one": ["saved-c"]])
        XCTAssertEqual(sameC.topLevelSelection, ["option-c"])
    }

    func testStateUsesRequestLifecycleTimestampAndLegacyFallbackOnlyOnce() {
        let lifecycle = Date(timeIntervalSince1970: 100)
        let request = preview(id: "request-1", timestamp: lifecycle)
        let state = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: request,
            persistedSelection: .init(),
            observedAt: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(state.timeoutReferenceDate, lifecycle)
        XCTAssertEqual(
            OriginalExpandedActionRequestState.transition(
                from: state,
                to: request,
                persistedSelection: .init(),
                observedAt: Date(timeIntervalSince1970: 900)
            ).timeoutReferenceDate,
            lifecycle
        )

        let legacy = preview(id: "legacy", timestamp: nil)
        let legacyState = OriginalExpandedActionRequestState.transition(
            from: nil,
            to: legacy,
            persistedSelection: .init(),
            observedAt: Date(timeIntervalSince1970: 600)
        )
        XCTAssertEqual(legacyState.timeoutReferenceDate, Date(timeIntervalSince1970: 600))
        XCTAssertEqual(
            OriginalExpandedActionRequestState.transition(
                from: legacyState,
                to: legacy,
                persistedSelection: .init(),
                observedAt: Date(timeIntervalSince1970: 900)
            ).timeoutReferenceDate,
            Date(timeIntervalSince1970: 600)
        )
    }

    func testTopLevelSelectionStoreIsExactRequestScopedWithoutUserDefaults() {
        var store = OriginalExpandedActionSelectionStore()
        store = store.recordingTopLevelSelection(["one"], requestID: "request-1")
        store = store.recordingTopLevelSelection(["two"], requestID: "request-2")

        XCTAssertEqual(store.topLevelSelections(forRequestID: "request-1"), ["one"])
        XCTAssertEqual(store.topLevelSelections(forRequestID: "request-2"), ["two"])
        XCTAssertTrue(store.topLevelSelections(forRequestID: "request-3").isEmpty)
    }

    func testTopLevelSelectionStorePersistsAndRestoresByExactRequestID() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Task7.\(UUID().uuidString)"))
        let first = OriginalExpandedActionSelectionStore(defaults: defaults)
        _ = first.recordingTopLevelSelection(["one"], requestID: "request-1")
        _ = first.recordingTopLevelSelection(["ten"], requestID: "request-10")

        let restored = OriginalExpandedActionSelectionStore(defaults: defaults)
        XCTAssertEqual(restored.topLevelSelections(forRequestID: "request-1"), ["one"])
        XCTAssertEqual(restored.topLevelSelections(forRequestID: "request-10"), ["ten"])
        XCTAssertTrue(restored.topLevelSelections(forRequestID: "request-").isEmpty)
    }

    func testSelectionStorePersistsDistinctEncodedRequestAndQuestionComponents() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Task7.Components.\(UUID().uuidString)"))
        let first = OriginalExpandedActionSelectionStore(defaults: defaults)
        _ = first.recordingQuestionAnswers(["first"], requestID: "a.b+c", questionID: "q")
        _ = first.recordingQuestionAnswers(["second"], requestID: "a+b.c", questionID: "q")
        _ = first.recordingQuestionAnswers(["nested-first"], requestID: "a.b", questionID: "c")
        _ = first.recordingQuestionAnswers(["nested-second"], requestID: "a", questionID: "b.c")
        _ = first.recordingTopLevelSelection(["top-first"], requestID: "a.b+c")
        _ = first.recordingTopLevelSelection(["top-second"], requestID: "a+b.c")
        _ = first.recordingTopLevelSelection(["top-nested-first"], requestID: "a.b")
        _ = first.recordingQuestionAnswers(["question-colliding-with-old-top-level"], requestID: "a", questionID: "b.topLevel")

        let restored = OriginalExpandedActionSelectionStore(defaults: defaults)
        XCTAssertEqual(restored.questionAnswers(forRequestID: "a.b+c", questionID: "q"), ["first"])
        XCTAssertEqual(restored.questionAnswers(forRequestID: "a+b.c", questionID: "q"), ["second"])
        XCTAssertEqual(restored.questionAnswers(forRequestID: "a.b", questionID: "c"), ["nested-first"])
        XCTAssertEqual(restored.questionAnswers(forRequestID: "a", questionID: "b.c"), ["nested-second"])
        XCTAssertEqual(restored.topLevelSelections(forRequestID: "a.b+c"), ["top-first"])
        XCTAssertEqual(restored.topLevelSelections(forRequestID: "a+b.c"), ["top-second"])
        XCTAssertEqual(restored.topLevelSelections(forRequestID: "a.b"), ["top-nested-first"])
        XCTAssertEqual(restored.questionAnswers(forRequestID: "a", questionID: "b.topLevel"), ["question-colliding-with-old-top-level"])
    }

    func testSelectionStoreDoesNotRestoreAmbiguousLegacyCollisionKeys() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Task7.LegacyCollision.\(UUID().uuidString)"))
        defaults.set("ambiguous-question", forKey: "expanded.action.a.b.c")
        defaults.set("ambiguous-cross-type", forKey: "expanded.action.a.b.topLevel")

        let store = OriginalExpandedActionSelectionStore(defaults: defaults)
        XCTAssertTrue(store.questionAnswers(forRequestID: "a.b", questionID: "c").isEmpty)
        XCTAssertTrue(store.questionAnswers(forRequestID: "a", questionID: "b.c").isEmpty)
        XCTAssertTrue(store.topLevelSelections(forRequestID: "a.b").isEmpty)
        XCTAssertTrue(store.questionAnswers(forRequestID: "a", questionID: "b.topLevel").isEmpty)
    }

    private func preview(id: String, timestamp: Date?) -> ActionRequestPreview {
        ActionRequestPreview(request: ActionableRequest(
            requestId: id,
            sessionId: "session-1",
            source: "opencode",
            kind: .question,
            toolName: "question",
            details: ActionRequestDetails(
                options: [ActionRequestOption(id: "one", label: "One")],
                questions: [ActionRequestQuestion(id: "one", header: "one", prompt: "one")]
            ),
            actionableRequestLifecycleTimestamp: timestamp
        ))
    }
}
