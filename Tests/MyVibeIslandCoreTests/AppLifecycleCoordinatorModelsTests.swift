import XCTest
@testable import MyVibeIslandCore

final class AppLifecycleCoordinatorModelsTests: XCTestCase {
    func testAppLifecycleCoordinatorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppLifecycleCoordinatorMatrixFixture.self,
            from: try FixtureLoader.data("settings/app-lifecycle-coordinator-matrix")
        )
        let coordinator = AppLifecycleCoordinator()
        let launched = AppLifecycleState(
            hasLaunched: true,
            route: .island,
            completedStartupSteps: [.createRuntime, .loadSettings]
        )
        let settingsLink = SettingsDeepLink(section: .about, rowId: "export")
        let terminated = coordinator.plan(.terminate, from: launched).nextState

        let cases = [
            AppLifecycleCoordinatorCase(
                name: "normal-launch-routes-island",
                projection: AppLifecyclePlanProjection(
                    coordinator.plan(.launch(context: AppLaunchContext()), from: AppLifecycleState())
                )
            ),
            AppLifecycleCoordinatorCase(
                name: "first-launch-routes-onboarding",
                projection: AppLifecyclePlanProjection(
                    coordinator.plan(.launch(context: AppLaunchContext(isFirstLaunch: true)), from: AppLifecycleState())
                )
            ),
            AppLifecycleCoordinatorCase(
                name: "pending-onboarding-routes-onboarding",
                projection: AppLifecyclePlanProjection(
                    coordinator.plan(
                        .launch(context: AppLaunchContext(hasPendingOnboarding: true)),
                        from: AppLifecycleState()
                    )
                )
            ),
            AppLifecycleCoordinatorCase(
                name: "launch-is-idempotent-after-startup",
                projection: AppLifecyclePlanProjection(
                    coordinator.plan(.launch(context: AppLaunchContext()), from: launched)
                )
            ),
            AppLifecycleCoordinatorCase(
                name: "reopen-default-route-shows-island",
                projection: AppLifecyclePlanProjection(
                    coordinator.plan(.reopen(target: .defaultRoute), from: launched)
                )
            ),
            AppLifecycleCoordinatorCase(
                name: "reopen-settings-keeps-deep-link",
                projection: AppLifecyclePlanProjection(
                    coordinator.plan(.reopen(target: .settings(settingsLink)), from: launched)
                )
            ),
            AppLifecycleCoordinatorCase(
                name: "reopen-onboarding-shows-onboarding",
                projection: AppLifecyclePlanProjection(
                    coordinator.plan(.reopen(target: .onboarding), from: launched)
                )
            ),
            AppLifecycleCoordinatorCase(
                name: "terminate-runs-shutdown-steps",
                projection: AppLifecyclePlanProjection(
                    coordinator.plan(.terminate, from: launched)
                )
            ),
            AppLifecycleCoordinatorCase(
                name: "terminate-is-idempotent-after-shutdown",
                projection: AppLifecyclePlanProjection(
                    coordinator.plan(.terminate, from: terminated)
                )
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testLaunchPlansStartupSequenceInDocumentedOrder() {
        let coordinator = AppLifecycleCoordinator()

        let plan = coordinator.plan(.launch(context: AppLaunchContext(isFirstLaunch: true)), from: AppLifecycleState())

        XCTAssertEqual(plan.steps, [
            .createRuntime,
            .loadSettings,
            .configureDockPolicy,
            .createScreenSelection,
            .createIslandWindow,
            .startBridge,
            .startRuntimeCoordinators,
            .runOnboardingDecision,
            .attachUpdateDriver,
            .scheduleHealthChecks
        ])
        XCTAssertTrue(plan.nextState.hasLaunched)
        XCTAssertEqual(plan.nextState.route, .onboarding)
    }

    func testReopenRoutesToSettingsOnDeepLinkAndIslandByDefault() {
        let coordinator = AppLifecycleCoordinator()
        let launched = AppLifecycleState(hasLaunched: true, route: .island)
        let settingsLink = SettingsDeepLink(section: .about, rowId: "export")

        let settings = coordinator.plan(.reopen(target: .settings(settingsLink)), from: launched)
        XCTAssertEqual(settings.steps, [.showSettingsWindow])
        XCTAssertEqual(settings.nextState.route, .settings)
        XCTAssertEqual(settings.nextState.pendingSettingsDeepLink, settingsLink)

        let island = coordinator.plan(.reopen(target: .defaultRoute), from: settings.nextState)
        XCTAssertEqual(island.steps, [.showIsland])
        XCTAssertEqual(island.nextState.route, .island)
        XCTAssertNil(island.nextState.pendingSettingsDeepLink)
    }

    func testTerminatePlansShutdownSequenceAndIsIdempotent() {
        let coordinator = AppLifecycleCoordinator()
        let launched = AppLifecycleState(hasLaunched: true, route: .island)

        let terminated = coordinator.plan(.terminate, from: launched)
        XCTAssertEqual(terminated.steps, [
            .persistSettingsAndSessions,
            .unregisterShortcuts,
            .closeWindows,
            .stopBridge,
            .flushDiagnostics
        ])
        XCTAssertTrue(terminated.nextState.isTerminated)
        XCTAssertEqual(terminated.nextState.route, .none)

        let repeated = coordinator.plan(.terminate, from: terminated.nextState)
        XCTAssertEqual(repeated.steps, [])
        XCTAssertEqual(repeated.nextState, terminated.nextState)
    }

    func testLaunchIsIdempotentAfterStartup() {
        let coordinator = AppLifecycleCoordinator()
        let launched = AppLifecycleState(hasLaunched: true, route: .island)

        let plan = coordinator.plan(.launch(context: AppLaunchContext()), from: launched)

        XCTAssertEqual(plan.steps, [])
        XCTAssertEqual(plan.nextState, launched)
    }

    func testLifecycleStateRoundTripsThroughJSON() throws {
        let state = AppLifecycleState(
            hasLaunched: true,
            route: .settings,
            pendingSettingsDeepLink: SettingsDeepLink(section: .integrations, rowId: "codex"),
            completedStartupSteps: [.createRuntime, .loadSettings],
            completedTerminationSteps: [.persistSettingsAndSessions],
            isTerminated: false
        )

        let decoded = try JSONDecoder().decode(AppLifecycleState.self, from: try JSONEncoder().encode(state))

        XCTAssertEqual(decoded, state)
    }

    private struct AppLifecycleCoordinatorMatrixFixture: Codable, Equatable {
        let cases: [AppLifecycleCoordinatorCase]
    }

    private struct AppLifecycleCoordinatorCase: Codable, Equatable {
        let name: String
        let projection: AppLifecyclePlanProjection
    }

    private struct AppLifecyclePlanProjection: Codable, Equatable {
        let route: AppLifecycleRoute
        let hasLaunched: Bool
        let isTerminated: Bool
        let pendingSettingsDeepLinkSection: SettingsSection?
        let pendingSettingsDeepLinkRowId: String?
        let completedStartupSteps: [AppLifecycleStep]
        let completedTerminationSteps: [AppLifecycleStep]
        let steps: [AppLifecycleStep]

        init(_ plan: AppLifecyclePlan) {
            self.route = plan.nextState.route
            self.hasLaunched = plan.nextState.hasLaunched
            self.isTerminated = plan.nextState.isTerminated
            self.pendingSettingsDeepLinkSection = plan.nextState.pendingSettingsDeepLink?.section
            self.pendingSettingsDeepLinkRowId = plan.nextState.pendingSettingsDeepLink?.rowId
            self.completedStartupSteps = plan.nextState.completedStartupSteps
            self.completedTerminationSteps = plan.nextState.completedTerminationSteps
            self.steps = plan.steps
        }
    }
}
