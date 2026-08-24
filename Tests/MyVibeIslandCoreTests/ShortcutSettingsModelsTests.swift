import XCTest
@testable import MyVibeIslandCore

final class ShortcutSettingsModelsTests: XCTestCase {
    func testShortcutSettingsMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ShortcutSettingsMatrixFixture.self,
            from: try FixtureLoader.data("settings/shortcut-settings-matrix")
        )

        let disabledSpec = hotKeySpec(
            id: "disabled-toggle",
            action: .toggleIsland,
            keyCode: 49,
            characters: "Space",
            modifiers: [.command],
            scope: .persistentGlobal,
            isEnabled: false
        )
        let toggleSpec = hotKeySpec(
            id: "toggle-island",
            action: .toggleIsland,
            keyCode: 49,
            characters: "Space",
            modifiers: [.command, .option],
            scope: .persistentGlobal
        )
        let panelSpec = hotKeySpec(
            id: "collapse",
            action: .collapsePanel,
            keyCode: 53,
            characters: "Esc",
            modifiers: [],
            scope: .expandedPanel
        )
        let conflictFirst = hotKeySpec(
            id: "focus-active",
            action: .focusActiveSession,
            keyCode: 40,
            characters: "K",
            modifiers: [.command],
            scope: .persistentGlobal
        )
        let conflictSecond = hotKeySpec(
            id: "jump-terminal",
            action: .jumpToTerminal,
            keyCode: 40,
            characters: "K",
            modifiers: [.command],
            scope: .persistentGlobal
        )
        let duplicateAllowed = hotKeySpec(
            id: "navigate-sessions",
            action: .navigateSessions,
            keyCode: 40,
            characters: "K",
            modifiers: [.command],
            scope: .persistentGlobal,
            conflictPolicy: .allowDuplicate
        )

        let actual = ShortcutSettingsMatrixFixture(
            combos: [
                comboRow(id: "negative-cmd-shift", combo: KeyCombo(keyCode: -1, characters: "K", modifiers: [.shift, .command])),
                comboRow(id: "control-tab", combo: KeyCombo(keyCode: 48, characters: "Tab", modifiers: [.control])),
                comboRow(id: "duplicate-modifiers", combo: KeyCombo(keyCode: 36, characters: "Return", modifiers: [.command, .command, .option])),
            ],
            plans: [
                planRow(
                    id: "active-persistent",
                    settings: ShortcutSettings(globalShortcuts: [disabledSpec, toggleSpec], panelShortcuts: [panelSpec]),
                    activeScopes: [.persistentGlobal]
                ),
                planRow(
                    id: "shortcuts-disabled",
                    settings: ShortcutSettings(
                        keyboardShortcutsEnabled: false,
                        globalShortcuts: [toggleSpec],
                        panelShortcuts: [panelSpec]
                    ),
                    activeScopes: [.persistentGlobal, .expandedPanel]
                ),
                planRow(
                    id: "conflict-and-allowed-duplicate",
                    settings: ShortcutSettings(globalShortcuts: [conflictFirst, conflictSecond, duplicateAllowed]),
                    activeScopes: [.persistentGlobal]
                ),
            ],
            persistedGroups: ShortcutPersistedGroupsFixture(
                persistentHotKeyIds: ["toggle-island"],
                expandedHotKeyIds: ["collapse"],
                switcherHotKeyIds: ["navigate-sessions"]
            )
        )

        XCTAssertEqual(actual, expected)
    }

    func testShortcutSettingsRoundTripsPersistedGroupsAndCombos() throws {
        let settings = ShortcutSettings(
            keyboardShortcutsEnabled: true,
            globalShortcuts: [
                HotKeyRegistrationSpec(
                    id: "toggle-island",
                    action: .toggleIsland,
                    keyCombo: KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command, .option]),
                    scope: .persistentGlobal,
                    isEnabled: true
                ),
            ],
            panelShortcuts: [
                HotKeyRegistrationSpec(
                    id: "approve",
                    action: .approvePermission,
                    keyCombo: KeyCombo(keyCode: 36, characters: "Return", modifiers: [.command]),
                    scope: .expandedPanel,
                    isEnabled: true
                ),
            ],
            switcherShortcuts: [],
            persistentHotKeyIds: ["toggle-island"],
            expandedHotKeyIds: ["approve"],
            switcherHotKeyIds: [],
            switcherKeyCombo: KeyCombo(keyCode: 48, characters: "Tab", modifiers: [.control]),
            collapseKeyCombo: KeyCombo(keyCode: 53, characters: "Esc", modifiers: [])
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ShortcutSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(decoded.globalShortcuts.first?.keyCombo.carbonModifiers, 2_304)
        XCTAssertEqual(decoded.switcherKeyCombo?.displayText, "Ctrl-Tab")
    }

    func testKeyComboNormalizesKeyCodeAndDerivesDisplayText() {
        let combo = KeyCombo(keyCode: -1, characters: "K", modifiers: [.shift, .command])

        XCTAssertEqual(combo.keyCode, 0)
        XCTAssertEqual(combo.carbonModifiers, 768)
        XCTAssertEqual(combo.displayText, "Cmd-Shift-K")
    }

    func testShortcutManagerPlansActiveScopeRegistrationAndPreservesDisabledMappings() {
        let disabledSpec = HotKeyRegistrationSpec(
            id: "disabled-toggle",
            action: .toggleIsland,
            keyCombo: KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command]),
            scope: .persistentGlobal,
            isEnabled: false
        )
        let activeSpec = HotKeyRegistrationSpec(
            id: "toggle-island",
            action: .toggleIsland,
            keyCombo: KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command, .option]),
            scope: .persistentGlobal,
            isEnabled: true
        )
        let panelSpec = HotKeyRegistrationSpec(
            id: "collapse",
            action: .collapsePanel,
            keyCombo: KeyCombo(keyCode: 53, characters: "Esc", modifiers: []),
            scope: .expandedPanel,
            isEnabled: true
        )
        let settings = ShortcutSettings(
            keyboardShortcutsEnabled: true,
            globalShortcuts: [disabledSpec, activeSpec],
            panelShortcuts: [panelSpec]
        )

        let plan = ShortcutManager().planRegistrations(
            settings: settings,
            activeScopes: [.persistentGlobal]
        )

        XCTAssertEqual(plan.registrations.map(\.id), ["toggle-island"])
        XCTAssertEqual(plan.skipped.map(\.reason), [.mappingDisabled, .scopeInactive])
        XCTAssertEqual(settings.globalShortcuts.map(\.id), ["disabled-toggle", "toggle-island"])
    }

    func testShortcutManagerReportsConflictsWithoutDroppingUnrelatedRegistrations() {
        let first = HotKeyRegistrationSpec(
            id: "toggle-island",
            action: .toggleIsland,
            keyCombo: KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command]),
            scope: .persistentGlobal,
            isEnabled: true
        )
        let conflicting = HotKeyRegistrationSpec(
            id: "focus-active",
            action: .focusActiveSession,
            keyCombo: KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command]),
            scope: .persistentGlobal,
            isEnabled: true
        )
        let unrelated = HotKeyRegistrationSpec(
            id: "jump-terminal",
            action: .jumpToTerminal,
            keyCombo: KeyCombo(keyCode: 37, characters: "L", modifiers: [.command, .option]),
            scope: .persistentGlobal,
            isEnabled: true
        )

        let plan = ShortcutManager().planRegistrations(
            settings: ShortcutSettings(globalShortcuts: [first, conflicting, unrelated]),
            activeScopes: [.persistentGlobal]
        )

        XCTAssertEqual(plan.registrations.map(\.id), ["toggle-island", "jump-terminal"])
        XCTAssertEqual(plan.conflicts.map(\.specId), ["focus-active"])
        XCTAssertEqual(plan.conflicts.first?.conflictingSpecId, "toggle-island")
    }

    private func hotKeySpec(
        id: String,
        action: ShortcutAction,
        keyCode: Int,
        characters: String,
        modifiers: [ModifierKeyOption],
        scope: ShortcutScope,
        isEnabled: Bool = true,
        conflictPolicy: ShortcutConflictPolicy = .reportConflict
    ) -> HotKeyRegistrationSpec {
        HotKeyRegistrationSpec(
            id: id,
            action: action,
            keyCombo: KeyCombo(keyCode: keyCode, characters: characters, modifiers: modifiers),
            scope: scope,
            isEnabled: isEnabled,
            conflictPolicy: conflictPolicy
        )
    }

    private func comboRow(id: String, combo: KeyCombo) -> ShortcutComboRowFixture {
        ShortcutComboRowFixture(
            id: id,
            keyCode: combo.keyCode,
            characters: combo.characters,
            modifiers: combo.modifiers.map(\.rawValue),
            carbonModifiers: combo.carbonModifiers,
            displayText: combo.displayText
        )
    }

    private func planRow(
        id: String,
        settings: ShortcutSettings,
        activeScopes: Set<ShortcutScope>
    ) -> ShortcutPlanRowFixture {
        let plan = ShortcutManager().planRegistrations(settings: settings, activeScopes: activeScopes)
        return ShortcutPlanRowFixture(
            id: id,
            activeScopes: activeScopes.map(\.rawValue).sorted(),
            registrationIds: plan.registrations.map(\.id),
            skipped: plan.skipped.map {
                ShortcutSkippedFixture(specId: $0.specId, reason: $0.reason.rawValue)
            },
            conflicts: plan.conflicts.map {
                ShortcutConflictFixture(
                    specId: $0.specId,
                    conflictingSpecId: $0.conflictingSpecId,
                    displayText: $0.keyCombo.displayText
                )
            }
        )
    }

    private struct ShortcutSettingsMatrixFixture: Codable, Equatable {
        let combos: [ShortcutComboRowFixture]
        let plans: [ShortcutPlanRowFixture]
        let persistedGroups: ShortcutPersistedGroupsFixture
    }

    private struct ShortcutComboRowFixture: Codable, Equatable {
        let id: String
        let keyCode: Int
        let characters: String
        let modifiers: [String]
        let carbonModifiers: Int
        let displayText: String
    }

    private struct ShortcutPlanRowFixture: Codable, Equatable {
        let id: String
        let activeScopes: [String]
        let registrationIds: [String]
        let skipped: [ShortcutSkippedFixture]
        let conflicts: [ShortcutConflictFixture]
    }

    private struct ShortcutSkippedFixture: Codable, Equatable {
        let specId: String
        let reason: String
    }

    private struct ShortcutConflictFixture: Codable, Equatable {
        let specId: String
        let conflictingSpecId: String
        let displayText: String
    }

    private struct ShortcutPersistedGroupsFixture: Codable, Equatable {
        let persistentHotKeyIds: [String]
        let expandedHotKeyIds: [String]
        let switcherHotKeyIds: [String]
    }
}
