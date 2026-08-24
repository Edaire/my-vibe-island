import XCTest
@testable import MyVibeIslandCore

final class AppRuntimeCompositionModelsTests: XCTestCase {
    func testAppRuntimeCompositionMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppRuntimeCompositionMatrixFixture.self,
            from: try FixtureLoader.data("settings/app-runtime-composition-matrix")
        )
        let composition = AppRuntimeComposition()
        let defaultSnapshot = AppRuntimeCompositionSnapshot.defaultAppShell()
        let started = observedAll(composition, from: defaultSnapshot)
        let stopPlan = composition.plan(.stopAll, from: started)
        let stopped = observedAll(composition, from: stopPlan.nextSnapshot, running: false)
        let disablePlan = composition.plan(.disable(.updateCoordinator), from: started)
        let disabledRunning = composition.plan(.markStopped(.updateCoordinator), from: disablePlan.nextSnapshot).nextSnapshot
        let disabledStopped = composition.plan(.disable(.screenSelectionCoordinator), from: defaultSnapshot).nextSnapshot

        let cases = [
            AppRuntimeCompositionCase(
                name: "default-app-shell-owner-order",
                projection: AppRuntimeCompositionProjection(snapshot: defaultSnapshot, actions: [])
            ),
            AppRuntimeCompositionCase(
                name: "start-all-starts-enabled-owners-in-order",
                projection: AppRuntimeCompositionProjection(composition.plan(.startAll, from: defaultSnapshot))
            ),
            AppRuntimeCompositionCase(
                name: "start-all-is-idempotent-when-running",
                projection: AppRuntimeCompositionProjection(composition.plan(.startAll, from: started))
            ),
            AppRuntimeCompositionCase(
                name: "stop-all-stops-running-owners-in-reverse-order",
                projection: AppRuntimeCompositionProjection(stopPlan)
            ),
            AppRuntimeCompositionCase(
                name: "stop-all-is-idempotent-when-stopped",
                projection: AppRuntimeCompositionProjection(composition.plan(.stopAll, from: stopped))
            ),
            AppRuntimeCompositionCase(
                name: "disable-running-owner-stops-only-that-owner",
                projection: AppRuntimeCompositionProjection(disablePlan)
            ),
            AppRuntimeCompositionCase(
                name: "disable-running-owner-is-idempotent",
                projection: AppRuntimeCompositionProjection(composition.plan(.disable(.updateCoordinator), from: disabledRunning))
            ),
            AppRuntimeCompositionCase(
                name: "enable-owner-does-not-start-it",
                projection: AppRuntimeCompositionProjection(composition.plan(.enable(.screenSelectionCoordinator), from: disabledStopped))
            ),
            AppRuntimeCompositionCase(
                name: "start-all-after-enable-starts-owner",
                projection: AppRuntimeCompositionProjection(
                    composition.plan(
                        .startAll,
                        from: composition.plan(.enable(.screenSelectionCoordinator), from: disabledStopped).nextSnapshot
                    )
                )
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testDefaultSnapshotContainsDocumentedOwnersInStartupOrder() {
        let snapshot = AppRuntimeCompositionSnapshot.defaultAppShell()

        XCTAssertEqual(snapshot.owners.map(\.owner), [
            .bridgeServer,
            .sessionCoordinator,
            .notchViewModel,
            .overlayController,
            .integrationCoordinator,
            .actionRouter,
            .terminalJumpRouter,
            .notificationCoordinator,
            .soundCoordinator,
            .usageCoordinator,
            .diagnosticsCoordinator,
            .settingsStore,
            .onboardingCoordinator,
            .appMenuController,
            .dockIconController,
            .launchAtLoginService,
            .updateCoordinator,
            .screenSelectionCoordinator,
            .whatsNewStore
        ])
        XCTAssertTrue(snapshot.owners.allSatisfy(\.isEnabled))
        XCTAssertFalse(snapshot.owners.contains(where: \.isRunning))
    }

    func testStartPlanDoesNotPredeclareOwnersRunningUntilObserved() {
        let composition = AppRuntimeComposition()
        let snapshot = AppRuntimeCompositionSnapshot.defaultAppShell()

        let startPlan = composition.plan(.startAll, from: snapshot)

        XCTAssertTrue(startPlan.actions.allSatisfy { $0.kind == .start })
        XCTAssertTrue(startPlan.nextSnapshot.owners.allSatisfy { !$0.isRunning })

        let observed = composition.plan(
            .markRunning(.bridgeServer),
            from: startPlan.nextSnapshot
        ).nextSnapshot

        XCTAssertTrue(observed.state(for: .bridgeServer)?.isRunning == true)
        XCTAssertFalse(observed.state(for: .sessionCoordinator)?.isRunning == true)
    }

    func testObservedStopMakesTerminationPlanTargetOnlyRealOwner() {
        let composition = AppRuntimeComposition()
        let started = composition.plan(.markRunning(.bridgeServer), from: .defaultAppShell()).nextSnapshot

        let stopPlan = composition.plan(.stopAll, from: started)

        XCTAssertEqual(stopPlan.actions, [AppRuntimeOwnerAction(owner: .bridgeServer, kind: .stop)])
    }

    func testStartAllPlansEnabledOwnersInOrderAndIsIdempotent() {
        let composition = AppRuntimeComposition()
        let snapshot = AppRuntimeCompositionSnapshot.defaultAppShell()

        let plan = composition.plan(.startAll, from: snapshot)

        XCTAssertEqual(plan.actions.map(\.kind), Array(repeating: .start, count: snapshot.owners.count))
        XCTAssertEqual(plan.actions.map(\.owner), snapshot.owners.map(\.owner))
        XCTAssertTrue(plan.nextSnapshot.owners.allSatisfy { !$0.isRunning })

        let observed = observedAll(composition, from: plan.nextSnapshot)
        let repeated = composition.plan(.startAll, from: observed)
        XCTAssertEqual(repeated.actions, [])
        XCTAssertEqual(repeated.nextSnapshot, observed)
    }

    func testStopAllPlansRunningOwnersInReverseOrderAndIsIdempotent() {
        let composition = AppRuntimeComposition()
        let started = observedAll(composition, from: .defaultAppShell())

        let plan = composition.plan(.stopAll, from: started)

        XCTAssertEqual(plan.actions.map(\.kind), Array(repeating: .stop, count: started.owners.count))
        XCTAssertEqual(plan.actions.map(\.owner), started.owners.map(\.owner).reversed())
        XCTAssertTrue(plan.nextSnapshot.owners.allSatisfy(\.isRunning))

        let stopped = observedAll(composition, from: plan.nextSnapshot, running: false)
        let repeated = composition.plan(.stopAll, from: stopped)
        XCTAssertEqual(repeated.actions, [])
        XCTAssertEqual(repeated.nextSnapshot, stopped)
    }

    func testDisableRunningOwnerStopsOnlyThatOwnerAndKeepsOrderStable() {
        let composition = AppRuntimeComposition()
        let started = observedAll(composition, from: .defaultAppShell())

        let plan = composition.plan(.disable(.updateCoordinator), from: started)

        XCTAssertEqual(plan.actions, [
            AppRuntimeOwnerAction(owner: .updateCoordinator, kind: .stop)
        ])
        XCTAssertEqual(plan.nextSnapshot.owners.map(\.owner), started.owners.map(\.owner))
        XCTAssertEqual(plan.nextSnapshot.state(for: .updateCoordinator)?.isEnabled, false)
        XCTAssertEqual(plan.nextSnapshot.state(for: .updateCoordinator)?.isRunning, true)

        let observed = composition.plan(.markStopped(.updateCoordinator), from: plan.nextSnapshot).nextSnapshot
        let repeated = composition.plan(.disable(.updateCoordinator), from: observed)
        XCTAssertEqual(repeated.actions, [])
        XCTAssertEqual(repeated.nextSnapshot, observed)
    }

    func testEnableOwnerDoesNotStartUntilStartAll() {
        let composition = AppRuntimeComposition()
        let disabled = composition.plan(.disable(.screenSelectionCoordinator), from: .defaultAppShell()).nextSnapshot

        let enabled = composition.plan(.enable(.screenSelectionCoordinator), from: disabled)
        XCTAssertEqual(enabled.actions, [])
        XCTAssertEqual(enabled.nextSnapshot.state(for: .screenSelectionCoordinator)?.isEnabled, true)
        XCTAssertEqual(enabled.nextSnapshot.state(for: .screenSelectionCoordinator)?.isRunning, false)

        let started = composition.plan(.startAll, from: enabled.nextSnapshot)
        XCTAssertTrue(started.actions.contains(AppRuntimeOwnerAction(owner: .screenSelectionCoordinator, kind: .start)))
        XCTAssertEqual(started.nextSnapshot.state(for: .screenSelectionCoordinator)?.isRunning, false)
    }

    private func observedAll(
        _ composition: AppRuntimeComposition,
        from snapshot: AppRuntimeCompositionSnapshot,
        running: Bool = true
    ) -> AppRuntimeCompositionSnapshot {
        snapshot.owners.reduce(snapshot) { current, state in
            composition.plan(
                running ? .markRunning(state.owner) : .markStopped(state.owner),
                from: current
            ).nextSnapshot
        }
    }

    func testSnapshotRoundTripsThroughJSON() throws {
        let snapshot = AppRuntimeCompositionSnapshot(owners: [
            AppRuntimeOwnerState(owner: .bridgeServer, isEnabled: true, isRunning: true),
            AppRuntimeOwnerState(owner: .updateCoordinator, isEnabled: false, isRunning: false)
        ])

        let decoded = try JSONDecoder().decode(
            AppRuntimeCompositionSnapshot.self,
            from: try JSONEncoder().encode(snapshot)
        )

        XCTAssertEqual(decoded, snapshot)
    }

    private struct AppRuntimeCompositionMatrixFixture: Codable, Equatable {
        let cases: [AppRuntimeCompositionCase]
    }

    private struct AppRuntimeCompositionCase: Codable, Equatable {
        let name: String
        let projection: AppRuntimeCompositionProjection
    }

    private struct AppRuntimeCompositionProjection: Codable, Equatable {
        let ownerCount: Int
        let enabledOwnerCount: Int
        let runningOwnerCount: Int
        let disabledOwners: [AppRuntimeOwner]
        let stoppedOwnerCount: Int
        let firstOwner: AppRuntimeOwner?
        let lastOwner: AppRuntimeOwner?
        let actionCount: Int
        let firstActions: [String]
        let lastActions: [String]

        init(_ plan: AppRuntimeCompositionPlan) {
            self.init(snapshot: plan.nextSnapshot, actions: plan.actions)
        }

        init(snapshot: AppRuntimeCompositionSnapshot, actions: [AppRuntimeOwnerAction]) {
            self.ownerCount = snapshot.owners.count
            self.enabledOwnerCount = snapshot.owners.filter(\.isEnabled).count
            self.runningOwnerCount = snapshot.owners.filter(\.isRunning).count
            self.disabledOwners = snapshot.owners.filter { !$0.isEnabled }.map(\.owner)
            self.stoppedOwnerCount = snapshot.owners.filter { !$0.isRunning }.count
            self.firstOwner = snapshot.owners.first?.owner
            self.lastOwner = snapshot.owners.last?.owner
            self.actionCount = actions.count
            let labels = actions.map(Self.actionLabel)
            self.firstActions = Array(labels.prefix(4))
            self.lastActions = Array(labels.suffix(4))
        }

        private static func actionLabel(_ action: AppRuntimeOwnerAction) -> String {
            "\(action.kind.rawValue):\(action.owner.rawValue)"
        }
    }
}
