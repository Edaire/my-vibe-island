import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandOnboardingViewsTests: XCTestCase {
    func testOnboardingViewPresentationMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OnboardingViewMatrixFixture.self,
            from: try AppFixtureLoader.data("app/onboarding-view-matrix")
        )
        let presentationText = (
            MyVibeIslandOnboardingDemoPresentation.cards.map(\.title)
                + MyVibeIslandOnboardingDemoPresentation.captions.flatMap {
                    [$0.label, $0.main, $0.sub]
                }
                + [
                    MyVibeIslandOnboardingReadyPresentation.title,
                    MyVibeIslandOnboardingReadyPresentation.restartHint,
                    MyVibeIslandOnboardingReadyPresentation.ctaTitle,
                ]
        ).joined(separator: " ").lowercased()
        let actual = OnboardingViewMatrixFixture(
            cards: MyVibeIslandOnboardingDemoPresentation.cards.map {
                OnboardingDemoCardFixture(
                    bundleIdentifier: $0.bundleIdentifier,
                    title: $0.title,
                    symbol: $0.symbol,
                    body: $0.body
                )
            },
            captions: MyVibeIslandOnboardingDemoPresentation.captions.map {
                OnboardingCaptionFixture(
                    time: $0.time,
                    label: $0.label,
                    main: $0.main,
                    sub: $0.sub
                )
            },
            eventTimes: MyVibeIslandOnboardingDemoPresentation.timeline.map(\.time),
            readyTitle: MyVibeIslandOnboardingReadyPresentation.title,
            restartHint: MyVibeIslandOnboardingReadyPresentation.restartHint,
            ctaTitle: MyVibeIslandOnboardingReadyPresentation.ctaTitle,
            palettes: MyVibeIslandOnboardingPalette.allCases.map(\.rawValue),
            commercialTermsPresent: ["license key", "free trial", "purchase", "pricing", "buy now"]
                .contains { presentationText.contains($0) }
        )

        XCTAssertEqual(actual, expected)
    }

    func testPaletteSelectionAlwaysExcludesCurrentPalette() {
        for current in MyVibeIslandOnboardingPalette.allCases {
            let selected = (0..<12).map {
                MyVibeIslandOnboardingPalette.next(excluding: current, selectionIndex: $0)
            }

            XCTAssertFalse(selected.contains(current))
            XCTAssertEqual(Set(selected), Set(MyVibeIslandOnboardingPalette.allCases.filter { $0 != current }))
        }
    }

    func testDemoViewStateAppliesConfirmedTimelineEvents() {
        var state = MyVibeIslandOnboardingDemoViewState.initial

        XCTAssertEqual(state.visibleCardCount, 0)
        XCTAssertNil(state.captionIndex)
        XCTAssertFalse(state.isFinished)

        for event in MyVibeIslandOnboardingDemoPresentation.timeline {
            state = state.applying(event.action)
        }

        XCTAssertEqual(state.visibleCardCount, 3)
        XCTAssertEqual(state.captionIndex, 2)
        XCTAssertTrue(state.isFinished)
    }

    @MainActor
    func testCallbacksCanRunWithoutMountingViews() {
        var events: [String] = []
        let demo = StepDemoView(
            state: OnboardingDemoRunnerState(defaultCwd: "/tmp/demo"),
            onNext: { events.append("demo") }
        )
        let ready = StepReadyView(
            state: OnboardingReadyWindowState(
                readinessOutcome: .ready,
                nextActions: [.startUsing]
            ),
            onFinish: { events.append("ready") }
        )

        demo.finish()
        ready.finish()

        XCTAssertEqual(events, ["demo", "ready"])
    }

}

private struct OnboardingViewMatrixFixture: Codable, Equatable {
    let cards: [OnboardingDemoCardFixture]
    let captions: [OnboardingCaptionFixture]
    let eventTimes: [Double]
    let readyTitle: String
    let restartHint: String
    let ctaTitle: String
    let palettes: [String]
    let commercialTermsPresent: Bool
}

private struct OnboardingDemoCardFixture: Codable, Equatable {
    let bundleIdentifier: String
    let title: String
    let symbol: String?
    let body: String
}

private struct OnboardingCaptionFixture: Codable, Equatable {
    let time: Double
    let label: String
    let main: String
    let sub: String
}
