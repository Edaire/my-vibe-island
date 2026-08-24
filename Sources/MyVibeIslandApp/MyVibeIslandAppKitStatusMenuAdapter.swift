import MyVibeIslandCore

public enum MyVibeIslandAppKitStatusMenuItemKind: String, Equatable, Sendable {
    case command
    case separator
    case sectionHeader
}

public enum MyVibeIslandAppKitStatusMenuItemState: String, Equatable, Sendable {
    case off
    case on
}

public struct MyVibeIslandAppKitStatusMenuItemDescriptor: Equatable, Sendable {
    public let kind: MyVibeIslandAppKitStatusMenuItemKind
    public let title: String
    public let command: AppCommand?
    public let isEnabled: Bool
    public let state: MyVibeIslandAppKitStatusMenuItemState

    public init(
        kind: MyVibeIslandAppKitStatusMenuItemKind,
        title: String = "",
        command: AppCommand? = nil,
        isEnabled: Bool = false,
        state: MyVibeIslandAppKitStatusMenuItemState = .off
    ) {
        self.kind = kind
        self.title = title
        self.command = command
        self.isEnabled = isEnabled
        self.state = state
    }
}

public struct MyVibeIslandAppKitStatusMenuDescriptor: Equatable, Sendable {
    public let isVisible: Bool
    public let accessibilityLabel: String
    public let items: [MyVibeIslandAppKitStatusMenuItemDescriptor]

    public init(
        isVisible: Bool,
        accessibilityLabel: String,
        items: [MyVibeIslandAppKitStatusMenuItemDescriptor]
    ) {
        self.isVisible = isVisible
        self.accessibilityLabel = accessibilityLabel
        self.items = items
    }
}

public struct MyVibeIslandAppKitStatusMenuAdapter: Sendable {
    public init() {}

    public func makeMenuDescriptor(
        from snapshot: StatusItemMenuSnapshot
    ) -> MyVibeIslandAppKitStatusMenuDescriptor {
        MyVibeIslandAppKitStatusMenuDescriptor(
            isVisible: snapshot.isVisible,
            accessibilityLabel: snapshot.accessibilityLabel,
            items: snapshot.isVisible ? snapshot.entries.map(makeItemDescriptor(from:)) : []
        )
    }

    private func makeItemDescriptor(
        from entry: StatusItemMenuEntry
    ) -> MyVibeIslandAppKitStatusMenuItemDescriptor {
        MyVibeIslandAppKitStatusMenuItemDescriptor(
            kind: itemKind(for: entry.kind),
            title: entry.title,
            command: entry.command,
            isEnabled: entry.isEnabled,
            state: entry.isChecked ? .on : .off
        )
    }

    private func itemKind(
        for kind: StatusItemMenuEntryKind
    ) -> MyVibeIslandAppKitStatusMenuItemKind {
        switch kind {
        case .command:
            return .command
        case .separator:
            return .separator
        case .sectionHeader:
            return .sectionHeader
        }
    }
}
