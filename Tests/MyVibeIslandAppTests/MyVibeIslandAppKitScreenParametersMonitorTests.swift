import AppKit
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class MyVibeIslandAppKitScreenParametersMonitorTests: XCTestCase {
    func testMonitorForwardsScreenParameterChangesAndStopsForwardingAfterStop() {
        let center = NotificationCenter()
        var changeCount = 0
        let monitor = MyVibeIslandAppKitScreenParametersMonitor(
            notificationCenter: center,
            onChange: { changeCount += 1 }
        )

        monitor.start()
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertEqual(changeCount, 1)

        monitor.stop()
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertEqual(changeCount, 1)
    }
}
