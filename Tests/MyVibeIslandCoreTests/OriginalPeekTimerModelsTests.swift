import Foundation
import MyVibeIslandCore
import XCTest

final class OriginalPeekTimerModelsTests: XCTestCase {
    func testUnchangedPreservesStateAndProducesNoOperations() {
        let state = OriginalPeekTimerState(
            generation: 7,
            hasTimer: true,
            autoExpandedAt: 41
        )

        XCTAssertEqual(
            OriginalPeekTimerPlan.apply(.unchanged, to: state, now: 100),
            OriginalPeekTimerPlan(state: state, operations: [])
        )
    }

    func testCancelIncrementsGenerationAndOnlyInvalidatesAnExistingTimer() {
        XCTAssertEqual(
            OriginalPeekTimerPlan.apply(
                .cancel,
                to: OriginalPeekTimerState(
                    generation: 7,
                    hasTimer: true,
                    autoExpandedAt: 41
                ),
                now: 100
            ),
            OriginalPeekTimerPlan(
                state: OriginalPeekTimerState(
                    generation: 8,
                    hasTimer: false,
                    autoExpandedAt: nil
                ),
                operations: [.invalidateExisting]
            )
        )
        XCTAssertEqual(
            OriginalPeekTimerPlan.apply(
                .cancel,
                to: OriginalPeekTimerState(
                    generation: 7,
                    hasTimer: false,
                    autoExpandedAt: nil
                ),
                now: 100
            ),
            OriginalPeekTimerPlan(
                state: OriginalPeekTimerState(
                    generation: 8,
                    hasTimer: false,
                    autoExpandedAt: nil
                ),
                operations: []
            )
        )
    }

    func testTransientCancelsThenSchedulesOneShotAtTheNewGeneration() {
        XCTAssertEqual(
            OriginalPeekTimerPlan.apply(
                .transient,
                to: OriginalPeekTimerState(
                    generation: 2,
                    hasTimer: true,
                    autoExpandedAt: 40
                ),
                now: 100,
                dwell: 5
            ),
            OriginalPeekTimerPlan(
                state: OriginalPeekTimerState(
                    generation: 3,
                    hasTimer: true,
                    autoExpandedAt: 100
                ),
                operations: [
                    .invalidateExisting,
                    .scheduleOneShot(delay: 5, generation: 3),
                ]
            )
        )
    }

    func testRepeatedTransientInvalidatesAndReplacesGenerationAndTimestamp() {
        let initial = OriginalPeekTimerState(
            generation: 10,
            hasTimer: false,
            autoExpandedAt: nil
        )
        let first = OriginalPeekTimerPlan.apply(.transient, to: initial, now: 100, dwell: 5)
        let second = OriginalPeekTimerPlan.apply(.transient, to: first.state, now: 102, dwell: 5)

        XCTAssertEqual(first.state.generation, 11)
        XCTAssertEqual(first.state.autoExpandedAt, 100)
        XCTAssertEqual(
            first.operations,
            [.scheduleOneShot(delay: 5, generation: 11)]
        )
        XCTAssertEqual(
            second,
            OriginalPeekTimerPlan(
                state: OriginalPeekTimerState(
                    generation: 12,
                    hasTimer: true,
                    autoExpandedAt: 102
                ),
                operations: [
                    .invalidateExisting,
                    .scheduleOneShot(delay: 5, generation: 12),
                ]
            )
        )
    }

    func testGenerationIncrementWrapsFromMaxToMin() {
        let state = OriginalPeekTimerState(
            generation: .max,
            hasTimer: false,
            autoExpandedAt: nil
        )

        XCTAssertEqual(
            OriginalPeekTimerPlan.apply(.cancel, to: state, now: 100).state.generation,
            Int.min
        )
        XCTAssertEqual(
            OriginalPeekTimerPlan.apply(.transient, to: state, now: 100).state.generation,
            Int.min
        )
    }

    func testZeroSecondDwellSchedulesOneShotImmediately() {
        let plan = OriginalPeekTimerPlan.apply(
            .transient,
            to: OriginalPeekTimerState(
                generation: 4,
                hasTimer: false,
                autoExpandedAt: nil
            ),
            now: 100,
            dwell: 0
        )

        XCTAssertEqual(plan.operations, [.scheduleOneShot(delay: 0, generation: 5)])
    }

    func testCollapseDecisionCancelClearsTransientTimerState() {
        let decision = OriginalPeekDecision.resolve(.collapseAutoTransient)
        let plan = OriginalPeekTimerPlan.apply(
            decision.timerPolicy,
            to: OriginalPeekTimerState(
                generation: 4,
                hasTimer: true,
                autoExpandedAt: 100
            ),
            now: 101
        )

        XCTAssertEqual(
            plan,
            OriginalPeekTimerPlan(
                state: OriginalPeekTimerState(
                    generation: 5,
                    hasTimer: false,
                    autoExpandedAt: nil
                ),
                operations: [.invalidateExisting]
            )
        )
    }

    func testTimerModelsRoundTripCodableAndAreSendable() throws {
        let plan = OriginalPeekTimerPlan.apply(
            .transient,
            to: OriginalPeekTimerState(
                generation: 4,
                hasTimer: true,
                autoExpandedAt: 90
            ),
            now: 100,
            dwell: 5
        )

        XCTAssertEqual(
            try JSONDecoder().decode(
                OriginalPeekTimerPlan.self,
                from: JSONEncoder().encode(plan)
            ),
            plan
        )
        assertSendable(plan)
    }

    func testPureSliceExcludesRealTimersAsyncWrappersAndProducers() throws {
        let source = try originalPeekSource(named: "OriginalPeekTimerModels.swift")
            + originalPeekSource(named: "OriginalPeekDecisionModels.swift")
        let forbidden = [
            "NSTimer",
            "Foundation.Timer",
            "DispatchWorkItem",
            "DispatchQueue",
            "Task {",
            "Task.detached",
            "async ",
            "await ",
            "NotificationCenter",
            "pendingNotification",
            "producer",
            "dedupe",
        ]

        for term in forbidden {
            XCTAssertFalse(source.contains(term), term)
        }
    }

    func testApplyRequiresFiniteNonnegativeDwell() throws {
        let source = try originalPeekSource(named: "OriginalPeekTimerModels.swift")

        XCTAssertTrue(source.contains("precondition(dwell.isFinite && dwell >= 0)"))
    }

    func testPeekDecisionAndTimerModelsHaveNoProductionWiring() throws {
        let sourcesURL = packageRootURL.appendingPathComponent("Sources")
        let declarationFiles = [
            "OriginalPeekDecisionModels.swift",
            "OriginalPeekTimerModels.swift",
        ]
        let forbidden = [
            "OriginalPeekDecisionIntent",
            "OriginalPeekDecision.resolve",
            "OriginalPeekTimerPlan.apply",
            "OriginalPeekTimerOperation",
        ]

        for relativePath in try FileManager.default.subpathsOfDirectory(atPath: sourcesURL.path)
            where relativePath.hasSuffix(".swift")
                && !declarationFiles.contains(URL(fileURLWithPath: relativePath).lastPathComponent)
        {
            let source = try String(
                contentsOf: sourcesURL.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            for term in forbidden {
                XCTAssertFalse(source.contains(term), "\(relativePath): \(term)")
            }
        }
    }

    private func originalPeekSource(named name: String) throws -> String {
        let sourceURL = packageRootURL
            .appendingPathComponent("Sources/MyVibeIslandCore/Runtime")
            .appendingPathComponent(name)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assertSendable<T: Sendable>(_: T) {}
}
