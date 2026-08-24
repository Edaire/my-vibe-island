import Foundation

public enum ModifierKeyOption: String, Codable, Equatable, CaseIterable, Sendable {
    case command
    case option
    case control
    case shift

    public var carbonValue: Int {
        switch self {
        case .command:
            return 256
        case .shift:
            return 512
        case .option:
            return 2_048
        case .control:
            return 4_096
        }
    }

    public var displayName: String {
        switch self {
        case .command:
            return "Cmd"
        case .option:
            return "Opt"
        case .control:
            return "Ctrl"
        case .shift:
            return "Shift"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .control:
            return 0
        case .option:
            return 1
        case .command:
            return 2
        case .shift:
            return 3
        }
    }
}

public struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    public let keyCode: Int
    public let characters: String
    public let modifiers: [ModifierKeyOption]

    public var carbonModifiers: Int {
        Set(modifiers).reduce(0) { $0 + $1.carbonValue }
    }

    public var displayText: String {
        let modifierText = Set(modifiers)
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.rawValue < rhs.rawValue
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            .map(\.displayName)

        return (modifierText + [characters]).filter { !$0.isEmpty }.joined(separator: "-")
    }

    public init(
        keyCode: Int,
        characters: String,
        modifiers: [ModifierKeyOption]
    ) {
        self.keyCode = max(keyCode, 0)
        self.characters = characters
        self.modifiers = Array(Set(modifiers)).sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.rawValue < rhs.rawValue
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }
}

public enum ShortcutScope: String, Codable, Equatable, Sendable {
    case persistentGlobal
    case expandedPanel
    case switcherPanel
}

public enum ShortcutAction: String, Codable, Equatable, Sendable {
    case toggleIsland
    case focusActiveSession
    case jumpToTerminal
    case navigateSessions
    case selectOption
    case submitMultiSelectAnswer
    case approvePermission
    case denyPermission
    case alwaysAllow
    case collapsePanel
}

public enum ShortcutConflictPolicy: String, Codable, Equatable, Sendable {
    case reportConflict
    case allowDuplicate
}

public struct HotKeyRegistrationSpec: Codable, Equatable, Sendable {
    public let id: String
    public let action: ShortcutAction
    public let keyCombo: KeyCombo
    public let scope: ShortcutScope
    public let isEnabled: Bool
    public let conflictPolicy: ShortcutConflictPolicy

    public init(
        id: String,
        action: ShortcutAction,
        keyCombo: KeyCombo,
        scope: ShortcutScope,
        isEnabled: Bool = true,
        conflictPolicy: ShortcutConflictPolicy = .reportConflict
    ) {
        self.id = id
        self.action = action
        self.keyCombo = keyCombo
        self.scope = scope
        self.isEnabled = isEnabled
        self.conflictPolicy = conflictPolicy
    }
}

public struct ShortcutSettings: Codable, Equatable, Sendable {
    public let keyboardShortcutsEnabled: Bool
    public let globalShortcuts: [HotKeyRegistrationSpec]
    public let panelShortcuts: [HotKeyRegistrationSpec]
    public let switcherShortcuts: [HotKeyRegistrationSpec]
    public let persistentHotKeyIds: [String]
    public let expandedHotKeyIds: [String]
    public let switcherHotKeyIds: [String]
    public let switcherKeyCombo: KeyCombo?
    public let collapseKeyCombo: KeyCombo?

    public init(
        keyboardShortcutsEnabled: Bool = true,
        globalShortcuts: [HotKeyRegistrationSpec] = [],
        panelShortcuts: [HotKeyRegistrationSpec] = [],
        switcherShortcuts: [HotKeyRegistrationSpec] = [],
        persistentHotKeyIds: [String] = [],
        expandedHotKeyIds: [String] = [],
        switcherHotKeyIds: [String] = [],
        switcherKeyCombo: KeyCombo? = nil,
        collapseKeyCombo: KeyCombo? = nil
    ) {
        self.keyboardShortcutsEnabled = keyboardShortcutsEnabled
        self.globalShortcuts = globalShortcuts
        self.panelShortcuts = panelShortcuts
        self.switcherShortcuts = switcherShortcuts
        self.persistentHotKeyIds = persistentHotKeyIds
        self.expandedHotKeyIds = expandedHotKeyIds
        self.switcherHotKeyIds = switcherHotKeyIds
        self.switcherKeyCombo = switcherKeyCombo
        self.collapseKeyCombo = collapseKeyCombo
    }

