import XCTest
@testable import MyVibeIslandCore

final class FocusModeLogEventTests: XCTestCase {
    func testParsesOriginalDuetExpertFocusStartEvent() {
        let line = "2026-08-18 10:00:00 duetexpertd: semanticModeIdentifier: com.apple.focus.work, starting: 1, semanticType: work"

        XCTAssertEqual(
            FocusModeLogEvent.parse(line),
            FocusModeLogEvent(
                modeIdentifier: "com.apple.focus.work",
                isStarting: true,
                semanticType: "work"
            )
        )
    }

    func testParsesOriginalDuetExpertFocusStopEvent() {
        let line = "semanticModeIdentifier: com.apple.focus.work, starting: 0, semanticType: work"

        XCTAssertEqual(
            FocusModeLogEvent.parse(line)?.modeIdentifier,
            "com.apple.focus.work"
        )
        XCTAssertEqual(FocusModeLogEvent.parse(line)?.isStarting, false)
    }

    func testRejectsLogLineWithoutOriginalFocusMarker() {
        XCTAssertNil(FocusModeLogEvent.parse("semanticType: work, starting: 1"))
    }

    func testFocusStateOnlyClearsForStopOfTheCurrentMode() {
        var state = FocusModeActivityState(activeModeIdentifier: "com.apple.focus.work")

        XCTAssertFalse(state.apply(FocusModeLogEvent(
            modeIdentifier: "com.apple.focus.personal-time",
            isStarting: false,
            semanticType: "personal"
        )))
        XCTAssertEqual(state.activeModeIdentifier, "com.apple.focus.work")

        XCTAssertTrue(state.apply(FocusModeLogEvent(
            modeIdentifier: "com.apple.focus.work",
            isStarting: false,
            semanticType: "work"
        )))
        XCTAssertNil(state.activeModeIdentifier)
    }
}
