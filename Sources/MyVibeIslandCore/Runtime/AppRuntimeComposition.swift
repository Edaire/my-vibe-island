public enum AppRuntimeOwner: String, Codable, Equatable, Hashable, Sendable {
    case bridgeServer
    case sessionCoordinator
    case notchViewModel
    case overlayController
    case integrationCoordinator
    case actionRouter
    case terminalJumpRouter
    case notificationCoordinator
    case soundCoordinator
    case usageCoordinator
    case diagnosticsCoordinator
    case settingsStore
    case onboardingCoordinator
    case appMenuController
    case dockIconController
    case launchAtLoginService
    case updateCoordinator
    case screenSelectionCoordinator
    case whatsNewStore
}

public struct AppRuntimeOwnerState: Codable, Equatable, Sendable {
    public let owner: AppRuntimeOwner
    public let isEnabled: Bool
    public let isRunning: Bool

    public init(owner: AppRuntimeOwner, isEnabled: Bool = true, isRunning: Bool = false) {
        self.owner = owner
        self.isEnabled = isEnabled
        self.isRunning = isRunning
    }
}

public struct AppRuntimeCompositionSnapshot: Codable, Equatable, Sendable {
    public let owners: [AppRuntimeOwnerState]

    public init(owners: [AppRuntimeOwnerState] = []) {
        self.owners = owners
    }

    public static func defaultAppShell() -> AppRuntimeCompositionSnapshot {
        AppRuntimeCompositionSnapshot(owners: defaultOwnerOrder.map { AppRuntimeOwnerState(owner: $0) })
    }

    public func state(for owner: AppRuntimeOwner) -> AppRuntimeOwnerState? {
        owners.first { $0.owner == owner }
    }

    fileprivate func replacing(_ replacement: AppRuntimeOwnerState) -> AppRuntimeCompositionSnapshot {
        AppRuntimeCompositionSnapshot(owners: owners.map { state in
            state.owner == replacement.owner ? replacement : state
        })
    }

    private static let defaultOwnerOrder: [AppRuntimeOwner] = [
        .bridgeServer,
        .sessionCoordinator,
        .notchViewModel,
        .overlayController,
        .integrationCoordinator,
        .actionRouter,
        .terminalJumpRouter,
        .notificationCoordinator,
        .soundCoordinator,
        .usageCoordinator,
        .diagnosticsCoordinator,
        .settingsStore,
        .onboardingCoordinator,
        .appMenuController,
        .dockIconController,
        .launchAtLoginService,
        .updateCoordinator,
        .screenSelectionCoordinator,
        .whatsNewStore
    ]
}

public enum AppRuntimeOwnerActionKind: String, Codable, Equatable, Sendable {
    case start
    case stop
}

public struct AppRuntimeOwnerAction: Codable, Equatable, Sendable {
    public let owner: AppRuntimeOwner
    public let kind: AppRuntimeOwnerActionKind

    public init(owner: AppRuntimeOwner, kind: AppRuntimeOwnerActionKind) {
        self.owner = owner
        self.kind = kind
    }
}

public enum AppRuntimeCompositionCommand: Equatable, Sendable {
    case startAll
    case stopAll
    case markRunning(AppRuntimeOwner)
    case markStopped(AppRuntimeOwner)
    case enable(AppRuntimeOwner)
    case disable(AppRuntimeOwner)
}

public struct AppRuntimeCompositionPlan: Equatable, Sendable {
    public let nextSnapshot: AppRuntimeCompositionSnapshot
    public let actions: [AppRuntimeOwnerAction]

    public init(nextSnapshot: AppRuntimeCompositionSnapshot, actions: [AppRuntimeOwnerAction]) {
        self.nextSnapshot = nextSnapshot
        self.actions = actions
    }
}

public struct AppRuntimeComposition: Sendable {
    public init() {}

    public func plan(
        _ command: AppRuntimeCompositionCommand,
        from snapshot: AppRuntimeCompositionSnapshot
    ) -> AppRuntimeCompositionPlan {
        switch command {
        case .startAll:
            let actions = snapshot.owners
                .filter { $0.isEnabled && !$0.isRunning }
                .map { AppRuntimeOwnerAction(owner: $0.owner, kind: .start) }
            return AppRuntimeCompositionPlan(
                nextSnapshot: snapshot,
                actions: actions
            )

        case .stopAll:
            let actions = snapshot.owners
                .filter(\.isRunning)
                .reversed()
                .map { AppRuntimeOwnerAction(owner: $0.owner, kind: .stop) }
            return AppRuntimeCompositionPlan(
                nextSnapshot: snapshot,
                actions: actions
            )

        case let .markRunning(owner):
            guard let state = snapshot.state(for: owner), state.isEnabled else {
                return AppRuntimeCompositionPlan(nextSnapshot: snapshot, actions: [])
            }
            return AppRuntimeCompositionPlan(
                nextSnapshot: snapshot.replacing(
                    AppRuntimeOwnerState(owner: owner, isEnabled: true, isRunning: true)
                ),
                actions: []
            )

        case let .markStopped(owner):
            guard let state = snapshot.state(for: owner) else {
                return AppRuntimeCompositionPlan(nextSnapshot: snapshot, actions: [])
            }
            return AppRuntimeCompositionPlan(
                nextSnapshot: snapshot.replacing(
                    AppRuntimeOwnerState(owner: owner, isEnabled: state.isEnabled, isRunning: false)
                ),
                actions: []
            )

        case let .enable(owner):
            guard let state = snapshot.state(for: owner), !state.isEnabled else {
                return AppRuntimeCompositionPlan(nextSnapshot: snapshot, actions: [])
            }
            return AppRuntimeCompositionPlan(
                nextSnapshot: snapshot.replacing(
                    AppRuntimeOwnerState(owner: owner, isEnabled: true, isRunning: state.isRunning)
                ),
                actions: []
            )

        case let .disable(owner):
            guard let state = snapshot.state(for: owner), state.isEnabled || state.isRunning else {
                return AppRuntimeCompositionPlan(nextSnapshot: snapshot, actions: [])
            }
            let action = state.isRunning ? [AppRuntimeOwnerAction(owner: owner, kind: .stop)] : []
            return AppRuntimeCompositionPlan(
                nextSnapshot: snapshot.replacing(
                    AppRuntimeOwnerState(owner: owner, isEnabled: false, isRunning: state.isRunning)
                ),
                actions: action
            )
        }
    }
}