    public var allSpecs: [HotKeyRegistrationSpec] {
        globalShortcuts + panelShortcuts + switcherShortcuts
    }

    public func withKeyboardShortcutsEnabled(_ isEnabled: Bool) -> ShortcutSettings {
        ShortcutSettings(
            keyboardShortcutsEnabled: isEnabled,
            globalShortcuts: globalShortcuts,
            panelShortcuts: panelShortcuts,
            switcherShortcuts: switcherShortcuts,
            persistentHotKeyIds: persistentHotKeyIds,
            expandedHotKeyIds: expandedHotKeyIds,
            switcherHotKeyIds: switcherHotKeyIds,
            switcherKeyCombo: switcherKeyCombo,
            collapseKeyCombo: collapseKeyCombo
        )
    }
}

public struct HotKeyRef: Codable, Equatable, Sendable {
    public let id: String
    public let carbonId: Int
    public let keyCombo: KeyCombo
    public let scope: ShortcutScope
    public let action: ShortcutAction

    public init(
        id: String,
        carbonId: Int,
        keyCombo: KeyCombo,
        scope: ShortcutScope,
        action: ShortcutAction
    ) {
        self.id = id
        self.carbonId = max(carbonId, 0)
        self.keyCombo = keyCombo
        self.scope = scope
        self.action = action
    }
}

public enum ShortcutRegistrationSkippedReason: String, Codable, Equatable, Sendable {
    case shortcutsDisabled
    case mappingDisabled
    case scopeInactive
}

public struct ShortcutRegistrationSkipped: Codable, Equatable, Sendable {
    public let specId: String
    public let reason: ShortcutRegistrationSkippedReason

    public init(specId: String, reason: ShortcutRegistrationSkippedReason) {
        self.specId = specId
        self.reason = reason
    }
}

public struct ShortcutRegistrationConflict: Codable, Equatable, Sendable {
    public let specId: String
    public let conflictingSpecId: String
    public let keyCombo: KeyCombo

    public init(specId: String, conflictingSpecId: String, keyCombo: KeyCombo) {
        self.specId = specId
        self.conflictingSpecId = conflictingSpecId
        self.keyCombo = keyCombo
    }
}

public struct ShortcutRegistrationPlan: Codable, Equatable, Sendable {
    public let registrations: [HotKeyRegistrationSpec]
    public let skipped: [ShortcutRegistrationSkipped]
    public let conflicts: [ShortcutRegistrationConflict]

    public init(
        registrations: [HotKeyRegistrationSpec],
        skipped: [ShortcutRegistrationSkipped],
        conflicts: [ShortcutRegistrationConflict]
    ) {
        self.registrations = registrations
        self.skipped = skipped
        self.conflicts = conflicts
    }
}

public struct ShortcutManager: Sendable {
    public init() {}

    public func planRegistrations(
        settings: ShortcutSettings,
        activeScopes: Set<ShortcutScope>
    ) -> ShortcutRegistrationPlan {
        var registrations: [HotKeyRegistrationSpec] = []
        var skipped: [ShortcutRegistrationSkipped] = []
        var conflicts: [ShortcutRegistrationConflict] = []
        var registeredCombos: [KeyCombo: String] = [:]

        for spec in settings.allSpecs {
            guard settings.keyboardShortcutsEnabled else {
                skipped.append(ShortcutRegistrationSkipped(specId: spec.id, reason: .shortcutsDisabled))
                continue
            }

            guard spec.isEnabled else {
                skipped.append(ShortcutRegistrationSkipped(specId: spec.id, reason: .mappingDisabled))
                continue
            }

            guard activeScopes.contains(spec.scope) else {
                skipped.append(ShortcutRegistrationSkipped(specId: spec.id, reason: .scopeInactive))
                continue
            }

            if spec.conflictPolicy == .reportConflict,
               let conflictingSpecId = registeredCombos[spec.keyCombo] {
                conflicts.append(ShortcutRegistrationConflict(
                    specId: spec.id,
                    conflictingSpecId: conflictingSpecId,
                    keyCombo: spec.keyCombo
                ))
                continue
            }

            registeredCombos[spec.keyCombo] = spec.id
            registrations.append(spec)
        }

        return ShortcutRegistrationPlan(
            registrations: registrations,
            skipped: skipped,
            conflicts: conflicts
        )
    }
}
