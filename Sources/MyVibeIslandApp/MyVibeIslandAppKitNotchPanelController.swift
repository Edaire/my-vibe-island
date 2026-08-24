import AppKit
import MyVibeIslandCore

private let originalWindowFrameMinimumSizeDelta = 5.0
private let originalWindowFrameUpdateDelay = 0.05

public final class MyVibeIslandAppKitNotchPanel: NSPanel {
    public override var canBecomeKey: Bool { true }

    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

@MainActor
public protocol MyVibeIslandAppKitNotchPanelControlling: AnyObject {
    var activeInteractionFrame: DisplayFrame? { get }
    func createPanel()
    func installMonitors()
    func removeMonitors()
    func applyTargetScreen(_ identifier: String)
    func applyPlacement(_ placement: DisplayPlacementPlan)
    func applyInteractionGeometry(_ geometry: MyVibeIslandAppKitPanelInteractionGeometry)
    func clearInteractionGeometry()
    func applyFrame(_ frame: DisplayFrame)
    func installContentView(_ view: NSView)
    func processExpandedContentHover(_ isInside: Bool)
    func applyInteractionAction(_ action: PanelInteractionAction)
    func setIdleHidden(_ isHidden: Bool)
    func show()
    func hide()
    func close()
}

public struct MyVibeIslandAppKitPanelInteractionGeometry: Equatable, Sendable {
    public static let menuBarHorizontalExpansion = 120.0
    public static let compactHoverOutset = 6.0

    public let compactFrame: DisplayFrame
    public let compactHoverFrame: DisplayFrame
    public let menuBarFrame: DisplayFrame
    /// The transparent AppKit host envelope. This is deliberately distinct
    /// from the visible expanded surface used for pointer classification.
    public let hostingFrame: DisplayFrame
    public let expandedFrame: DisplayFrame

    public init(
        compactFrame: DisplayFrame,
        menuBarFrame: DisplayFrame? = nil,
        hostingFrame: DisplayFrame? = nil,
        expandedFrame: DisplayFrame
    ) {
        self.compactFrame = compactFrame
        let resolvedMenuBarFrame = menuBarFrame ?? DisplayFrame(
            x: compactFrame.x - Self.menuBarHorizontalExpansion / 2,
            y: compactFrame.y,
            width: compactFrame.width + Self.menuBarHorizontalExpansion,
            height: compactFrame.height
        )
        compactHoverFrame = DisplayFrame(
            x: resolvedMenuBarFrame.x,
            y: compactFrame.y - Self.compactHoverOutset,
            width: resolvedMenuBarFrame.width,
            height: compactFrame.height + 2 * Self.compactHoverOutset
        )
        self.menuBarFrame = resolvedMenuBarFrame
        self.hostingFrame = hostingFrame ?? expandedFrame
        self.expandedFrame = expandedFrame
    }
}

public struct MyVibeIslandAppKitPanelInteractionTimerIntent: Equatable, Sendable {
    public let delay: Double
    public let generation: Int

    public init(delay: Double, generation: Int) {
        self.delay = delay
        self.generation = generation
    }
}

@MainActor
public final class MyVibeIslandAppKitNotchPanelController<Panel>: MyVibeIslandAppKitNotchPanelControlling {
    public private(set) var panel: Panel?
    public private(set) var targetScreenIdentifier: String?
    public private(set) var lastPlacement: DisplayPlacementPlan?
    public private(set) var interactionGeometry: MyVibeIslandAppKitPanelInteractionGeometry?
    public private(set) var lastFrame: DisplayFrame?
    public private(set) var lastContentView: NSView?
    public private(set) var lastInteractionAction: PanelInteractionAction?
    public private(set) var keyboardFocusRequested = false
    public private(set) var pendingHoverReveal: MyVibeIslandAppKitPanelInteractionTimerIntent?
    public private(set) var pendingAutoCollapse: MyVibeIslandAppKitPanelInteractionTimerIntent?
    public private(set) var pendingMouseLeaveCollapse: MyVibeIslandAppKitPanelInteractionTimerIntent?
    public private(set) var interactionDisplayState: PanelDisplayState = .closed
    public private(set) var lastCollapseReason: PanelCollapseReason?
    public private(set) var isVisible = false

