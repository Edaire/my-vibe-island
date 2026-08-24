import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalSessionsListShellModelsTests: XCTestCase {
    func testShellPlanMatchesObservedStructure() {
        let plan = OriginalSessionsListShellPlan.original

        XCTAssertEqual(plan.scrollAxis, .vertical)
        XCTAssertFalse(plan.showsIndicators)
        XCTAssertEqual(plan.stackAlignment, .center)
        XCTAssertEqual(plan.stackSpacing, 4)
        XCTAssertEqual(
            plan.paddingPasses,
            [.horizontal(8), .top(4), .bottom(6)]
        )
        XCTAssertFalse(plan.highlightedIDChangeInitial)
        assertSendable(plan)
    }

    func testNilHighlightedIDLeavesScrollingUnchanged() {
        XCTAssertEqual(
            OriginalSessionsListHighlightedIDDecision.resolve(nil),
            .unchanged
        )
    }

    func testNonNilHighlightedIDScrollsToExactIDAtCenterWithObservedAnimation() {
        for id in ["session-1", ""] {
            XCTAssertEqual(
                OriginalSessionsListHighlightedIDDecision.resolve(id),
                .scrollTo(
                    id: id,
                    anchor: .center,
                    animation: .easeOut(duration: 0.18)
                )
            )
        }
    }

    func testMeasuredHeightUsesZeroWhenCurrentHeightIsNil() {
        XCTAssertEqual(
            OriginalSessionsListMeasuredHeightDecision.resolve(
                measured: 0.5,
                current: nil
            ),
            .unchanged
        )
        XCTAssertEqual(
            OriginalSessionsListMeasuredHeightDecision.resolve(
                measured: 0.500_001,
                current: nil
            ),
            .replace(with: 0.500_001)
        )
    }

    func testMeasuredHeightChangesOnlyWhenAbsoluteDeltaExceedsThreshold() {
        let cases: [(measured: Double, current: Double, expected: OriginalSessionsListMeasuredHeightDecision)] = [
            (100.49, 100, .unchanged),
            (100.5, 100, .unchanged),
            (99.5, 100, .unchanged),
            (100.500_001, 100, .replace(with: 100.500_001)),
            (99.499_999, 100, .replace(with: 99.499_999)),
        ]

        for testCase in cases {
            XCTAssertEqual(
                OriginalSessionsListMeasuredHeightDecision.resolve(
                    measured: testCase.measured,
                    current: testCase.current
                ),
                testCase.expected
            )
        }
    }

    func testMeasuredHeightDecisionDoesNotAddProducerBoundaryValidation() {
        XCTAssertEqual(
            OriginalSessionsListMeasuredHeightDecision.resolve(
                measured: -1,
                current: 0
            ),
            .replace(with: -1)
        )
        XCTAssertEqual(
            OriginalSessionsListMeasuredHeightDecision.resolve(
                measured: .infinity,
                current: 0
            ),
            .replace(with: .infinity)
        )
        XCTAssertEqual(
            OriginalSessionsListMeasuredHeightDecision.resolve(
                measured: .nan,
                current: 0
            ),
            .unchanged
        )
    }

    func testModelsAreSendableAndDoNotAdoptCodable() throws {
        assertSendable(OriginalSessionsListHighlightedIDDecision.unchanged)
        assertSendable(OriginalSessionsListMeasuredHeightDecision.unchanged)

        let declaration = try String(contentsOf: declarationURL, encoding: .utf8)
        XCTAssertFalse(declaration.contains("Codable"))
    }

    func testUnwiredSessionsListShellModelsHaveNoProductionConsumers() throws {
        let sourcesURL = packageRootURL.appendingPathComponent("Sources")
        let sourceFiles = try FileManager.default
            .subpathsOfDirectory(atPath: sourcesURL.path)
            .filter { $0.hasSuffix(".swift") }
            .filter {
                $0 != "MyVibeIslandCore/Runtime/OriginalSessionsListShellModels.swift"
            }
        let modelTypes = [
            "OriginalSessionsListShellPlan",
            "OriginalSessionsListHighlightedIDDecision",
        ]

        XCTAssertFalse(sourceFiles.isEmpty)
        for file in sourceFiles {
            let source = try String(
                contentsOf: sourcesURL.appendingPathComponent(file),
                encoding: .utf8
            )
            for modelType in modelTypes {
                XCTAssertFalse(source.contains(modelType), "\(file): \(modelType)")
            }
        }
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
            .appendingPathComponent("OriginalSessionsListShellModels.swift")
    }

    private func assertSendable<T: Sendable>(_: T) {}
}
