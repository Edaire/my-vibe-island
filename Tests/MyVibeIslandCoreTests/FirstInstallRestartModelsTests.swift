import XCTest
@testable import MyVibeIslandCore

final class FirstInstallRestartModelsTests: XCTestCase {
    func testFirstInstallRestartMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            FirstInstallRestartMatrixFixture.self,
            from: try FixtureLoader.data("settings/first-install-restart-matrix")
        )
        let model = RestartBannerModel()
        let states = [
            FirstInstallStateCase(
                name: "fresh-install-current-version",
                state: FirstInstallState(
                    hasCompletedOnboarding: false,
                    onboardingVersion: 0,
                    isFirstInstall: true,
                    forceReplayOnboarding: false,
                    showFirstInstallRestartBanner: true
                ),
                shouldPresentOnboarding: FirstInstallState(
                    hasCompletedOnboarding: false,
                    onboardingVersion: 0,
                    isFirstInstall: true,
                    forceReplayOnboarding: false,
                    showFirstInstallRestartBanner: true
                ).shouldPresentOnboarding(currentVersion: 3),
                completedState: FirstInstallState(
                    hasCompletedOnboarding: false,
                    onboardingVersion: 0,
                    isFirstInstall: true,
                    forceReplayOnboarding: false,
                    showFirstInstallRestartBanner: true
                ).completed(version: 3)
            ),
            FirstInstallStateCase(
                name: "completed-current-version",
                state: FirstInstallState(hasCompletedOnboarding: true, onboardingVersion: 3),
                shouldPresentOnboarding: FirstInstallState(
                    hasCompletedOnboarding: true,
                    onboardingVersion: 3
                ).shouldPresentOnboarding(currentVersion: 3),
                completedState: FirstInstallState(hasCompletedOnboarding: true, onboardingVersion: 3)
                    .completed(version: 3)
            ),
            FirstInstallStateCase(
                name: "completed-old-version",
                state: FirstInstallState(hasCompletedOnboarding: true, onboardingVersion: 2),
                shouldPresentOnboarding: FirstInstallState(
                    hasCompletedOnboarding: true,
                    onboardingVersion: 2
                ).shouldPresentOnboarding(currentVersion: 3),
                completedState: FirstInstallState(hasCompletedOnboarding: true, onboardingVersion: 2)
                    .completed(version: 3)
            ),
            FirstInstallStateCase(
                name: "forced-replay",
                state: FirstInstallState(
                    hasCompletedOnboarding: true,
                    onboardingVersion: 3,
                    forceReplayOnboarding: true
                ),
                shouldPresentOnboarding: FirstInstallState(
                    hasCompletedOnboarding: true,
                    onboardingVersion: 3,
                    forceReplayOnboarding: true
                ).shouldPresentOnboarding(currentVersion: 3),
                completedState: FirstInstallState(
                    hasCompletedOnboarding: true,
                    onboardingVersion: 3,
                    forceReplayOnboarding: true
                ).completed(version: 3)
            )
        ]
        let banners = [
            RestartBannerCase(
                name: "hidden-without-affected-integrations",
                state: model.state(
                    firstInstallState: FirstInstallState(showFirstInstallRestartBanner: true),
                    affectedIntegrations: [],
                    shownAt: "2026-07-08T17:00:00Z"
                ),
                dismissedState: nil
            ),
            RestartBannerCase(
                name: "visible-first-install-restart",
                state: model.state(
                    firstInstallState: FirstInstallState(showFirstInstallRestartBanner: true),
                    affectedIntegrations: ["managed hooks", "terminal config"],
                    shownAt: "2026-07-08T17:00:00Z"
                ),
                dismissedState: model.dismiss(
                    model.state(
                        firstInstallState: FirstInstallState(showFirstInstallRestartBanner: true),
                        affectedIntegrations: ["managed hooks", "terminal config"],
                        shownAt: "2026-07-08T17:00:00Z"
                    ),
                    dismissedAt: "2026-07-08T17:01:00Z"
                )
            ),
            RestartBannerCase(
                name: "hidden-when-banner-flag-disabled",
                state: model.state(
                    firstInstallState: FirstInstallState(showFirstInstallRestartBanner: false),
                    affectedIntegrations: ["managed hooks"],
                    shownAt: "2026-07-08T17:00:00Z"
                ),
                dismissedState: nil
            )
        ]

        XCTAssertEqual(states, expected.states)
        XCTAssertEqual(banners, expected.banners)
    }

    func testFirstInstallStateRoundTripsLocalFlags() throws {
        let state = FirstInstallState(
            hasCompletedOnboarding: false,
            onboardingVersion: 2,
            isFirstInstall: true,
            forceReplayOnboarding: true,
            showFirstInstallRestartBanner: true
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(FirstInstallState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertTrue(decoded.shouldPresentOnboarding(currentVersion: 2))
    }

    func testCompletingOnboardingStoresVersionAndClearsReplay() {
        let initial = FirstInstallState(isFirstInstall: true, forceReplayOnboarding: true)
        let completed = initial.completed(version: 3)

        XCTAssertTrue(completed.hasCompletedOnboarding)
        XCTAssertEqual(completed.onboardingVersion, 3)
        XCTAssertFalse(completed.isFirstInstall)
        XCTAssertFalse(completed.forceReplayOnboarding)
        XCTAssertFalse(completed.shouldPresentOnboarding(currentVersion: 3))
    }

    func testRestartBannerStateShowsOnlyWhenRestartIsRequired() {
        let model = RestartBannerModel()
        let hidden = model.state(
            firstInstallState: FirstInstallState(showFirstInstallRestartBanner: true),
            affectedIntegrations: [],
            shownAt: "2026-07-08T17:00:00Z"
        )
        let visible = model.state(
            firstInstallState: FirstInstallState(showFirstInstallRestartBanner: true),
            affectedIntegrations: ["managed hooks", "terminal config"],
            shownAt: "2026-07-08T17:00:00Z"
        )

        XCTAssertFalse(hidden.visible)
        XCTAssertTrue(visible.visible)
        XCTAssertEqual(visible.source, .firstInstall)
        XCTAssertEqual(visible.affectedIntegrations, ["managed hooks", "terminal config"])
    }

    func testRestartBannerDismissalKeepsRestartRequirementButHidesBanner() {
        let state = RestartBannerState(
            visible: true,
            source: .terminalConfiguration,
            requiresRestart: true,
            affectedIntegrations: ["iterm"]
        )

        let dismissed = RestartBannerModel().dismiss(state, dismissedAt: "2026-07-08T17:01:00Z")

        XCTAssertFalse(dismissed.visible)
        XCTAssertTrue(dismissed.requiresRestart)
        XCTAssertEqual(dismissed.dismissedAt, "2026-07-08T17:01:00Z")
        XCTAssertEqual(dismissed.affectedIntegrations, ["iterm"])
    }

    private struct FirstInstallRestartMatrixFixture: Codable, Equatable {
        let states: [FirstInstallStateCase]
        let banners: [RestartBannerCase]
    }

    private struct FirstInstallStateCase: Codable, Equatable {
        let name: String
        let state: FirstInstallState
        let shouldPresentOnboarding: Bool
        let completedState: FirstInstallState
    }

    private struct RestartBannerCase: Codable, Equatable {
        let name: String
        let state: RestartBannerState
        let dismissedState: RestartBannerState?
    }
}
