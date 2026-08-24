public enum AppLifecycleRoute: String, Codable, Equatable, Sendable {
    case none
    case island
    case settings
    case onboarding
}

public enum AppLifecycleStep: String, Codable, Equatable, Sendable {
    case createRuntime
    case loadSettings
    case configureDockPolicy
    case createScreenSelection
    case createIslandWindow
    case startBridge
    case startRuntimeCoordinators
    case runOnboardingDecision
    case attachUpdateDriver
    case scheduleHealthChecks
    case showSettingsWindow
    case showOnboarding
    case showIsland
    case persistSettingsAndSessions
    case unregisterShortcuts
    case closeWindows
    case stopBridge
    case flushDiagnostics
}

public struct AppLaunchContext: Codable, Equatable, Sendable {
    public let isFirstLaunch: Bool
    public let hasPendingOnboarding: Bool
    public let hasPendingUpdateNotes: Bool

    public init(
        isFirstLaunch: Bool = false,
        hasPendingOnboarding: Bool = false,
        hasPendingUpdateNotes: Bool = false
    ) {
        self.isFirstLaunch = isFirstLaunch
        self.hasPendingOnboarding = hasPendingOnboarding
        self.hasPendingUpdateNotes = hasPendingUpdateNotes
    }
}

public enum AppReopenTarget: Equatable, Sendable {
    case defaultRoute
    case island
    case settings(SettingsDeepLink?)
    case onboarding
}

public enum AppLifecycleCommand: Equatable, Sendable {
    case launch(context: AppLaunchContext)
    case reopen(target: AppReopenTarget)
    case terminate
}

public struct AppLifecycleState: Codable, Equatable, Sendable {
    public let hasLaunched: Bool
    public let route: AppLifecycleRoute
    public let pendingSettingsDeepLink: SettingsDeepLink?
    public let completedStartupSteps: [AppLifecycleStep]
    public let completedTerminationSteps: [AppLifecycleStep]
    public let isTerminated: Bool

    public init(
        hasLaunched: Bool = false,
        route: AppLifecycleRoute = .none,
        pendingSettingsDeepLink: SettingsDeepLink? = nil,
        completedStartupSteps: [AppLifecycleStep] = [],
        completedTerminationSteps: [AppLifecycleStep] = [],
        isTerminated: Bool = false
    ) {
        self.hasLaunched = hasLaunched
        self.route = route
        self.pendingSettingsDeepLink = pendingSettingsDeepLink
        self.completedStartupSteps = completedStartupSteps
        self.completedTerminationSteps = completedTerminationSteps
        self.isTerminated = isTerminated
    }
}

public struct AppLifecyclePlan: Equatable, Sendable {
    public let nextState: AppLifecycleState
    public let steps: [AppLifecycleStep]

    public init(nextState: AppLifecycleState, steps: [AppLifecycleStep]) {
        self.nextState = nextState
        self.steps = steps
    }
}

public struct AppLifecycleCoordinator: Sendable {
    public init() {}

    public func plan(_ command: AppLifecycleCommand, from state: AppLifecycleState) -> AppLifecyclePlan {
        switch command {
        case let .launch(context):
            guard !state.hasLaunched else {
                return AppLifecyclePlan(nextState: state, steps: [])
            }

            let steps = Self.startupSteps
            return AppLifecyclePlan(
                nextState: AppLifecycleState(
                    hasLaunched: true,
                    route: Self.initialRoute(for: context),
                    completedStartupSteps: steps
                ),
                steps: steps
            )

        case let .reopen(target):
            switch target {
            case .defaultRoute, .island:
                return AppLifecyclePlan(
                    nextState: AppLifecycleState(
                        hasLaunched: state.hasLaunched,
                        route: .island,
                        completedStartupSteps: state.completedStartupSteps,
                        completedTerminationSteps: state.completedTerminationSteps,
                        isTerminated: state.isTerminated
                    ),
                    steps: [.showIsland]
                )
            case let .settings(deepLink):
                return AppLifecyclePlan(
                    nextState: AppLifecycleState(
                        hasLaunched: state.hasLaunched,
                        route: .settings,
                        pendingSettingsDeepLink: deepLink,
                        completedStartupSteps: state.completedStartupSteps,
                        completedTerminationSteps: state.completedTerminationSteps,
                        isTerminated: state.isTerminated
                    ),
                    steps: [.showSettingsWindow]
                )
            case .onboarding:
                return AppLifecyclePlan(
                    nextState: AppLifecycleState(
                        hasLaunched: state.hasLaunched,
                        route: .onboarding,
                        completedStartupSteps: state.completedStartupSteps,
                        completedTerminationSteps: state.completedTerminationSteps,
                        isTerminated: state.isTerminated
                    ),
                    steps: [.showOnboarding]
                )
            }

        case .terminate:
            guard !state.isTerminated else {
                return AppLifecyclePlan(nextState: state, steps: [])
            }

            let steps = Self.terminationSteps
            return AppLifecyclePlan(
                nextState: AppLifecycleState(
                    hasLaunched: state.hasLaunched,
                    route: .none,
                    completedStartupSteps: state.completedStartupSteps,
                    completedTerminationSteps: steps,
                    isTerminated: true
                ),
                steps: steps
            )
        }
    }

    private static let startupSteps: [AppLifecycleStep] = [
        .createRuntime,
        .loadSettings,
        .configureDockPolicy,
        .createScreenSelection,
        .createIslandWindow,
        .startBridge,
        .startRuntimeCoordinators,
        .runOnboardingDecision,
        .attachUpdateDriver,
        .scheduleHealthChecks
    ]

    private static let terminationSteps: [AppLifecycleStep] = [
        .persistSettingsAndSessions,
        .unregisterShortcuts,
        .closeWindows,
        .stopBridge,
        .flushDiagnostics
    ]

    private static func initialRoute(for context: AppLaunchContext) -> AppLifecycleRoute {
        if context.isFirstLaunch || context.hasPendingOnboarding {
            return .onboarding
        }
        return .island
    }
}