    public var activeInteractionFrame: DisplayFrame? {
        guard interactionDisplayState == .switcher else { return nil }
        return interactionGeometry?.expandedFrame ?? lastPlacement?.expandedFrame
    }

    private let makePanel: @MainActor () -> Panel
    private let installEventMonitors: @MainActor () -> Void
    private let removeEventMonitors: @MainActor () -> Void
    private let startMouseMonitoring: @MainActor (@escaping @MainActor (DisplayPoint) -> Void) -> Void
    private let stopMouseMonitoring: @MainActor () -> Void
    private let currentMouseLocation: @MainActor () -> DisplayPoint
    private let setIgnoresMouseEvents: @MainActor (Panel, Bool) -> Void
    private let movePanel: @MainActor (Panel, DisplayFrame) -> Void
    private let installContentView: @MainActor (Panel, NSView) -> Void
    private let showPanel: @MainActor (Panel) -> Void
    private let hidePanel: @MainActor (Panel) -> Void
    private let closePanel: @MainActor (Panel) -> Void
    private let requestKeyboardFocus: @MainActor (Panel) -> Void
    private let releaseKeyboardFocus: @MainActor (Panel) -> Void
    private let performInteraction: @MainActor (PanelInteractionCommand) -> Void
    private var mouseInMenuBarZone = false
    private var mouseInCompactHover = false
    private var mouseInExpandedPanel = false
    private var lastMouseLocation: DisplayPoint?
    private var hoverRevealTask: Task<Void, Never>?
    private var autoCollapseTask: Task<Void, Never>?
    private var mouseLeaveCollapseTask: Task<Void, Never>?
    private var windowFrameUpdateTask: Task<Void, Never>?
    private var pendingWindowFrame: DisplayFrame?
    private var hoverRevealGeneration: Int?
    private var hoverRevealDeadline: Date?
    private var autoCollapseGeneration: Int?
    private var mouseLeaveCollapseGeneration: Int?
    private var mouseMonitoringInstalled = false
    private var idleAutoHideRequested = false
    private var panelHiddenTarget: Bool?

    public init(
        makePanel: @escaping @MainActor () -> Panel,
        installEventMonitors: @escaping @MainActor () -> Void,
        removeEventMonitors: @escaping @MainActor () -> Void,
        startMouseMonitoring: @escaping @MainActor (@escaping @MainActor (DisplayPoint) -> Void) -> Void = { _ in },
        stopMouseMonitoring: @escaping @MainActor () -> Void = {},
        currentMouseLocation: @escaping @MainActor () -> DisplayPoint = {
            let point = NSEvent.mouseLocation
            return DisplayPoint(x: point.x, y: point.y)
        },
        setIgnoresMouseEvents: @escaping @MainActor (Panel, Bool) -> Void = { _, _ in },
        movePanel: @escaping @MainActor (Panel, DisplayFrame) -> Void,
        installContentView: @escaping @MainActor (Panel, NSView) -> Void,
        showPanel: @escaping @MainActor (Panel) -> Void,
        hidePanel: @escaping @MainActor (Panel) -> Void,
        closePanel: @escaping @MainActor (Panel) -> Void,
        requestKeyboardFocus: @escaping @MainActor (Panel) -> Void = { _ in },
        releaseKeyboardFocus: @escaping @MainActor (Panel) -> Void = { _ in },
        performInteraction: @escaping @MainActor (PanelInteractionCommand) -> Void = { _ in }
    ) {
        self.makePanel = makePanel
        self.installEventMonitors = installEventMonitors
        self.removeEventMonitors = removeEventMonitors
        self.startMouseMonitoring = startMouseMonitoring
        self.stopMouseMonitoring = stopMouseMonitoring
        self.currentMouseLocation = currentMouseLocation
        self.setIgnoresMouseEvents = setIgnoresMouseEvents
        self.movePanel = movePanel
        self.installContentView = installContentView
        self.showPanel = showPanel
        self.hidePanel = hidePanel
        self.closePanel = closePanel
        self.requestKeyboardFocus = requestKeyboardFocus
        self.releaseKeyboardFocus = releaseKeyboardFocus
        self.performInteraction = performInteraction
    }

