import MyVibeIslandCore

public enum MyVibeIslandAppDelegateLifecycle: String, Equatable, Sendable {
    case notLaunched
    case launched
    case terminated
}

public enum MyVibeIslandAppDelegateEvent: Equatable, Sendable {
    case didFinishLaunching
    case willTerminate
}

public struct MyVibeIslandAppDelegateState: Equatable, Sendable {
    public let lifecycle: MyVibeIslandAppDelegateLifecycle
    public let launchPlan: AppShellPlatformLaunchPlan?
    public let coordinatorState: AppShellCoordinatorState?
    public let runtimeOwnerFailures: [AppRuntimeOwner: String]

    public init(
        lifecycle: MyVibeIslandAppDelegateLifecycle = .notLaunched,
        launchPlan: AppShellPlatformLaunchPlan? = nil,
        coordinatorState: AppShellCoordinatorState? = nil,
        runtimeOwnerFailures: [AppRuntimeOwner: String] = [:]
    ) {
        self.lifecycle = lifecycle
        self.launchPlan = launchPlan
        self.coordinatorState = coordinatorState
        self.runtimeOwnerFailures = runtimeOwnerFailures
    }
}

public struct MyVibeIslandAppDelegatePlan: Equatable, Sendable {
    public let nextState: MyVibeIslandAppDelegateState
    public let intents: [AppShellPlatformLaunchIntent]

    public init(
        nextState: MyVibeIslandAppDelegateState,
        intents: [AppShellPlatformLaunchIntent]
    ) {
        self.nextState = nextState
        self.intents = intents
    }
}

public struct MyVibeIslandAppDelegateBridge: Sendable {
    public let application: MyVibeIslandApplication
    public let coordinator: AppShellCoordinatorModel
    public let platformLaunchPlanner: AppShellPlatformLaunchPlanner

    public init(
        application: MyVibeIslandApplication = MyVibeIslandApplication(),
        coordinator: AppShellCoordinatorModel = AppShellCoordinatorModel(),
        platformLaunchPlanner: AppShellPlatformLaunchPlanner = AppShellPlatformLaunchPlanner()
    ) {
        self.application = application
        self.coordinator = coordinator
        self.platformLaunchPlanner = platformLaunchPlanner
    }

    public func handle(
        _ event: MyVibeIslandAppDelegateEvent,
        from state: MyVibeIslandAppDelegateState
    ) -> MyVibeIslandAppDelegatePlan {
        switch event {
        case .didFinishLaunching:
            guard state.lifecycle != .launched else {
                return MyVibeIslandAppDelegatePlan(nextState: state, intents: [])
            }
            let launchPlan = application.prepareLaunch()
            return MyVibeIslandAppDelegatePlan(
                nextState: MyVibeIslandAppDelegateState(
                    lifecycle: .launched,
                    launchPlan: launchPlan,
                    coordinatorState: launchPlan.launchPlan.coordinatorPlan.nextState,
                    runtimeOwnerFailures: [:]
                ),
                intents: launchPlan.intents
            )

        case .willTerminate:
            guard state.lifecycle == .launched,
                  let coordinatorState = state.coordinatorState
            else {
                return MyVibeIslandAppDelegatePlan(nextState: state, intents: [])
            }
            let coordinatorPlan = coordinator.apply(.willTerminate, from: coordinatorState)
            return MyVibeIslandAppDelegatePlan(
                nextState: MyVibeIslandAppDelegateState(
                    lifecycle: .terminated,
                    launchPlan: state.launchPlan,
                    coordinatorState: coordinatorPlan.nextState
                ),
                intents: platformLaunchPlanner.makeIntents(from: coordinatorPlan.actions)
            )
        }
    }

    public func applyingRuntimeOwnerResults(
        _ results: [MyVibeIslandAppKitRuntimeOwnerResult],
        from state: MyVibeIslandAppDelegateState
    ) -> MyVibeIslandAppDelegateState {
        guard var coordinatorState = state.coordinatorState else { return state }
        var failures = state.runtimeOwnerFailures

        for result in results {
            let owner: AppRuntimeOwner
            let isRunning: Bool
            switch result {
            case let .started(value):
                owner = value
                isRunning = true
                failures.removeValue(forKey: value)
            case let .failed(value, reason), let .unavailable(value, reason):
                owner = value
                isRunning = false
                failures[value] = reason
            case let .stopped(value):
                owner = value
                isRunning = false
                failures.removeValue(forKey: value)
            }
            coordinatorState = coordinator.applyCommands(
                [.runtimeOwnerObserved(owner, isRunning: isRunning)],
                from: coordinatorState
            ).nextState
        }

        return MyVibeIslandAppDelegateState(
            lifecycle: state.lifecycle,
            launchPlan: state.launchPlan,
            coordinatorState: coordinatorState,
            runtimeOwnerFailures: failures
        )
    }
}
