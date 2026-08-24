import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitShortcutCoordinatorController {
    public private(set) var state: ShortcutCoordinatorState
    public private(set) var settings: ShortcutSettings
    public private(set) var lastLifecyclePlan: ShortcutCoordinatorLifecyclePlan?

    private let registerShortcuts: @MainActor (ShortcutRegistrationPlan) -> Void
    private let unregisterShortcuts: @MainActor ([String]) -> Void
    private let routeShortcutAction: @MainActor (ShortcutAction) -> Void
    private let onModifierRelease: @MainActor () -> Void

    public init(
        state: ShortcutCoordinatorState = ShortcutCoordinatorState(),
        settings: ShortcutSettings = ShortcutSettings(),
        registerShortcuts: @escaping @MainActor (ShortcutRegistrationPlan) -> Void = { _ in },
        unregisterShortcuts: @escaping @MainActor ([String]) -> Void = { _ in },
        routeShortcutAction: @escaping @MainActor (ShortcutAction) -> Void = { _ in },
        onModifierRelease: @escaping @MainActor () -> Void = {}
    ) {
        self.state = state
        self.settings = settings
        self.registerShortcuts = registerShortcuts
        self.unregisterShortcuts = unregisterShortcuts
        self.routeShortcutAction = routeShortcutAction
        self.onModifierRelease = onModifierRelease
    }

    @discardableResult
    public func start() -> ShortcutCoordinatorLifecyclePlan {
        apply(.start)
    }

    @discardableResult
    public func stop() -> ShortcutCoordinatorLifecyclePlan {
        apply(.stop)
    }

    @discardableResult
    public func enterScope(_ scope: ShortcutScope) -> ShortcutCoordinatorLifecyclePlan {
        apply(.enterScope(scope))
    }

    @discardableResult
    public func exitScope(_ scope: ShortcutScope) -> ShortcutCoordinatorLifecyclePlan {
        apply(.exitScope(scope))
    }

    @discardableResult
    public func updateSettings(_ settings: ShortcutSettings) -> ShortcutCoordinatorLifecyclePlan {
        let plan = apply(.updateSettings(settings))
        self.settings = settings
        return plan
    }

    @discardableResult
    public func handleHotKey(_ hotKeyId: String) -> ShortcutDispatchPlan {
        let plan = coordinator.planDispatch(hotKeyId: hotKeyId, state: state)
        if plan.action == .dispatchAction, let shortcutAction = plan.shortcutAction {
            routeShortcutAction(shortcutAction)
        }
        return plan
    }

    public func handleModifierReleaseEvent() {
        onModifierRelease()
    }

    private func apply(_ command: ShortcutCoordinatorCommand) -> ShortcutCoordinatorLifecyclePlan {
        let plan = coordinator.plan(command, from: state)
        state = plan.nextState
        lastLifecyclePlan = plan

        switch plan.action {
        case .registerShortcuts:
            registerShortcuts(plan.registrationPlan)
        case .unregisterShortcuts:
            unregisterShortcuts(plan.hotKeyIdsToUnregister)
        case .noChange:
            break
        }

        return plan
    }

    private var coordinator: ShortcutCoordinator {
        ShortcutCoordinator(settings: settings)
    }
}
