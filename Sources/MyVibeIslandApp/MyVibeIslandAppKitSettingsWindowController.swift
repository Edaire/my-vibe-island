import AppKit
import MyVibeIslandCore
import SwiftUI

@MainActor
public final class SettingsWindow: NSWindow {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = "Settings"
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        titlebarSeparatorStyle = .line
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
public final class MyVibeIslandAppKitSettingsWindowController {
    private var window: SettingsWindow?
    private var closeObserver: NSObjectProtocol?
    private var previousApp: NSRunningApplication?

    public init() {}

    isolated deinit {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
    }

    public func open(_ deepLink: SettingsDeepLink?) {
        show(deepLink?.section)
    }

    private func show(_ section: SettingsSection?) {
        if previousApp == nil {
            previousApp = NSWorkspace.shared.frontmostApplication
        }

        if let window {
            if let section {
                window.contentView = makeContentView(section: section)
            }
            present(window)
            return
        }

        let window = SettingsWindow()
        window.contentView = makeContentView(section: section ?? .general)
        window.center()
        window.contentView?.layoutSubtreeIfNeeded()
        self.window = window
        observeClose(of: window)
        present(window)
    }

    private func makeContentView(section: SettingsSection) -> NSView {
        NSHostingView(rootView: SettingsView(selectedSection: section))
    }

    private func present(_ window: SettingsWindow) {
        if !window.isVisible, let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let frame = window.frame
            window.setFrameOrigin(NSPoint(
                x: visibleFrame.midX - frame.width / 2,
                y: visibleFrame.midY - frame.height / 2
            ))
        }

        window.level = .floating
        window.orderFrontRegardless()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak window] in
            window?.level = .normal
            window?.makeKey()
        }
    }

    private func observeClose(of window: SettingsWindow) {
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleClose()
            }
        }
    }

    private func handleClose() {
        NSApp.setActivationPolicy(.accessory)
        restorePreviousApplication()
    }

    private func restorePreviousApplication() {
        defer { previousApp = nil }
        guard let previousApp, !previousApp.isTerminated else { return }
        guard previousApp.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        previousApp.activate(options: [])
    }
}
