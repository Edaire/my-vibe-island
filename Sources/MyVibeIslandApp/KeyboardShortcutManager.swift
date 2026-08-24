import Foundation
import MyVibeIslandCore
import Observation

private struct UnknownKeyboardShortcutManagerFieldValue {}

struct KeyCombo: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    static let disabled = KeyCombo(keyCode: .max, carbonModifiers: 0)
}

enum ApprovalAction: CaseIterable, Hashable, Sendable {
    case approve
    case deny
    case terminal
    case always
    case bypass
}

@MainActor
@Observable
final class KeyboardShortcutManager {
    static var preferenceStore = LocalPreferenceStore()
    static let shared = KeyboardShortcutManager()

    private var persistentHotKeyIds = UnknownKeyboardShortcutManagerFieldValue()
    private var expandedHotKeyIds = UnknownKeyboardShortcutManagerFieldValue()
    private var switcherHotKeyIds = UnknownKeyboardShortcutManagerFieldValue()
    private var isActive = false
    private var isPersistentActive = false
    private var isSwitcherActive = false
    private var flagsMonitor = UnknownKeyboardShortcutManagerFieldValue()
    private var localFlagsMonitor = UnknownKeyboardShortcutManagerFieldValue()
    private var globalKeyDownMonitor = UnknownKeyboardShortcutManagerFieldValue()
    private var localKeyDownMonitor = UnknownKeyboardShortcutManagerFieldValue()
    private var lastFiredAt: [String: Double] = [:]
    let dedupWindow = 0.15
    private let relevantModifierFlags = UnknownKeyboardShortcutManagerFieldValue()
    private var switcherHasNavigated = false
    private var switcherOpenedAt = UnknownKeyboardShortcutManagerFieldValue()
    let modifierHoldThreshold = 0.3
    private var isModifierHeld = false
    var modifierKey: ModifierKeyOption {
        didSet { Self.preferenceStore.set(modifierKey.rawValue, forKey: "modifierKey") }
    }
    var shortcutsEnabled: Bool {
        didSet { Self.preferenceStore.set(shortcutsEnabled, forKey: "keyboardShortcutsEnabled") }
    }
    var reverseSwitcherEnabled: Bool {
        didSet { Self.preferenceStore.set(reverseSwitcherEnabled, forKey: "reverseSwitcherEnabled") }
    }
    private(set) var approvalKeys: [ApprovalAction: UInt32]
    private(set) var switcherKeyCombo: KeyCombo
    private(set) var collapseKeyCombo: KeyCombo

    init(
        modifierKey: ModifierKeyOption? = nil,
        shortcutsEnabled: Bool? = nil,
        reverseSwitcherEnabled: Bool? = nil,
        approvalKeys: [ApprovalAction: UInt32] = [:],
        switcherKeyCombo: KeyCombo = .disabled,
        collapseKeyCombo: KeyCombo = .disabled
    ) {
        self.modifierKey = modifierKey
            ?? Self.preferenceStore.string(forKey: "modifierKey").flatMap(ModifierKeyOption.init(rawValue:))
            ?? .command
        self.shortcutsEnabled = shortcutsEnabled
            ?? Self.preferenceStore.bool(forKey: "keyboardShortcutsEnabled", default: true)
        self.reverseSwitcherEnabled = reverseSwitcherEnabled
            ?? Self.preferenceStore.bool(forKey: "reverseSwitcherEnabled", default: true)
        self.approvalKeys = approvalKeys.isEmpty ? Self.loadApprovalKeys() : approvalKeys
        self.switcherKeyCombo = switcherKeyCombo == .disabled
            ? Self.loadKeyCombo(forKey: "switcherKeyCombo") ?? .disabled
            : switcherKeyCombo
        self.collapseKeyCombo = collapseKeyCombo == .disabled
            ? Self.loadKeyCombo(forKey: "collapseKeyCombo") ?? .disabled
            : collapseKeyCombo
    }

    var hasInstalledEventMonitors: Bool {
        false
    }

    @discardableResult
    func updateApprovalKey(_ keyCode: UInt32, for action: ApprovalAction) -> Bool {
        guard !Self.reservedApprovalKeyCodes.contains(keyCode) else {
            return false
        }
        guard !approvalKeys.contains(where: { $0.key != action && $0.value == keyCode }) else {
            return false
        }

        approvalKeys[action] = keyCode
        Self.saveApprovalKeys(approvalKeys)
        return true
    }

    func updateSwitcherKeyCombo(_ keyCombo: KeyCombo) {
        switcherKeyCombo = keyCombo
        Self.save(keyCombo, forKey: "switcherKeyCombo")
    }

    func updateCollapseKeyCombo(_ keyCombo: KeyCombo) {
        collapseKeyCombo = keyCombo
        Self.save(keyCombo, forKey: "collapseKeyCombo")
    }

    private static func loadApprovalKeys() -> [ApprovalAction: UInt32] {
        guard let data = preferenceStore.data(forKey: "approvalKeys"),
              let stored = try? JSONDecoder().decode([String: UInt32].self, from: data)
        else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: ApprovalAction.allCases.compactMap { action in
            stored[action.storageKey].map { (action, $0) }
        })
    }

    private static func saveApprovalKeys(_ values: [ApprovalAction: UInt32]) {
        let stored = Dictionary(uniqueKeysWithValues: values.map { ($0.key.storageKey, $0.value) })
        preferenceStore.set(try? JSONEncoder().encode(stored), forKey: "approvalKeys")
    }

    private static func loadKeyCombo(forKey key: String) -> KeyCombo? {
        preferenceStore.data(forKey: key).flatMap { try? JSONDecoder().decode(KeyCombo.self, from: $0) }
    }

    private static func save(_ value: KeyCombo, forKey key: String) {
        preferenceStore.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static let reservedApprovalKeyCodes: Set<UInt32> = [
        18, 19, 20, 21, 22, 23, 25, 26, 28, 36, 43, 48, 53, 125, 126,
    ]
}

private extension ApprovalAction {
    var storageKey: String {
        switch self {
        case .approve: "approve"
        case .deny: "deny"
        case .terminal: "terminal"
        case .always: "always"
        case .bypass: "bypass"
        }
    }
}
