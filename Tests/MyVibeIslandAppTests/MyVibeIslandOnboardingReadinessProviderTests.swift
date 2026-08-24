import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandOnboardingReadinessProviderTests: XCTestCase {
    func testInstalledHealthyIntegrationAllowsStarting() {
        let state = provider.state(from: integrationState(
            installState: .installed,
            healthState: .healthy
        ))

        XCTAssertEqual(state.readinessOutcome, .ready)
        XCTAssertTrue(state.nextActions.contains(.startUsing))
    }

    func testMissingIntegrationUsesDemoOnlyActions() {
        let state = provider.state(from: integrationState(
            installState: .notInstalled,
            healthState: .unknown
        ))

        XCTAssertEqual(state.readinessOutcome, .demoOnly)
        XCTAssertEqual(state.nextActions, [.startDemo, .openSettings])
    }

    func testFailedRepairableIntegrationBlocksCompletion() {
        let state = provider.state(from: IntegrationCoordinatorState(rows: [
            IntegrationStatusRow(
                sourceId: "codex",
                displayName: "Codex CLI",
                supportLevel: .supported,
                installState: .needsRepair,
                healthState: .failed,
                repairAction: "repair",
                diagnostics: ["configMalformed"]
            )
        ]))

        XCTAssertEqual(state.readinessOutcome, .blocked)
        XCTAssertFalse(state.nextActions.contains(.startUsing))
        XCTAssertTrue(state.nextActions.contains(.openSettings))
    }

    private let provider = MyVibeIslandOnboardingReadinessProvider()

    private func integrationState(
        installState: IntegrationInstallState,
        healthState: IntegrationHealthState
    ) -> IntegrationCoordinatorState {
        IntegrationCoordinatorState(rows: [
            IntegrationStatusRow(
                sourceId: "codex",
                displayName: "Codex CLI",
                supportLevel: .supported,
                installState: installState,
                healthState: healthState
            )
        ])
    }
}
