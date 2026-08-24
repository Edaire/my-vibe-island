import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitStatusMenuAdapterTests: XCTestCase {
    func testStatusMenuAdapterMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            StatusMenuAdapterMatrixFixture.self,
            from: try AppFixtureLoader.data("app/status-menu-adapter-matrix")
        )
        let adapter = MyVibeIslandAppKitStatusMenuAdapter()

        let actual = StatusMenuAdapterMatrixFixture(rows: [
            row(
                id: "hidden-status-item-menu",
                descriptor: adapter.makeMenuDescriptor(from: StatusItemMenuSnapshot(
                    surface: .statusItem,
                    isVisible: false,
                    accessibilityLabel: "My Vibe Island Menu",
                    entries: []
                ))
            ),
            row(
                id: "visible-status-item-menu",
                descriptor: adapter.makeMenuDescriptor(from: StatusItemMenuSnapshot(
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
                            title: "Launch at Login",
                            command: .toggleLaunchAtLogin,
                            isEnabled: true,
                            isChecked: true
                        ),
                        StatusItemMenuEntry(
                            kind: .command,
                            title: "Export Diagnostics",
                            command: .exportDiagnostics,
                            isEnabled: false
                        )
                    ]
                ))
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    func testHiddenSnapshotProducesHiddenMenuDescriptor() {
        let adapter = MyVibeIslandAppKitStatusMenuAdapter()
        let snapshot = StatusItemMenuSnapshot(
            surface: .statusItem,
            isVisible: false,
            accessibilityLabel: "My Vibe Island Menu",
            entries: []
        )

        let descriptor = adapter.makeMenuDescriptor(from: snapshot)

        XCTAssertFalse(descriptor.isVisible)
        XCTAssertEqual(descriptor.accessibilityLabel, "My Vibe Island Menu")
        XCTAssertEqual(descriptor.items, [])
    }

    func testVisibleSnapshotProducesStableAppKitItems() {
        let adapter = MyVibeIslandAppKitStatusMenuAdapter()
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
                ),
                StatusItemMenuEntry(kind: .separator, title: ""),
                StatusItemMenuEntry(
                    kind: .command,
                    title: "Launch at Login",
                    command: .toggleLaunchAtLogin,
                    isEnabled: true,
                    isChecked: true
                ),
                StatusItemMenuEntry(
                    kind: .command,
                    title: "Export Diagnostics",
                    command: .exportDiagnostics,
                    isEnabled: false
                )
            ]
        )

        let descriptor = adapter.makeMenuDescriptor(from: snapshot)

        XCTAssertTrue(descriptor.isVisible)
        XCTAssertEqual(descriptor.items, [
            MyVibeIslandAppKitStatusMenuItemDescriptor(
                kind: .command,
                title: "Open Settings",
                command: .openSettings,
                isEnabled: true,
                state: .off
            ),
            MyVibeIslandAppKitStatusMenuItemDescriptor(kind: .separator),
            MyVibeIslandAppKitStatusMenuItemDescriptor(
                kind: .command,
                title: "Launch at Login",
                command: .toggleLaunchAtLogin,
                isEnabled: true,
                state: .on
            ),
            MyVibeIslandAppKitStatusMenuItemDescriptor(
                kind: .command,
                title: "Export Diagnostics",
                command: .exportDiagnostics,
                isEnabled: false,
                state: .off
            )
        ])
    }

    private func row(
        id: String,
        descriptor: MyVibeIslandAppKitStatusMenuDescriptor
    ) -> StatusMenuAdapterMatrixRow {
        StatusMenuAdapterMatrixRow(
            id: id,
            isVisible: descriptor.isVisible,
            accessibilityLabel: descriptor.accessibilityLabel,
            items: descriptor.items.map { item in
                StatusMenuAdapterItemRow(
                    kind: item.kind.rawValue,
                    title: item.title,
                    command: item.command?.summary,
                    isEnabled: item.isEnabled,
                    state: item.state.rawValue
                )
            }
        )
    }
}

private struct StatusMenuAdapterMatrixFixture: Codable, Equatable {
    let rows: [StatusMenuAdapterMatrixRow]
}

private struct StatusMenuAdapterMatrixRow: Codable, Equatable {
    let id: String
    let isVisible: Bool
    let accessibilityLabel: String
    let items: [StatusMenuAdapterItemRow]
}

private struct StatusMenuAdapterItemRow: Codable, Equatable {
    let kind: String
    let title: String
    let command: String?
    let isEnabled: Bool
    let state: String
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
