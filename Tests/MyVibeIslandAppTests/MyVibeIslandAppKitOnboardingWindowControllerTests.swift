import AppKit
import MyVibeIslandCore
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitOnboardingWindowControllerTests: XCTestCase {
    private let screenFrame = NSRect(x: 40, y: 60, width: 1440, height: 900)

    @MainActor
    func testShowCreatesMountedFullscreenWindowWithProductionContract() throws {
        let controller = makeController()
        defer { controller.close() }

        controller.show()

        let window = try XCTUnwrap(controller.fullscreenWindow)
        XCTAssertEqual(window.frame, screenFrame)
        XCTAssertEqual(window.styleMask.rawValue, 2)
        XCTAssertEqual(window.level.rawValue, 26)
        XCTAssertEqual(window.collectionBehavior.rawValue, 257)
        XCTAssertEqual(window.backgroundColor, .clear)
        XCTAssertFalse(window.isOpaque)
        XCTAssertFalse(window.hasShadow)
        XCTAssertFalse(window.isMovableByWindowBackground)
        XCTAssertTrue(window.contentView?.window === window)
        XCTAssertTrue(window.contentView is NSHostingView<MyVibeIslandAppKitProductionFullscreenView>)
    }

    @MainActor
    func testCompletingFullscreenOrdersItOutClearsReferenceAndCreatesCard() throws {
        let controller = makeController()
        defer { controller.close() }
        controller.show()
        let fullscreen = try XCTUnwrap(controller.fullscreenWindow)

        controller.completeFullscreen()

        XCTAssertFalse(fullscreen.isVisible)
        XCTAssertNil(controller.fullscreenWindow)
        let card = try XCTUnwrap(controller.cardWindow)
        XCTAssertEqual(card.contentLayoutRect.size, NSSize(width: 500, height: 640))
        XCTAssertEqual(card.level.rawValue, 0)
        XCTAssertEqual(card.collectionBehavior.rawValue, 257)
        XCTAssertEqual(card.backgroundColor, .clear)
        XCTAssertFalse(card.isOpaque)
        XCTAssertFalse(card.hasShadow)
        XCTAssertTrue(card.isMovableByWindowBackground)
        XCTAssertTrue(card.contentView?.window === card)
        XCTAssertTrue(card.contentView is NSHostingView<MyVibeIslandAppKitProductionCardView>)
        XCTAssertNil(controller.readyWindow)
    }

    @MainActor
    func testCompletingCardOrdersItOutClearsReferenceAndCreatesReady() throws {
        let controller = makeController()
        defer { controller.close() }
        controller.show()
        controller.completeFullscreen()
        let card = try XCTUnwrap(controller.cardWindow)

        controller.completeCard()

        XCTAssertFalse(card.isVisible)
        XCTAssertNil(controller.cardWindow)
        let ready = try XCTUnwrap(controller.readyWindow)
        XCTAssertEqual(ready.contentLayoutRect.size, NSSize(width: 800, height: 800))
        XCTAssertEqual(ready.level.rawValue, 0)
        XCTAssertEqual(ready.collectionBehavior.rawValue, 257)
        XCTAssertEqual(ready.backgroundColor, .clear)
        XCTAssertFalse(ready.isOpaque)
        XCTAssertFalse(ready.hasShadow)
        XCTAssertTrue(ready.contentView?.window === ready)
        XCTAssertTrue(ready.contentView is NSHostingView<MyVibeIslandAppKitProductionReadyView>)
    }

    @MainActor
    func testCompletingCardPublishesTypedSelectionBeforeShowingReady() throws {
        var selections: [MyVibeIslandOnboardingSelection] = []
        let controller = MyVibeIslandAppKitOnboardingWindowController(
            screenFrame: { self.screenFrame },
            onSelection: { selections.append($0) }
        )
        defer { controller.close() }
        controller.show()
        controller.completeFullscreen()
        let selection = MyVibeIslandOnboardingSelection(
            palette: .aurora,
            showCompletedTasks: false,
            playNotificationSounds: false
        )

        controller.completeCard(selection: selection)

        XCTAssertEqual(selections, [selection])
        XCTAssertNotNil(controller.readyWindow)
    }

    @MainActor
    func testStartVibingOrdersOutReadyClearsReferenceAndCompletesOnce() throws {
        var completionCount = 0
        let controller = makeController(onFinish: { completionCount += 1 })
        defer { controller.close() }
        controller.show()
        controller.completeFullscreen()
        controller.completeCard()
        let ready = try XCTUnwrap(controller.readyWindow)
        let host = try XCTUnwrap(ready.contentView as? NSHostingView<MyVibeIslandAppKitProductionReadyView>)

        host.rootView.finish()
        host.rootView.finish()

        XCTAssertFalse(ready.isVisible)
        XCTAssertNil(controller.readyWindow)
        XCTAssertEqual(completionCount, 1)
    }

    @MainActor
    func testBlockedReadyStateDoesNotFinishOnboarding() throws {
        var completionCount = 0
        let controller = MyVibeIslandAppKitOnboardingWindowController(
            screenFrame: { self.screenFrame },
            readyStateProvider: {
                OnboardingReadyWindowState(
                    readinessOutcome: .blocked,
                    nextActions: [.openSettings, .startDemo]
                )
            },
            onFinish: { completionCount += 1 }
        )
        defer { controller.close() }
        controller.show()
        controller.completeFullscreen()
        controller.completeCard()
        let host = try XCTUnwrap(
            controller.readyWindow?.contentView as? NSHostingView<MyVibeIslandAppKitProductionReadyView>
        )

        host.rootView.finish()

        XCTAssertEqual(completionCount, 0)
        XCTAssertNotNil(controller.readyWindow)
    }

    @MainActor
    func testDemoOnlyReadyStateCanFinishIntoLocalDemoMode() throws {
        var completionCount = 0
        let controller = MyVibeIslandAppKitOnboardingWindowController(
            screenFrame: { self.screenFrame },
            readyStateProvider: {
                OnboardingReadyWindowState(
                    readinessOutcome: .demoOnly,
                    nextActions: [.startDemo, .openSettings]
                )
            },
            onFinish: { completionCount += 1 }
        )
        defer { controller.close() }
        controller.show()
        controller.completeFullscreen()
        controller.completeCard()
        let host = try XCTUnwrap(
            controller.readyWindow?.contentView as? NSHostingView<MyVibeIslandAppKitProductionReadyView>
        )

        host.rootView.finish()

        XCTAssertEqual(completionCount, 1)
        XCTAssertNil(controller.readyWindow)
    }

    @MainActor
    func testProductionControllerBuildsBlockedReadyStateFromMalformedIntegration() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandOnboardingReadiness-" + UUID().uuidString)
        let configURL = home.appendingPathComponent(".codex/hooks.json")
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let original = Data("{".utf8)
        try original.write(to: configURL)
        defer { try? FileManager.default.removeItem(at: home) }
        let controller = MyVibeIslandAppKitOnboardingWindowController.production(
            homeDirectory: home,
            screenFrame: { self.screenFrame }
        )
        defer { controller.close() }

        controller.show()
        controller.completeFullscreen()
        controller.completeCard()

        let host = try XCTUnwrap(
            controller.readyWindow?.contentView as? NSHostingView<MyVibeIslandAppKitProductionReadyView>
        )
        XCTAssertEqual(host.rootView.state.readinessOutcome, .blocked)
        XCTAssertEqual(try Data(contentsOf: configURL), original)
    }

    @MainActor
    func testRepeatedShowDoesNotCreateDuplicateWindow() throws {
        let controller = makeController()
        defer { controller.close() }

        controller.show()
        let first = try XCTUnwrap(controller.fullscreenWindow)
        controller.show()

        XCTAssertTrue(controller.fullscreenWindow === first)
        XCTAssertNil(controller.cardWindow)
        XCTAssertNil(controller.readyWindow)
    }

    @MainActor
    func testFinishedControllerCanShowAgainAndCompletesOncePerRound() throws {
        var completionCount = 0
        let controller = makeController(onFinish: { completionCount += 1 })
        defer { controller.close() }

        controller.show()
        controller.completeFullscreen()
        controller.completeCard()
        let firstReady = try XCTUnwrap(
            controller.readyWindow?.contentView as? NSHostingView<MyVibeIslandAppKitProductionReadyView>
        )
        firstReady.rootView.finish()
        firstReady.rootView.finish()

        controller.show()
        XCTAssertNotNil(controller.fullscreenWindow)
        controller.completeFullscreen()
        controller.completeCard()
        let secondReady = try XCTUnwrap(
            controller.readyWindow?.contentView as? NSHostingView<MyVibeIslandAppKitProductionReadyView>
        )
        secondReady.rootView.finish()
        secondReady.rootView.finish()

        XCTAssertEqual(completionCount, 2)
        XCTAssertNil(controller.readyWindow)
    }

    @MainActor
    private func makeController(
        onFinish: @escaping @MainActor () -> Void = {}
    ) -> MyVibeIslandAppKitOnboardingWindowController {
        MyVibeIslandAppKitOnboardingWindowController(
            screenFrame: { self.screenFrame },
            onFinish: onFinish
        )
    }
}