    public func createPanel() {
        _ = currentPanel()
    }

    public func installMonitors() {
        installEventMonitors()
        ensureMouseMonitoring()
    }

    private func ensureMouseMonitoring() {
        guard !mouseMonitoringInstalled else { return }
        mouseMonitoringInstalled = true
        SessionCompletionTraceLog.append(
            stage: "hover.mouse_monitor_install",
            sessionId: nil,
            metadata: [:]
        )
        startMouseMonitoring { [weak self] point in
            self?.processMouseLocation(point)
        }
    }

    public func removeMonitors() {
        if mouseMonitoringInstalled {
            stopMouseMonitoring()
            mouseMonitoringInstalled = false
        }
        removeEventMonitors()
        cancelScheduledInteractionTasks()
    }

    public func applyTargetScreen(_ identifier: String) {
        targetScreenIdentifier = identifier
    }

    public func applyPlacement(_ placement: DisplayPlacementPlan) {
        lastPlacement = placement
        // A screen-parameter update must preserve the currently visible
        // branch. The original panel can receive placement updates while an
        // expanded render is on screen; forcing the compact frame here makes
        // the content and window geometry disagree until the next gesture.
        applyFrame(frame(for: interactionDisplayState, placement: placement))
        refreshMouseInteractivity()
    }

    private func frame(
        for displayState: PanelDisplayState,
        placement: DisplayPlacementPlan
    ) -> DisplayFrame {
        switch displayState {
        case .expanded, .notificationPeek, .switcher, .onboarding:
            return placement.expandedFrame
        case .closed, .opening, .hidden, .autoHidden:
            return placement.closedFrame
        }
    }

    public func applyInteractionGeometry(_ geometry: MyVibeIslandAppKitPanelInteractionGeometry) {
        interactionGeometry = geometry
        reclassifyCurrentPointer()
    }

    public func clearInteractionGeometry() {
        interactionGeometry = nil
        reclassifyCurrentPointer()
    }

    public func applyFrame(_ frame: DisplayFrame) {
        SessionCompletionTraceLog.append(
            stage: "panel.frame.request",
            sessionId: nil,
            metadata: [
                "requested": frameDescription(frame),
                "pending": frameDescription(pendingWindowFrame),
                "last": frameDescription(lastFrame),
                "displayState": String(describing: interactionDisplayState),
            ]
        )
        guard pendingWindowFrame != frame else { return }
        if lastFrame == frame {
            discardPendingWindowFrameUpdate()
            return
        }
        _ = currentPanel()
        pendingWindowFrame = frame
        windowFrameUpdateTask?.cancel()
        windowFrameUpdateTask = schedule(after: originalWindowFrameUpdateDelay) { [weak self] in
            self?.applyPendingWindowFrame(frame)
        }
    }

    private func applyPendingWindowFrame(_ frame: DisplayFrame) {
        guard pendingWindowFrame == frame else { return }
        pendingWindowFrame = nil
        windowFrameUpdateTask = nil

        if let lastFrame,
           abs(lastFrame.width - frame.width) <= originalWindowFrameMinimumSizeDelta,
           abs(lastFrame.height - frame.height) <= originalWindowFrameMinimumSizeDelta {
            return
        }
        lastFrame = frame
        SessionCompletionTraceLog.append(
            stage: "panel.frame.apply",
            sessionId: nil,
            metadata: [
                "requested": frameDescription(frame),
                "displayState": String(describing: interactionDisplayState),
            ]
        )
        movePanel(currentPanel(), frame)
        reclassifyCurrentPointer()
    }

