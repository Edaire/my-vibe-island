import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSystemCommandController {
    public private(set) var dockIconVisible: Bool
    public private(set) var launchAtLoginEnabled: Bool
    public private(set) var maintenanceCommands: [AppCommand]
    public private(set) var lastCommand: AppCommand?

    private let applyDockIconVisible: @MainActor (Bool) -> Void
    private let applyLaunchAtLoginEnabled: @MainActor (Bool) -> Void
    private let runCheckForUpdates: @MainActor () -> Void
    private let runExportDiagnostics: @MainActor () -> Void

    public init(
        dockIconVisible: Bool = false,
        launchAtLoginEnabled: Bool = false,
        maintenanceCommands: [AppCommand] = [],
        setDockIconVisible: @escaping @MainActor (Bool) -> Void = { _ in },
        setLaunchAtLoginEnabled: @escaping @MainActor (Bool) -> Void = { _ in },
        checkForUpdates: @escaping @MainActor () -> Void = {},
        exportDiagnostics: @escaping @MainActor () -> Void = {}
    ) {
        self.dockIconVisible = dockIconVisible
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.maintenanceCommands = maintenanceCommands
        self.applyDockIconVisible = setDockIconVisible
        self.applyLaunchAtLoginEnabled = setLaunchAtLoginEnabled
        self.runCheckForUpdates = checkForUpdates
        self.runExportDiagnostics = exportDiagnostics
    }

    public func setDockIconVisible(_ isVisible: Bool) {
        dockIconVisible = isVisible
        lastCommand = .toggleDockIcon
        applyDockIconVisible(isVisible)
    }

    public func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        launchAtLoginEnabled = isEnabled
        lastCommand = .toggleLaunchAtLogin
        applyLaunchAtLoginEnabled(isEnabled)
    }

    public func checkForUpdates() {
        maintenanceCommands.append(.checkForUpdates)
        lastCommand = .checkForUpdates
        runCheckForUpdates()
    }

    public func exportDiagnostics() {
        maintenanceCommands.append(.exportDiagnostics)
        lastCommand = .exportDiagnostics
        runExportDiagnostics()
    }
}
