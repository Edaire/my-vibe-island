import XCTest
@testable import MyVibeIslandCore

final class OnboardingStateModelsTests: XCTestCase {
    func testOnboardingStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OnboardingStateMatrixFixture.self,
            from: try FixtureLoader.data("settings/onboarding-state-matrix")
        )

        let model = OnboardingFlowModel()
        let actual = OnboardingStateMatrixFixture(
            stepOrder: OnboardingStep.allCases.map(\.rawValue),
            nextByStep: OnboardingStep.allCases.map {
                OnboardingStepTransitionFixture(step: $0.rawValue, next: $0.next?.rawValue)
            },
            advanceRows: [
                advanceRow(id: "welcome-start", state: OnboardingState(currentStep: .welcome), model: model),
                advanceRow(
                    id: "blocked-permissions",
                    state: OnboardingState(
                        currentStep: .permissions,
                        canContinue: false,
                        blockingIssue: "automation permission denied",
                        readinessOutcome: .blocked
                    ),
                    model: model
                ),
                advanceRow(id: "already-ready", state: OnboardingState(currentStep: .ready), model: model),
            ],
            readinessRows: [
                readinessRow(
                    id: "blocked-permission",
                    readiness: ReadinessScanResult(
                        permissions: [
                            PermissionReadiness(
                                permissionKind: .automation,
                                status: .denied,
                                requiredByFeature: "terminal jump"
                            ),
                        ]
                    ),
                    state: OnboardingState(currentStep: .environmentScan),
                    model: model
                ),
                readinessRow(
                    id: "ready-agent",
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
                    state: OnboardingState(currentStep: .verification),
                    model: model
                ),
                readinessRow(
                    id: "partial-terminal-repair",
                    readiness: ReadinessScanResult(
                        terminals: [
                            TerminalReadiness(
                                terminalId: "terminal",
                                installedState: .missing,
                                permissionState: .notRequired,
                                jumpCapabilityState: .unknown,
                                repairAction: "install terminal integration"
                            ),
                        ]
                    ),
                    state: OnboardingState(currentStep: .installRepair),
                    model: model
                ),
            ],
            coordinatorRows: [
                coordinatorRow(
                    id: "first-run-ready-restart",
                    coordinator: OnboardingCoordinator(currentVersion: 2),
                    firstInstallState: FirstInstallState(
                        hasCompletedOnboarding: false,
                        isFirstInstall: true,
                        showFirstInstallRestartBanner: true
                    ),
                    onboardingState: OnboardingState(currentStep: .verification),
                    readiness: ReadinessScanResult(
                        generatedAt: "2026-07-09T01:30:00Z",
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
                    affectedIntegrations: ["codex"],
                    observedAt: "2026-07-09T01:30:01Z"
                ),
                coordinatorRow(
                    id: "completed-no-presentation-demo-only",
                    coordinator: OnboardingCoordinator(currentVersion: 2),
                    firstInstallState: FirstInstallState(
                        hasCompletedOnboarding: true,
                        onboardingVersion: 2
                    ),
                    onboardingState: OnboardingState(currentStep: .ready),
                    readiness: ReadinessScanResult(),
                    affectedIntegrations: [],
                    observedAt: nil
                ),
            ]
        )

        XCTAssertEqual(actual, expected)
    }

    func testOnboardingStepsPreserveDocumentedOrderWithoutPaidSteps() {
        XCTAssertEqual(OnboardingStep.allCases, [
            .welcome,
            .localPrivacy,
            .environmentScan,
            .integrationSelection,
            .installRepair,
            .permissions,
            .demo,
            .verification,
            .ready,
        ])
        XCTAssertEqual(OnboardingStep.welcome.next, .localPrivacy)
        XCTAssertNil(OnboardingStep.ready.next)
    }

    func testOnboardingStateRoundTripsProgressAndReadinessOutcome() throws {
        let state = OnboardingState(
            currentStep: .permissions,
            completedSteps: [.welcome, .environmentScan, .welcome],
            skippedSteps: [.demo],
            canContinue: false,
            blockingIssue: "accessibility permission denied",
            readinessOutcome: .blocked
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(OnboardingState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.completedSteps, [.welcome, .environmentScan])
        XCTAssertEqual(decoded.skippedSteps, [.demo])
    }

    func testAdvancingMarksCurrentStepCompleteAndMovesToNextStep() {
        let state = OnboardingState(currentStep: .welcome)
        let result = OnboardingFlowModel().advance(from: state)

        XCTAssertEqual(result.decision, .advanced)
        XCTAssertEqual(result.nextState.currentStep, .localPrivacy)
        XCTAssertEqual(result.nextState.completedSteps, [.welcome])
    }

    func testBlockingStateDoesNotAdvanceUntilIssueClears() {
        let state = OnboardingState(
            currentStep: .permissions,
            canContinue: false,
            blockingIssue: "automation permission denied",
            readinessOutcome: .blocked
        )

        let result = OnboardingFlowModel().advance(from: state)

        XCTAssertEqual(result.decision, .blocked)
        XCTAssertEqual(result.nextState, state)
    }

    func testApplyingReadinessBlocksOnBlockingIssuesAndClearsOnReady() {
        let model = OnboardingFlowModel()
        let blocked = model.apply(
            readiness: ReadinessScanResult(
                permissions: [
                    PermissionReadiness(
                        permissionKind: .automation,
                        status: .denied,
                        requiredByFeature: "terminal jump"
                    ),
                ]
            ),
            to: OnboardingState(currentStep: .environmentScan)
        )

        XCTAssertFalse(blocked.canContinue)
        XCTAssertEqual(blocked.blockingIssue, "automation permission denied for terminal jump")
        XCTAssertEqual(blocked.readinessOutcome, .blocked)

        let ready = model.apply(
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
            to: blocked
        )

        XCTAssertTrue(ready.canContinue)
        XCTAssertNil(ready.blockingIssue)
        XCTAssertEqual(ready.readinessOutcome, .ready)
    }

    func testOnboardingCoordinatorPlansFirstRunReadinessRestartAndDemoState() throws {
        let coordinator = OnboardingCoordinator(currentVersion: 2)
        let readiness = ReadinessScanResult(
            generatedAt: "2026-07-09T01:30:00Z",
            agents: [
                AgentReadiness(
                    agentId: "codex",
                    supportLevel: .supported,
                    installedState: .installed,
                    hookConfiguredState: .configured,
                    watcherAvailableState: .available
                ),
            ]
        )

        let plan = coordinator.plan(
            firstInstallState: FirstInstallState(
                hasCompletedOnboarding: false,
                isFirstInstall: true,
                showFirstInstallRestartBanner: true
            ),
            onboardingState: OnboardingState(currentStep: .verification),
            readiness: readiness,
            affectedIntegrations: ["codex"],
            demoCwd: "/tmp/my-vibe-island-demo",
            observedAt: "2026-07-09T01:30:01Z"
        )
        let decoded = try JSONDecoder().decode(
            OnboardingCoordinatorPlan.self,
            from: try JSONEncoder().encode(plan)
        )

        XCTAssertEqual(decoded, plan)
        XCTAssertTrue(plan.shouldPresentOnboarding)
        XCTAssertEqual(plan.coordinatedState.currentStep, .verification)
        XCTAssertEqual(plan.coordinatedState.readinessOutcome, .ready)
        XCTAssertTrue(plan.restartBanner.visible)
        XCTAssertEqual(plan.restartBanner.affectedIntegrations, ["codex"])
        XCTAssertEqual(plan.readyWindow?.nextActions, [.restartApp, .openSettings])
        XCTAssertEqual(plan.demoPlan.previewCompletionSessionId, "demo-onboarding-completion")
    }

    private func advanceRow(
        id: String,
        state: OnboardingState,
        model: OnboardingFlowModel
    ) -> OnboardingAdvanceRowFixture {
        let result = model.advance(from: state)
        return OnboardingAdvanceRowFixture(
            id: id,
            initialState: state.fixture,
            decision: result.decision.rawValue,
            nextState: result.nextState.fixture
        )
    }

    private func readinessRow(
        id: String,
        readiness: ReadinessScanResult,
        state: OnboardingState,
        model: OnboardingFlowModel
    ) -> OnboardingReadinessApplyRowFixture {
        let applied = model.apply(readiness: readiness, to: state)
        return OnboardingReadinessApplyRowFixture(
            id: id,
            outcome: readiness.outcome.rawValue,
            blockingIssues: readiness.blockingIssues,
            repairActions: readiness.repairActions,
            appliedState: applied.fixture
        )
    }

    private func coordinatorRow(
        id: String,
        coordinator: OnboardingCoordinator,
        firstInstallState: FirstInstallState,
        onboardingState: OnboardingState,
        readiness: ReadinessScanResult,
        affectedIntegrations: [String],
        observedAt: String?
    ) -> OnboardingCoordinatorRowFixture {
        let plan = coordinator.plan(
            firstInstallState: firstInstallState,
            onboardingState: onboardingState,
            readiness: readiness,
            affectedIntegrations: affectedIntegrations,
            demoCwd: "/tmp/my-vibe-island-demo",
            observedAt: observedAt
        )

        return OnboardingCoordinatorRowFixture(
            id: id,
            shouldPresentOnboarding: plan.shouldPresentOnboarding,
            coordinatedState: plan.coordinatedState.fixture,
            restartBanner: RestartBannerFixture(
                visible: plan.restartBanner.visible,
                source: plan.restartBanner.source?.rawValue,
                requiresRestart: plan.restartBanner.requiresRestart,
                shownAt: plan.restartBanner.shownAt,
                firstInstallOnly: plan.restartBanner.firstInstallOnly,
                affectedIntegrations: plan.restartBanner.affectedIntegrations
            ),
            readyWindow: plan.readyWindow.map {
                OnboardingReadyWindowFixture(
                    readinessOutcome: $0.readinessOutcome.rawValue,
                    nextActions: $0.nextActions.map(\.rawValue),
                    isPresented: $0.isPresented
                )
            },
            demoPlan: OnboardingDemoPlanFixture(
                demoSource: plan.demoPlan.demoSource,
                sessionIds: plan.demoPlan.sessions.map(\.id),
                previewCompletionSessionId: plan.demoPlan.previewCompletionSessionId
            )
        )
    }

    fileprivate struct OnboardingStateMatrixFixture: Codable, Equatable {
        let stepOrder: [String]
        let nextByStep: [OnboardingStepTransitionFixture]
        let advanceRows: [OnboardingAdvanceRowFixture]
        let readinessRows: [OnboardingReadinessApplyRowFixture]
        let coordinatorRows: [OnboardingCoordinatorRowFixture]
    }

    fileprivate struct OnboardingStepTransitionFixture: Codable, Equatable {
        let step: String
        let next: String?
    }

    fileprivate struct OnboardingAdvanceRowFixture: Codable, Equatable {
        let id: String
        let initialState: OnboardingStateFixture
        let decision: String
        let nextState: OnboardingStateFixture
    }

    fileprivate struct OnboardingReadinessApplyRowFixture: Codable, Equatable {
        let id: String
        let outcome: String
        let blockingIssues: [String]
        let repairActions: [String]
        let appliedState: OnboardingStateFixture
    }

    fileprivate struct OnboardingCoordinatorRowFixture: Codable, Equatable {
        let id: String
        let shouldPresentOnboarding: Bool
        let coordinatedState: OnboardingStateFixture
        let restartBanner: RestartBannerFixture
        let readyWindow: OnboardingReadyWindowFixture?
        let demoPlan: OnboardingDemoPlanFixture
    }

    fileprivate struct OnboardingStateFixture: Codable, Equatable {
        let currentStep: String
        let completedSteps: [String]
        let skippedSteps: [String]
        let canContinue: Bool
        let blockingIssue: String?
        let readinessOutcome: String?
    }

    fileprivate struct RestartBannerFixture: Codable, Equatable {
        let visible: Bool
        let source: String?
        let requiresRestart: Bool
        let shownAt: String?
        let firstInstallOnly: Bool
        let affectedIntegrations: [String]
    }

    fileprivate struct OnboardingReadyWindowFixture: Codable, Equatable {
        let readinessOutcome: String
        let nextActions: [String]
        let isPresented: Bool
    }

    fileprivate struct OnboardingDemoPlanFixture: Codable, Equatable {
        let demoSource: String
        let sessionIds: [String]
        let previewCompletionSessionId: String
    }
}

private extension OnboardingState {
    var fixture: OnboardingStateModelsTests.OnboardingStateFixture {
        OnboardingStateModelsTests.OnboardingStateFixture(
            currentStep: currentStep.rawValue,
            completedSteps: completedSteps.map(\.rawValue),
            skippedSteps: skippedSteps.map(\.rawValue),
            canContinue: canContinue,
            blockingIssue: blockingIssue,
            readinessOutcome: readinessOutcome?.rawValue
        )
    }
}
