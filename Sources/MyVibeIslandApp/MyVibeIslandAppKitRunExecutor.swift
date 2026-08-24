import AppKit

public struct MyVibeIslandAppKitRunExecutor {
    public let setActivationPolicy: @MainActor (MyVibeIslandAppKitActivationPolicy) -> Void
    public let installDelegate: @MainActor (MyVibeIslandAppKitDelegate) -> Void
    public let runApplication: @MainActor () -> Void

    public init(
        setActivationPolicy: @escaping @MainActor (MyVibeIslandAppKitActivationPolicy) -> Void = { policy in
            NSApplication.shared.setActivationPolicy(nsApplicationActivationPolicy(for: policy))
        },
        installDelegate: @escaping @MainActor (MyVibeIslandAppKitDelegate) -> Void = { delegate in
            NSApplication.shared.delegate = delegate
        },
        runApplication: @escaping @MainActor () -> Void = {
            NSApplication.shared.run()
        }
    ) {
        self.setActivationPolicy = setActivationPolicy
        self.installDelegate = installDelegate
        self.runApplication = runApplication
    }

    @MainActor
    public func execute(_ plan: MyVibeIslandAppKitRunPlan) {
        for intent in plan.intents {
            switch intent {
            case let .setActivationPolicy(policy):
                setActivationPolicy(policy)
            case .installDelegate:
                installDelegate(plan.delegate)
            case .runApplication:
                runApplication()
            }
        }
    }
}

public func nsApplicationActivationPolicy(
    for policy: MyVibeIslandAppKitActivationPolicy
) -> NSApplication.ActivationPolicy {
    switch policy {
    case .accessory:
        return .accessory
    case .regular:
        return .regular
    case .prohibited:
        return .prohibited
    }
}
