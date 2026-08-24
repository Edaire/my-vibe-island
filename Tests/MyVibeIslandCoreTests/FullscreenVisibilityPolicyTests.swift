import XCTest
@testable import MyVibeIslandCore

final class FullscreenVisibilityPolicyTests: XCTestCase {
    func testFullscreenVisibilityPolicyMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            FullscreenVisibilityPolicyMatrixFixture.self,
            from: try FixtureLoader.data("settings/fullscreen-visibility-policy-matrix")
        )
        let policy = FullscreenVisibilityPolicy()
        let cases = [
            FullscreenVisibilityPolicyCase(
                name: "visible-when-setting-disabled",
                input: FullscreenVisibilityInput(
                    hideInFullscreen: false,
                    activeAppIsFullscreen: true,
                    fullscreenCheckGeneration: 7
                )
            ),
            FullscreenVisibilityPolicyCase(
                name: "hidden-when-fullscreen-setting-enabled",
                input: FullscreenVisibilityInput(
                    hideInFullscreen: true,
                    activeAppIsFullscreen: true,
                    fullscreenCheckGeneration: 8
                )
            ),
            FullscreenVisibilityPolicyCase(
                name: "visible-when-active-app-not-fullscreen",
                input: FullscreenVisibilityInput(
                    hideInFullscreen: true,
                    activeAppIsFullscreen: false,
                    fullscreenCheckGeneration: 9
                )
            ),
            FullscreenVisibilityPolicyCase(
                name: "blocking-action-overrides-fullscreen-hidden",
                input: FullscreenVisibilityInput(
                    hideInFullscreen: true,
                    activeAppIsFullscreen: true,
                    blockingActionVisible: true,
                    fullscreenCheckGeneration: 10
                )
            ),
            FullscreenVisibilityPolicyCase(
                name: "onboarding-fullscreen-owns-visibility",
                input: FullscreenVisibilityInput(
                    hideInFullscreen: false,
                    activeAppIsFullscreen: false,
                    blockingActionVisible: true,
                    onboardingFullscreenActive: true,
                    fullscreenCheckGeneration: 11
                )
            )
        ].map { testCase in
            FullscreenVisibilityPolicyCase(
                name: testCase.name,
                input: testCase.input,
                decision: policy.decide(testCase.input)
            )
        }

        XCTAssertEqual(cases, expected.cases)
    }

    func testFullscreenDoesNotHideWhenSettingIsDisabled() {
        let policy = FullscreenVisibilityPolicy()

        let decision = policy.decide(
            FullscreenVisibilityInput(
                hideInFullscreen: false,
                activeAppIsFullscreen: true,
                fullscreenCheckGeneration: 7
            )
        )

        XCTAssertTrue(decision.isVisible)
        XCTAssertEqual(decision.reason, .visible)
        XCTAssertEqual(decision.fullscreenCheckGeneration, 7)
    }

    func testFullscreenHidesWhenSettingIsEnabled() {
        let policy = FullscreenVisibilityPolicy()

        let decision = policy.decide(
            FullscreenVisibilityInput(hideInFullscreen: true, activeAppIsFullscreen: true)
        )

        XCTAssertFalse(decision.isVisible)
        XCTAssertEqual(decision.reason, .fullscreenHidden)
    }

    func testBlockingActionOverridesFullscreenHiding() {
        let policy = FullscreenVisibilityPolicy()

        let decision = policy.decide(
            FullscreenVisibilityInput(
                hideInFullscreen: true,
                activeAppIsFullscreen: true,
                blockingActionVisible: true
            )
        )

        XCTAssertTrue(decision.isVisible)
        XCTAssertEqual(decision.reason, .blockingActionVisible)
    }

    func testOnboardingFullscreenOwnsVisibilityBeforeBlockingAction() {
        let policy = FullscreenVisibilityPolicy()

        let decision = policy.decide(
            FullscreenVisibilityInput(
                hideInFullscreen: false,
                activeAppIsFullscreen: false,
                blockingActionVisible: true,
                onboardingFullscreenActive: true
            )
        )

        XCTAssertFalse(decision.isVisible)
        XCTAssertEqual(decision.reason, .onboardingFullscreen)
    }

    func testDecisionRoundTripsThroughJSON() throws {
        let decision = FullscreenVisibilityDecision(
            isVisible: false,
            reason: .fullscreenHidden,
            fullscreenCheckGeneration: 42
        )

        let decoded = try JSONDecoder().decode(
            FullscreenVisibilityDecision.self,
            from: try JSONEncoder().encode(decision)
        )

        XCTAssertEqual(decoded, decision)
    }

    private struct FullscreenVisibilityPolicyMatrixFixture: Codable, Equatable {
        let cases: [FullscreenVisibilityPolicyCase]
    }

    private struct FullscreenVisibilityPolicyCase: Codable, Equatable {
        let name: String
        let input: FullscreenVisibilityInput
        let decision: FullscreenVisibilityDecision?

        init(
            name: String,
            input: FullscreenVisibilityInput,
            decision: FullscreenVisibilityDecision? = nil
        ) {
            self.name = name
            self.input = input
            self.decision = decision
        }
    }
}
