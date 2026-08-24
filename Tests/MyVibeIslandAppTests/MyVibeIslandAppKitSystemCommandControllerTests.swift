import XCTest
import MyVibeIslandCore
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSystemCommandControllerTests: XCTestCase {
    @MainActor
    func testSystemCommandControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SystemCommandControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/system-command-controller-matrix")
        )

        let actual = SystemCommandControllerMatrixFixture(rows: [
            row(
                id: "enable-preferences",
                initialDockIconVisible: false,
                initialLaunchAtLoginEnabled: false,
                initialMaintenanceCommands: [],
                commands: [
                    .setDockIconVisible(true),
                    .setLaunchAtLoginEnabled(true)
                ]
            ),
            row(
                id: "disable-preferences",
                initialDockIconVisible: true,
                initialLaunchAtLoginEnabled: true,
                initialMaintenanceCommands: [],
                commands: [
                    .setDockIconVisible(false),
                    .setLaunchAtLoginEnabled(false)
                ]
            ),
            row(
                id: "maintenance-commands",
                initialDockIconVisible: true,
                initialLaunchAtLoginEnabled: false,
                initialMaintenanceCommands: [.checkForUpdates],
                commands: [
                    .checkForUpdates,
                    .exportDiagnostics
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerRecordsAndAppliesPreferenceAndMaintenanceCommands() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitSystemCommandController(
            setDockIconVisible: { isVisible in
                events.append("dock:\(isVisible)")
            },
            setLaunchAtLoginEnabled: { isEnabled in
                events.append("login:\(isEnabled)")
            },
            checkForUpdates: {
                events.append("updates")
            },
            exportDiagnostics: {
                events.append("diagnostics")
            }
        )

        controller.setDockIconVisible(true)
        controller.setLaunchAtLoginEnabled(false)
        controller.checkForUpdates()
        controller.exportDiagnostics()

        XCTAssertEqual(controller.dockIconVisible, true)
        XCTAssertEqual(controller.launchAtLoginEnabled, false)
        XCTAssertEqual(controller.maintenanceCommands, [.checkForUpdates, .exportDiagnostics])
        XCTAssertEqual(events, [
            "dock:true",
            "login:false",
            "updates",
            "diagnostics"
        ])
    }

    @MainActor
    func testControllerPublishesLastSystemCommandForOrchestration() {
        let controller = MyVibeIslandAppKitSystemCommandController(
            setDockIconVisible: { _ in },
            setLaunchAtLoginEnabled: { _ in },
            checkForUpdates: {},
            exportDiagnostics: {}
        )

        controller.setDockIconVisible(true)

        XCTAssertEqual(controller.lastCommand, .toggleDockIcon)

        controller.exportDiagnostics()

        XCTAssertEqual(controller.lastCommand, .exportDiagnostics)
    }

    @MainActor
    private func row(
        id: String,
        initialDockIconVisible: Bool,
        initialLaunchAtLoginEnabled: Bool,
        initialMaintenanceCommands: [AppCommand],
        commands: [SystemCommandControllerFixtureCommand]
    ) -> SystemCommandControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitSystemCommandController(
            dockIconVisible: initialDockIconVisible,
            launchAtLoginEnabled: initialLaunchAtLoginEnabled,
            maintenanceCommands: initialMaintenanceCommands,
            setDockIconVisible: { isVisible in
                events.append("dock:\(isVisible)")
            },
            setLaunchAtLoginEnabled: { isEnabled in
                events.append("login:\(isEnabled)")
            },
            checkForUpdates: {
                events.append("updates")
            },
            exportDiagnostics: {
                events.append("diagnostics")
            }
        )

        for command in commands {
            switch command {
            case let .setDockIconVisible(isVisible):
                controller.setDockIconVisible(isVisible)
            case let .setLaunchAtLoginEnabled(isEnabled):
                controller.setLaunchAtLoginEnabled(isEnabled)
            case .checkForUpdates:
                controller.checkForUpdates()
            case .exportDiagnostics:
                controller.exportDiagnostics()
            }
        }

        return SystemCommandControllerMatrixRow(
            id: id,
            initialDockIconVisible: initialDockIconVisible,
            initialLaunchAtLoginEnabled: initialLaunchAtLoginEnabled,
            initialMaintenanceCommands: initialMaintenanceCommands.map(\.summary),
            commands: commands.map(\.summary),
            dockIconVisible: controller.dockIconVisible,
            launchAtLoginEnabled: controller.launchAtLoginEnabled,
            maintenanceCommands: controller.maintenanceCommands.map(\.summary),
            lastCommand: controller.lastCommand?.summary,
            events: events
        )
    }
}

private struct SystemCommandControllerMatrixFixture: Codable, Equatable {
    let rows: [SystemCommandControllerMatrixRow]
}

private struct SystemCommandControllerMatrixRow: Codable, Equatable {
    let id: String
    let initialDockIconVisible: Bool
    let initialLaunchAtLoginEnabled: Bool
    let initialMaintenanceCommands: [String]
    let commands: [String]
    let dockIconVisible: Bool
    let launchAtLoginEnabled: Bool
    let maintenanceCommands: [String]
    let lastCommand: String?
    let events: [String]
}

private enum SystemCommandControllerFixtureCommand {
    case setDockIconVisible(Bool)
    case setLaunchAtLoginEnabled(Bool)
    case checkForUpdates
    case exportDiagnostics

    var summary: String {
        switch self {
        case let .setDockIconVisible(isVisible):
            return "setDockIconVisible:\(isVisible)"
        case let .setLaunchAtLoginEnabled(isEnabled):
            return "setLaunchAtLoginEnabled:\(isEnabled)"
        case .checkForUpdates:
            return "checkForUpdates"
        case .exportDiagnostics:
            return "exportDiagnostics"
        }
    }
}

private extension AppCommand {
    var summary: String {
        switch self {
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
            return "selectScreenMode:\(mode.rawValue)"
        case .quit:
            return "quit"
        }
    }
}
