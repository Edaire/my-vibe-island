import AppKit
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class MyVibeIslandAppKitScreenParametersMonitorTests: XCTestCase {
    func testMonitorForwardsScreenParameterChangesAndStopsForwardingAfterStop() async {
        let center = NotificationCenter()
        var changeCount = 0
        let monitor = MyVibeIslandAppKitScreenParametersMonitor(
            notificationCenter: center,
            screenChangeDelayNanoseconds: 1_000_000,
            onChange: { changeCount += 1 }
        )

        monitor.start()
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(changeCount, 1)

        monitor.stop()
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(changeCount, 1)
    }

    func testMonitorCoalescesScreenChangesUntilDisplayGeometrySettles() async {
        let center = NotificationCenter()
        var changeCount = 0
        let monitor = MyVibeIslandAppKitScreenParametersMonitor(
            notificationCenter: center,
            screenChangeDelayNanoseconds: 1_000_000,
            onChange: { changeCount += 1 }
        )

        monitor.start()
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)

        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(changeCount, 1)
        monitor.stop()
    }

    func testMonitorCancelsPendingSettledRefreshWhenStopped() async {
        let center = NotificationCenter()
        var changeCount = 0
        let monitor = MyVibeIslandAppKitScreenParametersMonitor(
            notificationCenter: center,
            screenChangeDelayNanoseconds: 20_000_000,
            onChange: { changeCount += 1 }
        )

        monitor.start()
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        monitor.stop()

        try? await Task.sleep(nanoseconds: 40_000_000)

        XCTAssertEqual(changeCount, 0)
    }
}
