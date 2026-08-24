import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitStatusMenuFactoryTests: XCTestCase {
    final class CommandTarget: NSObject {
        @objc func performStatusMenuCommand(_ sender: NSMenuItem) {}
    }

    @MainActor
    func testStatusMenuFactoryMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            StatusMenuFactoryMatrixFixture.self,
            from: try AppFixtureLoader.data("app/status-menu-factory-matrix")
        )
        let factory = MyVibeIslandAppKitStatusMenuFactory()

        let actual = StatusMenuFactoryMatrixFixture(rows: [
            row(
                id: "hidden-menu",
                menu: factory.makeMenu(from: MyVibeIslandAppKitStatusMenuDescriptor(
                    isVisible: false,
                    accessibilityLabel: "My Vibe Island Menu",
                    items: []
                ))
            ),
            row(
                id: "visible-menu",
                menu: factory.makeMenu(from: MyVibeIslandAppKitStatusMenuDescriptor(
                    isVisible: true,
                    accessibilityLabel: "My Vibe Island Menu",
                    items: [
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
                            title: "Manual Display",
                            command: .selectScreenMode(.manualDisplay),
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
                    ]
                ))
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testHiddenDescriptorDoesNotCreateMenu() {
        let factory = MyVibeIslandAppKitStatusMenuFactory()
        let descriptor = MyVibeIslandAppKitStatusMenuDescriptor(
            isVisible: false,
            accessibilityLabel: "My Vibe Island Menu",
            items: []
        )

        XCTAssertNil(factory.makeMenu(from: descriptor))
    }

    @MainActor
    func testVisibleDescriptorCreatesMenuItems() throws {
        let factory = MyVibeIslandAppKitStatusMenuFactory()
        let descriptor = MyVibeIslandAppKitStatusMenuDescriptor(
            isVisible: true,
            accessibilityLabel: "My Vibe Island Menu",
            items: [
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
            ]
        )

        let menu = try XCTUnwrap(factory.makeMenu(from: descriptor))

        XCTAssertEqual(menu.title, "My Vibe Island Menu")
        XCTAssertEqual(menu.items.map(\.title), [
            "Open Settings",
            "",
            "Launch at Login",
            "Export Diagnostics"
        ])
        XCTAssertEqual(menu.items[0].identifier?.rawValue, "openSettings")
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertEqual(menu.items[2].state, .on)
        XCTAssertEqual(menu.items[2].identifier?.rawValue, "toggleLaunchAtLogin")
        XCTAssertFalse(menu.items[3].isEnabled)
        XCTAssertEqual(menu.items[3].identifier?.rawValue, "exportDiagnostics")
    }

    @MainActor
    func testCommandItemsReceiveConfiguredTargetAndAction() throws {
        let target = CommandTarget()
        let action = #selector(CommandTarget.performStatusMenuCommand(_:))
        let factory = MyVibeIslandAppKitStatusMenuFactory(
            commandTarget: target,
            commandAction: action
        )
        let descriptor = MyVibeIslandAppKitStatusMenuDescriptor(
            isVisible: true,
            accessibilityLabel: "My Vibe Island Menu",
            items: [
                MyVibeIslandAppKitStatusMenuItemDescriptor(
                    kind: .command,
                    title: "Open Settings",
                    command: .openSettings,
                    isEnabled: true
                ),
                MyVibeIslandAppKitStatusMenuItemDescriptor(kind: .separator)
            ]
        )

        let menu = try XCTUnwrap(factory.makeMenu(from: descriptor))

        XCTAssertTrue(menu.items[0].target === target)
        XCTAssertEqual(menu.items[0].action, action)
        XCTAssertNil(menu.items[1].target)
        XCTAssertNil(menu.items[1].action)
    }

    private func row(id: String, menu: NSMenu?) -> StatusMenuFactoryMatrixRow {
        StatusMenuFactoryMatrixRow(
            id: id,
            menuTitle: menu?.title,
            itemCount: menu?.items.count ?? 0,
            items: menu?.items.map { item in
                StatusMenuFactoryItemRow(
                    title: item.title,
                    isSeparator: item.isSeparatorItem,
                    identifier: item.identifier?.rawValue,
                    isEnabled: item.isEnabled,
                    state: item.state == .on ? "on" : "off"
                )
            } ?? []
        )
    }
}

private struct StatusMenuFactoryMatrixFixture: Codable, Equatable {
    let rows: [StatusMenuFactoryMatrixRow]
}

private struct StatusMenuFactoryMatrixRow: Codable, Equatable {
    let id: String
    let menuTitle: String?
    let itemCount: Int
    let items: [StatusMenuFactoryItemRow]
}

private struct StatusMenuFactoryItemRow: Codable, Equatable {
    let title: String
    let isSeparator: Bool
    let identifier: String?
    let isEnabled: Bool
    let state: String
}
