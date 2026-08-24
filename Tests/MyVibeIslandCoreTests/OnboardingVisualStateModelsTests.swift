import XCTest
@testable import MyVibeIslandCore

final class OnboardingVisualStateModelsTests: XCTestCase {
    func testOnboardingVisualStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OnboardingVisualStateMatrixFixture.self,
            from: try FixtureLoader.data("settings/onboarding-visual-state-matrix")
        )

        let model = OnboardingVisualStateModel()
        var previous = OnboardingVisualState.idle
        let stepRows = OnboardingStep.allCases.map { step in
            let state = model.state(for: step, previous: previous)
            previous = state
            return OnboardingVisualStateStepRowFixture(
                step: step.rawValue,
                state: state.fixture
            )
        }
        let actual = OnboardingVisualStateMatrixFixture(
            idle: OnboardingVisualState.idle.fixture,
            clampedOverflow: OnboardingVisualState(
                glowIntensity: 2.0,
                glowRotation: 725.0,
                cornerBounce: -1.0,
                isGlowActive: true,
                isHidingNotch: false,
                onboardingRainbow: true
            ).fixture,
            negativeRotation: OnboardingVisualState(
                glowIntensity: 0.5,
                glowRotation: -15.0,
                cornerBounce: 0.5,
                isGlowActive: true,
                isHidingNotch: false,
                onboardingRainbow: true
            ).fixture,
            stepRows: stepRows
        )

        XCTAssertEqual(actual, expected)
    }

    func testVisualStateRoundTripsAnimationFields() throws {
        let state = OnboardingVisualState(
            glowIntensity: 0.75,
            glowRotation: 180.0,
            cornerBounce: 0.4,
            isGlowActive: true,
            isHidingNotch: true,
            onboardingRainbow: true
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(OnboardingVisualState.self, from: data)

        XCTAssertEqual(decoded, state)
    }

    func testVisualStateClampsAnimationRanges() {
        let state = OnboardingVisualState(
            glowIntensity: 2.0,
            glowRotation: 725.0,
            cornerBounce: -1.0,
            isGlowActive: true,
            isHidingNotch: false,
            onboardingRainbow: true
        )

        XCTAssertEqual(state.glowIntensity, 1.0)
        XCTAssertEqual(state.glowRotation, 5.0)
        XCTAssertEqual(state.cornerBounce, 0.0)
    }

    func testVisualModelActivatesOnboardingGlowForNonReadySteps() {
        let model = OnboardingVisualStateModel()

        let welcome = model.state(for: .welcome, previous: .idle)
        let ready = model.state(for: .ready, previous: welcome)

        XCTAssertTrue(welcome.isGlowActive)
        XCTAssertTrue(welcome.onboardingRainbow)
        XCTAssertFalse(welcome.isHidingNotch)
        XCTAssertFalse(ready.isGlowActive)
        XCTAssertFalse(ready.onboardingRainbow)
        XCTAssertFalse(ready.isHidingNotch)
    }

    func testVisualModelHidesNotchDuringDemoStep() {
        let state = OnboardingVisualStateModel().state(for: .demo, previous: .idle)

        XCTAssertTrue(state.isGlowActive)
        XCTAssertTrue(state.isHidingNotch)
        XCTAssertGreaterThan(state.cornerBounce, 0.0)
    }

    fileprivate struct OnboardingVisualStateMatrixFixture: Codable, Equatable {
        let idle: OnboardingVisualStateFixture
        let clampedOverflow: OnboardingVisualStateFixture
        let negativeRotation: OnboardingVisualStateFixture
        let stepRows: [OnboardingVisualStateStepRowFixture]
    }

    fileprivate struct OnboardingVisualStateStepRowFixture: Codable, Equatable {
        let step: String
        let state: OnboardingVisualStateFixture
    }

    fileprivate struct OnboardingVisualStateFixture: Codable, Equatable {
        let glowIntensity: Double
        let glowRotation: Double
        let cornerBounce: Double
        let isGlowActive: Bool
        let isHidingNotch: Bool
        let onboardingRainbow: Bool
    }
}

private extension OnboardingVisualState {
    var fixture: OnboardingVisualStateModelsTests.OnboardingVisualStateFixture {
        OnboardingVisualStateModelsTests.OnboardingVisualStateFixture(
            glowIntensity: glowIntensity,
            glowRotation: glowRotation,
            cornerBounce: cornerBounce,
            isGlowActive: isGlowActive,
            isHidingNotch: isHidingNotch,
            onboardingRainbow: onboardingRainbow
        )
    }
}
