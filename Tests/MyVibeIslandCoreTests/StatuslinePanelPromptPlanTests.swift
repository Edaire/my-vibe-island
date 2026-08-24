import XCTest
@testable import MyVibeIslandCore

final class StatuslinePanelPromptPlanTests: XCTestCase {
    func testStatuslinePanelPromptPlanMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            StatuslinePanelPromptPlanMatrixFixture.self,
            from: try FixtureLoader.data("agents/statusline-panel-prompt-plan-matrix")
        )

        let actual = StatuslinePanelPromptPlanMatrixFixture(rows: [
            row(id: "deduped-placeholders-enabled", plan: StatuslinePanelPromptPlan(
                sourceId: "codex",
                templateId: "approval-panel",
                placeholderKeys: ["sessionId", "cwd", "sessionId"],
                isEnabled: true
            )),
            row(id: "disabled-empty-placeholders", plan: StatuslinePanelPromptPlan(
                sourceId: "opencode",
                templateId: "question-panel",
                placeholderKeys: [],
                isEnabled: false
            )),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testStatuslinePanelPromptPlanStoresTemplateShapeWithoutRawPromptText() throws {
        let plan = StatuslinePanelPromptPlan(
            sourceId: "codex",
            templateId: "approval-panel",
            placeholderKeys: ["sessionId", "cwd", "sessionId"],
            isEnabled: true
        )

        XCTAssertEqual(plan.placeholderKeys, ["cwd", "sessionId"])
        XCTAssertEqual(plan.diagnosticSummary.placeholderCount, 2)
        XCTAssertTrue(plan.diagnosticSummary.isEnabled)

        let encoded = String(data: try JSONEncoder().encode(plan.diagnosticSummary), encoding: .utf8) ?? ""
        XCTAssertFalse(encoded.contains("codex"))
        XCTAssertFalse(encoded.contains("approval-panel"))
        XCTAssertFalse(encoded.contains("cwd"))
        XCTAssertFalse(encoded.contains("sessionId"))
    }

    private func row(
        id: String,
        plan: StatuslinePanelPromptPlan
    ) -> StatuslinePanelPromptPlanMatrixRow {
        StatuslinePanelPromptPlanMatrixRow(
            id: id,
            sourceId: plan.sourceId,
            templateId: plan.templateId,
            placeholderKeys: plan.placeholderKeys,
            isEnabled: plan.isEnabled,
            diagnosticSummary: StatuslinePanelPromptPlanDiagnosticFixture(
                placeholderCount: plan.diagnosticSummary.placeholderCount,
                isEnabled: plan.diagnosticSummary.isEnabled
            )
        )
    }

    private struct StatuslinePanelPromptPlanMatrixFixture: Codable, Equatable {
        let rows: [StatuslinePanelPromptPlanMatrixRow]
    }

    private struct StatuslinePanelPromptPlanMatrixRow: Codable, Equatable {
        let id: String
        let sourceId: String
        let templateId: String
        let placeholderKeys: [String]
        let isEnabled: Bool
        let diagnosticSummary: StatuslinePanelPromptPlanDiagnosticFixture
    }

    private struct StatuslinePanelPromptPlanDiagnosticFixture: Codable, Equatable {
        let placeholderCount: Int
        let isEnabled: Bool
    }
}
