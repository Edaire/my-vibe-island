import AppKit
import MyVibeIslandCore

public enum MyVibeIslandAppKitRoute: Equatable {
    case showIsland
    case openSettings(SettingsDeepLink?)
    case showOnboarding
    case quit
}

@MainActor
public final class MyVibeIslandAppKitRouteController {
    public private(set) var lastRoute: MyVibeIslandAppKitRoute?

    public let activateApplication: @MainActor () -> Void
    public let showWindow: @MainActor (String) -> Void
    public let quitApplication: @MainActor () -> Void
    private let settingsWindowController: MyVibeIslandAppKitSettingsWindowController?
    private let onboardingWindowController: MyVibeIslandAppKitOnboardingWindowController?

    public init(
        activateApplication: @escaping @MainActor () -> Void = {
            NSApplication.shared.activate()
        },
        showWindow: @escaping @MainActor (String) -> Void = { identifier in
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = identifier
            window.contentView = NSTextField(labelWithString: identifier)
            window.center()
            window.makeKeyAndOrderFront(nil)
        },
        settingsWindowController: MyVibeIslandAppKitSettingsWindowController? = nil,
        onboardingWindowController: MyVibeIslandAppKitOnboardingWindowController? = nil,
        quitApplication: @escaping @MainActor () -> Void = {
            NSApplication.shared.terminate(nil)
        }
    ) {
        self.activateApplication = activateApplication
        self.showWindow = showWindow
        self.settingsWindowController = settingsWindowController
        self.onboardingWindowController = onboardingWindowController
        self.quitApplication = quitApplication
    }

    public func showIsland() {
        lastRoute = .showIsland
        activateApplication()
    }

    public func openSettings(_ deepLink: SettingsDeepLink?) {
        lastRoute = .openSettings(deepLink)
        if let settingsWindowController {
            settingsWindowController.open(deepLink)
            return
        }
        showWindow(settingsWindowIdentifier(for: deepLink))
    }

    public func showOnboarding() {
        lastRoute = .showOnboarding
        onboardingWindowController?.show()
    }

    public func quit() {
        lastRoute = .quit
        quitApplication()
    }

    private func settingsWindowIdentifier(for deepLink: SettingsDeepLink?) -> String {
        let link = deepLink ?? SettingsDeepLink(section: .general)
        if let rowId = link.rowId {
            return "settings:\(link.section.rawValue):\(rowId)"
        }
        return "settings:\(link.section.rawValue)"
    }
}
