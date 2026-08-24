import AppKit
import CoreGraphics
import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitScreenSelectionController {
    public private(set) var snapshot: ScreenSelectionSnapshot
    public private(set) var lastPlan: ScreenSelectionPlan?
    public var onSnapshotChange: @MainActor (ScreenSelectionSnapshot) -> Void

    private let coordinator: ScreenSelectionCoordinator
    private let currentScreens: @MainActor () -> [ScreenDescriptor]
    private let applyTargetScreen: @MainActor (ScreenTarget) -> Void

    public init(
        snapshot: ScreenSelectionSnapshot = ScreenSelectionSnapshot(),
        coordinator: ScreenSelectionCoordinator = ScreenSelectionCoordinator(),
        currentScreens: (@MainActor () -> [ScreenDescriptor])? = nil,
        applyTargetScreen: @escaping @MainActor (ScreenTarget) -> Void = { _ in },
        onSnapshotChange: @escaping @MainActor (ScreenSelectionSnapshot) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.coordinator = coordinator
        self.currentScreens = currentScreens ?? appKitCurrentScreenDescriptors
        self.applyTargetScreen = applyTargetScreen
        self.onSnapshotChange = onSnapshotChange
    }

    @discardableResult
    public func refreshCurrentScreens() -> ScreenSelectionPlan {
        refreshScreens(currentScreens())
    }

    @discardableResult
    public func refreshScreens(_ screens: [ScreenDescriptor]) -> ScreenSelectionPlan {
        apply(.refreshScreens(screens))
    }

    @discardableResult
    public func selectMode(_ mode: AppScreenSelectionMode) -> ScreenSelectionPlan {
        apply(.selectMode(mode))
    }

    @discardableResult
    public func selectDisplay(_ identifier: String) -> ScreenSelectionPlan {
        apply(.selectDisplay(identifier))
    }

    @discardableResult
    public func focusDisplay(_ identifier: String) -> ScreenSelectionPlan {
        apply(.focusDisplay(identifier))
    }

    @discardableResult
    public func dismissSwitchTip() -> ScreenSelectionPlan {
        apply(.dismissSwitchTip)
    }

    private func apply(_ command: ScreenSelectionCommand) -> ScreenSelectionPlan {
        let plan = coordinator.plan(command, from: snapshot)
        snapshot = plan.nextSnapshot
        lastPlan = plan
        onSnapshotChange(snapshot)

        if plan.targetDidChange, let target = plan.nextSnapshot.target {
            applyTargetScreen(target)
        }

        return plan
    }
}

private extension ScreenDescriptor {
    init(screen: NSScreen) {
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        self.init(
            identifier: displayID.map(String.init) ?? screen.localizedName,
            displayName: screen.localizedName,
            isBuiltIn: displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false,
            hasNotch: screen.safeAreaInsets.top > 0,
            isMain: screen == NSScreen.main
        )
    }
}

private func appKitCurrentScreenDescriptors() -> [ScreenDescriptor] {
    NSScreen.screens.map(ScreenDescriptor.init(screen:))
}
