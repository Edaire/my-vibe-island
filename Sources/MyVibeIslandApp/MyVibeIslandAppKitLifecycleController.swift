import MyVibeIslandCore

public enum MyVibeIslandAppKitLifecycleAction: Equatable {
    case applyStep(AppLifecycleStep)
    case ignoreMenuCommand(AppCommand)
}

@MainActor
public final class MyVibeIslandAppKitLifecycleController {
    public private(set) var appliedSteps: [AppLifecycleStep] = []
    public private(set) var failedSteps: [AppLifecycleStep] = []
    public private(set) var ignoredMenuCommands: [AppCommand] = []
    public private(set) var lastAction: MyVibeIslandAppKitLifecycleAction?

    private let applyStep: @MainActor (AppLifecycleStep) -> Void
    private let ignoreMenuCommand: @MainActor (AppCommand) -> Void
    private let lifecycleStepExecutor: MyVibeIslandAppKitLifecycleStepExecutor?

    public init(
        applyStep: @escaping @MainActor (AppLifecycleStep) -> Void = { _ in },
        ignoreMenuCommand: @escaping @MainActor (AppCommand) -> Void = { _ in },
        lifecycleStepExecutor: MyVibeIslandAppKitLifecycleStepExecutor? = nil
    ) {
        self.applyStep = applyStep
        self.ignoreMenuCommand = ignoreMenuCommand
        self.lifecycleStepExecutor = lifecycleStepExecutor
    }

    @discardableResult
    public func apply(_ step: AppLifecycleStep) -> Bool {
        if let lifecycleStepExecutor {
            let wasAlreadyExecuted = lifecycleStepExecutor.executedSteps.contains(step)
            guard lifecycleStepExecutor.execute(step) else {
                failedSteps.append(step)
                return false
            }
            guard !wasAlreadyExecuted else { return true }
        }
        appliedSteps.append(step)
        lastAction = .applyStep(step)
        if lifecycleStepExecutor == nil {
            applyStep(step)
        }
        return true
    }

    public func ignore(_ command: AppCommand) {
        ignoredMenuCommands.append(command)
        lastAction = .ignoreMenuCommand(command)
        ignoreMenuCommand(command)
    }
}
