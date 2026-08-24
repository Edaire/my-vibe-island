import Foundation
import MyVibeIslandCore

public struct MyVibeIslandCommandLine {
    public let application: MyVibeIslandApplication
    public let coreCLI: AppCLI
    public let modeResolver: AppExecutableModeResolver
    public let launchModeResolver: MyVibeIslandLaunchModeResolver
    public let appKitRunner: MyVibeIslandAppKitRunner
    public let appKitLauncher: @MainActor () -> MyVibeIslandAppKitLaunchResult

    public init(
        application: MyVibeIslandApplication? = nil,
        coreCLI: AppCLI = AppCLI(),
        modeResolver: AppExecutableModeResolver = AppExecutableModeResolver(),
        launchModeResolver: MyVibeIslandLaunchModeResolver = MyVibeIslandLaunchModeResolver(),
        appKitRunner: MyVibeIslandAppKitRunner? = nil,
        appKitLauncher: (@MainActor () -> MyVibeIslandAppKitLaunchResult)? = nil
    ) {
        let resolvedApplication = application ?? MyVibeIslandApplication()
        let resolvedRunner = appKitRunner ?? MyVibeIslandAppKitRunner(application: resolvedApplication)
        self.application = resolvedApplication
        self.coreCLI = coreCLI
        self.modeResolver = modeResolver
        self.launchModeResolver = launchModeResolver
        self.appKitRunner = resolvedRunner
        self.appKitLauncher = appKitLauncher ?? {
            let composition = MyVibeIslandAppKitPlatformComposition.production()
            let launchRunner = application == nil
                ? MyVibeIslandAppKitRunner(application: .production(defaults: .standard))
                : resolvedRunner
            return MyVibeIslandAppKitLaunchController(
                runner: launchRunner,
                platformIntentExecutor: composition.platformIntentExecutor
            ).launch()
        }
    }

    @MainActor
    public func run(arguments: [String]) throws -> String {
        let resolution = modeResolver.resolve(arguments: arguments)
        guard resolution.mode == .appShell else {
            return try coreCLI.run(arguments: arguments)
        }

        let launchResolution = launchModeResolver.resolve(arguments: resolution.remainingArguments)
        return appShellOutput(
            mode: launchResolution.mode,
            arguments: launchResolution.remainingArguments
        )
    }

    @MainActor
    private func appShellOutput(
        mode: MyVibeIslandLaunchMode,
        arguments: [String]
    ) -> String {
        let plan = application.prepareLaunch()
        let appKitLaunchResult = mode == .appKit ? appKitLauncher() : nil
        let launchSummary = plan.launchPlan.summary
        let platformSummary = plan.summary
        var lines = [
            "My Vibe Island app shell",
            "launch plan: dry run",
            "launch mode: \(mode.rawValue)",
            "target: \(launchSummary.targetDisplayName)",
            "route: \(launchSummary.route.rawValue)",
            "runtime starts: \(launchSummary.runtimeOwnerStartCount)",
            "actions: \(launchSummary.actionCount)",
            "status menu entries: \(launchSummary.statusItemMenuEntryCount)",
            "closed frame: \(displayFrameOutput(launchSummary.closedFrame))",
            "platform intents: \(platformSummary.intentCount)",
            "lifecycle intents: \(platformSummary.lifecycleIntentCount)",
            "runtime start intents: \(platformSummary.runtimeStartIntentCount)",
            "notch window intents: \(platformSummary.notchWindowIntentCount)",
            "route intents: \(platformSummary.routeIntentCount)",
            "platform intent plan: \(platformSummary.intentGroupDescription)",
            "platform launch: \(platformLaunchOutput(for: mode, result: appKitLaunchResult))",
        ]
        if !arguments.isEmpty {
            lines.append("arguments: \(arguments.joined(separator: " "))")
        }
        if let appKitLaunchResult {
            lines.append("appkit runner intents: \(appKitRunner.runIntents().count)")
            lines.append("appkit executed intents: \(appKitLaunchResult.executedIntents.count)")
            lines.append("appkit executed platform intents: \(appKitLaunchResult.platformExecutionResult.executedIntents.count)")
        }
        return lines.joined(separator: "\n")
    }

    private func platformLaunchOutput(
        for mode: MyVibeIslandLaunchMode,
        result: MyVibeIslandAppKitLaunchResult?
    ) -> String {
        switch mode {
        case .dryRun:
            return "skipped (dry run)"
        case .appKit:
            return result == nil ? "appkit requested" : "executed"
        }
    }

    private func displayFrameOutput(_ frame: DisplayFrame) -> String {
        "\(numberOutput(frame.x)),\(numberOutput(frame.y)) \(numberOutput(frame.width))x\(numberOutput(frame.height))"
    }

    private func numberOutput(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }
}
