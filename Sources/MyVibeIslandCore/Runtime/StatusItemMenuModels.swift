public enum AppMenuSurface: String, Codable, Equatable, Sendable {
    case statusItem
    case dock
}

public enum StatusItemMenuEntryKind: String, Codable, Equatable, Sendable {
    case command
    case separator
    case sectionHeader
}

public struct StatusItemMenuEntry: Codable, Equatable, Sendable {
    public let kind: StatusItemMenuEntryKind
    public let title: String
    public let command: AppCommand?
    public let isEnabled: Bool
    public let isChecked: Bool

    public init(
        kind: StatusItemMenuEntryKind,
        title: String,
        command: AppCommand? = nil,
        isEnabled: Bool = false,
        isChecked: Bool = false
    ) {
        self.kind = kind
        self.title = title
        self.command = command
        self.isEnabled = isEnabled
        self.isChecked = isChecked
    }
}

public struct StatusItemMenuSnapshot: Codable, Equatable, Sendable {
    public let surface: AppMenuSurface
    public let isVisible: Bool
    public let accessibilityLabel: String
    public let entries: [StatusItemMenuEntry]

    public init(
        surface: AppMenuSurface,
        isVisible: Bool,
        accessibilityLabel: String,
        entries: [StatusItemMenuEntry]
    ) {
        self.surface = surface
        self.isVisible = isVisible
        self.accessibilityLabel = accessibilityLabel
        self.entries = entries
    }

    public func entry(for command: AppCommand) -> StatusItemMenuEntry? {
        entries.first { $0.command == command }
    }
}

public struct StatusItemMenuBuilder: Sendable {
    public init() {}

    public func build(
        from snapshot: AppMenuSnapshot,
        surface: AppMenuSurface
    ) -> StatusItemMenuSnapshot {
        let isVisible = isVisible(snapshot, on: surface)
        guard isVisible else {
            return StatusItemMenuSnapshot(
                surface: surface,
                isVisible: false,
                accessibilityLabel: accessibilityLabel(for: surface),
                entries: []
            )
        }

        return StatusItemMenuSnapshot(
            surface: surface,
            isVisible: true,
            accessibilityLabel: accessibilityLabel(for: surface),
            entries: entries(from: snapshot, surface: surface)
        )
    }

    private func isVisible(_ snapshot: AppMenuSnapshot, on surface: AppMenuSurface) -> Bool {
        switch surface {
        case .statusItem:
            return snapshot.statusItemVisible
        case .dock:
            return snapshot.dockMenuMode == .dockOnly || snapshot.dockMenuMode == .statusItemAndDock
        }
    }

    private func entries(from snapshot: AppMenuSnapshot, surface: AppMenuSurface) -> [StatusItemMenuEntry] {
        switch surface {
        case .statusItem:
            return statusItemEntries(from: snapshot)
        case .dock:
            return dockEntries(from: snapshot)
        }
    }

    private func statusItemEntries(from snapshot: AppMenuSnapshot) -> [StatusItemMenuEntry] {
        [
            command(.openSettings, title: "Open Settings", snapshot: snapshot),
            command(.checkForUpdates, title: updateTitle(snapshot.updateState), snapshot: snapshot),
            separator(),
            command(
                .toggleLaunchAtLogin,
                title: "Launch at Login",
                snapshot: snapshot,
                isChecked: snapshot.launchAtLoginEnabled
            ),
            command(
                .toggleDockIcon,
                title: "Show Dock Icon",
                snapshot: snapshot,
                isChecked: snapshot.dockIconVisible
            ),
            separator(),
            screenMode(.builtInNotchDisplay, title: "Built-in Notch Display", snapshot: snapshot),
            screenMode(.mainDisplay, title: "Main Display", snapshot: snapshot),
            screenMode(.followKeyboardFocus, title: "Follow Keyboard Focus", snapshot: snapshot),
            screenMode(.manualDisplay, title: "Manual Display", snapshot: snapshot),
            separator(),
            command(.exportDiagnostics, title: "Export Diagnostics", snapshot: snapshot),
            separator(),
            command(.quit, title: "Quit My Vibe Island", snapshot: snapshot)
        ]
    }

    private func dockEntries(from snapshot: AppMenuSnapshot) -> [StatusItemMenuEntry] {
        [
            command(.openSettings, title: "Open Settings", snapshot: snapshot),
            command(.checkForUpdates, title: updateTitle(snapshot.updateState), snapshot: snapshot),
            command(.exportDiagnostics, title: "Export Diagnostics", snapshot: snapshot),
            command(.quit, title: "Quit My Vibe Island", snapshot: snapshot)
        ]
    }

    private func command(
        _ command: AppCommand,
        title: String,
        snapshot: AppMenuSnapshot,
        isChecked: Bool = false
    ) -> StatusItemMenuEntry {
        StatusItemMenuEntry(
            kind: .command,
            title: title,
            command: command,
            isEnabled: isEnabled(command, in: snapshot),
            isChecked: isChecked
        )
    }

    private func screenMode(
        _ mode: AppScreenSelectionMode,
        title: String,
        snapshot: AppMenuSnapshot
    ) -> StatusItemMenuEntry {
        command(
            .selectScreenMode(mode),
            title: title,
            snapshot: snapshot,
            isChecked: snapshot.selectedScreenMode == mode
        )
    }

    private func separator() -> StatusItemMenuEntry {
        StatusItemMenuEntry(kind: .separator, title: "")
    }

    private func isEnabled(_ command: AppCommand, in snapshot: AppMenuSnapshot) -> Bool {
        guard snapshot.isEnabled(command) else {
            return false
        }

        switch command {
        case .checkForUpdates:
            return snapshot.updateState != .checking
        case .exportDiagnostics:
            return snapshot.diagnosticsExportAvailable
        case .openSettings,
             .toggleDockIcon,
             .toggleLaunchAtLogin,
             .selectScreenMode,
             .quit:
            return true
        }
    }

    private func updateTitle(_ state: AppMenuUpdateState) -> String {
        switch state {
        case .checking:
            return "Checking for Updates"
        case .available, .unavailable, .upToDate:
            return "Check for Updates"
        }
    }

    private func accessibilityLabel(for surface: AppMenuSurface) -> String {
        switch surface {
        case .statusItem:
            return "My Vibe Island Menu"
        case .dock:
            return "My Vibe Island Dock Menu"
        }
    }
}
