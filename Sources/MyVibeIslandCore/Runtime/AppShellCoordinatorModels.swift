public struct AppShellCoordinatorState: Codable, Equatable, Sendable {
    public let shellState: AppShellState
    public let lastIgnoredReason: AppShellIgnoredEventReason?

    public init(
        shellState: AppShellState = AppShellState(),
        lastIgnoredReason: AppShellIgnoredEventReason? = nil
    ) {
        self.shellState = shellState
        self.lastIgnoredReason = lastIgnoredReason
    }
}

public struct AppShellCoordinatorPlan: Equatable, Sendable {
    public let nextState: AppShellCoordinatorState
    public let commands: [AppShellCommand]
    public let actions: [AppShellAction]

    public init(
        nextState: AppShellCoordinatorState,
        commands: [AppShellCommand],
        actions: [AppShellAction]
    ) {
        self.nextState = nextState
        self.commands = commands
        self.actions = actions
    }
}

public struct AppShellCoordinatorModel: Sendable {
    public let eventRouter: AppShellEventRouter
    public let shellModel: AppShellModel

    public init(
        eventRouter: AppShellEventRouter = AppShellEventRouter(),
        shellModel: AppShellModel = AppShellModel()
    ) {
        self.eventRouter = eventRouter
        self.shellModel = shellModel
    }

    public func apply(
        _ event: AppShellPlatformEvent,
        from state: AppShellCoordinatorState
    ) -> AppShellCoordinatorPlan {
        let route = eventRouter.route(event)
        if let ignoredReason = route.ignoredReason {
            return AppShellCoordinatorPlan(
                nextState: AppShellCoordinatorState(
                    shellState: state.shellState,
                    lastIgnoredReason: ignoredReason
                ),
                commands: [],
                actions: []
            )
        }

        return applyCommands(route.commands, from: state)
    }

    public func applyCommands(
        _ commands: [AppShellCommand],
        from state: AppShellCoordinatorState
    ) -> AppShellCoordinatorPlan {
        var shellState = state.shellState
        var actions: [AppShellAction] = []

        for command in commands {
            let plan = shellModel.plan(command, from: shellState)
            shellState = plan.nextState
            actions.append(contentsOf: plan.actions)
        }

        return AppShellCoordinatorPlan(
            nextState: AppShellCoordinatorState(shellState: shellState),
            commands: commands,
            actions: actions
        )
    }
}
