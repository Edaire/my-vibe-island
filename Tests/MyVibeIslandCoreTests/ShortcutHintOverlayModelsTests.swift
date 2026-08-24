import XCTest
@testable import MyVibeIslandCore

final class ShortcutHintOverlayModelsTests: XCTestCase {
    func testShortcutHintOverlayMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ShortcutHintOverlayMatrixFixture.self,
            from: try FixtureLoader.data("settings/shortcut-hint-overlay-matrix")
        )

        let settings = ShortcutSettings(
            globalShortcuts: [
                HotKeyRegistrationSpec(
                    id: "toggle-island",
                    action: .toggleIsland,
                    keyCombo: KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command]),
                    scope: .persistentGlobal
                ),
            ],
            panelShortcuts: [
                HotKeyRegistrationSpec(
                    id: "approve",
                    action: .approvePermission,
                    keyCombo: KeyCombo(keyCode: 36, characters: "Return", modifiers: [.command]),
                    scope: .expandedPanel
                ),
                HotKeyRegistrationSpec(
                    id: "always-allow",
                    action: .alwaysAllow,
                    keyCombo: KeyCombo(keyCode: 1, characters: "A", modifiers: [.command, .option]),
                    scope: .expandedPanel
                ),
                HotKeyRegistrationSpec(
                    id: "disabled-deny",
                    action: .denyPermission,
                    keyCombo: KeyCombo(keyCode: 51, characters: "Delete", modifiers: [.command]),
                    scope: .expandedPanel,
                    isEnabled: false
                ),
                HotKeyRegistrationSpec(
                    id: "collapse",
                    action: .collapsePanel,
                    keyCombo: KeyCombo(keyCode: 53, characters: "Esc", modifiers: []),
                    scope: .expandedPanel
                ),
            ]
        )

        let model = ShortcutHintOverlayModel()
        let actual = ShortcutHintOverlayMatrixFixture(rows: [
            row(id: "collapsed-command", state: model.state(settings: settings, modifierKey: .command, isPanelExpanded: false)),
            row(id: "expanded-command", state: model.state(settings: settings, modifierKey: .command, isPanelExpanded: true)),
            row(id: "expanded-option", state: model.state(settings: settings, modifierKey: .option, isPanelExpanded: true)),
            row(id: "expanded-shift-no-match", state: model.state(settings: settings, modifierKey: .shift, isPanelExpanded: true)),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testShortcutHintOverlayStateRoundTripsVisibleModifierAndItems() throws {
        let state = ShortcutHintOverlayState(
            isVisible: true,
            modifierKey: .command,
            items: [
                ShortcutHintItem(action: .approvePermission, title: "Approve", keyCombo: KeyCombo(keyCode: 36, characters: "Return", modifiers: [.command])),
            ]
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ShortcutHintOverlayState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.items.first?.displayText, "Cmd-Return")
    }

    func testShortcutHintOverlayBuildsPanelLocalHintsOnly() {
        let settings = ShortcutSettings(
            globalShortcuts: [
                HotKeyRegistrationSpec(
                    id: "toggle-island",
                    action: .toggleIsland,
                    keyCombo: KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command]),
                    scope: .persistentGlobal
                ),
            ],
            panelShortcuts: [
                HotKeyRegistrationSpec(
                    id: "approve",
                    action: .approvePermission,
                    keyCombo: KeyCombo(keyCode: 36, characters: "Return", modifiers: [.command]),
                    scope: .expandedPanel
                ),
                HotKeyRegistrationSpec(
                    id: "disabled-deny",
                    action: .denyPermission,
                    keyCombo: KeyCombo(keyCode: 51, characters: "Delete", modifiers: [.command]),
                    scope: .expandedPanel,
                    isEnabled: false
                ),
            ]
        )

        let state = ShortcutHintOverlayModel().state(
            settings: settings,
            modifierKey: .command,
            isPanelExpanded: true
        )

        XCTAssertTrue(state.isVisible)
        XCTAssertEqual(state.items.map(\.action), [.approvePermission])
        XCTAssertEqual(state.items.map(\.title), ["Approve"])
    }

    func testShortcutHintOverlayHidesWhenPanelIsCollapsedOrNoMatchingModifierHints() {
        let settings = ShortcutSettings(
            panelShortcuts: [
                HotKeyRegistrationSpec(
                    id: "collapse",
                    action: .collapsePanel,
                    keyCombo: KeyCombo(keyCode: 53, characters: "Esc", modifiers: []),
                    scope: .expandedPanel
                ),
            ]
        )

        let model = ShortcutHintOverlayModel()
        let collapsed = model.state(settings: settings, modifierKey: .command, isPanelExpanded: false)
        let noModifierMatch = model.state(settings: settings, modifierKey: .command, isPanelExpanded: true)

        XCTAssertFalse(collapsed.isVisible)
        XCTAssertTrue(collapsed.items.isEmpty)
        XCTAssertFalse(noModifierMatch.isVisible)
        XCTAssertTrue(noModifierMatch.items.isEmpty)
    }

    private func row(
        id: String,
        state: ShortcutHintOverlayState
    ) -> ShortcutHintOverlayRow {
        ShortcutHintOverlayRow(
            id: id,
            isVisible: state.isVisible,
            modifierKey: state.modifierKey.rawValue,
            items: state.items.map {
                ShortcutHintItemFixture(
                    action: $0.action.rawValue,
                    title: $0.title,
                    displayText: $0.displayText
                )
            }
        )
    }

    private struct ShortcutHintOverlayMatrixFixture: Codable, Equatable {
        let rows: [ShortcutHintOverlayRow]
    }

    private struct ShortcutHintOverlayRow: Codable, Equatable {
        let id: String
        let isVisible: Bool
        let modifierKey: String
        let items: [ShortcutHintItemFixture]
    }

    private struct ShortcutHintItemFixture: Codable, Equatable {
        let action: String
        let title: String
        let displayText: String
    }
}
