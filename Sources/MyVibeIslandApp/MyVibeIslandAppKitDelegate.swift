import AppKit
import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitDelegate: NSObject, NSApplicationDelegate {
    public let bridge: MyVibeIslandAppDelegateBridge
    public private(set) var state: MyVibeIslandAppDelegateState
    public private(set) var lastPlan: MyVibeIslandAppDelegatePlan?
    public private(set) var lastPlatformExecutionResult: MyVibeIslandAppKitPlatformIntentExecutionResult?

    private let executePlatformIntents: @MainActor ([AppShellPlatformLaunchIntent]) -> MyVibeIslandAppKitPlatformIntentExecutionResult

    public init(
        bridge: MyVibeIslandAppDelegateBridge = MyVibeIslandAppDelegateBridge(),
        state: MyVibeIslandAppDelegateState = MyVibeIslandAppDelegateState(),
        executePlatformIntents: @escaping @MainActor ([AppShellPlatformLaunchIntent]) -> MyVibeIslandAppKitPlatformIntentExecutionResult = {
            MyVibeIslandAppKitPlatformIntentExecutionResult(executedIntents: $0)
        }
    ) {
        self.bridge = bridge
        self.state = state
        self.executePlatformIntents = executePlatformIntents
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        apply(.didFinishLaunching)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        apply(.willTerminate)
    }

    private func apply(_ event: MyVibeIslandAppDelegateEvent) {
        let plan = bridge.handle(event, from: state)
        state = plan.nextState
        lastPlan = plan
        if !plan.intents.isEmpty {
            let result = executePlatformIntents(plan.intents)
            state = bridge.applyingRuntimeOwnerResults(result.runtimeOwnerResults, from: state)
            lastPlatformExecutionResult = result
        }
    }
}
