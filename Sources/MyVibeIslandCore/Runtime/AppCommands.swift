public enum AppScreenSelectionMode: String, Codable, Equatable, Hashable, Sendable, Comparable {
    case builtInNotchDisplay
    case mainDisplay
    case followKeyboardFocus
    case manualDisplay
    case fallbackDisplay

    public static func < (lhs: AppScreenSelectionMode, rhs: AppScreenSelectionMode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum AppCommand: Codable, Equatable, Hashable, Sendable, Comparable {
    case openSettings
    case checkForUpdates
    case exportDiagnostics
    case toggleDockIcon
    case toggleLaunchAtLogin
    case selectScreenMode(AppScreenSelectionMode)
    case quit

    public static func < (lhs: AppCommand, rhs: AppCommand) -> Bool {
        lhs.sortKey < rhs.sortKey
    }

    private var sortKey: String {
        switch self {
        case .openSettings:
            return "00:openSettings"
        case .checkForUpdates:
            return "01:checkForUpdates"
        case .exportDiagnostics:
            return "02:exportDiagnostics"
        case .toggleDockIcon:
            return "03:toggleDockIcon"
        case .toggleLaunchAtLogin:
            return "04:toggleLaunchAtLogin"
        case let .selectScreenMode(mode):
            return "05:selectScreenMode:\(mode.rawValue)"
        case .quit:
            return "99:quit"
        }
    }
}

public enum AppMenuUpdateState: String, Codable, Equatable, Sendable {
    case unavailable
    case checking
    case available
    case upToDate
}

public enum AppDockMenuMode: String, Codable, Equatable, Sendable {
    case statusItemOnly
    case dockOnly
    case statusItemAndDock
}

public struct AppMenuSnapshot: Codable, Equatable, Sendable {
    public let statusItemVisible: Bool
    public let enabledCommands: [AppCommand]
    public let launchAtLoginEnabled: Bool
    public let dockIconVisible: Bool
    public let selectedScreenMode: AppScreenSelectionMode
    public let updateState: AppMenuUpdateState
    public let diagnosticsExportAvailable: Bool
    public let dockMenuMode: AppDockMenuMode

    public init(
        statusItemVisible: Bool = true,
        enabledCommands: [AppCommand] = [],
        launchAtLoginEnabled: Bool = false,
        dockIconVisible: Bool = false,
        selectedScreenMode: AppScreenSelectionMode = .builtInNotchDisplay,
        updateState: AppMenuUpdateState = .unavailable,
        diagnosticsExportAvailable: Bool = false,
        dockMenuMode: AppDockMenuMode = .statusItemOnly
    ) {
        self.statusItemVisible = statusItemVisible
        self.enabledCommands = Array(Set(enabledCommands)).sorted()
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.dockIconVisible = dockIconVisible
        self.selectedScreenMode = selectedScreenMode
        self.updateState = updateState
        self.diagnosticsExportAvailable = diagnosticsExportAvailable
        self.dockMenuMode = dockMenuMode
    }

    public func isEnabled(_ command: AppCommand) -> Bool {
        enabledCommands.contains(command)
    }

    public func replacing(
        launchAtLoginEnabled: Bool? = nil,
        dockIconVisible: Bool? = nil,
        selectedScreenMode: AppScreenSelectionMode? = nil
    ) -> AppMenuSnapshot {
        AppMenuSnapshot(
            statusItemVisible: statusItemVisible,
            enabledCommands: enabledCommands,
            launchAtLoginEnabled: launchAtLoginEnabled ?? self.launchAtLoginEnabled,
            dockIconVisible: dockIconVisible ?? self.dockIconVisible,
            selectedScreenMode: selectedScreenMode ?? self.selectedScreenMode,
            updateState: updateState,
            diagnosticsExportAvailable: diagnosticsExportAvailable,
            dockMenuMode: dockMenuMode
        )
    }
}

public enum AppMenuControllerAction: String, Codable, Equatable, Sendable {
    case routeCommand
    case ignoredDisabledCommand
}

public struct AppMenuControllerPlan: Equatable, Sendable {
    public let action: AppMenuControllerAction
    public let nextSnapshot: AppMenuSnapshot
    public let routedCommand: AppCommand?

    public init(
        action: AppMenuControllerAction,
        nextSnapshot: AppMenuSnapshot,
        routedCommand: AppCommand? = nil
    ) {
        self.action = action
        self.nextSnapshot = nextSnapshot
        self.routedCommand = routedCommand
    }
}

public struct AppMenuController: Sendable {
    public init() {}

    public func plan(_ command: AppCommand, from snapshot: AppMenuSnapshot) -> AppMenuControllerPlan {
        guard snapshot.isEnabled(command), isAvailable(command, in: snapshot) else {
            return AppMenuControllerPlan(action: .ignoredDisabledCommand, nextSnapshot: snapshot)
        }

        switch command {
        case .toggleDockIcon:
            return routed(
                command,
                snapshot: snapshot.replacing(dockIconVisible: !snapshot.dockIconVisible)
            )
        case .toggleLaunchAtLogin:
            return routed(
                command,
                snapshot: snapshot.replacing(launchAtLoginEnabled: !snapshot.launchAtLoginEnabled)
            )
        case let .selectScreenMode(mode):
            return routed(command, snapshot: snapshot.replacing(selectedScreenMode: mode))
        case .openSettings, .checkForUpdates, .exportDiagnostics, .quit:
            return routed(command, snapshot: snapshot)
        }
    }

    private func isAvailable(_ command: AppCommand, in snapshot: AppMenuSnapshot) -> Bool {
        switch command {
        case .checkForUpdates:
            return snapshot.updateState != .checking
        case .exportDiagnostics:
            return snapshot.diagnosticsExportAvailable
        case .openSettings, .toggleDockIcon, .toggleLaunchAtLogin, .selectScreenMode, .quit:
            return true
        }
    }

    private func routed(_ command: AppCommand, snapshot: AppMenuSnapshot) -> AppMenuControllerPlan {
        AppMenuControllerPlan(action: .routeCommand, nextSnapshot: snapshot, routedCommand: command)
    }
}
