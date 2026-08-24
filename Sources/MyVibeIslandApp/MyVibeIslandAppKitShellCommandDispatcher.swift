import MyVibeIslandCore

public struct MyVibeIslandAppKitShellCommandDispatchResult {
    public let coordinatorPlan: AppShellCoordinatorPlan
    public let platformExecutionResult: MyVibeIslandAppKitPlatformIntentExecutionResult

    public init(
        coordinatorPlan: AppShellCoordinatorPlan,
        platformExecutionResult: MyVibeIslandAppKitPlatformIntentExecutionResult
    ) {
        self.coordinatorPlan = coordinatorPlan
        self.platformExecutionResult = platformExecutionResult
    }
}

@MainActor
public final class MyVibeIslandAppKitShellCommandDispatcher {
    public private(set) var state: AppShellCoordinatorState
    public private(set) var lastDispatchResult: MyVibeIslandAppKitShellCommandDispatchResult?

    private let coordinator: AppShellCoordinatorModel
    private let platformLaunchPlanner: AppShellPlatformLaunchPlanner
    private let platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor
    private let screenSelectionController: MyVibeIslandAppKitScreenSelectionController?
    private let selectSession: @MainActor (String) -> Void
    private let jumpToSession: @MainActor (String) -> Void
    private let resolveAction: @MainActor (String, String) -> Void
    private let answerQuestion: @MainActor (String, String) -> Void
    private let submitActionResolution: @MainActor (ActionResolution) -> Void

    public init(
        initialState: AppShellCoordinatorState,
        coordinator: AppShellCoordinatorModel = AppShellCoordinatorModel(),
        platformLaunchPlanner: AppShellPlatformLaunchPlanner = AppShellPlatformLaunchPlanner(),
        screenSelectionController: MyVibeIslandAppKitScreenSelectionController? = nil,
        selectSession: @escaping @MainActor (String) -> Void = { _ in },
        jumpToSession: @escaping @MainActor (String) -> Void = { _ in },
        resolveAction: @escaping @MainActor (String, String) -> Void = { _, _ in },
        answerQuestion: @escaping @MainActor (String, String) -> Void = { _, _ in },
        submitActionResolution: @escaping @MainActor (ActionResolution) -> Void = { _ in },
        platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor
    ) {
        self.state = initialState
        self.coordinator = coordinator
        self.platformLaunchPlanner = platformLaunchPlanner
        self.screenSelectionController = screenSelectionController
        self.selectSession = selectSession
        self.jumpToSession = jumpToSession
        self.resolveAction = resolveAction
        self.answerQuestion = answerQuestion
        self.submitActionResolution = submitActionResolution
        self.platformIntentExecutor = platformIntentExecutor
    }

    public func dispatch(_ command: AppCommand) -> MyVibeIslandAppKitShellCommandDispatchResult {
        let coordinatorPlan = coordinator.apply(.menuCommand(command), from: state)
        state = coordinatorPlan.nextState
        applyScreenSelectionCommand(command, coordinatorPlan: coordinatorPlan)
        let platformExecutionResult = platformIntentExecutor.execute(
            platformLaunchPlanner.makeIntents(from: coordinatorPlan.actions)
        )
        let result = MyVibeIslandAppKitShellCommandDispatchResult(
            coordinatorPlan: coordinatorPlan,
            platformExecutionResult: platformExecutionResult
        )
        lastDispatchResult = result
        return result
    }

    public func dispatchOverlayAction(
        _ action: OverlayRoutedAction
    ) -> MyVibeIslandAppKitShellCommandDispatchResult {
        switch action {
        case .openSettings:
            return dispatch(.openSettings)
        case let .appCommand(command):
            return dispatch(command)
        case let .selectSession(sessionId):
            selectSession(sessionId)
            return ignoredOverlayActionResult()
        case let .jumpToSession(sessionId):
            jumpToSession(sessionId)
            return ignoredOverlayActionResult()
        case let .resolveAction(requestId, sessionId):
            resolveAction(requestId, sessionId)
            return ignoredOverlayActionResult()
        case let .answerQuestion(requestId, sessionId):
            answerQuestion(requestId, sessionId)
            return ignoredOverlayActionResult()
        case let .submitActionResolution(resolution):
            submitActionResolution(resolution)
            return ignoredOverlayActionResult()
        }
    }

    private func ignoredOverlayActionResult() -> MyVibeIslandAppKitShellCommandDispatchResult {
        let coordinatorPlan = AppShellCoordinatorPlan(
            nextState: state,
            commands: [],
            actions: []
        )
        let result = MyVibeIslandAppKitShellCommandDispatchResult(
            coordinatorPlan: coordinatorPlan,
            platformExecutionResult: platformIntentExecutor.execute([])
        )
        lastDispatchResult = result
        return result
    }

    private func applyScreenSelectionCommand(
        _ command: AppCommand,
        coordinatorPlan: AppShellCoordinatorPlan
    ) {
        guard let screenSelectionController,
              !coordinatorPlan.actions.contains(.ignoredMenuCommand(command))
        else {
            return
        }

        if case let .selectScreenMode(mode) = command {
            screenSelectionController.selectMode(mode)
        }
    }
}
