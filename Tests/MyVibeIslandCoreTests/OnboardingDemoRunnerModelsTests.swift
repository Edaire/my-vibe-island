import XCTest
@testable import MyVibeIslandCore

final class OnboardingDemoRunnerModelsTests: XCTestCase {
    func testOnboardingDemoRunnerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OnboardingDemoRunnerMatrixFixture.self,
            from: try FixtureLoader.data("settings/onboarding-demo-runner-matrix")
        )

        let factory = OnboardingDemoSessionFactory()
        let plan = factory.makePlan(demoCwd: "/tmp/my-vibe-island-demo")
        let startResult = OnboardingDemoRunnerModel().start(
            plan: plan,
            socketPath: "/tmp/my-vibe-island-demo/socket",
            persistentFd: -12,
            defaultEnv: [
                "MY_VIBE_ISLAND_DEMO": "1",
                "TERM": "xterm-256color",
            ],
            startedAt: "2026-07-08T17:02:00Z"
        )
        let finishResult = OnboardingDemoRunnerModel().finish(from: startResult.nextState)

        let actual = OnboardingDemoRunnerMatrixFixture(
            plan: plan.fixture,
            rows: [
                resultRow(id: "start-clamps-fd-and-activates-first-session", result: startResult),
                resultRow(id: "finish-clears-active-sessions", result: finishResult),
            ]
        )

        XCTAssertEqual(actual, expected)
    }

    func testDemoSessionFactoryCreatesSyntheticSessionsWithReservedPrefix() {
        let factory = OnboardingDemoSessionFactory()
        let plan = factory.makePlan(demoCwd: "/tmp/my-vibe-island-demo")

        XCTAssertEqual(plan.demoCwd, "/tmp/my-vibe-island-demo")
        XCTAssertEqual(plan.sessions.map(\.id), [
            "demo-onboarding-permission",
            "demo-onboarding-question",
            "demo-onboarding-completion",
            "demo-onboarding-notification",
        ])
        XCTAssertTrue(plan.sessions.allSatisfy(\.isSynthetic))
        XCTAssertTrue(plan.sessions.allSatisfy { !$0.shouldPersistToHistory })
        XCTAssertEqual(plan.previewCompletionSessionId, "demo-onboarding-completion")
    }

    func testDemoRunnerStateRoundTripsSocketEnvironmentAndActiveSessions() throws {
        let state = OnboardingDemoRunnerState(
            socketPath: "/tmp/my-vibe-island-demo/socket",
            defaultCwd: "/tmp/my-vibe-island-demo",
            persistentFd: 12,
            defaultEnv: ["MY_VIBE_ISLAND_DEMO": "1"],
            demoSessionIds: ["demo-onboarding-permission"],
            activeSessionIds: ["demo-onboarding-permission"],
            previewCompletionSessionId: "demo-onboarding-completion",
            startedAt: "2026-07-08T17:02:00Z"
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(OnboardingDemoRunnerState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertTrue(decoded.isRunning)
    }

    func testStartingDemoRunnerActivatesSyntheticSessions() {
        let result = OnboardingDemoRunnerModel().start(
            plan: OnboardingDemoSessionFactory().makePlan(demoCwd: "/tmp/my-vibe-island-demo"),
            socketPath: "/tmp/my-vibe-island-demo/socket",
            persistentFd: nil,
            defaultEnv: ["MY_VIBE_ISLAND_DEMO": "1"],
            startedAt: "2026-07-08T17:02:00Z"
        )

        XCTAssertEqual(result.decision, .started)
        XCTAssertEqual(result.nextState.activeSessionIds.first, "demo-onboarding-permission")
        XCTAssertEqual(result.nextState.demoSessionIds.count, 4)
        XCTAssertEqual(result.nextState.previewCompletionSessionId, "demo-onboarding-completion")
    }

    func testFinishingDemoRunnerClearsActiveSessionsButKeepsDemoIdsForDiagnostics() {
        let state = OnboardingDemoRunnerState(
            defaultCwd: "/tmp/my-vibe-island-demo",
            demoSessionIds: ["demo-onboarding-permission", "demo-onboarding-completion"],
            activeSessionIds: ["demo-onboarding-permission"],
            previewCompletionSessionId: "demo-onboarding-completion",
            startedAt: "2026-07-08T17:02:00Z"
        )

        let result = OnboardingDemoRunnerModel().finish(from: state)

        XCTAssertEqual(result.decision, .finished)
        XCTAssertTrue(result.nextState.activeSessionIds.isEmpty)
        XCTAssertEqual(result.nextState.demoSessionIds, state.demoSessionIds)
    }

    private func resultRow(
        id: String,
        result: OnboardingDemoRunnerResult
    ) -> OnboardingDemoRunnerRowFixture {
        OnboardingDemoRunnerRowFixture(
            id: id,
            decision: result.decision.rawValue,
            state: result.nextState.fixture
        )
    }

    fileprivate struct OnboardingDemoRunnerMatrixFixture: Codable, Equatable {
        let plan: OnboardingDemoPlanFixture
        let rows: [OnboardingDemoRunnerRowFixture]
    }

    fileprivate struct OnboardingDemoPlanFixture: Codable, Equatable {
        let reservedIdPrefix: String
        let demoCwd: String
        let demoSource: String
        let sessionIds: [String]
        let sessionTitles: [String]
        let allSynthetic: Bool
        let allSkippedFromHistory: Bool
        let previewCompletionSessionId: String
    }

    fileprivate struct OnboardingDemoRunnerRowFixture: Codable, Equatable {
        let id: String
        let decision: String
        let state: OnboardingDemoRunnerStateFixture
    }

    fileprivate struct OnboardingDemoRunnerStateFixture: Codable, Equatable {
        let socketPath: String?
        let defaultCwd: String
        let persistentFd: Int?
        let sortedEnv: [String]
        let demoSessionIds: [String]
        let activeSessionIds: [String]
        let previewCompletionSessionId: String?
        let startedAt: String?
        let isRunning: Bool
    }
}

private extension OnboardingDemoPlan {
    var fixture: OnboardingDemoRunnerModelsTests.OnboardingDemoPlanFixture {
        OnboardingDemoRunnerModelsTests.OnboardingDemoPlanFixture(
            reservedIdPrefix: reservedIdPrefix,
            demoCwd: demoCwd,
            demoSource: demoSource,
            sessionIds: sessions.map(\.id),
            sessionTitles: sessions.map(\.title),
            allSynthetic: sessions.allSatisfy(\.isSynthetic),
            allSkippedFromHistory: sessions.allSatisfy { !$0.shouldPersistToHistory },
            previewCompletionSessionId: previewCompletionSessionId
        )
    }
}

private extension OnboardingDemoRunnerState {
    var fixture: OnboardingDemoRunnerModelsTests.OnboardingDemoRunnerStateFixture {
        OnboardingDemoRunnerModelsTests.OnboardingDemoRunnerStateFixture(
            socketPath: socketPath,
            defaultCwd: defaultCwd,
            persistentFd: persistentFd,
            sortedEnv: defaultEnv.map { "\($0.key)=\($0.value)" }.sorted(),
            demoSessionIds: demoSessionIds,
            activeSessionIds: activeSessionIds,
            previewCompletionSessionId: previewCompletionSessionId,
            startedAt: startedAt,
            isRunning: isRunning
        )
    }
}