    public func installContentView(_ view: NSView) {
        guard lastContentView !== view else { return }
        lastContentView = view
        let panel = currentPanel()
        installContentView(panel, view)
    }

    public func processMouseLocation(
        _ point: DisplayPoint,
        forceExpandedPanelHoverUpdate: Bool = false
    ) {
        lastMouseLocation = point
        guard let placement = lastPlacement else {
            return
        }

        switch interactionDisplayState {
        case .expanded, .notificationPeek, .switcher, .onboarding:
            let isInside = contains(
                point,
                in: interactionGeometry?.expandedFrame ?? placement.expandedFrame
            )
            setIgnoresMouseEvents(currentPanel(), !isInside)
            updateExpandedPanelHover(isInside, force: forceExpandedPanelHoverUpdate)
        case .closed, .opening, .hidden, .autoHidden:
            updateCompactHover(contains(
                point,
                in: interactionGeometry?.compactHoverFrame ?? placement.closedFrame
            ))
            updateMenuBarZone(contains(
                point,
                in: interactionGeometry?.menuBarFrame ?? placement.closedFrame
            ))
        }
        firePendingHoverRevealIfDue()
    }

    /// Receives the root SwiftUI view's direct hover lifecycle.
    public func processExpandedContentHover(_ isInside: Bool) {
        guard interactionDisplayState.acceptsDirectInteraction else {
            return
        }
        updateExpandedPanelHover(isInside)
    }

    public func applyInteractionAction(_ action: PanelInteractionAction) {
        lastInteractionAction = action
        SessionCompletionTraceLog.append(
            stage: "hover.interaction_action",
            sessionId: nil,
            metadata: [
                "action": String(describing: action),
                "displayState": String(describing: interactionDisplayState),
                "compactHover": String(mouseInCompactHover),
                "menuBar": String(mouseInMenuBarZone),
                "expanded": String(mouseInExpandedPanel),
                "expandedFrame": frameDescription(
                    interactionGeometry?.expandedFrame ?? lastPlacement?.expandedFrame
                ),
            ]
        )
        switch action {
        case .requestKeyboardFocus:
            keyboardFocusRequested = true
            if isVisible {
                requestKeyboardFocus(currentPanel())
            }
        case .releaseKeyboardFocus:
            releasePanelKeyboardFocus()
        case let .scheduleHoverReveal(delay, generation):
            hoverRevealGeneration = generation
            hoverRevealDeadline = Date().addingTimeInterval(max(0, delay))
            pendingHoverReveal = MyVibeIslandAppKitPanelInteractionTimerIntent(
                delay: delay,
                generation: generation
            )
            hoverRevealTask?.cancel()
            if delay <= 0 {
                fireHoverReveal(generation: generation)
                return
            }
            hoverRevealTask = schedule(after: delay) { [weak self] in
                self?.fireHoverReveal(generation: generation)
            }
        case .cancelHoverReveal:
            pendingHoverReveal = nil
            hoverRevealTask?.cancel()
            hoverRevealTask = nil
            hoverRevealGeneration = nil
            hoverRevealDeadline = nil
        case let .scheduleAutoCollapse(delay, generation):
            autoCollapseGeneration = generation
            pendingAutoCollapse = MyVibeIslandAppKitPanelInteractionTimerIntent(
                delay: delay,
                generation: generation
            )
            autoCollapseTask?.cancel()
            autoCollapseTask = schedule(after: delay) { [weak self] in
                self?.fireAutoCollapse(generation: generation)
            }
        case .cancelAutoCollapse:
            pendingAutoCollapse = nil
            autoCollapseTask?.cancel()
            autoCollapseTask = nil
            autoCollapseGeneration = nil
        case let .scheduleMouseLeaveCollapse(delay, generation):
            mouseLeaveCollapseGeneration = generation
            pendingMouseLeaveCollapse = MyVibeIslandAppKitPanelInteractionTimerIntent(
                delay: delay,
                generation: generation
            )
            mouseLeaveCollapseTask?.cancel()
            mouseLeaveCollapseTask = schedule(after: delay) { [weak self] in
                self?.fireMouseLeaveCollapse(generation: generation)
            }
        case .cancelMouseLeaveCollapse:
            pendingMouseLeaveCollapse = nil
            mouseLeaveCollapseTask?.cancel()
            mouseLeaveCollapseTask = nil
            mouseLeaveCollapseGeneration = nil
        case let .setDisplayState(displayState):
            interactionDisplayState = displayState
            reclassifyCurrentPointer(
                forceExpandedPanelHoverUpdate: displayState == .expanded && mouseInMenuBarZone
            )
        case let .collapsePanel(reason):
            releasePanelKeyboardFocus()
            interactionDisplayState = .closed
            setIgnoresMouseEvents(currentPanel(), true)
            lastCollapseReason = reason
        }
    }

