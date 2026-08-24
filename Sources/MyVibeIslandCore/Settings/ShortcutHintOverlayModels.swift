import Foundation

public struct ShortcutHintItem: Codable, Equatable, Sendable {
    public let action: ShortcutAction
    public let title: String
    public let keyCombo: KeyCombo

    public var displayText: String {
        keyCombo.displayText
    }

    public init(
        action: ShortcutAction,
        title: String,
        keyCombo: KeyCombo
    ) {
        self.action = action
        self.title = title
        self.keyCombo = keyCombo
    }
}

public struct ShortcutHintOverlayState: Codable, Equatable, Sendable {
    public let isVisible: Bool
    public let modifierKey: ModifierKeyOption
    public let items: [ShortcutHintItem]

    public init(
        isVisible: Bool,
        modifierKey: ModifierKeyOption,
        items: [ShortcutHintItem] = []
    ) {
        self.isVisible = isVisible
        self.modifierKey = modifierKey
        self.items = items
    }
}

public struct ShortcutHintOverlayModel: Sendable {
    public init() {}

    public func state(
        settings: ShortcutSettings,
        modifierKey: ModifierKeyOption,
        isPanelExpanded: Bool
    ) -> ShortcutHintOverlayState {
        guard isPanelExpanded else {
            return ShortcutHintOverlayState(isVisible: false, modifierKey: modifierKey)
        }

        let items = settings.panelShortcuts
            .filter { spec in
                spec.isEnabled
                    && spec.scope == .expandedPanel
                    && spec.keyCombo.modifiers.contains(modifierKey)
            }
            .map { spec in
                ShortcutHintItem(
                    action: spec.action,
                    title: Self.title(for: spec.action),
                    keyCombo: spec.keyCombo
                )
            }

        return ShortcutHintOverlayState(
            isVisible: !items.isEmpty,
            modifierKey: modifierKey,
            items: items
        )
    }

    private static func title(for action: ShortcutAction) -> String {
        switch action {
        case .toggleIsland:
            return "Toggle Island"
        case .focusActiveSession:
            return "Focus Active"
        case .jumpToTerminal:
            return "Jump"
        case .navigateSessions:
            return "Navigate"
        case .selectOption:
            return "Select"
        case .submitMultiSelectAnswer:
            return "Submit"
        case .approvePermission:
            return "Approve"
        case .denyPermission:
            return "Deny"
        case .alwaysAllow:
            return "Always Allow"
        case .collapsePanel:
            return "Collapse"
        }
    }
}
