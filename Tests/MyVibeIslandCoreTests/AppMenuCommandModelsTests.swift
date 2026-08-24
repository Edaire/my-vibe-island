import XCTest
@testable import MyVibeIslandCore

final class AppMenuCommandModelsTests: XCTestCase {
    func testAppMenuCommandMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppMenuCommandMatrixFixture.self,
            from: try FixtureLoader.data("settings/app-menu-command-matrix")
        )
        let controller = AppMenuController()
        let normalized = AppMenuSnapshot(
            statusItemVisible: true,
            enabledCommands: [.quit, .openSettings, .openSettings, .selectScreenMode(.mainDisplay)],
            launchAtLoginEnabled: true,
            dockIconVisible: false,
            selectedScreenMode: .manualDisplay,
            updateState: .available,
            diagnosticsExportAvailable: true,
            dockMenuMode: .statusItemAndDock
        )
        let toggleInitial = AppMenuSnapshot(
            enabledCommands: [.toggleDockIcon, .toggleLaunchAtLogin, .selectScreenMode(.mainDisplay)],
            launchAtLoginEnabled: false,
            dockIconVisible: true,
            selectedScreenMode: .builtInNotchDisplay
        )
        let disabled = AppMenuSnapshot(
            enabledCommands: [.openSettings, .checkForUpdates, .exportDiagnostics],
            updateState: .checking,
            diagnosticsExportAvailable: false
        )
        let navigation = AppMenuSnapshot(enabledCommands: [.openSettings, .quit])

        let cases = [
            AppMenuCommandCase(
                name: "snapshot-normalizes-enabled-commands",
                snapshot: AppMenuSnapshotProjection(normalized),
                plan: nil
            ),
            AppMenuCommandCase(
                name: "toggle-dock-icon",
                snapshot: AppMenuSnapshotProjection(toggleInitial),
                plan: AppMenuControllerPlanProjection(controller.plan(.toggleDockIcon, from: toggleInitial))
            ),
            AppMenuCommandCase(
                name: "toggle-launch-at-login",
                snapshot: AppMenuSnapshotProjection(toggleInitial),
                plan: AppMenuControllerPlanProjection(controller.plan(.toggleLaunchAtLogin, from: toggleInitial))
            ),
            AppMenuCommandCase(
                name: "select-main-display",
                snapshot: AppMenuSnapshotProjection(toggleInitial),
                plan: AppMenuControllerPlanProjection(controller.plan(.selectScreenMode(.mainDisplay), from: toggleInitial))
            ),
            AppMenuCommandCase(
                name: "checking-update-disabled",
                snapshot: AppMenuSnapshotProjection(disabled),
                plan: AppMenuControllerPlanProjection(controller.plan(.checkForUpdates, from: disabled))
            ),
            AppMenuCommandCase(
                name: "diagnostics-disabled",
                snapshot: AppMenuSnapshotProjection(disabled),
                plan: AppMenuControllerPlanProjection(controller.plan(.exportDiagnostics, from: disabled))
            ),
            AppMenuCommandCase(
                name: "navigation-open-settings",
                snapshot: AppMenuSnapshotProjection(navigation),
                plan: AppMenuControllerPlanProjection(controller.plan(.openSettings, from: navigation))
            ),
            AppMenuCommandCase(
                name: "navigation-quit",
                snapshot: AppMenuSnapshotProjection(navigation),
                plan: AppMenuControllerPlanProjection(controller.plan(.quit, from: navigation))
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testAppCommandRoundTripsMenuCommandNames() throws {
        let commands: [AppCommand] = [
            .openSettings,
            .checkForUpdates,
            .exportDiagnostics,
            .toggleDockIcon,
            .toggleLaunchAtLogin,
            .selectScreenMode(.followKeyboardFocus),
            .quit
        ]

        let data = try JSONEncoder().encode(commands)
        let decoded = try JSONDecoder().decode([AppCommand].self, from: data)

        XCTAssertEqual(decoded, commands)
    }

    func testMenuSnapshotNormalizesVisibleItemsAndSelection() {
        let snapshot = AppMenuSnapshot(
            statusItemVisible: true,
            enabledCommands: [.quit, .openSettings, .openSettings],
            launchAtLoginEnabled: true,
            dockIconVisible: false,
            selectedScreenMode: .manualDisplay,
            updateState: .available,
            diagnosticsExportAvailable: true,
            dockMenuMode: .statusItemAndDock
        )

        XCTAssertEqual(snapshot.enabledCommands, [.openSettings, .quit])
        XCTAssertTrue(snapshot.isEnabled(.openSettings))
        XCTAssertFalse(snapshot.isEnabled(.checkForUpdates))
        XCTAssertEqual(snapshot.selectedScreenMode, .manualDisplay)
    }

    func testMenuControllerPlansTogglesAndScreenSelection() {
        let controller = AppMenuController()
        let initial = AppMenuSnapshot(
            enabledCommands: [.toggleDockIcon, .toggleLaunchAtLogin, .selectScreenMode(.mainDisplay)],
            launchAtLoginEnabled: false,
            dockIconVisible: true,
            selectedScreenMode: .builtInNotchDisplay
        )

        let dock = controller.plan(.toggleDockIcon, from: initial)
        XCTAssertFalse(dock.nextSnapshot.dockIconVisible)
        XCTAssertEqual(dock.routedCommand, .toggleDockIcon)

        let login = controller.plan(.toggleLaunchAtLogin, from: dock.nextSnapshot)
        XCTAssertTrue(login.nextSnapshot.launchAtLoginEnabled)
        XCTAssertEqual(login.routedCommand, .toggleLaunchAtLogin)

        let screen = controller.plan(.selectScreenMode(.mainDisplay), from: login.nextSnapshot)
        XCTAssertEqual(screen.nextSnapshot.selectedScreenMode, .mainDisplay)
        XCTAssertEqual(screen.routedCommand, .selectScreenMode(.mainDisplay))
    }

    func testDisabledCommandsDoNotRouteOrMutate() {
        let controller = AppMenuController()
        let snapshot = AppMenuSnapshot(
            enabledCommands: [.openSettings],
            updateState: .checking,
            diagnosticsExportAvailable: false
        )

        let update = controller.plan(.checkForUpdates, from: snapshot)
        XCTAssertEqual(update.action, .ignoredDisabledCommand)
        XCTAssertEqual(update.nextSnapshot, snapshot)
        XCTAssertNil(update.routedCommand)

        let diagnostics = controller.plan(.exportDiagnostics, from: snapshot)
        XCTAssertEqual(diagnostics.action, .ignoredDisabledCommand)
        XCTAssertEqual(diagnostics.nextSnapshot, snapshot)
        XCTAssertNil(diagnostics.routedCommand)
    }

    func testNavigationCommandsRouteWithoutChangingSnapshot() {
        let controller = AppMenuController()
        let snapshot = AppMenuSnapshot(enabledCommands: [.openSettings, .quit])

        let settings = controller.plan(.openSettings, from: snapshot)
        XCTAssertEqual(settings.nextSnapshot, snapshot)
        XCTAssertEqual(settings.routedCommand, .openSettings)

        let quit = controller.plan(.quit, from: snapshot)
        XCTAssertEqual(quit.nextSnapshot, snapshot)
        XCTAssertEqual(quit.routedCommand, .quit)
    }

    private struct AppMenuCommandMatrixFixture: Codable, Equatable {
        let cases: [AppMenuCommandCase]
    }

    private struct AppMenuCommandCase: Codable, Equatable {
        let name: String
        let snapshot: AppMenuSnapshotProjection
        let plan: AppMenuControllerPlanProjection?
    }

    private struct AppMenuSnapshotProjection: Codable, Equatable {
        let statusItemVisible: Bool
        let enabledCommands: [String]
        let launchAtLoginEnabled: Bool
        let dockIconVisible: Bool
        let selectedScreenMode: AppScreenSelectionMode
        let updateState: AppMenuUpdateState
        let diagnosticsExportAvailable: Bool
        let dockMenuMode: AppDockMenuMode

        init(_ snapshot: AppMenuSnapshot) {
            self.statusItemVisible = snapshot.statusItemVisible
            self.enabledCommands = snapshot.enabledCommands.map(AppMenuControllerPlanProjection.commandLabel)
            self.launchAtLoginEnabled = snapshot.launchAtLoginEnabled
            self.dockIconVisible = snapshot.dockIconVisible
            self.selectedScreenMode = snapshot.selectedScreenMode
            self.updateState = snapshot.updateState
            self.diagnosticsExportAvailable = snapshot.diagnosticsExportAvailable
            self.dockMenuMode = snapshot.dockMenuMode
        }
    }

    private struct AppMenuControllerPlanProjection: Codable, Equatable {
        let action: AppMenuControllerAction
        let nextSnapshot: AppMenuSnapshotProjection
        let routedCommand: String?

        init(_ plan: AppMenuControllerPlan) {
            self.action = plan.action
            self.nextSnapshot = AppMenuSnapshotProjection(plan.nextSnapshot)
            self.routedCommand = plan.routedCommand.map(Self.commandLabel)
        }

        static func commandLabel(_ command: AppCommand) -> String {
            switch command {
            case .openSettings:
                return "openSettings"
            case .checkForUpdates:
                return "checkForUpdates"
            case .exportDiagnostics:
                return "exportDiagnostics"
            case .quit:
                return "quit"
            case .toggleDockIcon:
                return "toggleDockIcon"
            case .toggleLaunchAtLogin:
                return "toggleLaunchAtLogin"
            case let .selectScreenMode(mode):
                return "selectScreenMode:\(mode.rawValue)"
            }
        }
    }
}
