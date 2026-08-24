import AppKit
import MyVibeIslandCore
import SwiftUI

@MainActor
public final class MyVibeIslandAppKitOnboardingWindowController {
    public private(set) var fullscreenWindow: NSWindow?
    public private(set) var cardWindow: NSWindow?
    public private(set) var readyWindow: NSWindow?
    public var onSelection: @MainActor (MyVibeIslandOnboardingSelection) -> Void
    public var onFinish: @MainActor () -> Void

    private let screenFrame: @MainActor () -> NSRect
    private let readyStateProvider: @MainActor () -> OnboardingReadyWindowState
    private var didFinish = false

    public init(
        screenFrame: @escaping @MainActor () -> NSRect = {
            NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        },
        readyStateProvider: @escaping @MainActor () -> OnboardingReadyWindowState = {
            OnboardingReadyWindowState(
                readinessOutcome: .ready,
                nextActions: [.startUsing]
            )
        },
        onSelection: @escaping @MainActor (MyVibeIslandOnboardingSelection) -> Void = { _ in },
        onFinish: @escaping @MainActor () -> Void = {}
    ) {
        self.screenFrame = screenFrame
        self.readyStateProvider = readyStateProvider
        self.onSelection = onSelection
        self.onFinish = onFinish
    }

    public static func production(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        screenFrame: @escaping @MainActor () -> NSRect = {
            NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        }
    ) -> MyVibeIslandAppKitOnboardingWindowController {
        let integrationController = MyVibeIslandAppKitIntegrationCoordinatorController.production(
            homeDirectory: homeDirectory
        )
        return MyVibeIslandAppKitOnboardingWindowController(
            screenFrame: screenFrame,
            readyStateProvider: {
                _ = integrationController.refresh(
                    at: ISO8601DateFormatter().string(from: Date())
                )
                return MyVibeIslandOnboardingReadinessProvider().state(
                    from: integrationController.state
                )
            }
        )
    }

    public func show() {
        guard fullscreenWindow == nil, cardWindow == nil, readyWindow == nil else { return }
        didFinish = false

        let frame = screenFrame()
        let content = NSHostingView(rootView: MyVibeIslandAppKitProductionFullscreenView(
            onComplete: { [weak self] in self?.completeFullscreen() }
        ))
        content.identifier = NSUserInterfaceItemIdentifier("my-vibe-island.onboarding.fullscreen.host")
        let window = NSWindow(
            contentRect: frame,
            styleMask: NSWindow.StyleMask(rawValue: 2),
            backing: .buffered,
            defer: false
        )
        configure(window, level: NSWindow.Level(rawValue: 26), movableByBackground: false)
        window.contentView = content
        window.setFrame(frame, display: false)
        fullscreenWindow = window
        window.orderFrontRegardless()
    }

    func completeFullscreen() {
        guard let window = fullscreenWindow, cardWindow == nil, readyWindow == nil else { return }

        orderOut(window)
        fullscreenWindow = nil
        showCard()
    }

    func completeCard(
        selection: MyVibeIslandOnboardingSelection = MyVibeIslandOnboardingSelection()
    ) {
        guard let window = cardWindow, readyWindow == nil else { return }

        onSelection(selection)
        orderOut(window)
        cardWindow = nil
        showReady()
    }

    func finish() {
        guard let window = readyWindow, !didFinish else { return }

        didFinish = true
        orderOut(window)
        readyWindow = nil
        onFinish()
    }

    public func close() {
        [fullscreenWindow, cardWindow, readyWindow].compactMap { $0 }.forEach { $0.orderOut(nil) }
        fullscreenWindow = nil
        cardWindow = nil
        readyWindow = nil
    }

    private func showCard() {
        let content = NSHostingView(rootView: MyVibeIslandAppKitProductionCardView(
            onComplete: { [weak self] selection in self?.completeCard(selection: selection) }
        ))
        content.identifier = NSUserInterfaceItemIdentifier("my-vibe-island.onboarding.card.host")
        let window = makeCenteredWindow(contentSize: NSSize(width: 500, height: 640))
        configure(window, level: .normal, movableByBackground: true)
        window.contentView = content
        cardWindow = window
        window.orderFrontRegardless()
    }

    private func showReady() {
        let content = NSHostingView(rootView: MyVibeIslandAppKitProductionReadyView(
            state: readyStateProvider(),
            onFinish: { [weak self] in self?.finish() }
        ))
        content.identifier = NSUserInterfaceItemIdentifier("my-vibe-island.onboarding.ready.host")
        let window = makeCenteredWindow(contentSize: NSSize(width: 800, height: 800))
        configure(window, level: .normal, movableByBackground: false)
        window.contentView = content
        readyWindow = window
        window.orderFrontRegardless()
    }

    private func makeCenteredWindow(contentSize: NSSize) -> NSWindow {
        let screen = screenFrame()
        let origin = NSPoint(
            x: screen.midX - contentSize.width / 2,
            y: screen.midY - contentSize.height / 2
        )
        return NSWindow(
            contentRect: NSRect(origin: origin, size: contentSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
    }

    private func configure(
        _ window: NSWindow,
        level: NSWindow.Level,
        movableByBackground: Bool
    ) {
        window.level = level
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = NSWindow.CollectionBehavior(rawValue: 257)
        window.isMovableByWindowBackground = movableByBackground
        window.isReleasedWhenClosed = false
    }

    private func orderOut(_ window: NSWindow) {
        window.alphaValue = 0
        window.orderOut(nil)
    }
}
