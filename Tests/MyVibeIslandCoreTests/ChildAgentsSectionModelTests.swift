import XCTest
@testable import MyVibeIslandCore

final class ChildAgentsSectionModelTests: XCTestCase {
    func testRuntimeProfileUsesV3PreferencesAndReasoningNormalization() {
        XCTAssertEqual(
            ChildAgentRuntimeProfileText.resolve(
                model: "gpt-5.6-terra",
                reasoningEffort: "medium",
                showModel: true,
                showReasoningEffort: true
            ),
            "gpt-5.6-terra · Medium"
        )
        XCTAssertEqual(
            ChildAgentRuntimeProfileText.resolve(
                model: "gpt-5.6-terra",
                reasoningEffort: "xhigh",
                showModel: false,
                showReasoningEffort: true
            ),
            "XHigh"
        )
        XCTAssertNil(
            ChildAgentRuntimeProfileText.resolve(
                model: " ",
                reasoningEffort: " ",
                showModel: true,
                showReasoningEffort: true
            )
        )
    }

    func testRuntimeProfilePreservesUnknownTrimmedReasoningValue() {
        XCTAssertEqual(
            ChildAgentRuntimeProfileText.resolve(
                model: nil,
                reasoningEffort: "  deliberate  ",
                showModel: false,
                showReasoningEffort: true
            ),
            "deliberate"
        )
    }

    func testShowingDetailsPrioritizesRunningTaskChildrenBeforeCompletedRowsAndCapsAtFive() {
        let children = [
            child("running-1", status: "running"),
            child("done-1", status: "completed"),
            child("running-2", status: "running"),
            child("done-2", status: "completed"),
            child("running-3", status: "running"),
            child("done-3", status: "completed"),
            child("running-4", status: "running"),
        ]

        let model = ChildAgentsSectionModel.resolve(
            taskSubagents: children,
            showSubagents: true
        )

        XCTAssertEqual(model.visibleTaskSubagents.map(\.id), [
            "running-1", "running-2", "running-3", "running-4", "done-1",
        ])
        XCTAssertEqual(model.overflow.runningCount, 0)
        XCTAssertEqual(model.overflow.completedCount, 2)
        XCTAssertEqual(model.hiddenRunningCount, 0)
    }

    func testHidingDetailsSuppressesRowsAndRetainsTheTotalRunningCount() {
        let model = ChildAgentsSectionModel.resolve(
            taskSubagents: [
                child("running", status: "running"),
                child("done", status: "completed"),
                child("unknown", status: nil),
            ],
            showSubagents: false
        )

        XCTAssertTrue(model.visibleTaskSubagents.isEmpty)
        XCTAssertEqual(model.overflow.runningCount, 0)
        XCTAssertEqual(model.overflow.completedCount, 0)
        XCTAssertEqual(model.hiddenRunningCount, 2)
    }

    private func child(_ id: String, status: String?) -> SubagentState {
        SubagentState(
            id: id,
            source: "codex",
            parentSessionId: "parent",
            status: status
        )
    }
}
