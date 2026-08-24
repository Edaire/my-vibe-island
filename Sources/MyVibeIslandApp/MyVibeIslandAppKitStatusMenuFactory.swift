import AppKit
import MyVibeIslandCore

public struct MyVibeIslandAppKitStatusMenuFactory {
    public let commandTarget: AnyObject?
    public let commandAction: Selector?

    public init(
        commandTarget: AnyObject? = nil,
        commandAction: Selector? = nil
    ) {
        self.commandTarget = commandTarget
        self.commandAction = commandAction
    }

    @MainActor
    public func makeMenu(
        from descriptor: MyVibeIslandAppKitStatusMenuDescriptor
    ) -> NSMenu? {
        guard descriptor.isVisible else {
            return nil
        }

        let menu = NSMenu(title: descriptor.accessibilityLabel)
        menu.items = descriptor.items.map(makeMenuItem(from:))
        return menu
    }

    @MainActor
    private func makeMenuItem(
        from descriptor: MyVibeIslandAppKitStatusMenuItemDescriptor
    ) -> NSMenuItem {
        switch descriptor.kind {
        case .separator:
            return NSMenuItem.separator()
        case .command, .sectionHeader:
            let item = NSMenuItem(title: descriptor.title, action: nil, keyEquivalent: "")
            item.isEnabled = descriptor.isEnabled
            item.state = descriptor.state == .on ? .on : .off
            item.identifier = descriptor.command.map { NSUserInterfaceItemIdentifier(commandIdentifier(for: $0)) }
            if descriptor.command != nil {
                item.target = commandTarget
                item.action = commandAction
            }
            return item
        }
    }

    private func commandIdentifier(for command: AppCommand) -> String {
        switch command {
        case .openSettings:
            return "openSettings"
        case .checkForUpdates:
            return "checkForUpdates"
        case .exportDiagnostics:
            return "exportDiagnostics"
        case .toggleDockIcon:
            return "toggleDockIcon"
        case .toggleLaunchAtLogin:
            return "toggleLaunchAtLogin"
        case let .selectScreenMode(mode):
            return "selectScreenMode.\(mode.rawValue)"
        case .quit:
            return "quit"
        }
    }
}
