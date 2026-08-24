import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitMemoryRestartGuardControllerTests: XCTestCase {
    @MainActor
    func testMemoryRestartGuardControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            MemoryRestartGuardControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/memory-restart-guard-controller-matrix")
        )

        let actual = MemoryRestartGuardControllerMatrixFixture(rows: [
            row(
                id: "restart-eligible-publishes-decision",
                state: MemoryRestartGuardState(restartCount: 0),
                policy: policy(labsRestartOptInEnabled: true, maxRestartAttempts: 1),
                actions: [
                    .evaluate(
                        snapshot: sample(physicalBytes: 1_500),
                        context: MemoryRestartGuardContext(
                            isIdle: true,
                            hasActiveSession: false,
                            hasPendingApproval: false
                        )
                    )
                ]
            ),
            row(
                id: "labs-disabled-warns-without-state-mutation",
                state: MemoryRestartGuardState(restartCount: 0),
                policy: policy(labsRestartOptInEnabled: false, maxRestartAttempts: 1),
                actions: [
                    .evaluate(
                        snapshot: sample(physicalBytes: 1_500),
                        context: MemoryRestartGuardContext(
                            isIdle: true,
                            hasActiveSession: false,
                            hasPendingApproval: false
                        )
                    )
                ]
            ),
            row(
                id: "record-restart-attempt-after-eligible-decision",
                state: MemoryRestartGuardState(restartCount: 0),
                policy: policy(labsRestartOptInEnabled: true, maxRestartAttempts: 2),
                actions: [
                    .evaluate(
                        snapshot: sample(physicalBytes: 1_500),
                        context: MemoryRestartGuardContext(
                            isIdle: true,
                            hasActiveSession: false,
                            hasPendingApproval: false
                        )
                    ),
                    .recordRestartAttempt("2026-07-08T10:00:00Z")
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerEvaluatesSnapshotAndPublishesRestartEligibleDecision() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitMemoryRestartGuardController(
            policy: MemoryRestartGuardPolicy(
                warningThresholdBytes: 512,
                restartThresholdBytes: 1_024,
                maxRestartAttempts: 1,
                labsRestartOptInEnabled: true
            ),
            publishDecision: { decision in
                events.append("\(decision.action.rawValue):\(decision.reason.rawValue)")
            }
        )

        let decision = controller.evaluate(
            snapshot: sample(physicalBytes: 1_500),
            context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false)
        )

        XCTAssertEqual(decision.action, .restartEligible)
        XCTAssertTrue(decision.isRestartEligible)
        XCTAssertEqual(controller.lastDecision, decision)
        XCTAssertEqual(events, ["restartEligible:eligible"])
    }

    @MainActor
    func testControllerRecordsWarningWithoutIncrementingRestartCount() {
        let controller = MyVibeIslandAppKitMemoryRestartGuardController(
            policy: MemoryRestartGuardPolicy(
                warningThresholdBytes: 512,
                restartThresholdBytes: 1_024,
                maxRestartAttempts: 1,
                labsRestartOptInEnabled: false
            )
        )

        let decision = controller.evaluate(
            snapshot: sample(physicalBytes: 1_500),
            context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false)
        )

        XCTAssertEqual(decision.action, .warnOnly)
        XCTAssertEqual(decision.reason, .labsOptInDisabled)
        XCTAssertEqual(controller.state.restartCount, 0)
        XCTAssertEqual(controller.lastDecision, decision)
    }

    @MainActor
    func testControllerRecordsRestartAttemptOnlyForEligibleDecision() {
        let controller = MyVibeIslandAppKitMemoryRestartGuardController(
            policy: MemoryRestartGuardPolicy(
                warningThresholdBytes: 512,
                restartThresholdBytes: 1_024,
                maxRestartAttempts: 2,
                labsRestartOptInEnabled: true
            )
        )
        _ = controller.evaluate(
            snapshot: sample(physicalBytes: 1_500),
            context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false)
        )

        let state = controller.recordRestartAttempt(at: "2026-07-08T10:00:00Z")

        XCTAssertEqual(state.restartCount, 1)
        XCTAssertEqual(state.lastRestartAt, "2026-07-08T10:00:00Z")
    }

    private func sample(physicalBytes: Int64) -> MemoryFootprintSnapshot {
        MemoryFootprintSnapshot(
            virtualBytes: physicalBytes * 2,
            residentBytes: physicalBytes,
            physicalFootprintBytes: physicalBytes,
            compressedBytes: 0,
            reusableBytes: 0
        )
    }

    private func policy(
        labsRestartOptInEnabled: Bool,
        maxRestartAttempts: Int
    ) -> MemoryRestartGuardPolicy {
        MemoryRestartGuardPolicy(
            warningThresholdBytes: 512,
            restartThresholdBytes: 1_024,
            maxRestartAttempts: maxRestartAttempts,
            labsRestartOptInEnabled: labsRestartOptInEnabled
        )
    }

    @MainActor
    private func row(
        id: String,
        state: MemoryRestartGuardState,
        policy: MemoryRestartGuardPolicy,
        actions: [MemoryRestartGuardControllerFixtureAction]
    ) -> MemoryRestartGuardControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitMemoryRestartGuardController(
            policy: policy,
            state: state,
            publishDecision: { decision in
                events.append("\(decision.action.rawValue):\(decision.reason.rawValue)")
            }
        )
        var outcomes: [MemoryRestartGuardControllerOutcomeSummary] = []

        for action in actions {
            switch action {
            case let .evaluate(snapshot, context):
                outcomes.append(.decision(MemoryRestartGuardDecisionSummary(controller.evaluate(
                    snapshot: snapshot,
                    context: context
                ))))
            case let .recordRestartAttempt(timestamp):
                outcomes.append(.state(MemoryRestartGuardStateSummary(controller.recordRestartAttempt(at: timestamp))))
            }
        }

        return MemoryRestartGuardControllerMatrixRow(
            id: id,
            actions: actions.map(\.summary),
            outcomes: outcomes,
            finalState: MemoryRestartGuardStateSummary(controller.state),
            lastDecision: controller.lastDecision.map(MemoryRestartGuardDecisionSummary.init),
            events: events
        )
    }
}

