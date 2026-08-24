import AppKit
import MyVibeIslandCore
import Foundation
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var selectedSection: SettingsSection

    init(selectedSection: SettingsSection = .general) {
        _selectedSection = State(initialValue: selectedSection)
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.defaultSidebarSections, id: \.self) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.iconName)
                }
                .buttonStyle(.plain)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 190, max: 220)
        } detail: {
            selectedPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 620, minHeight: 680)
    }

    @ViewBuilder
    private var selectedPane: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsPane()
        case .integrations:
            IntegrationsSettingsPane()
        case .notifications:
            NotificationsPane()
        case .display:
            DisplaySettingsPane()
        case .sound:
            SoundSettingsPane()
        case .usage:
            UsageSettingsPane()
        case .shortcuts:
            ShortcutsSettingsPane()
        case .sshRemote:
            SSHRemoteSettingsPane()
        case .labs:
            LabsSettingsPane()
        case .about:
            AboutSettingsPane()
        }
    }
}

struct SettingsDetailHeader: View {
    let section: SettingsSection

    var body: some View {
        Text(section.title)
            .font(.title2.weight(.semibold))
    }
}

private struct UnknownIDAFieldValue {}

struct GeneralSettingsPane: View {
    @State private var isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    @State private var idleTimeoutHours: Double
    private let viewModel: MyVibeIslandSettingsModel

