import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitShortcutManagerController {
    public private(set) var coordinatorState: ShortcutCoordinatorState
    public private(set) var settings: ShortcutSettings
    public private(set) var lastLifecyclePlan: ShortcutCoordinatorLifecyclePlan?
    public private(set) var lastCarbonRegistrationPlan: CarbonHotKeyRegistrationPlan?
    public private(set) var lastCarbonUnregistrationPlan: CarbonHotKeyUnregistrationPlan?

    private let carbonController: MyVibeIslandAppKitCarbonHotKeyController
    private let routeShortcutAction: @MainActor (ShortcutAction) -> Void

    public var carbonRefs: [HotKeyRef] {
        carbonController.refs
    }

    public init(
        settings: ShortcutSettings = ShortcutSettings(),
        state: ShortcutCoordinatorState = ShortcutCoordinatorState(),
        carbonController: MyVibeIslandAppKitCarbonHotKeyController? = nil,
        registerHotKey: @escaping @MainActor (HotKeyRef) -> Bool = { _ in true },
        unregisterHotKey: @escaping @MainActor (HotKeyRef) -> Void = { _ in },
        routeShortcutAction: @escaping @MainActor (ShortcutAction) -> Void = { _ in }
    ) {
        self.settings = settings
        self.coordinatorState = state
        self.carbonController = carbonController ?? MyVibeIslandAppKitCarbonHotKeyController(
            registerHotKey: registerHotKey,
            unregisterHotKey: unregisterHotKey
        )
        self.routeShortcutAction = routeShortcutAction
    }

    @discardableResult
    public func start() -> ShortcutCoordinatorLifecyclePlan {
        apply(.start)
    }

    @discardableResult
    public func stop() -> ShortcutCoordinatorLifecyclePlan {
        let plan = apply(.stop)
        carbonController.stop()
        return plan
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
        self.settings = settings
        return apply(.updateSettings(settings))
    }

    @discardableResult
    public func handleHotKey(_ hotKeyId: String) -> ShortcutDispatchPlan {
        guard carbonRefs.contains(where: { $0.id == hotKeyId }) else {
            return ShortcutDispatchPlan(
                action: .ignore,
                hotKeyId: hotKeyId,
                dispatchPolicy: .notRegistered
            )
        }

        let plan = coordinator.planDispatch(hotKeyId: hotKeyId, state: coordinatorState)
        if plan.action == .dispatchAction, let shortcutAction = plan.shortcutAction {
            routeShortcutAction(shortcutAction)
        }
        return plan
    }

    private func apply(_ command: ShortcutCoordinatorCommand) -> ShortcutCoordinatorLifecyclePlan {
        let plan = coordinator.plan(command, from: coordinatorState)
        coordinatorState = plan.nextState
        lastLifecyclePlan = plan

        switch plan.action {
        case .registerShortcuts:
            let carbonPlan = carbonController.register(plan.registrationPlan.registrations)
            lastCarbonRegistrationPlan = carbonPlan
        case .unregisterShortcuts:
            let carbonPlan = carbonController.unregister(ids: Set(plan.hotKeyIdsToUnregister))
            lastCarbonUnregistrationPlan = carbonPlan
        case .noChange:
            break
        }

        return plan
    }

    private var coordinator: ShortcutCoordinator {
        ShortcutCoordinator(settings: settings)
    }
}
