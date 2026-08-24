import XCTest
@testable import MyVibeIslandCore

final class DockLoginStateModelsTests: XCTestCase {
    func testDockLoginStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DockLoginStateMatrixFixture.self,
            from: try FixtureLoader.data("settings/dock-login-state-matrix")
        )
        let controller = DockIconController()
        let loginService = LaunchAtLoginService()
        let initialDock = DockIconControllerState()
        let shownDock = controller.plan(.setPreferredDockVisible(true, reason: .userPreference), from: initialDock)
        let unchangedDock = controller.plan(.setPreferredDockVisible(true, reason: .userPreference), from: shownDock.nextState)
        let hiddenDock = controller.plan(.setPreferredDockVisible(false, reason: .restoredSettings), from: shownDock.nextState)
        let initialLogin = LaunchAtLoginState()
        let desiredLogin = loginService.plan(.setDesiredEnabled(true), from: initialLogin)
        let matchedLogin = loginService.plan(.observeEnabled(true), from: desiredLogin.nextState)
        let mismatchedLogin = loginService.plan(.observeEnabled(false), from: matchedLogin.nextState)
        let failedLogin = loginService.plan(.recordFailure("registration denied"), from: mismatchedLogin.nextState)
        let menuSnapshot = AppMenuSnapshot(
            enabledCommands: [
                .quit,
                .toggleDockIcon,
                .openSettings,
                .toggleLaunchAtLogin,
                .checkForUpdates,
                .selectScreenMode(.manualDisplay),
                .exportDiagnostics
            ],
            diagnosticsExportAvailable: true
        )

        let fixture = DockLoginStateMatrixFixture(
            dockPlans: [
                DockIconPlanProjection(plan: shownDock),
                DockIconPlanProjection(plan: unchangedDock),
                DockIconPlanProjection(plan: hiddenDock)
            ],
            launchAtLoginPlans: [
                LaunchAtLoginPlanProjection(plan: desiredLogin),
                LaunchAtLoginPlanProjection(plan: matchedLogin),
                LaunchAtLoginPlanProjection(plan: mismatchedLogin),
                LaunchAtLoginPlanProjection(plan: failedLogin)
            ],
            safeDockMenuCommands: DockIconController.safeDockMenuCommands(from: menuSnapshot)
        )

        XCTAssertEqual(fixture, expected)
    }

    func testDockIconControllerDefaultsToAccessoryMode() {
        let state = DockIconControllerState()

        XCTAssertFalse(state.preferredDockVisible)
        XCTAssertEqual(state.currentPolicy, .accessory)
        XCTAssertEqual(state.reopenBehavior, .showIsland)
    }

    func testDockIconControllerPlansExplicitPolicyChangesOnlyWhenNeeded() {
        let controller = DockIconController()
        let initial = DockIconControllerState()

        let show = controller.plan(.setPreferredDockVisible(true, reason: .userPreference), from: initial)
        XCTAssertEqual(show.action, .setRegularPolicy)
        XCTAssertTrue(show.nextState.preferredDockVisible)
        XCTAssertEqual(show.nextState.currentPolicy, .regular)
        XCTAssertEqual(show.nextState.lastPolicyChangeReason, .userPreference)

        let unchanged = controller.plan(.setPreferredDockVisible(true, reason: .userPreference), from: show.nextState)
        XCTAssertEqual(unchanged.action, .noChange)
        XCTAssertEqual(unchanged.nextState, show.nextState)

        let hide = controller.plan(.setPreferredDockVisible(false, reason: .userPreference), from: show.nextState)
        XCTAssertEqual(hide.action, .setAccessoryPolicy)
        XCTAssertEqual(hide.nextState.currentPolicy, .accessory)
    }

    func testDockMenuMirrorsOnlySafeCommands() {
        let snapshot = AppMenuSnapshot(enabledCommands: [
            .quit,
            .toggleDockIcon,
            .openSettings,
            .toggleLaunchAtLogin,
            .checkForUpdates,
            .selectScreenMode(.manualDisplay),
            .exportDiagnostics
        ], diagnosticsExportAvailable: true)

        let commands = DockIconController.safeDockMenuCommands(from: snapshot)

        XCTAssertEqual(commands, [.openSettings, .checkForUpdates, .exportDiagnostics, .quit])
    }

    func testLaunchAtLoginServicePlansDesiredObservedAndFailureStates() {
        let service = LaunchAtLoginService()
        let initial = LaunchAtLoginState()

        let desired = service.plan(.setDesiredEnabled(true), from: initial)
        XCTAssertTrue(desired.nextState.desiredEnabled)
        XCTAssertEqual(desired.nextState.reconciliationResult, .pending)

        let observed = service.plan(.observeEnabled(true), from: desired.nextState)
        XCTAssertEqual(observed.action, .stateMatched)
        XCTAssertTrue(observed.nextState.observedEnabled)
        XCTAssertEqual(observed.nextState.reconciliationResult, .matched)

        let failed = service.plan(.recordFailure("registration denied"), from: observed.nextState)
        XCTAssertEqual(failed.action, .recordRepairHint)
        XCTAssertEqual(failed.nextState.reconciliationResult, .failed)
        XCTAssertEqual(failed.nextState.lastError, "registration denied")
    }

    func testLaunchAtLoginServiceReportsMismatchWithoutMutatingDesiredState() {
        let service = LaunchAtLoginService()
        let state = LaunchAtLoginState(desiredEnabled: true, observedEnabled: true, reconciliationResult: .matched)

        let observed = service.plan(.observeEnabled(false), from: state)

        XCTAssertEqual(observed.action, .needsReconcile)
        XCTAssertTrue(observed.nextState.desiredEnabled)
        XCTAssertFalse(observed.nextState.observedEnabled)
        XCTAssertEqual(observed.nextState.reconciliationResult, .mismatched)
    }

    private struct DockLoginStateMatrixFixture: Codable, Equatable {
        let dockPlans: [DockIconPlanProjection]
        let launchAtLoginPlans: [LaunchAtLoginPlanProjection]
        let safeDockMenuCommands: [AppCommand]
    }

    private struct DockIconPlanProjection: Codable, Equatable {
        let action: DockIconControllerAction
        let nextState: DockIconControllerState

        init(plan: DockIconControllerPlan) {
            self.action = plan.action
            self.nextState = plan.nextState
        }
    }

    private struct LaunchAtLoginPlanProjection: Codable, Equatable {
        let action: LaunchAtLoginPlanAction
        let nextState: LaunchAtLoginState

        init(plan: LaunchAtLoginPlan) {
            self.action = plan.action
            self.nextState = plan.nextState
        }
    }
}
