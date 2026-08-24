import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitStatusItemMenuPresenterTests: XCTestCase {
    @MainActor
    func testStatusItemMenuPresenterMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            StatusItemMenuPresenterMatrixFixture.self,
            from: try AppFixtureLoader.data("app/status-item-menu-presenter-matrix")
        )

        let actual = StatusItemMenuPresenterMatrixFixture(rows: [
            row(
                id: "visible-menu",
                snapshot: StatusItemMenuSnapshot(
                    surface: .statusItem,
                    isVisible: true,
                    accessibilityLabel: "My Vibe Island Menu",
                    entries: [
                        StatusItemMenuEntry(
                            kind: .command,
                            title: "Open Settings",
                            command: .openSettings,
                            isEnabled: true
                        ),
                        StatusItemMenuEntry(kind: .separator, title: ""),
                        StatusItemMenuEntry(
                            kind: .command,
                            title: "Check for Updates",
                            command: .checkForUpdates,
                            isEnabled: false
                        )
                    ]
                ),
                triggerFirstItem: true
            ),
            row(
                id: "hidden-menu",
                snapshot: StatusItemMenuSnapshot(
                    surface: .statusItem,
                    isVisible: false,
                    accessibilityLabel: "My Vibe Island Menu",
                    entries: []
                ),
                triggerFirstItem: false
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testPresenterBuildsAndInstallsMenuFromSnapshot() throws {
        var installedMenus: [NSMenu?] = []
        var dispatchedCommands: [AppCommand] = []
        let presenter = MyVibeIslandAppKitStatusItemMenuPresenter(
            dispatch: { command in
                dispatchedCommands.append(command)
            },
            installMenu: { menu in
                installedMenus.append(menu)
            }
        )
        let snapshot = StatusItemMenuSnapshot(
            surface: .statusItem,
            isVisible: true,
            accessibilityLabel: "My Vibe Island Menu",
            entries: [
                StatusItemMenuEntry(
                    kind: .command,
                    title: "Open Settings",
                    command: .openSettings,
                    isEnabled: true
                )
            ]
        )

        let result = presenter.apply(snapshot)

        let menu = try XCTUnwrap(result.menu)
        XCTAssertEqual(installedMenus.count, 1)
        XCTAssertTrue(installedMenus[0] === menu)
        XCTAssertEqual(menu.items[0].identifier?.rawValue, "openSettings")
        let router = try XCTUnwrap(menu.items[0].target as? MyVibeIslandAppKitStatusMenuCommandRouter)

        router.performStatusMenuCommand(menu.items[0])

        XCTAssertEqual(dispatchedCommands, [.openSettings])
    }

    @MainActor
    func testPresenterInstallsNilForHiddenSnapshot() {
        var installedMenus: [NSMenu?] = []
        let presenter = MyVibeIslandAppKitStatusItemMenuPresenter(
            dispatch: { _ in },
            installMenu: { menu in
                installedMenus.append(menu)
            }
        )
        let snapshot = StatusItemMenuSnapshot(
            surface: .statusItem,
            isVisible: false,
            accessibilityLabel: "My Vibe Island Menu",
            entries: []
        )

        let result = presenter.apply(snapshot)

        XCTAssertNil(result.menu)
        XCTAssertEqual(installedMenus.count, 1)
        XCTAssertNil(installedMenus[0])
    }

    @MainActor
    func testPresenterPublishesLastPresentationResultForOrchestration() throws {
        let presenter = MyVibeIslandAppKitStatusItemMenuPresenter(
            dispatch: { _ in },
            installMenu: { _ in }
        )
        let snapshot = StatusItemMenuSnapshot(
            surface: .statusItem,
            isVisible: true,
            accessibilityLabel: "My Vibe Island Menu",
            entries: [
                StatusItemMenuEntry(
                    kind: .command,
                    title: "Check for Updates",
                    command: .checkForUpdates,
                    isEnabled: true
                )
            ]
        )

        let result = presenter.apply(snapshot)

        XCTAssertEqual(presenter.lastResult?.descriptor, result.descriptor)
        XCTAssertTrue(presenter.lastResult?.menu === result.menu)
        XCTAssertEqual(presenter.lastResult?.descriptor.items.map(\.command), [.checkForUpdates])
    }

    @MainActor
    private func row(
        id: String,
        snapshot: StatusItemMenuSnapshot,
        triggerFirstItem: Bool
    ) -> StatusItemMenuPresenterMatrixRow {
        var installedMenuTitles: [String?] = []
        var dispatchedCommands: [AppCommand] = []
        let presenter = MyVibeIslandAppKitStatusItemMenuPresenter(
            dispatch: { command in
                dispatchedCommands.append(command)
            },
            installMenu: { menu in
                installedMenuTitles.append(menu?.title)
            }
        )

        let result = presenter.apply(snapshot)
        if triggerFirstItem, let item = result.menu?.items.first {
            presenter.commandRouter.performStatusMenuCommand(item)
        }

        return StatusItemMenuPresenterMatrixRow(
            id: id,
            descriptorVisible: result.descriptor.isVisible,
            descriptorItemCount: result.descriptor.items.count,
            installedMenuTitles: installedMenuTitles,
            menuTitle: result.menu?.title,
            menuItemIdentifiers: result.menu?.items.map { $0.identifier?.rawValue } ?? [],
            dispatchedCommands: dispatchedCommands.map(\.summary),
            lastResultDescriptorItemCount: presenter.lastResult?.descriptor.items.count
        )
    }
}

private struct StatusItemMenuPresenterMatrixFixture: Codable, Equatable {
    let rows: [StatusItemMenuPresenterMatrixRow]
}

private struct StatusItemMenuPresenterMatrixRow: Codable, Equatable {
    let id: String
    let descriptorVisible: Bool
    let descriptorItemCount: Int
    let installedMenuTitles: [String?]
    let menuTitle: String?
    let menuItemIdentifiers: [String?]
    let dispatchedCommands: [String]
    let lastResultDescriptorItemCount: Int?
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