    /// Mirrors the original `_isAutoHidden` observer: panel alpha changes
    /// without changing the Island's presentation or interaction state.
    public func setIdleHidden(_ isHidden: Bool) {
        idleAutoHideRequested = isHidden
        synchronizeIdleVisibilityTarget()
    }

    public func show() {
        ensureMouseMonitoring()
        guard !isVisible else { return }
        showPanel(currentPanel())
        isVisible = true
        reclassifyCurrentPointer()
    }

    public func hide() {
        let panel = currentPanel()
        releasePanelKeyboardFocus()
        hidePanel(panel)
        isVisible = false
        resetInteractionIntentState()
    }

    public func close() {
        guard let panel else {
            return
        }
        cancelPendingWindowFrameUpdate()
        releasePanelKeyboardFocus()
        closePanel(panel)
        self.panel = nil
        isVisible = false
        resetInteractionIntentState()
    }

    private func currentPanel() -> Panel {
        if let panel {
            return panel
        }
        let created = makePanel()
        panel = created
        return created
    }

    private func resetInteractionIntentState() {
        lastInteractionAction = nil
        keyboardFocusRequested = false
        cancelScheduledInteractionTasks()
        interactionDisplayState = .closed
        lastCollapseReason = nil
        mouseInMenuBarZone = false
        mouseInCompactHover = false
        mouseInExpandedPanel = false
        lastMouseLocation = nil
        if let panel {
            setIgnoresMouseEvents(panel, true)
        }
    }

    private func releasePanelKeyboardFocus() {
        keyboardFocusRequested = false
        if let panel {
            releaseKeyboardFocus(panel)
        }
    }

    private func cancelScheduledInteractionTasks() {
        pendingHoverReveal = nil
        pendingAutoCollapse = nil
        pendingMouseLeaveCollapse = nil
        hoverRevealTask?.cancel()
        hoverRevealTask = nil
        autoCollapseTask?.cancel()
        autoCollapseTask = nil
        mouseLeaveCollapseTask?.cancel()
        mouseLeaveCollapseTask = nil
    }

    private func cancelPendingWindowFrameUpdate() {
        discardPendingWindowFrameUpdate()
        hoverRevealGeneration = nil
        hoverRevealDeadline = nil
        autoCollapseGeneration = nil
        mouseLeaveCollapseGeneration = nil
    }

    private func discardPendingWindowFrameUpdate() {
        windowFrameUpdateTask?.cancel()
        windowFrameUpdateTask = nil
        pendingWindowFrame = nil
    }

    private func fireHoverReveal(generation: Int) {
        guard hoverRevealGeneration == generation else { return }
        pendingHoverReveal = nil
        hoverRevealTask = nil
        hoverRevealGeneration = nil
        hoverRevealDeadline = nil
        performInteraction(.hoverRevealTick(generation: generation))
    }

