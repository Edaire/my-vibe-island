import XCTest
@testable import MyVibeIslandCore

final class MemoryRestartGuardModelsTests: XCTestCase {
    func testMemoryRestartGuardMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            MemoryRestartGuardMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/memory-restart-guard-matrix")
        )

        let guardModel = MemoryRestartGuard()
        let policy = MemoryRestartGuardPolicy(
            warningThresholdBytes: 512,
            restartThresholdBytes: 1_024,
            maxRestartAttempts: 1,
            labsRestartOptInEnabled: true
        )
        let actual = MemoryRestartGuardMatrixFixture(rows: [
            row(
                id: "below-warning-threshold",
                snapshot: snapshot(physicalFootprintBytes: 511),
                state: MemoryRestartGuardState(restartCount: -1),
                policy: policy,
                context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false),
                decision: guardModel.evaluate(
                    snapshot: snapshot(physicalFootprintBytes: 511),
                    state: MemoryRestartGuardState(restartCount: -1),
                    policy: policy,
                    context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false)
                )
            ),
            row(
                id: "below-restart-threshold",
                snapshot: snapshot(physicalFootprintBytes: 900),
                state: MemoryRestartGuardState(restartCount: 0),
                policy: policy,
                context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false),
                decision: guardModel.evaluate(
                    snapshot: snapshot(physicalFootprintBytes: 900),
                    state: MemoryRestartGuardState(restartCount: 0),
                    policy: policy,
                    context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false)
                )
            ),
            row(
                id: "labs-opt-in-disabled",
                snapshot: snapshot(physicalFootprintBytes: 1_500),
                state: MemoryRestartGuardState(restartCount: 0),
                policy: MemoryRestartGuardPolicy(
                    warningThresholdBytes: 512,
                    restartThresholdBytes: 1_024,
                    maxRestartAttempts: 1,
                    labsRestartOptInEnabled: false
                ),
                context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false),
                decision: guardModel.evaluate(
                    snapshot: snapshot(physicalFootprintBytes: 1_500),
                    state: MemoryRestartGuardState(restartCount: 0),
                    policy: MemoryRestartGuardPolicy(
                        warningThresholdBytes: 512,
                        restartThresholdBytes: 1_024,
                        maxRestartAttempts: 1,
                        labsRestartOptInEnabled: false
                    ),
                    context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false)
                )
            ),
            row(
                id: "not-idle-active-session",
                snapshot: snapshot(physicalFootprintBytes: 1_500),
                state: MemoryRestartGuardState(restartCount: 0),
                policy: policy,
                context: MemoryRestartGuardContext(isIdle: false, hasActiveSession: true, hasPendingApproval: true),
                decision: guardModel.evaluate(
                    snapshot: snapshot(physicalFootprintBytes: 1_500),
                    state: MemoryRestartGuardState(restartCount: 0),
                    policy: policy,
                    context: MemoryRestartGuardContext(isIdle: false, hasActiveSession: true, hasPendingApproval: true)
                )
            ),
            row(
                id: "restart-limit-reached",
                snapshot: snapshot(physicalFootprintBytes: 1_500),
                state: MemoryRestartGuardState(restartCount: 1),
                policy: policy,
                context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false),
                decision: guardModel.evaluate(
                    snapshot: snapshot(physicalFootprintBytes: 1_500),
                    state: MemoryRestartGuardState(restartCount: 1),
                    policy: policy,
                    context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false)
                )
            ),
            row(
                id: "restart-eligible",
                snapshot: snapshot(physicalFootprintBytes: 1_500),
                state: MemoryRestartGuardState(restartCount: 0),
                policy: policy,
                context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false),
                decision: guardModel.evaluate(
                    snapshot: snapshot(physicalFootprintBytes: 1_500),
                    state: MemoryRestartGuardState(restartCount: 0),
                    policy: policy,
                    context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false)
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRestartGuardPolicyRoundTripsThresholdAndLimits() throws {
        let policy = MemoryRestartGuardPolicy(
            warningThresholdBytes: 512,
            restartThresholdBytes: 1_024,
            maxRestartAttempts: 2,
            labsRestartOptInEnabled: true
        )

        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(MemoryRestartGuardPolicy.self, from: data)

        XCTAssertEqual(decoded, policy)
        XCTAssertEqual(decoded.maxRestartAttempts, 2)
    }

    func testRestartGuardDefaultsToWarnOnlyWithoutLabsOptIn() {
        let guardState = MemoryRestartGuardState(restartCount: 0)
        let policy = MemoryRestartGuardPolicy(
            warningThresholdBytes: 512,
            restartThresholdBytes: 1_024,
            maxRestartAttempts: 1,
            labsRestartOptInEnabled: false
        )
        let snapshot = MemoryFootprintSnapshot(
            virtualBytes: 4_096,
            residentBytes: 2_048,
            physicalFootprintBytes: 1_500,
            compressedBytes: 256,
            reusableBytes: 128
        )

        let decision = MemoryRestartGuard().evaluate(
            snapshot: snapshot,
            state: guardState,
            policy: policy,
            context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false)
        )

        XCTAssertEqual(decision.action, .warnOnly)
        XCTAssertFalse(decision.isRestartEligible)
        XCTAssertEqual(decision.reason, .labsOptInDisabled)
    }

    func testRestartGuardRequiresIdleAndAttemptsBelowLimitForRestartEligibility() {
        let guardModel = MemoryRestartGuard()
        let policy = MemoryRestartGuardPolicy(
            warningThresholdBytes: 512,
            restartThresholdBytes: 1_024,
            maxRestartAttempts: 1,
            labsRestartOptInEnabled: true
        )
        let snapshot = MemoryFootprintSnapshot(
            virtualBytes: 4_096,
            residentBytes: 2_048,
            physicalFootprintBytes: 1_500,
            compressedBytes: 256,
            reusableBytes: 128
        )

        let eligible = guardModel.evaluate(
            snapshot: snapshot,
            state: MemoryRestartGuardState(restartCount: 0),
            policy: policy,
            context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false)
        )
        XCTAssertEqual(eligible.action, .restartEligible)
        XCTAssertTrue(eligible.isRestartEligible)

        let busy = guardModel.evaluate(
            snapshot: snapshot,
            state: MemoryRestartGuardState(restartCount: 0),
            policy: policy,
            context: MemoryRestartGuardContext(isIdle: false, hasActiveSession: true, hasPendingApproval: true)
        )
        XCTAssertEqual(busy.action, .warnOnly)
        XCTAssertEqual(busy.reason, .notIdle)

        let exhausted = guardModel.evaluate(
            snapshot: snapshot,
            state: MemoryRestartGuardState(restartCount: 1),
            policy: policy,
            context: MemoryRestartGuardContext(isIdle: true, hasActiveSession: false, hasPendingApproval: false)
        )
        XCTAssertEqual(exhausted.action, .warnOnly)
        XCTAssertEqual(exhausted.reason, .restartLimitReached)
    }

    private func snapshot(physicalFootprintBytes: Int64) -> MemoryFootprintSnapshot {
        MemoryFootprintSnapshot(
            virtualBytes: 4_096,
            residentBytes: 2_048,
            physicalFootprintBytes: physicalFootprintBytes,
            compressedBytes: 256,
            reusableBytes: 128
        )
    }

    private func row(
        id: String,
        snapshot: MemoryFootprintSnapshot,
        state: MemoryRestartGuardState,
        policy: MemoryRestartGuardPolicy,
        context: MemoryRestartGuardContext,
        decision: MemoryRestartGuardDecision
    ) -> MemoryRestartGuardRowFixture {
        MemoryRestartGuardRowFixture(
            id: id,
            physicalFootprintBytes: snapshot.physicalFootprintBytes,
            restartCount: state.restartCount,
            warningThresholdBytes: policy.warningThresholdBytes,
            restartThresholdBytes: policy.restartThresholdBytes,
            maxRestartAttempts: policy.maxRestartAttempts,
            labsRestartOptInEnabled: policy.labsRestartOptInEnabled,
            isIdle: context.isIdle,
            hasActiveSession: context.hasActiveSession,
            hasPendingApproval: context.hasPendingApproval,
            action: decision.action.rawValue,
            reason: decision.reason.rawValue,
            isRestartEligible: decision.isRestartEligible
        )
    }

    private struct MemoryRestartGuardMatrixFixture: Codable, Equatable {
        let rows: [MemoryRestartGuardRowFixture]
    }

    private struct MemoryRestartGuardRowFixture: Codable, Equatable {
        let id: String
        let physicalFootprintBytes: Int64
        let restartCount: Int
        let warningThresholdBytes: Int64
        let restartThresholdBytes: Int64
        let maxRestartAttempts: Int
        let labsRestartOptInEnabled: Bool
        let isIdle: Bool
        let hasActiveSession: Bool
        let hasPendingApproval: Bool
        let action: String
        let reason: String
        let isRestartEligible: Bool
    }
}
