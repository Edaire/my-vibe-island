import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitStatusMenuCommandRouterTests: XCTestCase {
    @MainActor
    func testStatusMenuCommandRouterMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            StatusMenuCommandRouterMatrixFixture.self,
            from: try AppFixtureLoader.data("app/status-menu-command-router-matrix")
        )

        let actual = StatusMenuCommandRouterMatrixFixture(rows: [
            row(id: "open-settings", identifier: "openSettings"),
            row(id: "toggle-dock", identifier: "toggleDockIcon"),
            row(id: "screen-manual", identifier: "selectScreenMode.manualDisplay"),
            row(id: "screen-invalid", identifier: "selectScreenMode.unknown"),
            row(id: "unknown", identifier: "unknown"),
            row(id: "missing", identifier: nil)
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testRouterDispatchesCommandFromMenuItemIdentifier() {
        var commands: [AppCommand] = []
        let router = MyVibeIslandAppKitStatusMenuCommandRouter { command in
            commands.append(command)
        }
        let item = NSMenuItem(title: "Show Dock Icon", action: nil, keyEquivalent: "")
        item.identifier = NSUserInterfaceItemIdentifier("toggleDockIcon")

        router.performStatusMenuCommand(item)

        XCTAssertEqual(commands, [.toggleDockIcon])
    }

    @MainActor
    func testRouterDecodesScreenSelectionCommand() {
        var commands: [AppCommand] = []
        let router = MyVibeIslandAppKitStatusMenuCommandRouter { command in
            commands.append(command)
        }
        let item = NSMenuItem(title: "Manual Display", action: nil, keyEquivalent: "")
        item.identifier = NSUserInterfaceItemIdentifier("selectScreenMode.manualDisplay")

        router.performStatusMenuCommand(item)

        XCTAssertEqual(commands, [.selectScreenMode(.manualDisplay)])
    }

    @MainActor
    func testRouterPublishesLastDispatchedCommandForComposition() {
        let router = MyVibeIslandAppKitStatusMenuCommandRouter { _ in }
        let item = NSMenuItem(title: "Check for Updates", action: nil, keyEquivalent: "")
        item.identifier = NSUserInterfaceItemIdentifier("checkForUpdates")

        router.performStatusMenuCommand(item)

        XCTAssertEqual(router.lastCommand, .checkForUpdates)
    }

    @MainActor
    func testRouterIgnoresMissingOrUnknownIdentifiers() {
        var commands: [AppCommand] = []
        let router = MyVibeIslandAppKitStatusMenuCommandRouter { command in
            commands.append(command)
        }

        router.performStatusMenuCommand(NSMenuItem(title: "Missing", action: nil, keyEquivalent: ""))
        let unknown = NSMenuItem(title: "Unknown", action: nil, keyEquivalent: "")
        unknown.identifier = NSUserInterfaceItemIdentifier("unknown")
        router.performStatusMenuCommand(unknown)

        XCTAssertEqual(commands, [])
    }

    @MainActor
    private func row(id: String, identifier: String?) -> StatusMenuCommandRouterMatrixRow {
        var commands: [AppCommand] = []
        let router = MyVibeIslandAppKitStatusMenuCommandRouter { command in
            commands.append(command)
        }
        let item = NSMenuItem(title: id, action: nil, keyEquivalent: "")
        if let identifier {
            item.identifier = NSUserInterfaceItemIdentifier(identifier)
        }

        router.performStatusMenuCommand(item)

        return StatusMenuCommandRouterMatrixRow(
            id: id,
            identifier: identifier,
            dispatchedCommands: commands.map(\.summary),
            lastCommand: router.lastCommand?.summary
        )
    }
}

private struct StatusMenuCommandRouterMatrixFixture: Codable, Equatable {
    let rows: [StatusMenuCommandRouterMatrixRow]
}

private struct StatusMenuCommandRouterMatrixRow: Codable, Equatable {
    let id: String
    let identifier: String?
    let dispatchedCommands: [String]
    let lastCommand: String?
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