    private func firePendingHoverRevealIfDue() {
        guard let generation = hoverRevealGeneration,
              let deadline = hoverRevealDeadline,
              Date() >= deadline else {
            return
        }
        fireHoverReveal(generation: generation)
    }

    private func fireAutoCollapse(generation: Int) {
        SessionCompletionTraceLog.append(
            stage: "hover.auto_collapse_tick",
            sessionId: nil,
            metadata: [
                "generation": String(generation),
                "scheduledGeneration": String(describing: autoCollapseGeneration),
                "displayState": String(describing: interactionDisplayState),
                "expanded": String(mouseInExpandedPanel),
                "menuBar": String(mouseInMenuBarZone),
            ]
        )
        guard autoCollapseGeneration == generation else { return }
        pendingAutoCollapse = nil
        autoCollapseTask = nil
        autoCollapseGeneration = nil
        performInteraction(.autoCollapseTick(generation: generation))
    }

    private func fireMouseLeaveCollapse(generation: Int) {
        SessionCompletionTraceLog.append(
            stage: "hover.mouse_leave_collapse_tick",
            sessionId: nil,
            metadata: [
                "generation": String(generation),
                "scheduledGeneration": String(describing: mouseLeaveCollapseGeneration),
                "displayState": String(describing: interactionDisplayState),
                "expanded": String(mouseInExpandedPanel),
                "menuBar": String(mouseInMenuBarZone),
            ]
        )
        guard mouseLeaveCollapseGeneration == generation else { return }
        pendingMouseLeaveCollapse = nil
        mouseLeaveCollapseTask = nil
        mouseLeaveCollapseGeneration = nil
        performInteraction(.mouseLeaveCollapseTick(generation: generation))
    }

    private func updateCompactHover(_ isInside: Bool) {
        guard isInside != mouseInCompactHover else {
            return
        }
        mouseInCompactHover = isInside
        logCompactHoverBoundary(isInside)
        performInteraction(.setMenuBarHover(isInside))
    }

    private func updateMenuBarZone(_ isInside: Bool) {
        guard isInside != mouseInMenuBarZone else {
            return
        }
        mouseInMenuBarZone = isInside
        performInteraction(.setMouseInMenuBarZone(isInside))
        synchronizeIdleVisibilityTarget()
    }

    private func synchronizeIdleVisibilityTarget() {
        let targetHidden = idleAutoHideRequested && !mouseInMenuBarZone
        let previousTarget = panelHiddenTarget
        guard previousTarget != targetHidden else {
            return
        }
        panelHiddenTarget = targetHidden

        // The original target cache starts unknown. Establishing an initial
        // visible target does not replay a show/reclassification cycle.
        guard targetHidden || previousTarget == true else {
            return
        }
        let panel = currentPanel()
        if targetHidden {
            hidePanel(panel)
        } else {
            showPanel(panel)
            reclassifyCurrentPointer()
        }
    }

    private func updateExpandedPanelHover(_ isInside: Bool, force: Bool = false) {
        guard force || isInside != mouseInExpandedPanel else {
            return
        }
        mouseInExpandedPanel = isInside
        SessionCompletionTraceLog.append(
            stage: "hover.pointer_state",
            sessionId: nil,
            metadata: [
                "inside": String(isInside),
                "displayState": String(describing: interactionDisplayState),
                "point": frameDescription(lastMouseLocation.map { DisplayFrame(x: $0.x, y: $0.y, width: 0, height: 0) }),
                "interactiveFrame": frameDescription(
                    interactionGeometry?.expandedFrame ?? lastPlacement?.expandedFrame
                ),
                "menuBar": String(mouseInMenuBarZone),
            ]
        )
        performInteraction(.setExpandedPanelHover(isInside))
    }

    private func contains(_ point: DisplayPoint, in frame: DisplayFrame) -> Bool {
        point.x >= frame.x && point.x <= frame.x + frame.width
            && point.y >= frame.y && point.y <= frame.y + frame.height
    }

