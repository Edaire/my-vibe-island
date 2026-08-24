import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitQuietSceneMonitorTests: XCTestCase {
    @MainActor
    func testScreenObscuredStatePublishesOnlyOnAggregateEdge() {
        var published: [Bool] = []
        let monitor = MyVibeIslandAppKitQuietSceneMonitor(
            enabled: [.screenObscured: true],
            publishStateDidChange: { state in published.append(state.isQuietSceneActive) }
        )

        XCTAssertTrue(monitor.setScreenObscured(true))
        XCTAssertFalse(monitor.setScreenObscured(true))
        XCTAssertTrue(monitor.isQuietSceneActive)
        XCTAssertTrue(monitor.setScreenObscured(false))
        XCTAssertFalse(monitor.isQuietSceneActive)
        XCTAssertEqual(published, [true, false])
    }

    @MainActor
    func testScreenCaptureStatePublishesOnlyOnAggregateEdge() {
        var published: [Bool] = []
        let monitor = MyVibeIslandAppKitQuietSceneMonitor(
            enabled: [.screenCapture: true],
            publishStateDidChange: { state in published.append(state.isQuietSceneActive) }
        )

        XCTAssertTrue(monitor.setScreenCapture(true))
        XCTAssertFalse(monitor.setScreenCapture(true))
        XCTAssertTrue(monitor.isQuietSceneActive)
        XCTAssertTrue(monitor.setScreenCapture(false))
        XCTAssertFalse(monitor.isQuietSceneActive)
        XCTAssertEqual(published, [true, false])
    }

    @MainActor
    func testOriginalFocusLogEventsDriveOnlyConfiguredQuietModes() {
        var published: [Bool] = []
        let monitor = MyVibeIslandAppKitQuietSceneMonitor(
            enabled: [.focus: true],
            focusQuietModeIdentifiers: ["com.apple.focus.work"],
            publishStateDidChange: { state in published.append(state.isQuietSceneActive) }
        )

        monitor.observeFocusLogLine(
            "semanticModeIdentifier: com.apple.focus.personal-time, starting: 1, semanticType: personal"
        )
        XCTAssertFalse(monitor.isQuietSceneActive)

        monitor.observeFocusLogLine(
            "semanticModeIdentifier: com.apple.focus.work, starting: 1, semanticType: work"
        )
        XCTAssertTrue(monitor.isQuietSceneActive)

        monitor.observeFocusLogLine(
            "semanticModeIdentifier: com.apple.focus.work, starting: 0, semanticType: work"
        )
        XCTAssertFalse(monitor.isQuietSceneActive)
        XCTAssertEqual(published, [true, false])
    }
}
