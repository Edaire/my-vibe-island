import AppKit
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class MyVibeIslandAppKitKeyboardFocusTests: XCTestCase {
    func testRequestFocusMakesVisibleNotchPanelKeyWithHostingViewFirstResponder() throws {
        let (controller, panel, hostingView) = makeVisibleController()
        XCTAssertTrue(panel is MyVibeIslandAppKitNotchPanel)

        controller.applyInteractionAction(.requestKeyboardFocus)

        XCTAssertTrue(panel.isKeyWindow)
        XCTAssertTrue(panel.firstResponder === hostingView)
        XCTAssertTrue(controller.keyboardFocusRequested)
        controller.close()
    }

    func testReleaseAndCollapseClearFirstResponderAndResignKeyPanel() throws {
        let (controller, panel, hostingView) = makeVisibleController()
        controller.applyInteractionAction(.requestKeyboardFocus)

        controller.applyInteractionAction(.releaseKeyboardFocus)

        XCTAssertFalse(panel.isKeyWindow)
        XCTAssertFalse(panel.firstResponder === hostingView)
        XCTAssertFalse(controller.keyboardFocusRequested)

        controller.applyInteractionAction(.requestKeyboardFocus)
        controller.applyInteractionAction(.collapsePanel(reason: .outsideClick))

        XCTAssertFalse(panel.isKeyWindow)
        XCTAssertFalse(panel.firstResponder === hostingView)
        XCTAssertFalse(controller.keyboardFocusRequested)
        controller.close()
    }

    func testHideAndCloseClearFirstResponderAndResignKeyPanel() throws {
        let (hiddenController, hiddenPanel, hiddenHostingView) = makeVisibleController()
        hiddenController.applyInteractionAction(.requestKeyboardFocus)

        hiddenController.hide()

        XCTAssertFalse(hiddenPanel.isKeyWindow)
        XCTAssertFalse(hiddenPanel.firstResponder === hiddenHostingView)
        XCTAssertFalse(hiddenController.keyboardFocusRequested)

        let (closedController, closedPanel, closedHostingView) = makeVisibleController()
        closedController.applyInteractionAction(.requestKeyboardFocus)

        closedController.close()

        XCTAssertFalse(closedPanel.isKeyWindow)
        XCTAssertFalse(closedPanel.firstResponder === closedHostingView)
        XCTAssertFalse(closedController.keyboardFocusRequested)
        XCTAssertNil(closedController.panel)
    }

    private func makeVisibleController() -> (
        MyVibeIslandAppKitNotchPanelController<NSPanel>,
        NSPanel,
        NSHostingView<Text>
    ) {
        NSApplication.shared.activate()
        let controller = MyVibeIslandAppKitNotchPanelController<NSPanel>()
        let hostingView = NSHostingView(rootView: Text("Switcher"))
        controller.installContentView(hostingView)
        controller.show()
        return (controller, controller.panel!, hostingView)
    }
}
