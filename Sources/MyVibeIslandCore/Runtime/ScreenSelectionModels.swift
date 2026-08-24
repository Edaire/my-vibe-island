public struct ScreenDescriptor: Codable, Equatable, Sendable {
    public let identifier: String
    public let displayName: String
    public let isBuiltIn: Bool
    public let hasNotch: Bool
    public let isMain: Bool

    public init(
        identifier: String,
        displayName: String,
        isBuiltIn: Bool,
        hasNotch: Bool,
        isMain: Bool
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.isBuiltIn = isBuiltIn
        self.hasNotch = hasNotch
        self.isMain = isMain
    }
}

public struct ScreenTarget: Codable, Equatable, Sendable {
    public let identifier: String
    public let displayName: String
    public let isBuiltIn: Bool
    public let isMain: Bool

    public init(identifier: String, displayName: String, isBuiltIn: Bool, isMain: Bool) {
        self.identifier = identifier
        self.displayName = displayName
        self.isBuiltIn = isBuiltIn
        self.isMain = isMain
    }

    public init(screen: ScreenDescriptor) {
        self.init(
            identifier: screen.identifier,
            displayName: screen.displayName,
            isBuiltIn: screen.isBuiltIn,
            isMain: screen.isMain
        )
    }
}

public struct ScreenSelectionSnapshot: Codable, Equatable, Sendable {
    public let mode: AppScreenSelectionMode
    public let availableScreens: [ScreenDescriptor]
    public let target: ScreenTarget?
    public let manualScreenIdentifier: String?
    public let focusedScreenIdentifier: String?
    public let switchTipDismissed: Bool

    public init(
        mode: AppScreenSelectionMode = .builtInNotchDisplay,
        availableScreens: [ScreenDescriptor] = [],
        target: ScreenTarget? = nil,
        manualScreenIdentifier: String? = nil,
        focusedScreenIdentifier: String? = nil,
        switchTipDismissed: Bool = false
    ) {
        self.mode = mode
        self.availableScreens = availableScreens
        self.target = target
        self.manualScreenIdentifier = manualScreenIdentifier
        self.focusedScreenIdentifier = focusedScreenIdentifier
        self.switchTipDismissed = switchTipDismissed
    }
}

public enum ScreenSelectionCommand: Equatable, Sendable {
    case refreshScreens([ScreenDescriptor])
    case selectMode(AppScreenSelectionMode)
    case selectDisplay(String)
    case focusDisplay(String)
    case dismissSwitchTip
}

public struct ScreenSelectionPlan: Equatable, Sendable {
    public let nextSnapshot: ScreenSelectionSnapshot
    public let targetDidChange: Bool

    public init(nextSnapshot: ScreenSelectionSnapshot, targetDidChange: Bool) {
        self.nextSnapshot = nextSnapshot
        self.targetDidChange = targetDidChange
    }
}

public struct ScreenSelectionCoordinator: Sendable {
    public init() {}

    public func plan(
        _ command: ScreenSelectionCommand,
        from snapshot: ScreenSelectionSnapshot
    ) -> ScreenSelectionPlan {
        switch command {
        case let .refreshScreens(screens):
            return resolve(
                mode: snapshot.mode,
                screens: screens,
                previousTarget: snapshot.target,
                manualScreenIdentifier: snapshot.manualScreenIdentifier,
                focusedScreenIdentifier: snapshot.focusedScreenIdentifier,
                switchTipDismissed: snapshot.switchTipDismissed
            )

        case let .selectMode(mode):
            return resolve(
                mode: mode,
                screens: snapshot.availableScreens,
                previousTarget: snapshot.target,
                manualScreenIdentifier: snapshot.manualScreenIdentifier,
                focusedScreenIdentifier: snapshot.focusedScreenIdentifier,
                switchTipDismissed: snapshot.switchTipDismissed
            )

        case let .selectDisplay(identifier):
            return resolve(
                mode: .manualDisplay,
                screens: snapshot.availableScreens,
                previousTarget: snapshot.target,
                manualScreenIdentifier: identifier,
                focusedScreenIdentifier: snapshot.focusedScreenIdentifier,
                switchTipDismissed: snapshot.switchTipDismissed
            )

        case let .focusDisplay(identifier):
            guard snapshot.mode == .followKeyboardFocus,
                  snapshot.availableScreens.contains(where: { $0.identifier == identifier })
            else {
                return ScreenSelectionPlan(
                    nextSnapshot: ScreenSelectionSnapshot(
                        mode: snapshot.mode,
                        availableScreens: snapshot.availableScreens,
                        target: snapshot.target,
                        manualScreenIdentifier: snapshot.manualScreenIdentifier,
                        focusedScreenIdentifier: snapshot.focusedScreenIdentifier,
                        switchTipDismissed: snapshot.switchTipDismissed
                    ),
                    targetDidChange: false
                )
            }
            return resolve(
                mode: snapshot.mode,
                screens: snapshot.availableScreens,
                previousTarget: snapshot.target,
                manualScreenIdentifier: snapshot.manualScreenIdentifier,
                focusedScreenIdentifier: identifier,
                switchTipDismissed: snapshot.switchTipDismissed
            )

        case .dismissSwitchTip:
            return ScreenSelectionPlan(
                nextSnapshot: ScreenSelectionSnapshot(
                    mode: snapshot.mode,
                    availableScreens: snapshot.availableScreens,
                    target: snapshot.target,
                    manualScreenIdentifier: snapshot.manualScreenIdentifier,
                    focusedScreenIdentifier: snapshot.focusedScreenIdentifier,
                    switchTipDismissed: true
                ),
                targetDidChange: false
            )
        }
    }

    private func resolve(
        mode: AppScreenSelectionMode,
        screens: [ScreenDescriptor],
        previousTarget: ScreenTarget?,
        manualScreenIdentifier: String?,
        focusedScreenIdentifier: String?,
        switchTipDismissed: Bool
    ) -> ScreenSelectionPlan {
        let selectedScreen = screen(
            for: mode,
            screens: screens,
            manualScreenIdentifier: manualScreenIdentifier,
            focusedScreenIdentifier: focusedScreenIdentifier
        )
        let target = selectedScreen.map(ScreenTarget.init(screen:))

        return ScreenSelectionPlan(
            nextSnapshot: ScreenSelectionSnapshot(
                mode: mode,
                availableScreens: screens,
                target: target,
                manualScreenIdentifier: manualScreenIdentifier,
                focusedScreenIdentifier: focusedScreenIdentifier,
                switchTipDismissed: switchTipDismissed
            ),
            targetDidChange: target?.identifier != previousTarget?.identifier
        )
    }

    private func screen(
        for mode: AppScreenSelectionMode,
        screens: [ScreenDescriptor],
        manualScreenIdentifier: String?,
        focusedScreenIdentifier: String?
    ) -> ScreenDescriptor? {
        switch mode {
        case .builtInNotchDisplay:
            return screens.first { $0.isBuiltIn && $0.hasNotch }
                ?? screens.first(where: \.isMain)
                ?? screens.first
        case .mainDisplay:
            return screens.first
        case .followKeyboardFocus:
            if let focusedScreenIdentifier,
               let focused = screens.first(where: { $0.identifier == focusedScreenIdentifier }) {
                return focused
            }
            return screens.first(where: \.isMain) ?? screens.first
        case .manualDisplay:
            if let manualScreenIdentifier,
               let manual = screens.first(where: { $0.identifier == manualScreenIdentifier }) {
                return manual
            }
            return screens.first
        case .fallbackDisplay:
            return screens.first(where: \.isMain) ?? screens.first
        }
    }
}
