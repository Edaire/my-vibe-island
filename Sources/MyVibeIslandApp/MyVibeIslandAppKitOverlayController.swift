import AppKit
import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitOverlayController {
    public private(set) var lastPresentation: NotchPresentationState?
    public private(set) var lastIslandSurfaceDescriptor: MyVibeIslandAppKitIslandSurfaceDescriptor?
    public private(set) var lastIslandSurfaceView: NSView?
    public private(set) var lastDisplayReason: DisplayIntentReason?
    public private(set) var lastRoutedAction: OverlayRoutedAction?
    public private(set) var lastAppliedFrame: DisplayFrame?
    public private(set) var lastShownPanelState: PanelDisplayState?
    public private(set) var lastHiddenPanelReason: DisplayIntentReason?
    public private(set) var lastForwardedInteractionAction: PanelInteractionAction?
    public private(set) var currentPanelDisplayState: PanelDisplayState = .closed
    public private(set) var keyboardFocusRequested = false
    public private(set) var pendingHoverReveal: MyVibeIslandAppKitPanelInteractionTimerIntent?
    public private(set) var pendingAutoCollapse: MyVibeIslandAppKitPanelInteractionTimerIntent?

    private let renderPresentation: @MainActor (NotchPresentationState) -> Void
    private let renderIslandSurfaceDescriptor: @MainActor (MyVibeIslandAppKitIslandSurfaceDescriptor) -> Void
    private let buildOriginalIslandSurfaceView: (@MainActor (IslandSurfaceRenderList) -> NSView?)?
    private let buildIslandSurfaceView: @MainActor (MyVibeIslandAppKitIslandSurfaceDescriptor) -> NSView
    private let renderIslandSurfaceView: @MainActor (NSView) -> Void
    private let applyFrame: @MainActor (DisplayFrame) -> Void
    private let showPanel: @MainActor (PanelDisplayState) -> Void
    private let hidePanel: @MainActor (DisplayIntentReason) -> Void
    private let forwardInteractionAction: @MainActor (PanelInteractionAction) -> Void
    private let routeAction: @MainActor (OverlayRoutedAction) -> Void
    private let recordDisplayReason: @MainActor (DisplayIntentReason) -> Void

    public init(
        renderPresentation: @escaping @MainActor (NotchPresentationState) -> Void = { _ in },
        renderIslandSurface: @escaping @MainActor (MyVibeIslandAppKitIslandSurfaceDescriptor) -> Void = { _ in },
        buildOriginalIslandSurfaceView: (@MainActor (IslandSurfaceRenderList) -> NSView?)? = nil,
        buildIslandSurfaceView: @escaping @MainActor (MyVibeIslandAppKitIslandSurfaceDescriptor) -> NSView = {
            MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: $0)
        },
        renderIslandSurfaceView: @escaping @MainActor (NSView) -> Void = { _ in },
        applyFrame: @escaping @MainActor (DisplayFrame) -> Void = { _ in },
        showPanel: @escaping @MainActor (PanelDisplayState) -> Void = { _ in },
        hidePanel: @escaping @MainActor (DisplayIntentReason) -> Void = { _ in },
        forwardInteractionAction: @escaping @MainActor (PanelInteractionAction) -> Void = { _ in },
        routeAction: @escaping @MainActor (OverlayRoutedAction) -> Void = { _ in },
        recordDisplayReason: @escaping @MainActor (DisplayIntentReason) -> Void = { _ in }
    ) {
        self.renderPresentation = renderPresentation
        self.renderIslandSurfaceDescriptor = renderIslandSurface
        self.buildOriginalIslandSurfaceView = buildOriginalIslandSurfaceView
        self.buildIslandSurfaceView = buildIslandSurfaceView
        self.renderIslandSurfaceView = renderIslandSurfaceView
        self.applyFrame = applyFrame
        self.showPanel = showPanel
        self.hidePanel = hidePanel
        self.forwardInteractionAction = forwardInteractionAction
        self.routeAction = routeAction
        self.recordDisplayReason = recordDisplayReason
    }

    public func renderIslandSurface(_ renderList: IslandSurfaceRenderList) {
        let originalView = buildOriginalIslandSurfaceView?(renderList)
        let descriptor = MyVibeIslandAppKitIslandSurfaceAdapter()
            .makeSurfaceDescriptor(from: renderList)
        lastIslandSurfaceDescriptor = descriptor
        renderIslandSurfaceDescriptor(descriptor)
        guard originalView != nil || !renderList.items.contains(where: { $0.section == .actionRequests }) else {
            return
        }
        let view = originalView ?? buildIslandSurfaceView(descriptor)
        lastIslandSurfaceView = view
        renderIslandSurfaceView(view)
    }

    public func apply(_ action: OverlayControllerAction) {
        switch action {
        case let .renderPresentation(presentation):
            lastPresentation = presentation
            renderPresentation(presentation)
        case let .renderIslandSurface(renderList):
            renderIslandSurface(renderList)
        case let .applyPanelPlan(actions):
            applyPanelPlan(actions)
        case let .routeAction(action):
            lastRoutedAction = action
            routeAction(action)
        case let .recordDisplayReason(reason):
            lastDisplayReason = reason
            recordDisplayReason(reason)
        }
    }

    private func applyPanelPlan(_ actions: [OverlayPanelAction]) {
        for action in actions {
            switch action {
            case let .applyFrame(frame):
                lastAppliedFrame = frame
                applyFrame(frame)
            case let .showPanel(displayState):
                lastShownPanelState = displayState
                currentPanelDisplayState = displayState
                showPanel(displayState)
            case let .hidePanel(reason):
                lastHiddenPanelReason = reason
                currentPanelDisplayState = .closed
                resetInteractionIntentState()
                hidePanel(reason)
            case let .forwardInteractionAction(action):
                lastForwardedInteractionAction = action
                applyForwardedInteractionState(action)
                forwardInteractionAction(action)
            case let .recordDisplayReason(reason):
                lastDisplayReason = reason
                recordDisplayReason(reason)
            }
        }
    }

    private func resetInteractionIntentState() {
        lastForwardedInteractionAction = nil
        keyboardFocusRequested = false
        pendingHoverReveal = nil
        pendingAutoCollapse = nil
        currentPanelDisplayState = .closed
    }

    private func applyForwardedInteractionState(_ action: PanelInteractionAction) {
        switch action {
        case let .setDisplayState(displayState):
            currentPanelDisplayState = displayState
        case .collapsePanel:
            currentPanelDisplayState = .closed
        case .requestKeyboardFocus:
            keyboardFocusRequested = true
        case .releaseKeyboardFocus:
            keyboardFocusRequested = false
        case let .scheduleHoverReveal(delay, generation):
            pendingHoverReveal = MyVibeIslandAppKitPanelInteractionTimerIntent(
                delay: delay,
                generation: generation
            )
        case .cancelHoverReveal:
            pendingHoverReveal = nil
        case let .scheduleAutoCollapse(delay, generation):
            pendingAutoCollapse = MyVibeIslandAppKitPanelInteractionTimerIntent(
                delay: delay,
                generation: generation
            )
        case .cancelAutoCollapse:
            pendingAutoCollapse = nil
        case .cancelMouseLeaveCollapse, .scheduleMouseLeaveCollapse:
            break
        }
    }
}