    private func logCompactHoverBoundary(_ isInside: Bool) {
        guard let point = lastMouseLocation,
              let placement = lastPlacement else {
            return
        }
        let geometry = interactionGeometry
        SessionCompletionTraceLog.append(
            stage: "hover.compact_boundary",
            sessionId: nil,
            metadata: [
                "inside": String(isInside),
                "point": "\(point.x),\(point.y)",
                "compact": frameDescription(geometry?.compactFrame ?? placement.closedFrame),
                "hover": frameDescription(geometry?.compactHoverFrame ?? placement.closedFrame),
                "menuBar": frameDescription(geometry?.menuBarFrame ?? placement.closedFrame),
                "expanded": frameDescription(geometry?.expandedFrame ?? placement.expandedFrame),
                "displayState": String(describing: interactionDisplayState),
            ]
        )
    }

    private func frameDescription(_ frame: DisplayFrame?) -> String {
        guard let frame else { return "-" }
        return "\(frame.x),\(frame.y),\(frame.width),\(frame.height)"
    }

    private func refreshMouseInteractivity() {
        guard interactionDisplayState.acceptsDirectInteraction,
              let point = lastMouseLocation,
              let frame = interactionGeometry?.expandedFrame ?? lastPlacement?.expandedFrame
        else {
            if let panel {
                setIgnoresMouseEvents(panel, true)
            }
            return
        }
        setIgnoresMouseEvents(currentPanel(), !contains(point, in: frame))
    }

    private func reclassifyCurrentPointer(forceExpandedPanelHoverUpdate: Bool = false) {
        processMouseLocation(
            currentMouseLocation(),
            forceExpandedPanelHoverUpdate: forceExpandedPanelHoverUpdate
        )
    }

    private func schedule(
        after delay: Double,
        action: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else {
                return
            }
            action()
        }
    }
}

