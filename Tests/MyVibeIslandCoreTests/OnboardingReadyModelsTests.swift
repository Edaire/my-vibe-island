import XCTest
@testable import MyVibeIslandCore

final class OnboardingReadyModelsTests: XCTestCase {
    func testOnboardingReadyMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OnboardingReadyMatrixFixture.self,
            from: try FixtureLoader.data("settings/onboarding-ready-matrix")
        )

        let model = OnboardingReadyModel()
        let actual = OnboardingReadyMatrixFixture(rows: [
            row(
                id: "ready-start-using",
                state: model.state(
                    readiness: ReadinessScanResult(
                        agents: [
                            AgentReadiness(
                                agentId: "codex",
                                supportLevel: .supported,
                                installedState: .installed,
                                hookConfiguredState: .configured,
                                watcherAvailableState: .available
                            ),
                        ]
                    ),
                    restartHint: .init()
                )
            ),
            row(
                id: "ready-restart-first",
                state: model.state(
                    readiness: ReadinessScanResult(
                        terminals: [
                            TerminalReadiness(
                                terminalId: "iterm",
                                installedState: .installed,
                                permissionState: .granted,
                                jumpCapabilityState: .available
                            ),
                        ]
                    ),
                    restartHint: RestartBannerState(
                        visible: true,
                        source: .firstInstall,
                        requiresRestart: true,
                        firstInstallOnly: true,
                        affectedIntegrations: ["iterm"]
                    )
                )
            ),
            row(
                id: "partial-repair-and-demo",
                state: model.state(
                    readiness: ReadinessScanResult(
                        agents: [
                            AgentReadiness(
                                agentId: "claude",
                                supportLevel: .supported,
                                installedState: .installed,
                                hookConfiguredState: .missing,
                                watcherAvailableState: .available,
                                repairAction: "Install managed hook"
                            ),
                        ]
                    ),
                    restartHint: .init()
                )
            ),
            row(
                id: "partial-restart-included",
                state: model.state(
                    readiness: ReadinessScanResult(
                        agents: [
                            AgentReadiness(
                                agentId: "claude",
                                supportLevel: .supported,
                                installedState: .installed,
                                hookConfiguredState: .missing,
                                watcherAvailableState: .available,
                                repairAction: "Install managed hook"
                            ),
                        ]
                    ),
                    restartHint: RestartBannerState(
                        visible: true,
                        source: .managedHooks,
                        requiresRestart: true,
                        affectedIntegrations: ["claude"]
                    )
                )
            ),
            row(
                id: "demo-only-demo-first",
                state: model.state(
                    readiness: ReadinessScanResult(),
                    restartHint: .init()
                )
            ),
            row(
                id: "blocked-settings-first",
                state: model.state(
                    readiness: ReadinessScanResult(
                        permissions: [
                            PermissionReadiness(
                                permissionKind: .automation,
                                status: .denied,
                                requiredByFeature: "terminal jump"
                            ),
                        ]
                    ),
                    restartHint: .init()
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testReadyWindowStateRoundTripsReadinessRestartHintAndNextActions() throws {
        let state = OnboardingReadyWindowState(
            readyWindowId: "readyWindow",
            readinessOutcome: .partial,
            restartHint: RestartBannerState(
                visible: true,
                source: .managedHooks,
                requiresRestart: true,
                affectedIntegrations: ["codex"]
            ),
            nextActions: [.openSettings, .startDemo],
            isPresented: true
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(OnboardingReadyWindowState.self, from: data)

        XCTAssertEqual(decoded, state)
    }

    func testReadyModelOffersStartUsingForReadyOutcomeWithoutRestartHint() {
        let state = OnboardingReadyModel().state(
            readiness: ReadinessScanResult(
                agents: [
                    AgentReadiness(
                        agentId: "codex",
                        supportLevel: .supported,
                        installedState: .installed,
                        hookConfiguredState: .configured,
                        watcherAvailableState: .available
                    ),
                ]
            ),
            restartHint: .init()
        )

        XCTAssertEqual(state.readyWindowId, "readyWindow")
        XCTAssertEqual(state.readinessOutcome, .ready)
        XCTAssertEqual(state.nextActions, [.startUsing, .openSettings])
        XCTAssertTrue(state.isPresented)
    }

    func testReadyModelOffersRepairAndSettingsForPartialOutcomeWithRestartHint() {
        let state = OnboardingReadyModel().state(
            readiness: ReadinessScanResult(
                agents: [
                    AgentReadiness(
                        agentId: "claude",
                        supportLevel: .supported,
                        installedState: .installed,
                        hookConfiguredState: .missing,
                        watcherAvailableState: .available,
                        repairAction: "Install managed hook"
                    ),
                ]
            ),
            restartHint: RestartBannerState(
                visible: true,
                source: .managedHooks,
                requiresRestart: true,
                affectedIntegrations: ["claude"]
            )
        )

        XCTAssertEqual(state.readinessOutcome, .partial)
        XCTAssertEqual(state.nextActions, [.openSettings, .restartApp, .startDemo])
        XCTAssertTrue(state.restartHint.visible)
    }

    func testReadyModelOffersDemoForBlockedOutcome() {
        let state = OnboardingReadyModel().state(
            readiness: ReadinessScanResult(
                permissions: [
                    PermissionReadiness(
                        permissionKind: .automation,
                        status: .denied,
                        requiredByFeature: "terminal jump"
                    ),
                ]
            ),
            restartHint: .init()
        )

        XCTAssertEqual(state.readinessOutcome, .blocked)
        XCTAssertEqual(state.nextActions, [.openSettings, .startDemo])
    }

    private func row(id: String, state: OnboardingReadyWindowState) -> OnboardingReadyRowFixture {
        OnboardingReadyRowFixture(
            id: id,
            readyWindowId: state.readyWindowId,
            readinessOutcome: state.readinessOutcome.rawValue,
            nextActions: state.nextActions.map(\.rawValue),
            isPresented: state.isPresented,
            restartVisible: state.restartHint.visible,
            restartSource: state.restartHint.source?.rawValue,
            requiresRestart: state.restartHint.requiresRestart,
            firstInstallOnly: state.restartHint.firstInstallOnly,
            affectedIntegrations: state.restartHint.affectedIntegrations
        )
    }

    private struct OnboardingReadyMatrixFixture: Codable, Equatable {
        let rows: [OnboardingReadyRowFixture]
    }

    private struct OnboardingReadyRowFixture: Codable, Equatable {
        let id: String
        let readyWindowId: String
        let readinessOutcome: String
        let nextActions: [String]
        let isPresented: Bool
        let restartVisible: Bool
        let restartSource: String?
        let requiresRestart: Bool
        let firstInstallOnly: Bool
        let affectedIntegrations: [String]
    }
}
