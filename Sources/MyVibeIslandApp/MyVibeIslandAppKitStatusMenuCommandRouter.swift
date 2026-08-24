import AppKit
import MyVibeIslandCore

public final class MyVibeIslandAppKitStatusMenuCommandRouter: NSObject {
    public private(set) var lastCommand: AppCommand?
    public let dispatch: @MainActor (AppCommand) -> Void

    public init(dispatch: @escaping @MainActor (AppCommand) -> Void) {
        self.dispatch = dispatch
    }

    @objc
    @MainActor
    public func performStatusMenuCommand(_ sender: NSMenuItem) {
        guard let identifier = sender.identifier?.rawValue,
              let command = command(for: identifier) else {
            return
        }

        lastCommand = command
        dispatch(command)
    }

    private func command(for identifier: String) -> AppCommand? {
        switch identifier {
        case "openSettings":
            return .openSettings
        case "checkForUpdates":
            return .checkForUpdates
        case "exportDiagnostics":
            return .exportDiagnostics
        case "toggleDockIcon":
            return .toggleDockIcon
        case "toggleLaunchAtLogin":
            return .toggleLaunchAtLogin
        case "quit":
            return .quit
        default:
            return screenSelectionCommand(for: identifier)
        }
    }

    private func screenSelectionCommand(for identifier: String) -> AppCommand? {
        let prefix = "selectScreenMode."
        guard identifier.hasPrefix(prefix) else {
            return nil
        }

        let rawMode = String(identifier.dropFirst(prefix.count))
        guard let mode = AppScreenSelectionMode(rawValue: rawMode) else {
            return nil
        }

        return .selectScreenMode(mode)
    }
}
