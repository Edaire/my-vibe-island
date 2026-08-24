import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class KeyboardShortcutManagerTests: XCTestCase {
    func testKeyComboMatchesIDAFieldLayoutAndCodableShape() throws {
        let combo = MyVibeIslandApp.KeyCombo(keyCode: 49, carbonModifiers: 256)

        XCTAssertEqual(Mirror(reflecting: combo).children.compactMap(\.label), [
            "keyCode", "carbonModifiers",
        ])
        XCTAssertEqual(combo.keyCode, 49)
        XCTAssertEqual(combo.carbonModifiers, 256)
        XCTAssertEqual(
            try JSONDecoder().decode(
                MyVibeIslandApp.KeyCombo.self,
                from: JSONEncoder().encode(combo)
            ),
            combo
        )
    }

    func testApprovalActionOrderMatchesIDAEnumTags() {
        XCTAssertEqual(ApprovalAction.allCases, [
            .approve, .deny, .terminal, .always, .bypass,
        ])
    }

    @MainActor
    func testStoredFieldsMatchIDAReflection() {
        let manager = KeyboardShortcutManager(
            modifierKey: .option,
            shortcutsEnabled: false,
            reverseSwitcherEnabled: true
        )

        XCTAssertEqual(Mirror(reflecting: manager).children.compactMap(\.label), [
            "_persistentHotKeyIds", "_expandedHotKeyIds", "_switcherHotKeyIds",
            "_isActive", "_isPersistentActive", "_isSwitcherActive",
            "_flagsMonitor", "_localFlagsMonitor", "_globalKeyDownMonitor", "_localKeyDownMonitor",
            "_lastFiredAt", "dedupWindow", "relevantModifierFlags", "_switcherHasNavigated",
            "_switcherOpenedAt", "modifierHoldThreshold", "_isModifierHeld", "_modifierKey",
            "_shortcutsEnabled", "_reverseSwitcherEnabled", "_approvalKeys",
            "_switcherKeyCombo", "_collapseKeyCombo", "_$observationRegistrar",
        ])
    }

    @MainActor
    func testSettingsPropertiesMutateWithoutStartingRuntimeMonitors() {
        let manager = KeyboardShortcutManager(
            modifierKey: .command,
            shortcutsEnabled: true,
            reverseSwitcherEnabled: false
        )

        manager.modifierKey = .control
        manager.shortcutsEnabled = false
        manager.reverseSwitcherEnabled = true

        XCTAssertEqual(manager.modifierKey, .control)
        XCTAssertFalse(manager.shortcutsEnabled)
        XCTAssertTrue(manager.reverseSwitcherEnabled)
        XCTAssertFalse(manager.hasInstalledEventMonitors)
    }

    @MainActor
    func testSharedReturnsStableProcessSingleton() {
        XCTAssertTrue(KeyboardShortcutManager.shared === KeyboardShortcutManager.shared)
    }

    @MainActor
    func testMappingFieldsUseRecoveredConcreteTypes() throws {
        let manager = KeyboardShortcutManager(
            approvalKeys: [.approve: 36, .deny: 53],
            switcherKeyCombo: MyVibeIslandApp.KeyCombo(keyCode: 48, carbonModifiers: 256),
            collapseKeyCombo: MyVibeIslandApp.KeyCombo(keyCode: 53, carbonModifiers: 0)
        )
        let fields = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: manager).children.compactMap {
                child -> (String, Any)? in
                guard let label = child.label else { return nil }
                return (label, child.value)
            }
        )

        XCTAssertNotNil(fields["_approvalKeys"] as? [ApprovalAction: UInt32])
        XCTAssertNotNil(fields["_switcherKeyCombo"] as? MyVibeIslandApp.KeyCombo)
        XCTAssertNotNil(fields["_collapseKeyCombo"] as? MyVibeIslandApp.KeyCombo)
    }

    @MainActor
    func testApprovalKeyUpdateRejectsReservedAndDuplicateKeyCodes() {
        let manager = KeyboardShortcutManager(
            approvalKeys: [.approve: 36, .deny: 53]
        )

        XCTAssertFalse(manager.updateApprovalKey(36, for: .deny))
        XCTAssertFalse(manager.updateApprovalKey(126, for: .terminal))
        XCTAssertEqual(manager.approvalKeys, [.approve: 36, .deny: 53])

        XCTAssertTrue(manager.updateApprovalKey(40, for: .terminal))
        XCTAssertEqual(manager.approvalKeys[.terminal], 40)
    }

    @MainActor
    func testSwitcherAndCollapseMappingsReplaceWithoutStartingMonitors() {
        let manager = KeyboardShortcutManager(
            switcherKeyCombo: MyVibeIslandApp.KeyCombo(keyCode: 48, carbonModifiers: 256),
            collapseKeyCombo: MyVibeIslandApp.KeyCombo(keyCode: 53, carbonModifiers: 0)
        )
        let switcher = MyVibeIslandApp.KeyCombo(keyCode: 49, carbonModifiers: 4096)
        let collapse = MyVibeIslandApp.KeyCombo(keyCode: 36, carbonModifiers: 0)

        manager.updateSwitcherKeyCombo(switcher)
        manager.updateCollapseKeyCombo(collapse)

        XCTAssertEqual(manager.switcherKeyCombo, switcher)
        XCTAssertEqual(manager.collapseKeyCombo, collapse)
        XCTAssertFalse(manager.hasInstalledEventMonitors)
    }

    @MainActor
    func testSettingsLoadAndPersistRecoveredPreferenceKeys() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "KeyboardShortcutManagerTests.\(UUID().uuidString)"))
        defaults.set("option", forKey: "modifierKey")
        defaults.set(false, forKey: "keyboardShortcutsEnabled")
        defaults.set(false, forKey: "reverseSwitcherEnabled")
        KeyboardShortcutManager.preferenceStore = LocalPreferenceStore(defaults: defaults)
        defer { KeyboardShortcutManager.preferenceStore = LocalPreferenceStore() }

        let manager = KeyboardShortcutManager()
        XCTAssertEqual(manager.modifierKey, .option)
        XCTAssertFalse(manager.shortcutsEnabled)
        XCTAssertFalse(manager.reverseSwitcherEnabled)

        manager.modifierKey = .control
        manager.shortcutsEnabled = true
        manager.reverseSwitcherEnabled = true

        XCTAssertEqual(defaults.string(forKey: "modifierKey"), "control")
        XCTAssertEqual(defaults.object(forKey: "keyboardShortcutsEnabled") as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: "reverseSwitcherEnabled") as? Bool, true)
    }
}