@MainActor
private final class MyVibeIslandAppKitMouseMoveMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hasLoggedFirstEvent = false

    func start(_ handle: @escaping @MainActor (DisplayPoint) -> Void) {
        stop()
        SessionCompletionTraceLog.append(
            stage: "hover.mouse_monitor_start",
            sessionId: nil,
            metadata: ["events": "mouseMoved,leftMouseDragged"]
        )
        let forward: @MainActor (String) -> Void = { source in
            if !self.hasLoggedFirstEvent {
                self.hasLoggedFirstEvent = true
                SessionCompletionTraceLog.append(
                    stage: "hover.mouse_monitor_first_event",
                    sessionId: nil,
                    metadata: ["source": source]
                )
            }
            let point = NSEvent.mouseLocation
            handle(DisplayPoint(x: point.x, y: point.y))
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { _ in
            Task { @MainActor in forward("global") }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { event in
            forward("local")
            return event
        }
        SessionCompletionTraceLog.append(
            stage: "hover.mouse_monitor_registered",
            sessionId: nil,
            metadata: [
                "global": String(globalMonitor != nil),
                "local": String(localMonitor != nil),
            ]
        )
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}

public extension MyVibeIslandAppKitNotchPanelController where Panel == NSPanel {
    private static func applyOriginalPanelVisibilityFade(
        _ panel: NSPanel,
        targetAlpha: CGFloat,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunctionName,
        disablesMouseEventsBeforeAnimation: Bool
    ) {
        if disablesMouseEventsBeforeAnimation {
            panel.ignoresMouseEvents = true
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: timingFunction)
            panel.animator().alphaValue = targetAlpha
        }
    }

    static func pixelAlignedFrame(_ frame: DisplayFrame, scale: Double) -> DisplayFrame {
        let resolvedScale = max(scale, 1)
        func snap(_ value: Double) -> Double {
            (value * resolvedScale).rounded() / resolvedScale
        }
        return DisplayFrame(
            x: snap(frame.x),
            y: snap(frame.y),
            width: snap(frame.width),
            height: snap(frame.height)
        )
    }

    convenience init(
        performInteraction: @escaping @MainActor (PanelInteractionCommand) -> Void = { _ in }
    ) {
        let mouseMoveMonitor = MyVibeIslandAppKitMouseMoveMonitor()
        self.init(
            makePanel: {
                let panel = MyVibeIslandAppKitNotchPanel(
                    contentRect: NSRect(x: 0, y: 0, width: 220, height: 36),
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                panel.isFloatingPanel = true
                panel.level = NSWindow.Level(rawValue: 27)
                panel.hidesOnDeactivate = false
                panel.becomesKeyOnlyIfNeeded = true
                panel.collectionBehavior = [
                    .canJoinAllSpaces,
                    .stationary,
                    .ignoresCycle,
                    .fullScreenAuxiliary,
                ]
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = false
                panel.titleVisibility = .hidden
                panel.titlebarAppearsTransparent = true
                panel.allowsToolTipsWhenApplicationIsInactive = true
                panel.ignoresMouseEvents = true
                panel.acceptsMouseMovedEvents = false
                panel.isMovable = false
                panel.animationBehavior = .none
                panel.isReleasedWhenClosed = false
                return panel
            },
            installEventMonitors: {},
            removeEventMonitors: {},
            startMouseMonitoring: mouseMoveMonitor.start,
            stopMouseMonitoring: mouseMoveMonitor.stop,
            setIgnoresMouseEvents: { panel, ignoresMouseEvents in
                panel.ignoresMouseEvents = ignoresMouseEvents
            },
            movePanel: { panel, frame in
                let aligned = Self.pixelAlignedFrame(
                    frame,
                    scale: Double(panel.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1)
                )
                panel.setFrame(
                    NSRect(x: aligned.x, y: aligned.y, width: aligned.width, height: aligned.height),
                    display: true
                )
                SessionCompletionTraceLog.append(
                    stage: "panel.frame.actual",
                    sessionId: nil,
                    metadata: [
                        "requested": "x=\(frame.x),y=\(frame.y),w=\(frame.width),h=\(frame.height)",
                        "aligned": "x=\(aligned.x),y=\(aligned.y),w=\(aligned.width),h=\(aligned.height)",
                        "actual": "x=\(panel.frame.origin.x),y=\(panel.frame.origin.y),w=\(panel.frame.size.width),h=\(panel.frame.size.height)",
                        "contentFrame": panel.contentView.map { "x=\($0.frame.origin.x),y=\($0.frame.origin.y),w=\($0.frame.size.width),h=\($0.frame.size.height)" } ?? "nil",
                    ]
                )
            },
            installContentView: { panel, view in
                if panel.contentView !== view {
                    panel.contentView = view
                }
            },
            showPanel: { panel in
                panel.orderFrontRegardless()
                guard panel.alphaValue < 1 else { return }
                Self.applyOriginalPanelVisibilityFade(
                    panel,
                    targetAlpha: 1,
                    duration: 0.12,
                    timingFunction: .easeOut,
                    disablesMouseEventsBeforeAnimation: false
                )
            },
            hidePanel: { panel in
                Self.applyOriginalPanelVisibilityFade(
                    panel,
                    targetAlpha: 0,
                    duration: 0.16,
                    timingFunction: .easeIn,
                    disablesMouseEventsBeforeAnimation: true
                )
            },
            closePanel: { panel in
                panel.close()
            },
            requestKeyboardFocus: { panel in
                guard panel.isVisible, let contentView = panel.contentView else { return }
                panel.makeKeyAndOrderFront(nil)
                panel.makeFirstResponder(contentView)
            },
            releaseKeyboardFocus: { panel in
                panel.makeFirstResponder(nil)
                panel.resignKey()
            },
            performInteraction: performInteraction
        )
    }
}

private extension PanelDisplayState {
    var acceptsDirectInteraction: Bool {
        switch self {
        case .expanded, .notificationPeek, .switcher, .onboarding:
            return true
        case .closed, .opening, .hidden, .autoHidden:
            return false
        }
    }
}
