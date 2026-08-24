import AppKit
import MyVibeIslandCore
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSettingsWindowControllerTests: XCTestCase {
    @MainActor
    func testSettingsWindowControllerStoredFieldsMatchIDAReflection() {
        let labels = Mirror(reflecting: MyVibeIslandAppKitSettingsWindowController()).children.compactMap(\.label)

        XCTAssertEqual(labels, ["window", "closeObserver", "previousApp"])
    }

    @MainActor
    func testSettingsViewStoredFieldsMatchIDAReflection() {
        let labels = Mirror(reflecting: SettingsView(selectedSection: .general)).children.compactMap(\.label)

        XCTAssertEqual(labels, ["_selectedSection"])
    }

    @MainActor
    func testGeneralSettingsPaneStoredFieldsMatchIDAReflection() {
        let labels = Mirror(reflecting: GeneralSettingsPane()).children.compactMap(\.label)

        XCTAssertEqual(labels, ["_isLaunchAtLoginEnabled", "_idleTimeoutHours", "viewModel"])
    }

    @MainActor
    func testGeneralSettingsPaneResolvedStateTypesAndIdleDefaultMatchIDA() throws {
        let fields: [String: Any] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: GeneralSettingsPane()).children.compactMap {
                guard let label = $0.label else { return nil }
                return (label, $0.value)
            }
        )

        _ = try XCTUnwrap(fields["_isLaunchAtLoginEnabled"] as? State<Bool>)
        let idleTimeout = try XCTUnwrap(fields["_idleTimeoutHours"] as? State<Double>)
        XCTAssertEqual(idleTimeout.wrappedValue, 2.0)
    }

    @MainActor
    func testGeneralSettingsPaneIdleTimeoutPickerTagsMatchIDA() {
        let values = Set(reflectedValues(in: GeneralSettingsPane().body).compactMap { $0 as? Double })

        XCTAssertTrue(Set([0.5, 1.0, 2.0, 4.0, 8.0, 24.0, -1.0]).isSubset(of: values), "Found tags: \(values.sorted())")
    }

    @MainActor
    func testGeneralSettingsPaneIdleTimeoutPickerHasIDAOnChangeAction() {
        XCTAssertTrue(
            String(reflecting: type(of: GeneralSettingsPane().body))
                .contains("_ValueActionModifier2<Swift.Double>")
        )
    }

    @MainActor
    func testGeneralSettingsPaneSectionOrderMatchesIDA() throws {
        let strings = reflectedValues(in: GeneralSettingsPane().body).compactMap { $0 as? String }
        let headers = ["System", "Expansion", "Visibility", "Dismissal", "Interaction"]
        let positions = try headers.map { header in
            try XCTUnwrap(strings.firstIndex(of: header), "Missing section header: \(header)")
        }

        XCTAssertEqual(positions, positions.sorted())
    }

    @MainActor
    func testGeneralSettingsPaneLaunchAtLoginToggleMatchesIDA() {
        let body = GeneralSettingsPane().body
        let values = reflectedValues(in: body)

        XCTAssertTrue(String(reflecting: type(of: body)).contains("Toggle"))
        XCTAssertTrue(values.compactMap { $0 as? String }.contains("Launch at Login"))
    }

    @MainActor
    func testGeneralSettingsPaneLaunchAtLoginToggleHasIDAOnChangeAction() {
        XCTAssertTrue(
            String(reflecting: type(of: GeneralSettingsPane().body))
                .contains("_ValueActionModifier2<Swift.Bool>")
        )
    }

    @MainActor
    func testIntegrationsSettingsPaneStoredFieldsMatchIDAReflection() {
        XCTAssertEqual(storedFieldLabels(IntegrationsSettingsPane()), [
            "_ideStatuses", "_installingIDE", "_hookStatuses", "_hookAutoConfigs",
            "_autoConfigureNewlyDetectedCLIs", "_disableClaudeNativeTitle", "_repairingHook", "_repairResult",
            "_configuringKiro", "_activatingHermes", "_hermesActivationError", "_authorizingCodexTrust",
            "_codexTrustError", "_codexTrustManualGuidance", "_deniedTerminals", "_showAddCustomPath",
            "_customPathKind", "_customPathInput", "_customPathError",
        ])
    }

    @MainActor
    func testIntegrationsSettingsPaneResolvedStateTypesAndDefaultsMatchIDA() throws {
        let fields: [String: Any] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: IntegrationsSettingsPane()).children.compactMap {
                guard let label = $0.label else { return nil }
                return (label, $0.value)
            }
        )

        XCTAssertNil(try XCTUnwrap(fields["_installingIDE"] as? State<String?>).wrappedValue)
        XCTAssertEqual(try XCTUnwrap(fields["_hookAutoConfigs"] as? State<[String: Bool]>).wrappedValue, [:])
        let defaults = UserDefaults.standard
        XCTAssertEqual(
            try XCTUnwrap(fields["_autoConfigureNewlyDetectedCLIs"] as? State<Bool>).wrappedValue,
            defaults.object(forKey: "autoConfigureNewlyDetectedCLIs") as? Bool ?? true
        )
        XCTAssertEqual(
            try XCTUnwrap(fields["_disableClaudeNativeTitle"] as? State<Bool>).wrappedValue,
            defaults.object(forKey: "disableClaudeNativeTitle") as? Bool ?? true
        )
        for name in [
            "_repairingHook", "_configuringKiro", "_activatingHermes",
            "_authorizingCodexTrust", "_codexTrustManualGuidance", "_showAddCustomPath",
        ] {
            XCTAssertFalse(try XCTUnwrap(fields[name] as? State<Bool>).wrappedValue, name)
        }
        for name in ["_hermesActivationError", "_codexTrustError", "_customPathError"] {
            XCTAssertNil(try XCTUnwrap(fields[name] as? State<String?>).wrappedValue, name)
        }
        XCTAssertEqual(
            try XCTUnwrap(fields["_deniedTerminals"] as? State<[(id: String, name: String)]>).wrappedValue.count,
            0
        )
        XCTAssertEqual(try XCTUnwrap(fields["_customPathInput"] as? State<String>).wrappedValue, "")
        XCTAssertTrue(
            String(reflecting: type(of: try XCTUnwrap(fields["_repairResult"])))
                .contains("State<Swift.Optional<MyVibeIslandApp.IntegrationsSettingsPane.RepairResult>>")
        )
        XCTAssertTrue(
            String(reflecting: type(of: try XCTUnwrap(fields["_customPathKind"])))
                .contains("State<MyVibeIslandApp.CustomConfigPathKind>")
        )
        XCTAssertTrue(String(reflecting: try XCTUnwrap(fields["_customPathKind"])).contains("claude"))
    }

    @MainActor
    func testIntegrationsSettingsPaneSectionsAndResolvedControlsMatchIDA() throws {
        let body = IntegrationsSettingsPane().body
        let typeName = String(reflecting: type(of: body))
        let strings = reflectedValues(in: body).compactMap { $0 as? String }
        let orderedLabels = [
            "CLI Hooks", "Auto-configure new CLIs", "Coding Agent", "IDE Extensions",
            "Terminal Permissions", "Developer",
        ]
        let positions = try orderedLabels.map { label in
            try XCTUnwrap(strings.firstIndex(of: label), "Missing Integrations label: \(label)")
        }

        XCTAssertEqual(typeName.components(separatedBy: "SwiftUI.Section<").count - 1, 6)
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.Toggle<").count - 1, 2)
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.Button<").count - 1, 4)
        XCTAssertEqual(positions, positions.sorted())
        XCTAssertTrue(Set([
            "Disable Claude Code Native Terminal Title", "Add CLI Branch…",
            "Add Claude Code Config…", "Add Codex Branch…", "Custom Jump Rules",
        ]).isSubset(of: Set(strings)))
    }

    @MainActor
    func testNotificationsPaneStoredFieldsMatchIDAReflection() {
        XCTAssertEqual(storedFieldLabels(NotificationsPane()), [
            "_store", "_admissionStore", "_newCwdInput", "_newPromptInput", "_admissionStatusMessage",
            "_newPromptMatchType", "_focusedField", "_cwdLivePreviewCount", "_promptLivePreviewCount",
        ])
    }

    @MainActor
    func testNotificationsPaneResolvedStateTypesAndDefaultsMatchIDA() throws {
        let fields: [String: Any] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: NotificationsPane()).children.compactMap {
                guard let label = $0.label else { return nil }
                return (label, $0.value)
            }
        )

        XCTAssertEqual(try XCTUnwrap(fields["_newCwdInput"] as? State<String>).wrappedValue, "")
        XCTAssertEqual(try XCTUnwrap(fields["_newPromptInput"] as? State<String>).wrappedValue, "")
        XCTAssertNil(try XCTUnwrap(fields["_admissionStatusMessage"] as? State<String?>).wrappedValue)
        XCTAssertEqual(try XCTUnwrap(fields["_cwdLivePreviewCount"] as? State<Int>).wrappedValue, 0)
        XCTAssertEqual(try XCTUnwrap(fields["_promptLivePreviewCount"] as? State<Int>).wrappedValue, 0)
        XCTAssertTrue(
            String(reflecting: type(of: try XCTUnwrap(fields["_newPromptMatchType"])))
                .contains("State<MyVibeIslandApp.SilenceMatchType>")
        )
        XCTAssertTrue(String(reflecting: try XCTUnwrap(fields["_newPromptMatchType"])).contains("prefix"))
        XCTAssertTrue(
            String(reflecting: type(of: try XCTUnwrap(fields["_focusedField"])))
                .contains("FocusState<Swift.Optional<MyVibeIslandApp.NotificationsPane.FocusedField>>")
        )
    }

    @MainActor
    func testNotificationsPaneHidesControlsWithoutRuntimeBacking() {
        let body = NotificationsPane().body
        let typeName = String(reflecting: type(of: body))
        let strings = reflectedValues(in: body).compactMap { $0 as? String }

        XCTAssertEqual(typeName.components(separatedBy: "SwiftUI.Section<").count - 1, 1)
        XCTAssertFalse(typeName.contains("SwiftUI.TextField<"))
        XCTAssertFalse(typeName.contains("SwiftUI.Picker<"))
        XCTAssertFalse(typeName.contains("SwiftUI.Button<"))
        XCTAssertTrue(strings.contains("Filter which sessions appear in your panel. More notification settings coming soon."))
        XCTAssertTrue(Set([
            "System Filters", "Blocked Launcher Apps", "Custom Filters: Directory",
            "Custom Filters: First Prompt", "Add App…", "Add Pattern",
        ]).isDisjoint(with: Set(strings)))
    }

    @MainActor
    func testDisplaySettingsPaneStoredFieldsMatchIDAReflection() {
        XCTAssertEqual(storedFieldLabels(DisplaySettingsPane()), [
            "viewModel", "screenSelector", "_hideDetail", "_hideTaskSubagents", "_showModel", "_showWorktree",
        ])
    }

    @MainActor
    func testDisplaySettingsPaneResolvedAppStorageTypesAndDefaultsMatchIDA() throws {
        let fields: [String: Any] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: DisplaySettingsPane()).children.compactMap {
                guard let label = $0.label else { return nil }
                return (label, $0.value)
            }
        )

        XCTAssertFalse(try XCTUnwrap(fields["_hideDetail"] as? AppStorage<Bool>).wrappedValue)
        XCTAssertFalse(try XCTUnwrap(fields["_hideTaskSubagents"] as? AppStorage<Bool>).wrappedValue)
        XCTAssertFalse(try XCTUnwrap(fields["_showModel"] as? AppStorage<Bool>).wrappedValue)
        XCTAssertTrue(try XCTUnwrap(fields["_showWorktree"] as? AppStorage<Bool>).wrappedValue)
    }

    @MainActor
    func testDisplaySettingsPaneSectionsAndResolvedControlsMatchIDA() throws {
        let body = DisplaySettingsPane().body
        let typeName = String(reflecting: type(of: body))
        let strings = reflectedValues(in: body).compactMap { $0 as? String }
        let sectionHeaders = ["Notch", "Panel size", "Session card", "Tuning"]
        let positions = try sectionHeaders.map { header in
            try XCTUnwrap(strings.firstIndex(of: header), "Missing Display section: \(header)")
        }

        XCTAssertEqual(typeName.components(separatedBy: "SwiftUI.Section<").count - 1, 4)
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.Toggle<").count - 1, 4)
        XCTAssertEqual(positions, positions.sorted())
        XCTAssertTrue(Set([
            "Display", "Main Display", "Follow Focus", "Content Font Size", "Completion Card Height",
            "Max Panel Height", "Max Panel Width", "Show AI Model", "Show Worktree",
            "Show Agent Activity Detail", "Show Subagents", "Notch Width", "Notch Height",
            "Hide fan-out Task subagents to keep the panel clean and fast. Agent Teams and Codex stay visible.",
            "Fine-tune notch dimensions if your machine doesn't fit perfectly. 0 uses the macOS API value.",
        ]).isSubset(of: Set(strings)))
    }

    @MainActor
    func testSoundSettingsPaneStoredFieldsMatchIDAReflection() {
        XCTAssertEqual(storedFieldLabels(SoundSettingsPane()), [
            "sound", "store", "sourceStore", "customStore", "_isEnabled", "_volume", "_selectedPackId",
            "_installedPacks", "_registryEntries", "_downloadStates", "_autoDetect", "_importPackError",
            "_searchText", "_registryFailed", "_quietHoursEnabled", "_quietHoursStart", "_quietHoursEnd",
            "_quietHoursActive", "_soundPacksEnabled",
        ])
    }

    @MainActor
    func testSoundSettingsPaneResolvedStateTypesAndDefaultsMatchIDA() throws {
        let fields: [String: Any] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: SoundSettingsPane()).children.compactMap {
                guard let label = $0.label else { return nil }
                return (label, $0.value)
            }
        )

        _ = try XCTUnwrap(fields["_isEnabled"] as? State<Bool>)
        XCTAssertTrue(
            String(reflecting: type(of: try XCTUnwrap(fields["_volume"])))
                .contains("State<Swift.Float>")
        )
        _ = try XCTUnwrap(fields["_selectedPackId"] as? State<String?>)
        _ = try XCTUnwrap(fields["_autoDetect"] as? State<Bool>)
        XCTAssertNil(try XCTUnwrap(fields["_importPackError"] as? State<String?>).wrappedValue)
        XCTAssertEqual(try XCTUnwrap(fields["_searchText"] as? State<String>).wrappedValue, "")
        XCTAssertFalse(try XCTUnwrap(fields["_registryFailed"] as? State<Bool>).wrappedValue)
        _ = try XCTUnwrap(fields["_quietHoursEnabled"] as? State<Bool>)
        for name in ["_quietHoursStart", "_quietHoursEnd"] {
            XCTAssertTrue(
                String(reflecting: type(of: try XCTUnwrap(fields[name])))
                    .contains("State<Foundation.Date>"),
                name
            )
        }
        _ = try XCTUnwrap(fields["_quietHoursActive"] as? State<Bool>)
        let soundPacksEnabled = try XCTUnwrap(fields["_soundPacksEnabled"] as? AppStorage<Bool>)
        XCTAssertEqual(
            soundPacksEnabled.wrappedValue,
            UserDefaults.standard.object(forKey: "debugSoundPacksEnabled") as? Bool ?? false
        )
    }

    @MainActor
    func testSoundSettingsPaneSectionsAndResolvedControlsMatchIDA() throws {
        let body = SoundSettingsPane().body
        let typeName = String(reflecting: type(of: body))
        let strings = reflectedValues(in: body).compactMap { $0 as? String }
        let orderedLabels = [
            "Enable Sound Effects", "Session", "Interactions", "System",
            "My Sounds", "Quiet Hours", "Filters",
        ]
        let positions = try orderedLabels.map { label in
            try XCTUnwrap(strings.firstIndex(of: label), "Missing Sound label: \(label)")
        }

        XCTAssertEqual(typeName.components(separatedBy: "SwiftUI.Section<").count - 1, 7)
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.Toggle<").count - 1, 3)
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.Slider<").count - 1, 1)
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.DatePicker<").count - 1, 2)
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.Button<").count - 1, 1)
        XCTAssertEqual(positions, positions.sorted())
        XCTAssertTrue(Set([
            "Volume", "Import Sound Pack…", "Auto-detect probe sessions",
            "Automatically mutes health-check sessions (e.g. CodexBar ClaudeProbe)",
            "Silence during quiet hours", "Start", "End", "No imported sounds yet.",
        ]).isSubset(of: Set(strings)))
    }

    @MainActor
    func testUsageSettingsPaneStoredFieldsMatchIDAReflection() {
        XCTAssertEqual(storedFieldLabels(UsageSettingsPane()), [
            "viewModel", "_bridgeState", "_bridgeBusy", "_bridgeErrorMessage",
        ])
    }

    @MainActor
    func testUsageSettingsPaneResolvedStateTypesAndDefaultsMatchIDA() throws {
        let fields: [String: Any] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: UsageSettingsPane()).children.compactMap {
                guard let label = $0.label else { return nil }
                return (label, $0.value)
            }
        )

        XCTAssertTrue(
            String(reflecting: type(of: try XCTUnwrap(fields["_bridgeState"])))
                .contains("State<MyVibeIslandApp.StatuslineBridgeInjector.State>")
        )
        XCTAssertFalse(try XCTUnwrap(fields["_bridgeBusy"] as? State<Bool>).wrappedValue)
        XCTAssertNil(try XCTUnwrap(fields["_bridgeErrorMessage"] as? State<String?>).wrappedValue)
        XCTAssertTrue(String(reflecting: try XCTUnwrap(fields["_bridgeState"])).contains("noCustomStatusline"))
    }

    @MainActor
    func testUsageSettingsPaneHidesUnavailableProviderAndBridgeControls() {
        let body = UsageSettingsPane().body
        let typeName = String(reflecting: type(of: body))
        let strings = reflectedValues(in: body).compactMap { $0 as? String }

        XCTAssertEqual(typeName.components(separatedBy: "SwiftUI.Section<").count - 1, 1)
        XCTAssertEqual(typeName.components(separatedBy: "SwiftUI.Picker<").count - 1, 1)
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.Toggle<").count - 1, 2)
        XCTAssertFalse(typeName.contains("SwiftUI.Button<"))
        XCTAssertTrue(Set([
            "Usage Limits", "Display Value", "Alert Threshold", "Usage limit alert",
            "Show Usage Limits", "Used", "Remaining",
        ]).isSubset(of: Set(strings)))
        XCTAssertTrue(Set([
            "Preferred Provider", "Claude Usage Bridge", "Connect Usage", "Auto (follow session)",
        ]).isDisjoint(with: Set(strings)))
    }

    @MainActor
    func testShortcutsSettingsPaneStoredFieldsMatchIDAReflection() {
        XCTAssertEqual(storedFieldLabels(ShortcutsSettingsPane()), ["_keyboardManager"])
    }

    @MainActor
    func testShortcutsSettingsPaneUsesConcreteSharedBindableManager() throws {
        let fields: [String: Any] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: ShortcutsSettingsPane()).children.compactMap {
                guard let label = $0.label else { return nil }
                return (label, $0.value)
            }
        )

        let bindable = try XCTUnwrap(fields["_keyboardManager"] as? Bindable<KeyboardShortcutManager>)
        XCTAssertTrue(bindable.wrappedValue === KeyboardShortcutManager.shared)
    }

    @MainActor
    func testShortcutsSettingsPaneFiveSectionOrderMatchesIDA() throws {
        let body = ShortcutsSettingsPane().body
        let typeName = String(reflecting: type(of: body))
        let strings = reflectedValues(in: body).compactMap { $0 as? String }
        let orderedLabels = [
            "Modifier Key", "Global Shortcuts", "Panel Shortcuts",
            "Select Option", "Navigate Sessions",
        ]
        let positions = try orderedLabels.map { label in
            try XCTUnwrap(strings.firstIndex(of: label), "Missing shortcuts label: \(label)")
        }

        XCTAssertEqual(typeName.components(separatedBy: "SwiftUI.Section<").count - 1, 5)
        XCTAssertEqual(positions, positions.sorted())
    }

    @MainActor
    func testShortcutsSettingsPaneResolvedControlsAndLabelsMatchIDA() {
        let body = ShortcutsSettingsPane().body
        let typeName = String(reflecting: type(of: body))
        let values = reflectedValues(in: body)
        let strings = Set(values.compactMap { $0 as? String })
        let modifierOptions = Set(values.compactMap { $0 as? ModifierKeyOption })

        XCTAssertTrue(typeName.contains("Picker"))
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.Toggle<").count - 1, 2)
        XCTAssertEqual(modifierOptions, Set([.control, .option, .command]))
        XCTAssertTrue(Set([
            "Enable Keyboard Shortcuts", "Open Switcher", "Reverse Switcher", "Collapse Panel",
            "Approve", "Deny", "Always Allow", "Bypass Permissions", "Jump to Terminal",
            "Select Option", "Submit Multi-Select", "Navigate Sessions",
            "All shortcuts below are active while the panel is expanded. Hold your modifier key to reveal hints on every button — handy for shortcuts you forgot.",
        ]).isSubset(of: strings), "Found strings: \(strings.sorted())")
    }

    @MainActor
    func testSSHRemoteSettingsPaneStoredFieldsMatchIDAReflection() {
        XCTAssertEqual(storedFieldLabels(SSHRemoteSettingsPane()), [
            "_store", "_showAddSheet", "_deployingHostId", "_deployMessage", "_deployError",
            "_showResultAlert", "_lastResultSuccess", "_pendingDeployHost",
        ])
    }

    @MainActor
    func testSSHRemoteSettingsPaneResolvedStateTypesAndDefaultsMatchIDA() throws {
        let fields: [String: Any] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: SSHRemoteSettingsPane()).children.compactMap {
                guard let label = $0.label else { return nil }
                return (label, $0.value)
            }
        )

        XCTAssertFalse(try XCTUnwrap(fields["_showAddSheet"] as? State<Bool>).wrappedValue)
        XCTAssertNil(try XCTUnwrap(fields["_deployingHostId"] as? State<UUID?>).wrappedValue)
        XCTAssertEqual(try XCTUnwrap(fields["_deployMessage"] as? State<String>).wrappedValue, "")
        XCTAssertEqual(try XCTUnwrap(fields["_deployError"] as? State<String>).wrappedValue, "")
        XCTAssertFalse(try XCTUnwrap(fields["_showResultAlert"] as? State<Bool>).wrappedValue)
        XCTAssertFalse(try XCTUnwrap(fields["_lastResultSuccess"] as? State<Bool>).wrappedValue)
        XCTAssertNil(try XCTUnwrap(fields["_pendingDeployHost"] as? State<SSHRemoteHost?>).wrappedValue)
    }

    @MainActor
    func testSSHRemoteSettingsPaneDefaultSectionsAndControlsMatchIDA() throws {
        let body = SSHRemoteSettingsPane().body
        let typeName = String(reflecting: type(of: body))
        let strings = reflectedValues(in: body).compactMap { $0 as? String }
        let orderedLabels = [
            "Monitor and approve remote AI CLI sessions from your Notch.",
            "Hosts", "No hosts configured yet", "Add Host",
            "Manual install (for restricted networks)", "Docker container",
        ]
        let positions = try orderedLabels.map { label in
            try XCTUnwrap(strings.firstIndex(of: label), "Missing SSH Remote label: \(label)")
        }

        XCTAssertEqual(typeName.components(separatedBy: "SwiftUI.Section<").count - 1, 4)
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.Button<").count - 1, 1)
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.DisclosureGroup<").count - 1, 2)
        XCTAssertEqual(positions, positions.sorted())
        XCTAssertTrue(strings.contains("Add Host → Set Up → Connect. Requires SSH pubkey auth (or ControlMaster for MFA)."))
    }

    @MainActor
    func testLabsSettingsPaneStoredFieldsMatchIDAReflection() {
        XCTAssertEqual(storedFieldLabels(LabsSettingsPane()), [
            "viewModel", "_cursorApproval", "_codexApprovalMode", "_kiroPermissionHintDelaySeconds",
            "_receiveBetaUpdates", "_autoModeInsteadOfBypass", "_deferClaudeApprovalsToNative",
            "_memoryRestartEnabled", "_toolAvailability",
        ])
    }

    @MainActor
    func testLabsSettingsPaneResolvedStateTypesAndDefaultsMatchIDA() throws {
        let fields: [String: Any] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: LabsSettingsPane()).children.compactMap {
                guard let label = $0.label else { return nil }
                return (label, $0.value)
            }
        )

        XCTAssertEqual(try XCTUnwrap(fields["_cursorApproval"] as? State<String>).wrappedValue, "auto")
        XCTAssertEqual(try XCTUnwrap(fields["_codexApprovalMode"] as? State<String>).wrappedValue, "approve_here")
        XCTAssertEqual(try XCTUnwrap(fields["_kiroPermissionHintDelaySeconds"] as? State<Int>).wrappedValue, 5)
        for name in ["_receiveBetaUpdates", "_autoModeInsteadOfBypass", "_deferClaudeApprovalsToNative", "_memoryRestartEnabled"] {
            XCTAssertFalse(try XCTUnwrap(fields[name] as? State<Bool>).wrappedValue, name)
        }
        XCTAssertEqual(
            try XCTUnwrap(fields["_toolAvailability"] as? State<LabsToolAvailability>).wrappedValue,
            LabsToolAvailability()
        )
    }

    @MainActor
    func testLabsSettingsPaneSectionsControlsAndOptionsMatchIDA() throws {
        let body = LabsSettingsPane().body
        let typeName = String(reflecting: type(of: body))
        let values = reflectedValues(in: body)
        let strings = values.compactMap { $0 as? String }
        let sectionHeaders = ["Stability", "Claude Code", "Codex", "Other CLIs"]
        let positions = try sectionHeaders.map { header in
            try XCTUnwrap(strings.firstIndex(of: header), "Missing Labs section: \(header)")
        }

        XCTAssertEqual(typeName.components(separatedBy: "SwiftUI.Section<").count - 1, 4)
        XCTAssertEqual(positions, positions.sorted())
        XCTAssertTrue(Set([
            "Beta Updates", "Restart when memory is high", "Use Native Claude Code Approvals",
            "Use Auto Mode instead of Bypass", "When Codex needs your approval",
            "Cursor Sandbox Approval", "Kiro Permission Hints",
            "Approve Here", "Remind", "Hide", "Auto", "Always", "Never (observe only)", "Off",
        ]).isSubset(of: strings))
        XCTAssertTrue(Set([0, 3, 5, 10, 50]).isSubset(of: Set(values.compactMap { $0 as? Int })))
    }

    @MainActor
    func testAboutSettingsPaneStoredFieldsMatchIDAReflection() {
        XCTAssertEqual(storedFieldLabels(AboutSettingsPane()), [
            "_showCommunitySheet", "_showAcknowledgements", "_isExportingDiagnostics",
            "_diagnosticExportError", "_showUninstallConfirm", "_isUninstalling", "_showUninstallDone",
        ])
    }

    @MainActor
    func testAboutSettingsPaneResolvedStateTypesAndDefaultsMatchIDA() throws {
        let fields: [String: Any] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: AboutSettingsPane()).children.compactMap {
                guard let label = $0.label else { return nil }
                return (label, $0.value)
            }
        )

        for name in ["_showCommunitySheet", "_showAcknowledgements", "_isExportingDiagnostics", "_showUninstallConfirm", "_isUninstalling", "_showUninstallDone"] {
            XCTAssertFalse(try XCTUnwrap(fields[name] as? State<Bool>).wrappedValue, name)
        }
        XCTAssertNil(try XCTUnwrap(fields["_diagnosticExportError"] as? State<String?>).wrappedValue)
    }

    @MainActor
    func testAboutSettingsPaneSectionCountAndTelemetryToggleMatchIDA() {
        let body = AboutSettingsPane().body
        let typeName = String(reflecting: type(of: body))
        let strings = reflectedValues(in: body).compactMap { $0 as? String }

        XCTAssertEqual(typeName.components(separatedBy: "SwiftUI.Section<").count - 1, 6)
        XCTAssertFalse(strings.contains("Help Improve Vibe Island"))
    }

    @MainActor
    func testAboutSettingsPaneNonCommercialSectionLabelsMatchIDA() throws {
        let body = AboutSettingsPane().body
        let typeName = String(reflecting: type(of: body))
        let strings = reflectedValues(in: body).compactMap { $0 as? String }
        let orderedLabels = [
            "Vibe Island", "Join Community", "Export Diagnostic Report",
            "Acknowledgements", "Remove All Auto-Configuration", "Quit Vibe Island",
        ]
        let positions = try orderedLabels.map { label in
            try XCTUnwrap(strings.firstIndex(of: label), "Missing About label: \(label)")
        }

        XCTAssertEqual(typeName.components(separatedBy: "SwiftUI.Section<").count - 1, 6)
        XCTAssertGreaterThanOrEqual(typeName.components(separatedBy: "SwiftUI.Button<").count - 1, 5)
        XCTAssertEqual(positions, positions.sorted())
        XCTAssertTrue(strings.contains("Includes system info and anonymized logs. No personal data."))
    }

    @MainActor
    func testSettingsWindowCanBecomeKeyAndMain() {
        let window = SettingsWindow()

        XCTAssertTrue(window.canBecomeKey)
        XCTAssertTrue(window.canBecomeMain)
        XCTAssertEqual(window.frame.size, NSSize(width: 620, height: 680))
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertFalse(window.hidesOnDeactivate)
    }

    private func storedFieldLabels<T>(_ value: T) -> [String] {
        Mirror(reflecting: value).children.compactMap(\.label)
    }

    private func reflectedValues(in value: Any, depth: Int = 0) -> [Any] {
        guard depth < 64 else { return [] }
        return [value] + Mirror(reflecting: value).children.flatMap {
            reflectedValues(in: $0.value, depth: depth + 1)
        }
    }
}
