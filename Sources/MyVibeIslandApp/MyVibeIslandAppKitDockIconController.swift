import AppKit
import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitDockIconController {
    public private(set) var state: DockIconControllerState
    public private(set) var lastPlan: DockIconControllerPlan?

    private let controller: DockIconController
    private let applyActivationPolicy: @MainActor (MyVibeIslandAppKitActivationPolicy) -> Void

    public init(
        state: DockIconControllerState = DockIconControllerState(),
        controller: DockIconController = DockIconController(),
        applyActivationPolicy: @escaping @MainActor (MyVibeIslandAppKitActivationPolicy) -> Void = { policy in
            NSApplication.shared.setActivationPolicy(nsApplicationActivationPolicy(for: policy))
        }
    ) {
        self.state = state
        self.controller = controller
        self.applyActivationPolicy = applyActivationPolicy
    }

    @discardableResult
    public func setVisible(_ isVisible: Bool) -> DockIconControllerPlan {
        let plan = controller.plan(
            .setPreferredDockVisible(isVisible, reason: .userPreference),
            from: state
        )
        state = plan.nextState
        lastPlan = plan

        switch plan.action {
        case .setRegularPolicy:
            applyActivationPolicy(.regular)
        case .setAccessoryPolicy:
            applyActivationPolicy(.accessory)
        case .noChange:
            break
        }

        return plan
    }
}
