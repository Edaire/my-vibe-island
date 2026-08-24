import XCTest
@testable import MyVibeIslandCore

final class StatusItemMenuModelsTests: XCTestCase {
    func testStatusItemMenuMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            StatusItemMenuMatrixFixture.self,
            from: try FixtureLoader.data("settings/status-item-menu-matrix")
        )
        let builder = StatusItemMenuBuilder()
        let hiddenStatusItem = AppMenuSnapshot(
            statusItemVisible: false,
            enabledCommands: [.openSettings, .quit]
        )
        let hiddenDock = AppMenuSnapshot(
            enabledCommands: [.openSettings, .quit],
            dockMenuMode: .statusItemOnly
        )
        let full = fullSnapshot()
        let disabledAvailability = AppMenuSnapshot(
            enabledCommands: [.openSettings, .checkForUpdates, .exportDiagnostics, .quit],
            updateState: .checking,
            diagnosticsExportAvailable: false,
            dockMenuMode: .statusItemAndDock
        )
        let manualSelection = AppMenuSnapshot(
            enabledCommands: [
                .toggleLaunchAtLogin,
                .toggleDockIcon,
                .selectScreenMode(.builtInNotchDisplay),
                .selectScreenMode(.manualDisplay)
            ],
            launchAtLoginEnabled: true,
            dockIconVisible: false,
            selectedScreenMode: .manualDisplay
        )

        let cases = [
            StatusItemMenuCase(
                name: "hidden-status-item-builds-no-rows",
                menu: StatusItemMenuProjection(builder.build(from: hiddenStatusItem, surface: .statusItem))
            ),
            StatusItemMenuCase(
                name: "dock-menu-hidden-when-status-item-only",
                menu: StatusItemMenuProjection(builder.build(from: hiddenDock, surface: .dock))
            ),
            StatusItemMenuCase(
                name: "full-status-item-menu",
                menu: StatusItemMenuProjection(builder.build(from: full, surface: .statusItem))
            ),
            StatusItemMenuCase(
                name: "dock-menu-safe-command-subset",
                menu: StatusItemMenuProjection(builder.build(from: full, surface: .dock))
            ),
            StatusItemMenuCase(
                name: "disabled-availability-keeps-rows",
                menu: StatusItemMenuProjection(builder.build(from: disabledAvailability, surface: .statusItem))
            ),
            StatusItemMenuCase(
                name: "toggle-and-manual-selection-checkmarks",
                menu: StatusItemMenuProjection(builder.build(from: manualSelection, surface: .statusItem))
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testHiddenStatusItemBuildsNoRows() {
        let builder = StatusItemMenuBuilder()
        let snapshot = AppMenuSnapshot(statusItemVisible: false, enabledCommands: [.openSettings, .quit])

        let menu = builder.build(from: snapshot, surface: .statusItem)

        XCTAssertFalse(menu.isVisible)
        XCTAssertEqual(menu.surface, .statusItem)
        XCTAssertEqual(menu.entries, [])
    }

    func testStatusItemRowsAreBuiltInStableOrder() {
        let builder = StatusItemMenuBuilder()
        let snapshot = fullSnapshot()

        let menu = builder.build(from: snapshot, surface: .statusItem)

        XCTAssertEqual(menu.entries.map(\.title), [
            "Open Settings",
            "Check for Updates",
            "",
            "Launch at Login",
            "Show Dock Icon",
            "",
            "Built-in Notch Display",
            "Main Display",
            "Follow Keyboard Focus",
            "Manual Display",
            "",
            "Export Diagnostics",
            "",
            "Quit My Vibe Island"
        ])
        XCTAssertEqual(menu.entries.compactMap(\.command), [
            .openSettings,
            .checkForUpdates,
            .toggleLaunchAtLogin,
            .toggleDockIcon,
            .selectScreenMode(.builtInNotchDisplay),
            .selectScreenMode(.mainDisplay),
            .selectScreenMode(.followKeyboardFocus),
            .selectScreenMode(.manualDisplay),
            .exportDiagnostics,
            .quit
        ])
    }

    func testToggleAndScreenRowsMirrorSnapshotState() {
        let builder = StatusItemMenuBuilder()
        let snapshot = AppMenuSnapshot(
            enabledCommands: [
                .toggleLaunchAtLogin,
                .toggleDockIcon,
                .selectScreenMode(.builtInNotchDisplay),
                .selectScreenMode(.manualDisplay)
            ],
            launchAtLoginEnabled: true,
            dockIconVisible: false,
            selectedScreenMode: .manualDisplay
        )

        let menu = builder.build(from: snapshot, surface: .statusItem)

        XCTAssertEqual(menu.entry(for: .toggleLaunchAtLogin)?.isChecked, true)
        XCTAssertEqual(menu.entry(for: .toggleDockIcon)?.isChecked, false)
        XCTAssertEqual(menu.entry(for: .selectScreenMode(.builtInNotchDisplay))?.isChecked, false)
        XCTAssertEqual(menu.entry(for: .selectScreenMode(.manualDisplay))?.isChecked, true)
    }

    func testDockMenuOnlyIncludesSafeCommands() {
        let builder = StatusItemMenuBuilder()

        let menu = builder.build(from: fullSnapshot(), surface: .dock)

        XCTAssertTrue(menu.isVisible)
        XCTAssertEqual(menu.entries.compactMap(\.command), [
            .openSettings,
            .checkForUpdates,
            .exportDiagnostics,
            .quit
        ])
        XCTAssertFalse(menu.entries.contains { $0.command == .toggleDockIcon })
        XCTAssertFalse(menu.entries.contains { $0.command == .toggleLaunchAtLogin })
        XCTAssertFalse(menu.entries.contains { entry in
            if case .selectScreenMode = entry.command {
                return true
            }
            return false
        })
    }

    func testAvailabilityMarksRowsDisabledWithoutRemovingThem() {
        let builder = StatusItemMenuBuilder()
        let snapshot = AppMenuSnapshot(
            enabledCommands: [.openSettings, .checkForUpdates, .exportDiagnostics, .quit],
            updateState: .checking,
            diagnosticsExportAvailable: false
        )

        let menu = builder.build(from: snapshot, surface: .statusItem)

        XCTAssertEqual(menu.entry(for: .checkForUpdates)?.title, "Checking for Updates")
        XCTAssertEqual(menu.entry(for: .checkForUpdates)?.isEnabled, false)
        XCTAssertEqual(menu.entry(for: .exportDiagnostics)?.isEnabled, false)
        XCTAssertEqual(menu.entry(for: .openSettings)?.isEnabled, true)
    }

    func testMenuSnapshotRoundTripsThroughJSON() throws {
        let menu = StatusItemMenuBuilder().build(from: fullSnapshot(), surface: .statusItem)

        let decoded = try JSONDecoder().decode(
            StatusItemMenuSnapshot.self,
            from: try JSONEncoder().encode(menu)
        )

        XCTAssertEqual(decoded, menu)
    }

    private func fullSnapshot() -> AppMenuSnapshot {
        AppMenuSnapshot(
            enabledCommands: [
                .openSettings,
                .checkForUpdates,
                .exportDiagnostics,
                .toggleDockIcon,
                .toggleLaunchAtLogin,
                .selectScreenMode(.builtInNotchDisplay),
                .selectScreenMode(.mainDisplay),
                .selectScreenMode(.followKeyboardFocus),
                .selectScreenMode(.manualDisplay),
                .quit
            ],
            launchAtLoginEnabled: true,
            dockIconVisible: true,
            selectedScreenMode: .followKeyboardFocus,
            updateState: .available,
            diagnosticsExportAvailable: true,
            dockMenuMode: .statusItemAndDock
        )
    }

    private struct StatusItemMenuMatrixFixture: Codable, Equatable {
        let cases: [StatusItemMenuCase]
    }

    private struct StatusItemMenuCase: Codable, Equatable {
        let name: String
        let menu: StatusItemMenuProjection
    }

    private struct StatusItemMenuProjection: Codable, Equatable {
        let surface: AppMenuSurface
        let isVisible: Bool
        let accessibilityLabel: String
        let entries: [StatusItemMenuEntryProjection]

        init(_ snapshot: StatusItemMenuSnapshot) {
            self.surface = snapshot.surface
            self.isVisible = snapshot.isVisible
            self.accessibilityLabel = snapshot.accessibilityLabel
            self.entries = snapshot.entries.map(StatusItemMenuEntryProjection.init)
        }
    }

    private struct StatusItemMenuEntryProjection: Codable, Equatable {
        let kind: StatusItemMenuEntryKind
        let title: String
        let command: String?
        let isEnabled: Bool
        let isChecked: Bool

        init(_ entry: StatusItemMenuEntry) {
            self.kind = entry.kind
            self.title = entry.title
            self.command = entry.command.map(Self.commandLabel)
            self.isEnabled = entry.isEnabled
            self.isChecked = entry.isChecked
        }

        private static func commandLabel(_ command: AppCommand) -> String {
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
