import Foundation

public struct ShortcutCoordinatorState: Codable, Equatable, Sendable {
    public let activeScopes: [ShortcutScope]
    public let registeredHotKeyIds: [String]
    public let isStarted: Bool

    public init(
        activeScopes: [ShortcutScope] = [],
        registeredHotKeyIds: [String] = [],
        isStarted: Bool = false
    ) {
        self.activeScopes = Self.normalizedScopes(activeScopes)
        self.registeredHotKeyIds = registeredHotKeyIds
        self.isStarted = isStarted
    }

    public static func normalizedScopes(_ scopes: [ShortcutScope]) -> [ShortcutScope] {
        Array(Set(scopes)).sorted { lhs, rhs in
            lhs.sortOrder < rhs.sortOrder
        }
    }
}

public enum ShortcutCoordinatorCommand: Equatable, Sendable {
    case start
    case stop
    case enterScope(ShortcutScope)
    case exitScope(ShortcutScope)
    case updateSettings(ShortcutSettings)
}

public enum ShortcutCoordinatorLifecycleAction: String, Codable, Equatable, Sendable {
    case registerShortcuts
    case unregisterShortcuts
    case noChange
}

public struct ShortcutCoordinatorLifecyclePlan: Codable, Equatable, Sendable {
    public let action: ShortcutCoordinatorLifecycleAction
    public let registrationPlan: ShortcutRegistrationPlan
    public let hotKeyIdsToUnregister: [String]
    public let nextState: ShortcutCoordinatorState

    public init(
        action: ShortcutCoordinatorLifecycleAction,
        registrationPlan: ShortcutRegistrationPlan,
        hotKeyIdsToUnregister: [String] = [],
        nextState: ShortcutCoordinatorState
    ) {
        self.action = action
        self.registrationPlan = registrationPlan
        self.hotKeyIdsToUnregister = hotKeyIdsToUnregister.sorted()
        self.nextState = nextState
    }
}

public enum ShortcutDispatchAction: String, Codable, Equatable, Sendable {
    case dispatchAction
    case ignore
}

public enum ShortcutDispatchPolicy: String, Codable, Equatable, Sendable {
    case routeThroughActionRouter
    case notRegistered
    case unknownHotKey
}

public struct ShortcutDispatchPlan: Codable, Equatable, Sendable {
    public let action: ShortcutDispatchAction
    public let hotKeyId: String
    public let shortcutAction: ShortcutAction?
    public let dispatchPolicy: ShortcutDispatchPolicy

    public init(
        action: ShortcutDispatchAction,
        hotKeyId: String,
        shortcutAction: ShortcutAction? = nil,
        dispatchPolicy: ShortcutDispatchPolicy
    ) {
        self.action = action
        self.hotKeyId = hotKeyId
        self.shortcutAction = shortcutAction
        self.dispatchPolicy = dispatchPolicy
    }
}

public struct ShortcutCoordinator: Sendable {
    public let settings: ShortcutSettings
    private let manager: ShortcutManager

    public init(
        settings: ShortcutSettings,
        manager: ShortcutManager = ShortcutManager()
    ) {
        self.settings = settings
        self.manager = manager
    }

    public func plan(
        _ command: ShortcutCoordinatorCommand,
        from state: ShortcutCoordinatorState
    ) -> ShortcutCoordinatorLifecyclePlan {
        switch command {
        case .start:
            return registrationPlan(scopes: [.persistentGlobal], settings: settings, isStarted: true)
        case .stop:
            return unregistrationPlan(scopes: [], from: state, settings: settings, isStarted: false)
        case let .enterScope(scope):
            return registrationPlan(
                scopes: state.activeScopes + [scope],
                settings: settings,
                isStarted: state.isStarted
            )
        case let .exitScope(scope):
            let nextScopes = state.activeScopes.filter { $0 != scope }
            return unregistrationPlan(scopes: nextScopes, from: state, settings: settings, isStarted: state.isStarted)
        case let .updateSettings(updatedSettings):
            if !updatedSettings.keyboardShortcutsEnabled {
                return unregistrationPlan(scopes: state.activeScopes, from: state, settings: updatedSettings, isStarted: state.isStarted)
            }
            return registrationPlan(scopes: state.activeScopes, settings: updatedSettings, isStarted: state.isStarted)
        }
    }

    public func planDispatch(
        hotKeyId: String,
        state: ShortcutCoordinatorState
    ) -> ShortcutDispatchPlan {
        guard state.registeredHotKeyIds.contains(hotKeyId) else {
            return ShortcutDispatchPlan(
                action: .ignore,
                hotKeyId: hotKeyId,
                dispatchPolicy: .notRegistered
            )
        }

        guard let spec = settings.allSpecs.first(where: { $0.id == hotKeyId }) else {
            return ShortcutDispatchPlan(
                action: .ignore,
                hotKeyId: hotKeyId,
                dispatchPolicy: .unknownHotKey
            )
        }

        return ShortcutDispatchPlan(
            action: .dispatchAction,
            hotKeyId: hotKeyId,
            shortcutAction: spec.action,
            dispatchPolicy: .routeThroughActionRouter
        )
    }

    private func registrationPlan(
        scopes: [ShortcutScope],
        settings: ShortcutSettings,
        isStarted: Bool
    ) -> ShortcutCoordinatorLifecyclePlan {
        let normalizedScopes = ShortcutCoordinatorState.normalizedScopes(scopes)
        let registrationPlan = manager.planRegistrations(
            settings: settings,
            activeScopes: Set(normalizedScopes)
        )
        let nextState = ShortcutCoordinatorState(
            activeScopes: normalizedScopes,
            registeredHotKeyIds: registrationPlan.registrations.map(\.id),
            isStarted: isStarted
        )

        return ShortcutCoordinatorLifecyclePlan(
            action: registrationPlan.registrations.isEmpty ? .noChange : .registerShortcuts,
            registrationPlan: registrationPlan,
            nextState: nextState
        )
    }

    private func unregistrationPlan(
        scopes: [ShortcutScope],
        from state: ShortcutCoordinatorState,
        settings: ShortcutSettings,
        isStarted: Bool
    ) -> ShortcutCoordinatorLifecyclePlan {
        let normalizedScopes = ShortcutCoordinatorState.normalizedScopes(scopes)
        let registrationPlan = manager.planRegistrations(
            settings: settings,
            activeScopes: Set(normalizedScopes)
        )
        let nextRegisteredIds = registrationPlan.registrations.map(\.id)
        let idsToUnregister = state.registeredHotKeyIds.filter { !nextRegisteredIds.contains($0) }
        let nextState = ShortcutCoordinatorState(
            activeScopes: normalizedScopes,
            registeredHotKeyIds: nextRegisteredIds,
            isStarted: isStarted
        )

        return ShortcutCoordinatorLifecyclePlan(
            action: idsToUnregister.isEmpty ? .noChange : .unregisterShortcuts,
            registrationPlan: registrationPlan,
            hotKeyIdsToUnregister: idsToUnregister,
            nextState: nextState
        )
    }
}

private extension ShortcutScope {
    var sortOrder: Int {
        switch self {
        case .persistentGlobal:
            return 0
        case .expandedPanel:
            return 1
        case .switcherPanel:
            return 2
        }
    }
}