private struct MemoryRestartGuardControllerMatrixFixture: Codable, Equatable {
    let rows: [MemoryRestartGuardControllerMatrixRow]
}

private struct MemoryRestartGuardControllerMatrixRow: Codable, Equatable {
    let id: String
    let actions: [String]
    let outcomes: [MemoryRestartGuardControllerOutcomeSummary]
    let finalState: MemoryRestartGuardStateSummary
    let lastDecision: MemoryRestartGuardDecisionSummary?
    let events: [String]
}

private enum MemoryRestartGuardControllerFixtureAction {
    case evaluate(snapshot: MemoryFootprintSnapshot, context: MemoryRestartGuardContext)
    case recordRestartAttempt(String)

    var summary: String {
        switch self {
        case let .evaluate(snapshot, context):
            [
                "evaluate",
                "physical=\(snapshot.physicalFootprintBytes)",
                "idle=\(context.isIdle)",
                "active=\(context.hasActiveSession)",
                "pending=\(context.hasPendingApproval)"
            ].joined(separator: ":")
        case let .recordRestartAttempt(timestamp):
            "recordRestartAttempt:\(timestamp)"
        }
    }
}

private enum MemoryRestartGuardControllerOutcomeSummary: Codable, Equatable {
    case decision(MemoryRestartGuardDecisionSummary)
    case state(MemoryRestartGuardStateSummary)

    private enum CodingKeys: String, CodingKey {
        case kind
        case decision
        case state
    }

    private enum Kind: String, Codable {
        case decision
        case state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .decision:
            self = .decision(try container.decode(MemoryRestartGuardDecisionSummary.self, forKey: .decision))
        case .state:
            self = .state(try container.decode(MemoryRestartGuardStateSummary.self, forKey: .state))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .decision(decision):
            try container.encode(Kind.decision, forKey: .kind)
            try container.encode(decision, forKey: .decision)
        case let .state(state):
            try container.encode(Kind.state, forKey: .kind)
            try container.encode(state, forKey: .state)
        }
    }
}

private struct MemoryRestartGuardDecisionSummary: Codable, Equatable {
    let action: String
    let reason: String
    let isRestartEligible: Bool

    init(_ decision: MemoryRestartGuardDecision) {
        self.action = decision.action.rawValue
        self.reason = decision.reason.rawValue
        self.isRestartEligible = decision.isRestartEligible
    }
}

private struct MemoryRestartGuardStateSummary: Codable, Equatable {
    let restartCount: Int
    let lastRestartAt: String?
    let lastWarningAt: String?

    init(_ state: MemoryRestartGuardState) {
        self.restartCount = state.restartCount
        self.lastRestartAt = state.lastRestartAt
        self.lastWarningAt = state.lastWarningAt
    }
}