    init(viewModel: MyVibeIslandSettingsModel = MyVibeIslandSettingsRuntime.shared) {
        self.viewModel = viewModel
        _idleTimeoutHours = State(initialValue: viewModel.idleTimeoutHours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsDetailHeader(section: .general)
            Form {
                Section {
                    Toggle(
                        NSLocalizedString(
                            "menu.launchAtLogin",
                            value: "Launch at Login",
                            comment: "Onboarding Act 3: terminals section"
                        ),
                        isOn: $isLaunchAtLoginEnabled
                    )
                    .onChange(of: isLaunchAtLoginEnabled) { _, isEnabled in
                        if isEnabled {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
                } header: {
                    Text(NSLocalizedString("settings.display.system", value: "System", comment: "Settings General: system section header (launch at login, etc.)"))
                }
                Section {
                    EmptyView()
                } header: {
                    Text(NSLocalizedString("settings.behaviour.expansion", value: "Expansion", comment: "Settings: Behaviour subsection - when to expand the notch"))
                }
                Section {
                    EmptyView()
                } header: {
                    Text(NSLocalizedString("settings.behaviour.visibility", value: "Visibility", comment: "Settings: Behaviour subsection - when the pill is visible"))
                }
                Section {
                    Picker(
                        NSLocalizedString(
                            "settings.behaviour.idleTimeout",
                            value: "Idle session cleanup",
                            comment: "Settings General: idle fallback timeout picker title"
                        ),
                        selection: $idleTimeoutHours
                    ) {
                        Text(NSLocalizedString("settings.behaviour.idleTimeout.30m", value: "30 minutes", comment: "Settings: idle timeout option - 30 minutes")).tag(0.5)
                        Text(NSLocalizedString("settings.behaviour.idleTimeout.1h", value: "1 hour", comment: "Settings: idle timeout option - 1 hour")).tag(1.0)
                        Text(NSLocalizedString("settings.behaviour.idleTimeout.2h", value: "2 hours (default)", comment: "Settings: idle timeout option - 2 hours (default)")).tag(2.0)
                        Text(NSLocalizedString("settings.behaviour.idleTimeout.4h", value: "4 hours", comment: "Settings: idle timeout option - 4 hours")).tag(4.0)
                        Text(NSLocalizedString("settings.behaviour.idleTimeout.8h", value: "8 hours", comment: "Settings: idle timeout option - 8 hours")).tag(8.0)
                        Text(NSLocalizedString("settings.behaviour.idleTimeout.24h", value: "24 hours", comment: "Settings: idle timeout option - 24 hours")).tag(24.0)
                        Text(NSLocalizedString("settings.behaviour.idleTimeout.never", value: "Never", comment: "Settings: idle timeout option - never auto-clean")).tag(-1.0)
                    }
                    .onChange(of: idleTimeoutHours) { _, value in
                        viewModel.idleTimeoutHours = value
                    }
                    Text(
                        NSLocalizedString(
                            "settings.behaviour.idleTimeout.help",
                            value: "Applies only to sessions without a clear close signal (Codex, OpenCode, Cursor).",
                            comment: "Settings General: idle fallback timeout help text"
                        )
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                } header: {
                    Text(NSLocalizedString("settings.behaviour.dismissal", value: "Dismissal", comment: "Settings: Behaviour subsection - when to collapse/dismiss the panel"))
                }
                Section {
                    EmptyView()
                } header: {
                    Text(NSLocalizedString("settings.behaviour.interaction", value: "Interaction", comment: "Settings: Behaviour subsection - when to collapse/dismiss the panel"))
                }
            }
        }
        .padding(24)
    }
}
struct IntegrationsSettingsPane: View {
    private let _ideStatuses: UnknownIDAFieldValue? = nil
    @State private var installingIDE: String?
    @State private var hookStatuses: [IntegrationSettingsRow]
    @State private var hookAutoConfigs: [String: Bool] = [:]
    @State private var autoConfigureNewlyDetectedCLIs: Bool
    @State private var disableClaudeNativeTitle: Bool
    @State private var repairingHook = false
    @State private var repairResult: RepairResult?
    @State private var configuringKiro = false
    @State private var activatingHermes = false
    @State private var hermesActivationError: String?
    @State private var authorizingCodexTrust = false
    @State private var codexTrustError: String?
    @State private var codexTrustManualGuidance = false
    @State private var deniedTerminals: [(id: String, name: String)] = []
    @State private var showAddCustomPath = false
    @State private var customPathKind = CustomConfigPathKind.claude
    @State private var customPathInput = ""
    @State private var customPathError: String?

    enum RepairResult {
        case success
        case failed
    }

    init(viewModel: MyVibeIslandSettingsModel = MyVibeIslandSettingsRuntime.shared) {
        _hookStatuses = State(initialValue: viewModel.refreshIntegrations().rows)
        _autoConfigureNewlyDetectedCLIs = State(initialValue: viewModel.autoConfigureNewlyDetectedCLIs)
        _disableClaudeNativeTitle = State(initialValue: viewModel.disableClaudeNativeTitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsDetailHeader(section: .integrations)
            Form {
                Section(NSLocalizedString("settings.integrations.cliHooksSection", value: "CLI Hooks", comment: "Integrations CLI hooks section")) {
                    ForEach(hookStatuses, id: \.sourceId) { status in
                        HStack {
                            Text(status.displayName)
                            Spacer()
                            Text(status.statusSummary.rawValue)
                                .foregroundStyle(.secondary)
                            switch status.hookStatus {
                            case .notInstalled:
                                Button("Install") { performHookAction(.install, status: status) }
                            case .needsRepair:
                                Button("Repair") { performHookAction(.repair, status: status) }
                            case .installed:
                                Button("Uninstall") { performHookAction(.uninstall, status: status) }
                            case .unsupported:
                                EmptyView()
                            }
                        }
                    }
                    if repairingHook {
                        ProgressView()
                    }
                    if let repairResult {
                        Text(repairResult == .success ? "Integration updated" : "Integration update failed")
                            .font(.caption)
                            .foregroundStyle(repairResult == .success ? Color.secondary : Color.red)
                    }
                }
                Section {
                    Toggle(
                        NSLocalizedString("settings.cliHooks.autoConfigureNewCLIs", value: "Auto-configure new CLIs", comment: "Automatically configure newly detected CLIs"),
                        isOn: $autoConfigureNewlyDetectedCLIs
                    )
                    Text("New supported CLIs are set up automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section(NSLocalizedString("settings.codingAgent", value: "Coding Agent", comment: "Coding agent configuration section")) {
                    Toggle(
                        NSLocalizedString("settings.disableNativeTitle", value: "Disable Claude Code Native Terminal Title", comment: "Disable Claude Code terminal title"),
                        isOn: $disableClaudeNativeTitle
                    )
                    Button("Add CLI Branch…") {
                        showAddCustomPath = true
                    }
                    Button("Add Claude Code Config…") {
                        customPathKind = .claude
                        showAddCustomPath = true
                    }
                    Button("Add Codex Branch…") {
                        customPathKind = .codex
                        showAddCustomPath = true
                    }
                }
                Section(NSLocalizedString("settings.ideExtensions", value: "IDE Extensions", comment: "IDE extensions section")) {
                    Text("Visual Studio Code")
                    Text("Cursor")
                    Text("Windsurf")
                    if let installingIDE {
                        Text(installingIDE)
                            .foregroundStyle(.secondary)
                    }
                }
                Section(NSLocalizedString("settings.terminalPermissions", value: "Terminal Permissions", comment: "Terminal permissions section")) {
                    if deniedTerminals.isEmpty {
                        Text("No denied Automation permissions")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(deniedTerminals, id: \.id) { terminal in
                            Text(terminal.name)
                        }
                    }
                }
                Section(NSLocalizedString("settings.developer", value: "Developer", comment: "Developer section")) {
                    Button(NSLocalizedString("settings.customJumpRules", value: "Custom Jump Rules", comment: "Open custom jump rules documentation")) {}
                }
            }
        }
        .padding(24)
        .onChange(of: autoConfigureNewlyDetectedCLIs) { _, value in
            MyVibeIslandSettingsRuntime.shared.autoConfigureNewlyDetectedCLIs = value
        }
        .onChange(of: disableClaudeNativeTitle) { _, value in
            MyVibeIslandSettingsRuntime.shared.disableClaudeNativeTitle = value
        }
        .sheet(isPresented: $showAddCustomPath) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("CLI", selection: $customPathKind) {
                    Text("Claude Code").tag(CustomConfigPathKind.claude)
                    Text("Codex").tag(CustomConfigPathKind.codex)
                }
                TextField(
                    customPathKind == .codex ? "~/.internal-codex" : "~/.xxx/engine/cc",
                    text: $customPathInput
                )
                if let customPathError {
                    Text(customPathError)
                        .foregroundStyle(.red)
                }
                Button("Cancel") {
                    showAddCustomPath = false
                }
            }
            .padding(24)
            .frame(minWidth: 420)
        }
    }

    private func performHookAction(
        _ operation: IntegrationRepairOperation,
        status: IntegrationSettingsRow
    ) {
        repairingHook = true
        let result: IntegrationRepairResult?
        switch operation {
        case .install:
            result = MyVibeIslandSettingsRuntime.shared.installIntegration(sourceId: status.sourceId)
        case .repair:
            result = MyVibeIslandSettingsRuntime.shared.repairIntegration(sourceId: status.sourceId)
        case .uninstall:
            result = MyVibeIslandSettingsRuntime.shared.uninstallIntegration(sourceId: status.sourceId)
        case .addCustomPath, .removeCustomPath:
            result = nil
        }
        hookStatuses = MyVibeIslandSettingsRuntime.shared.integrationSnapshot.rows
        repairResult = result?.isSuccessful == true ? .success : .failed
        repairingHook = false
    }
}

enum CustomConfigPathKind: String, Equatable {
    case claude
    case codex
}

struct NotificationsPane: View {
    private let _store: UnknownIDAFieldValue? = nil
    private let _admissionStore: UnknownIDAFieldValue? = nil
    @State private var newCwdInput = ""
    @State private var newPromptInput = ""
    @State private var admissionStatusMessage: String?
    @State private var newPromptMatchType = SilenceMatchType.prefix
    @FocusState private var focusedField: FocusedField?
    @State private var cwdLivePreviewCount = 0
    @State private var promptLivePreviewCount = 0

    enum FocusedField: Hashable {
        case cwd
        case prompt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsDetailHeader(section: .notifications)
            Form {
                Section {
                    Text(NSLocalizedString(
                        "notifications.pane.intro",
                        value: "Filter which sessions appear in your panel. More notification settings coming soon.",
                        comment: "Notifications pane introduction"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
    }
}

enum SilenceMatchType: String, Equatable {
    case contains
    case equals
    case prefix
}

struct DisplaySettingsPane: View {
    private let viewModel: UnknownIDAFieldValue? = nil
    private let screenSelector: UnknownIDAFieldValue? = nil
    @AppStorage("hideAgentDetailLine") private var hideDetail = false
    @AppStorage("hideTaskSubagents") private var hideTaskSubagents = false
    @AppStorage("showModelInPanel") private var showModel = false
    @AppStorage("showWorktreeChip") private var showWorktree = true

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsDetailHeader(section: .display)
            Form {
                Section(NSLocalizedString("settings.display.notch", value: "Notch", comment: "Settings Display: notch appearance section header")) {
                    Text(NSLocalizedString("menu.display", value: "Display", comment: "Screen/display selection menu"))
                    Text(NSLocalizedString("menu.mainDisplay", value: "Main Display", comment: "Main display screen selection"))
                    Text(NSLocalizedString("menu.followFocus", value: "Follow Focus", comment: "Follow keyboard focus screen selection"))
                }
                Section(NSLocalizedString("settings.display.panel", value: "Panel size", comment: "Settings Display: panel dimensions section header")) {
                    Text(NSLocalizedString("settings.contentFontSize", value: "Content Font Size", comment: "Settings: font size for markdown, plan, and completion text"))
                    Text(NSLocalizedString("settings.completionHeight", value: "Completion Card Height", comment: "Settings: completion card content max height"))
                    Text(NSLocalizedString("settings.maxPanelHeight", value: "Max Panel Height", comment: "Settings: maximum expanded panel height"))
                    Text(NSLocalizedString("settings.maxPanelWidth", value: "Max Panel Width", comment: "Settings: maximum expanded panel width override"))
                }
                Section(NSLocalizedString("settings.display.sessionCard", value: "Session card", comment: "Settings Display: session card content section header")) {
                    Toggle(
                        NSLocalizedString("settings.showModel", value: "Show AI Model", comment: "Settings: show the AI model name on session cards"),
                        isOn: $showModel
                    )
                    Toggle(
                        NSLocalizedString("settings.showWorktree", value: "Show Worktree", comment: "Settings: show the worktree chip on session cards"),
                        isOn: $showWorktree
                    )
                    Toggle(
                        NSLocalizedString("settings.showAgentDetail", value: "Show Agent Activity Detail", comment: "Settings: show agent tool activity detail line"),
                        isOn: Binding(
                            get: { !hideDetail },
                            set: { hideDetail = !$0 }
                        )
                    )
                    Toggle(
                        NSLocalizedString("settings.showSubagents", value: "Show Subagents", comment: "Settings: show fan-out Task subagents"),
                        isOn: Binding(
                            get: { !hideTaskSubagents },
                            set: { hideTaskSubagents = !$0 }
                        )
                    )
                    Text(NSLocalizedString(
                        "settings.showSubagents.help",
                        value: "Hide fan-out Task subagents to keep the panel clean and fast. Agent Teams and Codex stay visible.",
                        comment: "Settings: help text under the Show Subagents toggle"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Section(NSLocalizedString("settings.tuning", value: "Tuning", comment: "Settings section: notch geometry fine-tuning")) {
                    Text(NSLocalizedString("settings.notchWidth", value: "Notch Width", comment: "Settings: notch width fine-tune offset"))
                    Text(NSLocalizedString("settings.notchHeight", value: "Notch Height", comment: "Settings: notch height fine-tune offset"))
                    Text(NSLocalizedString(
                        "settings.tuning.help",
                        value: "Fine-tune notch dimensions if your machine doesn't fit perfectly. 0 uses the macOS API value.",
                        comment: "Settings help text: notch tuning purpose and default"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
    }
}

struct SoundSettingsPane: View {
    private let sound: SoundManager
    private let store: SoundPreferencesStore
    private let sourceStore: SoundSourceStore
    private let customStore: CustomSoundStore
    @State private var isEnabled: Bool
    @State private var volume: Float
    @State private var selectedPackId: String?
    private let _installedPacks: UnknownIDAFieldValue? = nil
    private let _registryEntries: UnknownIDAFieldValue? = nil
    private let _downloadStates: UnknownIDAFieldValue? = nil
    @State private var autoDetect: Bool
    @State private var importPackError: String?
    @State private var searchText = ""
    @State private var registryFailed = false
    @State private var quietHoursEnabled: Bool
    @State private var quietHoursStart: Date
    @State private var quietHoursEnd: Date
    @State private var quietHoursActive: Bool
    @AppStorage("debugSoundPacksEnabled") private var soundPacksEnabled = false

    init(store: SoundPreferencesStore = SoundPreferencesStore()) {
        let settings = store.loadManagerSettings()
        let filter = store.loadFilter()
        let sourceSnapshot = store.loadSourceSelections()
        let selections = Dictionary(
            uniqueKeysWithValues: sourceSnapshot.selections.map { ($0.category, $0) }
        )
        let sourceStore = SoundSourceStore(selections: selections)
        let customStore = CustomSoundStore()
        self.store = store
        self.sourceStore = sourceStore
        self.customStore = customStore
        sound = SoundManager(snapshot: SoundManagerSnapshot(
            settings: settings,
            filter: filter,
            sourceSelections: selections,
            customSoundStore: customStore.snapshot
        ))
        _isEnabled = State(initialValue: settings.isEnabled)
        _volume = State(initialValue: Float(settings.volume))
        _selectedPackId = State(initialValue: settings.selectedPackId)
        _autoDetect = State(initialValue: filter.autoDetectProbes)
        _quietHoursEnabled = State(initialValue: settings.quietHoursEnabled)
        _quietHoursStart = State(initialValue: Self.date(minuteOfDay: settings.quietHoursStartMinutes))
        _quietHoursEnd = State(initialValue: Self.date(minuteOfDay: settings.quietHoursEndMinutes))
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minute = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        _quietHoursActive = State(initialValue: settings.isQuiet(atMinuteOfDay: minute))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsDetailHeader(section: .sound)
            Form {
                Section {
                    Toggle("Enable Sound Effects", isOn: $isEnabled)
                    LabeledContent("Volume") {
                        Slider(value: $volume, in: 0 ... 1)
                    }
                }

                if isEnabled {
                    Section("Session") {
                        Text("Session lifecycle sounds")
                            .foregroundStyle(.secondary)
                    }

                    Section("Interactions") {
                        Text("Interaction sounds")
                            .foregroundStyle(.secondary)
                    }

                    Section("System") {
                        Text("System sounds")
                            .foregroundStyle(.secondary)
                    }

                    Section("My Sounds") {
                        Text("No imported sounds yet.")
                            .foregroundStyle(.secondary)
                        Button("Import Sound Pack…") {}
                            .disabled(true)
                    }

                    Section("Quiet Hours") {
                        Toggle("Silence during quiet hours", isOn: $quietHoursEnabled)
                        Text("Mutes all sounds during the selected time range (crosses midnight if end is earlier than start). Useful when agents run overnight.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("Start", selection: $quietHoursStart, displayedComponents: .hourAndMinute)
                            .disabled(!quietHoursEnabled)
                        DatePicker("End", selection: $quietHoursEnd, displayedComponents: .hourAndMinute)
                            .disabled(!quietHoursEnabled)
                        if quietHoursActive {
                            Text("Quiet hours active — sounds muted")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Filters") {
                        Toggle("Auto-detect probe sessions", isOn: $autoDetect)
                        Text("Automatically mutes health-check sessions (e.g. CodexBar ClaudeProbe)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .onChange(of: isEnabled) { _, _ in persistManagerSettings() }
        .onChange(of: volume) { _, _ in persistManagerSettings() }
        .onChange(of: selectedPackId) { _, _ in persistManagerSettings() }
        .onChange(of: quietHoursEnabled) { _, _ in persistManagerSettings() }
        .onChange(of: quietHoursStart) { _, _ in persistManagerSettings() }
        .onChange(of: quietHoursEnd) { _, _ in persistManagerSettings() }
        .onChange(of: autoDetect) { _, value in
            let current = store.loadFilter()
            store.saveFilter(SoundFilter(autoDetectProbes: value, rules: current.rules))
        }
    }

    private func persistManagerSettings() {
        store.saveManagerSettings(SoundManagerSettings(
            selectedPackId: selectedPackId,
            isEnabled: isEnabled,
            volume: Double(volume),
            quietHoursEnabled: quietHoursEnabled,
            quietHoursStartMinutes: Self.minuteOfDay(quietHoursStart),
            quietHoursEndMinutes: Self.minuteOfDay(quietHoursEnd)
        ))
    }

    private static func date(minuteOfDay: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minuteOfDay / 60,
            minute: minuteOfDay % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private static func minuteOfDay(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

enum StatuslineBridgeInjector {
    enum State: Equatable {
        case customNotInstalled(path: String)
        case customInstalled(path: String)
        case customChainNotInstalled(command: String)
        case customChainInstalled(command: String)
        case customScriptMissing(path: String)
        case noCustomStatusline
        case managedByVibeIsland
    }
}

struct UsageSettingsPane: View {
    private let viewModel: MyVibeIslandSettingsModel
    @State private var bridgeState: StatuslineBridgeInjector.State = .noCustomStatusline
    @State private var bridgeBusy = false
    @State private var bridgeErrorMessage: String?

    init(viewModel: MyVibeIslandSettingsModel = MyVibeIslandSettingsRuntime.shared) {
        self.viewModel = viewModel
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: 16) {
            SettingsDetailHeader(section: .usage)
            Form {
                Section(NSLocalizedString("settings.usage.section", value: "Usage Limits", comment: "Settings section header for usage limits configuration")) {
                    Picker(
                        NSLocalizedString("settings.usageValueMode", value: "Display Value", comment: "Settings picker: used or remaining percentage"),
                        selection: $viewModel.usageValueMode
                    ) {
                        Text(NSLocalizedString("settings.usageValueMode.used", value: "Used", comment: "Usage value mode: used percentage"))
                            .tag(UsageValueMode.used)
                        Text(NSLocalizedString("settings.usageValueMode.remaining", value: "Remaining", comment: "Usage value mode: remaining percentage"))
                            .tag(UsageValueMode.remaining)
                    }
                    LabeledContent(NSLocalizedString("settings.usageThresholdPercent", value: "Alert Threshold", comment: "Usage threshold percentage")) {
                        Slider(value: $viewModel.usageThresholdPercent, in: 0 ... 100, step: 1)
                    }
                    Toggle(
                        NSLocalizedString("settings.usageThresholdAlert", value: "Usage limit alert", comment: "Show usage threshold alert"),
                        isOn: $viewModel.usageThresholdAlert
                    )
                    Text(NSLocalizedString(
                        "settings.usageThresholdAlertHelp",
                        value: "Show a lightweight peek once when any usage window crosses the selected used percentage.",
                        comment: "Settings help text for usage threshold alerts"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Toggle(
                        NSLocalizedString("settings.showUsage", value: "Show Usage Limits", comment: "Show subscription usage limits in the notch panel"),
                        isOn: $viewModel.showUsage
                    )
                    Text(NSLocalizedString(
                        "settings.showUsageHelp",
                        value: "Display subscription usage limits in the notch panel header",
                        comment: "Settings help text for usage limits display"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
    }
}

struct ShortcutsSettingsPane: View {
    @Bindable private var keyboardManager: KeyboardShortcutManager

    init(keyboardManager: KeyboardShortcutManager = .shared) {
        _keyboardManager = Bindable(wrappedValue: keyboardManager)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsDetailHeader(section: .shortcuts)
            Form {
                Section(NSLocalizedString("menu.modifierKey", value: "Modifier Key", comment: "Keyboard modifier key selection")) {
                    Picker(
                        NSLocalizedString("menu.modifierKey", value: "Modifier Key", comment: "Keyboard modifier key selection"),
                        selection: $keyboardManager.modifierKey
                    ) {
                        Text("⌃ Control").tag(ModifierKeyOption.control)
                        Text("⌥ Option").tag(ModifierKeyOption.option)
                        Text("⌘ Command").tag(ModifierKeyOption.command)
                    }
                }
                Section(NSLocalizedString("settings.globalShortcuts", value: "Global Shortcuts", comment: "Settings section: Global Shortcuts")) {
                    Toggle(
                        NSLocalizedString("settings.keyboardShortcutsEnabled", value: "Enable Keyboard Shortcuts", comment: "Settings: keyboard shortcuts master switch label"),
                        isOn: $keyboardManager.shortcutsEnabled
                    )
                    Text(NSLocalizedString("settings.keyboardShortcutsEnabledDesc", value: "Turn off every Vibe Island shortcut without clearing your mappings.", comment: "Settings: keyboard shortcuts master switch description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("settings.togglePanel", value: "Open Switcher", comment: "Settings: switcher shortcut label"))
                    Text(NSLocalizedString("settings.togglePanelDesc", value: "Quick tap to open and pick with ↑↓ + Enter (Alfred style). Hold and press again to cycle through sessions, release the modifier to jump (⌘Tab style).", comment: "Settings: switcher dual-behavior description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(
                        NSLocalizedString("settings.reverseSwitcherEnabled", value: "Reverse Switcher", comment: "Settings: reverse switcher toggle label"),
                        isOn: $keyboardManager.reverseSwitcherEnabled
                    )
                    Text(NSLocalizedString("settings.reverseSwitcherEnabledDesc", value: "Adds Shift + switcher combo for backwards cycling. Only active while the switcher panel is open, so it rarely conflicts with other apps' shortcuts.", comment: "Settings: reverse switcher description with constraint and rationale"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("settings.shortcut.collapse", value: "Collapse Panel", comment: "Shortcut label: collapse panel with ESC"))
                    Text(NSLocalizedString("settings.shortcut.collapseDesc", value: "Active only when the panel is expanded.", comment: "Settings: collapse shortcut description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Text(NSLocalizedString("settings.shortcut.approve", value: "Approve", comment: "Shortcut label: approve permission"))
                    Text(NSLocalizedString("settings.shortcut.deny", value: "Deny", comment: "Shortcut label: deny permission"))
                    Text(NSLocalizedString("settings.shortcut.alwaysAllow", value: "Always Allow", comment: "Shortcut label: always allow"))
                    Text(NSLocalizedString("settings.shortcut.bypass", value: "Bypass Permissions", comment: "Shortcut label: bypass permissions"))
                    Text(NSLocalizedString("settings.shortcut.terminal", value: "Jump to Terminal", comment: "Shortcut label: jump to terminal"))
                } header: {
                    Text(NSLocalizedString("settings.panelShortcuts", value: "Panel Shortcuts", comment: "Settings section: Panel Shortcuts"))
                }
                Section {
                    Text(NSLocalizedString("settings.shortcut.selectOption", value: "Select Option", comment: "Shortcut label: select option 1-9"))
                    Text(NSLocalizedString("settings.shortcut.submitMulti", value: "Submit Multi-Select", comment: "Shortcut label: submit multi-select answer"))
                }
                Section {
                    Text(NSLocalizedString("settings.shortcut.navigate", value: "Navigate Sessions", comment: "Shortcut label: navigate sessions up/down"))
                } footer: {
                    Text(NSLocalizedString(
                        "settings.shortcut.footer",
                        value: "All shortcuts below are active while the panel is expanded. Hold your modifier key to reveal hints on every button — handy for shortcuts you forgot.",
                        comment: "Settings: panel shortcuts footer emphasizing modifier-hold hint discovery"
                    ))
                }
            }
        }
        .padding(24)
    }
}

struct SSHRemoteSettingsPane: View {
    private let _store: UnknownIDAFieldValue? = nil
    @State private var showAddSheet = false
    @State private var deployingHostId: UUID?
    @State private var deployMessage = ""
    @State private var deployError = ""
    @State private var showResultAlert = false
    @State private var lastResultSuccess = false
    @State private var pendingDeployHost: SSHRemoteHost?

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsDetailHeader(section: .sshRemote)
            Form {
                Section {
                    Text("Monitor and approve remote AI CLI sessions from your Notch.")
                    Text(NSLocalizedString(
                        "sshRemote.introHint",
                        value: "Add Host → Set Up → Connect. Requires SSH pubkey auth (or ControlMaster for MFA).",
                        comment: "SSH Remote introduction hint"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Section("Hosts") {
                    Text(NSLocalizedString("sshRemote.noHosts", value: "No hosts configured yet", comment: "SSH Remote empty host list"))
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label(
                            NSLocalizedString("sshRemote.addHost", value: "Add Host", comment: "SSH Remote add host button"),
                            systemImage: "plus.circle.fill"
                        )
                    }
                }
                Section {
                    DisclosureGroup(NSLocalizedString(
                        "sshRemote.disclosure.manual",
                        value: "Manual install (for restricted networks)",
                        comment: "SSH Remote manual install disclosure"
                    )) {
                        Text("Install the remote hook through an approved transfer channel, then run Set Up again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    DisclosureGroup(NSLocalizedString(
                        "sshRemote.disclosure.docker",
                        value: "Docker container",
                        comment: "SSH Remote Docker disclosure"
                    )) {
                        Text("Run the hook as a sidecar inside the target container environment.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .sheet(isPresented: $showAddSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("sshRemote.addHostTitle", value: "Add Host", comment: "SSH Remote add host sheet title"))
                    .font(.headline)
                Button("Cancel") {
                    showAddSheet = false
                }
            }
            .padding(24)
            .frame(minWidth: 360)
        }
        .alert(lastResultSuccess ? "Setup Successful" : "SSH Remote", isPresented: $showResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lastResultSuccess ? deployMessage : deployError)
        }
    }
}

struct LabsSettingsPane: View {
    private let viewModel: MyVibeIslandSettingsModel
    @State private var cursorApproval: String
    @State private var codexApprovalMode: String
    @State private var kiroPermissionHintDelaySeconds: Int
    @State private var receiveBetaUpdates: Bool
    @State private var autoModeInsteadOfBypass: Bool
    @State private var deferClaudeApprovalsToNative: Bool
    @State private var memoryRestartEnabled: Bool
    @State private var toolAvailability = LabsToolAvailability()

    init(viewModel: MyVibeIslandSettingsModel = MyVibeIslandSettingsRuntime.shared) {
        self.viewModel = viewModel
        _cursorApproval = State(initialValue: viewModel.cursorApproval)
        _codexApprovalMode = State(initialValue: viewModel.codexApprovalMode)
        _kiroPermissionHintDelaySeconds = State(initialValue: viewModel.kiroPermissionHintDelaySeconds)
        _receiveBetaUpdates = State(initialValue: viewModel.receiveBetaUpdates)
        _autoModeInsteadOfBypass = State(initialValue: viewModel.autoModeInsteadOfBypass)
        _deferClaudeApprovalsToNative = State(initialValue: viewModel.deferClaudeApprovalsToNative)
        _memoryRestartEnabled = State(initialValue: viewModel.memoryRestartEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsDetailHeader(section: .labs)
            Form {
                Section(NSLocalizedString("settings.labs.section.stability", value: "Stability", comment: "Settings Labs: stability safeguards section header")) {
                    Toggle(
                        NSLocalizedString("settings.betaUpdates", value: "Beta Updates", comment: "Settings Labs: beta updates toggle"),
                        isOn: $receiveBetaUpdates
                    )
                    Toggle(
                        NSLocalizedString("settings.labs.memoryRestart", value: "Restart when memory is high", comment: "Settings Labs: auto restart on high memory toggle"),
                        isOn: $memoryRestartEnabled
                    )
                }
                Section(NSLocalizedString("settings.labs.section.claude", value: "Claude Code", comment: "Settings Labs: Claude Code section header")) {
                    Toggle(
                        NSLocalizedString("settings.labs.nativeClaudeApprovals", value: "Use Native Claude Code Approvals", comment: "Settings Labs: skip Vibe Island Claude Code approval cards"),
                        isOn: $deferClaudeApprovalsToNative
                    )
                    Toggle(
                        NSLocalizedString("settings.labs.autoMode", value: "Use Auto Mode instead of Bypass", comment: "Settings Labs: toggle title for Auto Mode replacement"),
                        isOn: $autoModeInsteadOfBypass
                    )
                }
                Section(NSLocalizedString("settings.labs.section.codex", value: "Codex", comment: "Settings Labs: Codex section header")) {
                    Picker(
                        NSLocalizedString("settings.labs.codexApprovalMode", value: "When Codex needs your approval", comment: "Codex approval mode picker label"),
                        selection: $codexApprovalMode
                    ) {
                        Text("Approve Here").tag("approve_here")
                        Text("Remind").tag("remind")
                        Text("Hide").tag("hide")
                    }
                }
                Section(NSLocalizedString("settings.labs.section.otherCLIs", value: "Other CLIs", comment: "Settings Labs: other CLI tools section header")) {
                    Picker(
                        NSLocalizedString("settings.labs.cursorApproval", value: "Cursor Sandbox Approval", comment: "Settings Labs: Cursor sandbox approval picker title"),
                        selection: $cursorApproval
                    ) {
                        Text("Auto").tag("auto")
                        Text("Always").tag("always")
                        Text("Never (observe only)").tag("never")
                    }
                    Picker(
                        NSLocalizedString("settings.labs.kiroHints", value: "Kiro Permission Hints", comment: "Settings Labs: Kiro permission hint toggle title"),
                        selection: $kiroPermissionHintDelaySeconds
                    ) {
                        Text("Off").tag(0)
                        ForEach([3, 5, 10, 50], id: \.self) { seconds in
                            Text("\(seconds) seconds").tag(seconds)
                        }
                    }
                }
            }
        }
        .padding(24)
        .onChange(of: cursorApproval) { _, value in viewModel.cursorApproval = value }
        .onChange(of: codexApprovalMode) { _, value in viewModel.codexApprovalMode = value }
        .onChange(of: kiroPermissionHintDelaySeconds) { _, value in viewModel.kiroPermissionHintDelaySeconds = value }
        .onChange(of: receiveBetaUpdates) { _, value in viewModel.receiveBetaUpdates = value }
        .onChange(of: autoModeInsteadOfBypass) { _, value in viewModel.autoModeInsteadOfBypass = value }
        .onChange(of: deferClaudeApprovalsToNative) { _, value in viewModel.deferClaudeApprovalsToNative = value }
        .onChange(of: memoryRestartEnabled) { _, value in viewModel.memoryRestartEnabled = value }
    }
}

struct AboutSettingsPane: View {
    @State private var showCommunitySheet = false
    @State private var showAcknowledgements = false
    @State private var isExportingDiagnostics = false
    @State private var diagnosticExportError: String?
    @State private var showUninstallConfirm = false
    @State private var isUninstalling = false
    @State private var showUninstallDone = false

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Form {
                Section {
                    Text("Vibe Island")
                        .font(.title2.weight(.semibold))
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button(NSLocalizedString("settings.joinCommunity", value: "Join Community", comment: "Settings About: community link label")) {
                        showCommunitySheet = true
                    }
                }
                Section {
                    Button(NSLocalizedString("menu.exportDiagnostics", value: "Export Diagnostic Report", comment: "Export diagnostic logs for troubleshooting")) {
                        isExportingDiagnostics = true
                        do {
                            _ = try MyVibeIslandAppKitDiagnosticExportPresenter(
                                controller: .production()
                            ).export()
                            diagnosticExportError = nil
                        } catch {
                            diagnosticExportError = error.localizedDescription
                        }
                        isExportingDiagnostics = false
                    }
                    .disabled(isExportingDiagnostics)
                } footer: {
                    Text(NSLocalizedString("menu.exportDiagnosticsFooter", value: "Includes system info and anonymized logs. No personal data.", comment: "Privacy note for diagnostic export"))
                }
                Section {
                    Button(NSLocalizedString("settings.acknowledgements", value: "Acknowledgements", comment: "Settings About: open-source licenses button")) {
                        showAcknowledgements = true
                    }
                }
                Section {
                    Button(NSLocalizedString("settings.removeAutoConfig", value: "Remove All Auto-Configuration", comment: "Settings: uninstall all hooks, extensions, and runtime files")) {
                        showUninstallConfirm = true
                    }
                }
                Section {
                    Button(role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Text(NSLocalizedString("menu.quit", value: "Quit Vibe Island", comment: "Quit Vibe Island"))
                    }
                }
            }
        }
        .padding(24)
        .sheet(isPresented: $showCommunitySheet) {
            Text(NSLocalizedString("wechat.community.title", value: "Vibe Island Community", comment: "WeChat QR sheet: modal title"))
                .padding(32)
        }
        .sheet(isPresented: $showAcknowledgements) {
            Text(NSLocalizedString("settings.acknowledgements", value: "Acknowledgements", comment: "Settings About: open-source licenses button"))
                .padding(32)
        }
    }
}

private struct SettingsPanePlaceholder: View {
    let section: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsDetailHeader(section: section)
            Spacer(minLength: 0)
        }
        .padding(24)
    }
}
