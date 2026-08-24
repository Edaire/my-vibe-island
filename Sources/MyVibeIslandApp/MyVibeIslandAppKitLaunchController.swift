public struct MyVibeIslandAppKitLaunchResult {
    public let runPlan: MyVibeIslandAppKitRunPlan
    public let executedIntents: [MyVibeIslandAppKitRunIntent]
    public let platformExecutionResult: MyVibeIslandAppKitPlatformIntentExecutionResult

    public init(
        runPlan: MyVibeIslandAppKitRunPlan,
        executedIntents: [MyVibeIslandAppKitRunIntent],
        platformExecutionResult: MyVibeIslandAppKitPlatformIntentExecutionResult
    ) {
        self.runPlan = runPlan
        self.executedIntents = executedIntents
        self.platformExecutionResult = platformExecutionResult
    }
}

public struct MyVibeIslandAppKitLaunchController {
    public let runner: MyVibeIslandAppKitRunner
    public let executor: MyVibeIslandAppKitRunExecutor
    public let platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor

    public init(
        runner: MyVibeIslandAppKitRunner = MyVibeIslandAppKitRunner(),
        executor: MyVibeIslandAppKitRunExecutor = MyVibeIslandAppKitRunExecutor(),
        platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor = MyVibeIslandAppKitPlatformIntentExecutor()
    ) {
        self.runner = runner
        self.executor = executor
        self.platformIntentExecutor = platformIntentExecutor
    }

    @MainActor
    public func launch() -> MyVibeIslandAppKitLaunchResult {
        let runPlan = runner.prepareRun(platformIntentExecutor: platformIntentExecutor)
        executor.execute(runPlan)
        return MyVibeIslandAppKitLaunchResult(
            runPlan: runPlan,
            executedIntents: runPlan.intents,
            platformExecutionResult: runPlan.delegate.lastPlatformExecutionResult
                ?? MyVibeIslandAppKitPlatformIntentExecutionResult(executedIntents: [])
        )
    }
}
