import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalSessionCardShellModelsTests: XCTestCase {
    func testHorizontalBranchPlanMatchesObservedStructure() {
        let plan = OriginalSessionCardShellPlan.horizontalBranch

        XCTAssertEqual(plan.axis, .horizontal)
        XCTAssertEqual(plan.alignment, .center)
        XCTAssertEqual(plan.spacing, 8)
        XCTAssertEqual(plan.paddingPasses, [.horizontal(8), .vertical(6)])
        XCTAssertEqual(plan.cornerStyle, .continuous)
        XCTAssertEqual(plan.cornerRadius, 10)
        XCTAssertEqual(plan.strokeWidth, 1)
        XCTAssertEqual(plan.animation, .easeInOut(duration: 0.15))
        assertSendable(plan)
    }

    func testVerticalBranchPlanMatchesObservedStructure() {
        let plan = OriginalSessionCardShellPlan.verticalBranch

        XCTAssertEqual(plan.axis, .vertical)
        XCTAssertEqual(plan.alignment, .center)
        XCTAssertEqual(plan.spacing, 8)
        XCTAssertEqual(plan.paddingPasses, [.horizontal(8), .vertical(8)])
        XCTAssertEqual(plan.cornerStyle, .continuous)
        XCTAssertEqual(plan.cornerRadius, 10)
        XCTAssertEqual(plan.strokeWidth, 1)
        XCTAssertEqual(plan.animation, .easeInOut(duration: 0.15))
        assertSendable(plan)
    }

    func testSwitcherHighlightRequiresNonNilExactIDEquality() {
        let cases: [(cardID: String, highlightedID: String?, expected: Bool)] = [
            ("card-1", nil, false),
            ("card-1", "card-2", false),
            ("card-1", "card-1", true),
            ("", "", true),
        ]

        for testCase in cases {
            XCTAssertEqual(
                OriginalSessionCardHorizontalVisualDecision.resolve(
                    isHovered: false,
                    cardID: testCase.cardID,
                    highlightedID: testCase.highlightedID
                ).isHighlighted,
                testCase.expected
            )
            XCTAssertEqual(
                OriginalSessionCardVerticalVisualDecision.resolve(
                    isHovered: false,
                    isApprovalHovered: false,
                    cardID: testCase.cardID,
                    highlightedID: testCase.highlightedID
                ).isHighlighted,
                testCase.expected
            )
        }
    }

    func testHorizontalVisualDecisionCoversInteractionAndHighlightPriorityMatrix() {
        let cases: [(
            isHovered: Bool,
            highlightedID: String?,
            expectedHighlighted: Bool,
            expectedEmphasized: Bool,
            expectedFill: OriginalSessionCardShellColor,
            expectedStroke: OriginalSessionCardShellColor
        )] = [
            (false, nil, false, false, .clear, .clear),
            (false, "card", true, true, .white(opacity: 0.08), .white(opacity: 0.25)),
            (true, nil, false, true, .white(opacity: 0.08), .white(opacity: 0.06)),
            (true, "card", true, true, .white(opacity: 0.08), .white(opacity: 0.25)),
        ]

        for testCase in cases {
            let decision = OriginalSessionCardHorizontalVisualDecision.resolve(
                isHovered: testCase.isHovered,
                cardID: "card",
                highlightedID: testCase.highlightedID
            )

            XCTAssertEqual(decision.isHighlighted, testCase.expectedHighlighted)
            XCTAssertEqual(decision.emphasized, testCase.expectedEmphasized)
            XCTAssertEqual(decision.fill, testCase.expectedFill)
            XCTAssertEqual(decision.stroke, testCase.expectedStroke)
            XCTAssertEqual(decision.animationValue, testCase.expectedEmphasized)
            XCTAssertEqual(decision.animation, OriginalSessionCardShellPlan.horizontalBranch.animation)
            assertSendable(decision)
        }
    }

    func testVerticalVisualDecisionCoversInteractionAndHighlightTruthTable() {
        let cases: [(
            isHovered: Bool,
            isApprovalHovered: Bool,
            highlightedID: String?,
            expectedEmphasized: Bool,
            expectedFill: OriginalSessionCardShellColor,
            expectedStroke: OriginalSessionCardShellColor
        )] = [
            (false, false, nil, false, .clear, .clear),
            (false, false, "card", true, .white(opacity: 0.10), .white(opacity: 0.25)),
            (false, true, nil, false, .clear, .clear),
            (false, true, "card", true, .white(opacity: 0.10), .white(opacity: 0.25)),
            (true, false, nil, false, .clear, .white(opacity: 0.08)),
            (true, false, "card", true, .white(opacity: 0.10), .white(opacity: 0.25)),
            (true, true, nil, true, .white(opacity: 0.10), .clear),
            (true, true, "card", true, .white(opacity: 0.10), .white(opacity: 0.25)),
        ]

        for testCase in cases {
            let decision = OriginalSessionCardVerticalVisualDecision.resolve(
                isHovered: testCase.isHovered,
                isApprovalHovered: testCase.isApprovalHovered,
                cardID: "card",
                highlightedID: testCase.highlightedID
            )

            XCTAssertEqual(decision.isHighlighted, testCase.highlightedID == "card")
            XCTAssertEqual(decision.emphasized, testCase.expectedEmphasized)
            XCTAssertEqual(decision.fill, testCase.expectedFill)
            XCTAssertEqual(decision.stroke, testCase.expectedStroke)
            XCTAssertEqual(decision.animationValue, testCase.expectedEmphasized)
            XCTAssertEqual(decision.animation, OriginalSessionCardShellPlan.verticalBranch.animation)
            assertSendable(decision)
        }
    }

    func testDeclarationHasNoUIImportsOrCodable() throws {
        let declaration = try String(contentsOf: declarationURL, encoding: .utf8)

        XCTAssertFalse(declaration.contains("import SwiftUI"))
        XCTAssertFalse(declaration.contains("import AppKit"))
        XCTAssertFalse(declaration.contains("Codable"))
    }

    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var declarationURL: URL {
        packageRootURL
            .appendingPathComponent("Sources/MyVibeIslandCore/Runtime")
            .appendingPathComponent("OriginalSessionCardShellModels.swift")
    }

    private func assertSendable<T: Sendable>(_: T) {}
}
