import AppKit

public enum MyVibeIslandAppKitActivationPolicy: String, Equatable, Sendable {
    case accessory
    case regular
    case prohibited
}

public enum MyVibeIslandAppKitRunIntent: Equatable, Sendable {
    case setActivationPolicy(MyVibeIslandAppKitActivationPolicy)
    case installDelegate
    case runApplication
}

public struct MyVibeIslandAppKitRunPlan {
    public let delegate: MyVibeIslandAppKitDelegate
    public let intents: [MyVibeIslandAppKitRunIntent]

    public init(
        delegate: MyVibeIslandAppKitDelegate,
        intents: [MyVibeIslandAppKitRunIntent]
    ) {
        self.delegate = delegate
        self.intents = intents
    }
}

public struct MyVibeIslandAppKitRunner: Sendable {
    public let application: MyVibeIslandApplication
    public let activationPolicy: MyVibeIslandAppKitActivationPolicy

    public init(
        application: MyVibeIslandApplication = MyVibeIslandApplication(),
        activationPolicy: MyVibeIslandAppKitActivationPolicy = .accessory
    ) {
        self.application = application
        self.activationPolicy = activationPolicy
    }

    @MainActor
    public func prepareRun(
        platformIntentExecutor: MyVibeIslandAppKitPlatformIntentExecutor = MyVibeIslandAppKitPlatformIntentExecutor()
    ) -> MyVibeIslandAppKitRunPlan {
        MyVibeIslandAppKitRunPlan(
            delegate: MyVibeIslandAppKitDelegate(
                bridge: MyVibeIslandAppDelegateBridge(application: application),
                executePlatformIntents: { intents in
                    platformIntentExecutor.execute(intents)
                }
            ),
            intents: runIntents()
        )
    }

    public func runIntents() -> [MyVibeIslandAppKitRunIntent] {
        [
            .setActivationPolicy(activationPolicy),
            .installDelegate,
            .runApplication
        ]
    }
}
