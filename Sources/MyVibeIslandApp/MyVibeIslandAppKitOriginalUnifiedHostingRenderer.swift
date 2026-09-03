import AppKit
import MyVibeIslandCore
import SwiftUI

struct OriginalExpandedContentHeight: Equatable {
    static func resolve(
        baseListHeight: Double,
        completionSiblingHeight: Double
    ) -> Double {
        max(0, baseListHeight) + max(0, completionSiblingHeight)
    }
}

@MainActor
public final class MyVibeIslandAppKitOriginalUnifiedHostingRenderer {
    public private(set) var model: OriginalUnifiedIslandHostingModel?
    public private(set) var container: NSView?
    public private(set) var hostingView: NSHostingView<OriginalUnifiedIslandRootView>?
    public private(set) var interactionGeometry: MyVibeIslandAppKitPanelInteractionGeometry?
    private var lastRenderList: IslandSurfaceRenderList?
    private var lastScreen: OriginalNSScreenMetricsInput?
    private var measuredExpandedContentHeight: Double?
    private var measuredExpandedBaseContentHeight: Double?
    private var measuredExpandedCompletionContentHeight: Double?
    private var measuredExpandedSessionIDs: [String]?
    // V3 owns this separately as NotchViewModel._switcherHighlightedId. It
    // must survive ordinary session-list publications while the switcher is open.
    private var switcherHighlightedID: String?
    private var lastLoggedCompletionFlashTick: Int?
    private var lastLoggedRootHoverInput: Bool?
    private var renderRevision = 0
    private var geometryRevision = 0
    private let onOpenSettings: () -> Void
    private let onContextMenuCommand: (AppCommand) -> Void
    private let onSelectSession: (String) -> Void
    private let onJumpToSession: (String) -> Void
    private var onToggleManualExpansion: (String) -> Void = { _ in }
    private let onNavigateSwitcher: (SwitcherNavigationDirection) -> Void
    private let onSubmitSwitcher: () -> Void
    private let onCollapseSwitcher: () -> Void
    private let onRequestFocus: () -> Void
    private let onReleaseFocus: () -> Void
    private let onExpandedContentHoverChange: (Bool) -> Void
    private let onInteractionGeometryChange: (MyVibeIslandAppKitPanelInteractionGeometry) -> Void
    private let onSubmitActionResolution: (ActionResolution) -> Bool

    public init(
        onNavigateSwitcher: @escaping (SwitcherNavigationDirection) -> Void,
        onSubmitSwitcher: @escaping () -> Void,
        onCollapseSwitcher: @escaping () -> Void,
        onRequestFocus: @escaping () -> Void,
        onReleaseFocus: @escaping () -> Void,
        onExpandedContentHoverChange: @escaping (Bool) -> Void = { _ in },
        onInteractionGeometryChange: @escaping (MyVibeIslandAppKitPanelInteractionGeometry) -> Void = { _ in },
        onOpenSettings: @escaping () -> Void = {},
        onContextMenuCommand: @escaping (AppCommand) -> Void = { _ in },
        onSelectSession: @escaping (String) -> Void = { _ in },
        onJumpToSession: @escaping (String) -> Void = { _ in },
        onSubmitActionResolution: @escaping (ActionResolution) -> Bool = { _ in false }
    ) {
        self.onOpenSettings = onOpenSettings
        self.onContextMenuCommand = onContextMenuCommand
        self.onSelectSession = onSelectSession
        self.onJumpToSession = onJumpToSession
        self.onNavigateSwitcher = onNavigateSwitcher
        self.onSubmitSwitcher = onSubmitSwitcher
        self.onCollapseSwitcher = onCollapseSwitcher
        self.onRequestFocus = onRequestFocus
        self.onReleaseFocus = onReleaseFocus
        self.onExpandedContentHoverChange = onExpandedContentHoverChange
        self.onInteractionGeometryChange = onInteractionGeometryChange
        self.onSubmitActionResolution = onSubmitActionResolution
    }

    public func render(
        _ inputRenderList: IslandSurfaceRenderList,
        screen: OriginalNSScreenMetricsInput
    ) -> NSView? {
        let renderList = inputRenderList
        renderRevision += 1
        SessionCompletionTraceLog.append(
            stage: "render.pass.begin",
            sessionId: renderList.sections.focusedSessionId,
            metadata: [
                "renderRevision": String(renderRevision),
                "displayStatus": renderList.sections.displayStatus.rawValue,
                "rootContentStatus": String(describing: renderList.sections.rootContentStatus),
                "layoutMode": String(describing: renderList.sections.layoutMode),
                "itemCount": String(renderList.items.count),
                "sessionCount": String(renderList.sections.sessions.count),
                "actionRequestCount": String(renderList.sections.actionRequestPreviews.count),
                "focusedSessionId": renderList.sections.focusedSessionId ?? "-",
                "screen": screenDescription(screen),
            ]
        )
        if renderList.sections.rootContentStatus == .expanded {
            let sessionIDs = expandedSessionIDs(in: renderList)
            if measuredExpandedSessionIDs != sessionIDs {
                measuredExpandedContentHeight = nil
                measuredExpandedBaseContentHeight = nil
                measuredExpandedCompletionContentHeight = nil
                measuredExpandedSessionIDs = sessionIDs
            }
        }
        guard let presentation = presentation(
            from: renderList,
            screen: screen,
            measuredContentHeight: measuredExpandedContentHeight
        ) else {
            SessionCompletionTraceLog.append(
                stage: "render.pass.empty",
                sessionId: renderList.sections.focusedSessionId,
                metadata: ["renderRevision": String(renderRevision)]
            )
            interactionGeometry = nil
            lastRenderList = nil
            lastScreen = nil
            measuredExpandedContentHeight = nil
            measuredExpandedBaseContentHeight = nil
            measuredExpandedCompletionContentHeight = nil
            measuredExpandedSessionIDs = nil
            return nil
        }
        lastRenderList = renderList
        lastScreen = screen
        SessionCompletionTraceLog.append(
            stage: "render.pass.presentation",
            sessionId: renderList.sections.focusedSessionId,
            metadata: [
                "renderRevision": String(renderRevision),
                "presentation": String(describing: presentation.displayState),
            ]
        )
        logRootHoverInputIfChanged(renderList)
        logCompletionFlashTickIfChanged(renderList)
        updateInteractionGeometry(for: presentation, screen: screen)

        let makeRootView: (OriginalUnifiedIslandHostingModel) -> OriginalUnifiedIslandRootView = { [weak self] model in
            OriginalUnifiedIslandRootView(
                model: model,
                onExpandedContentHeightChange: { [weak self] measuredHeight, sessionIDs in
                    self?.replaceMeasuredExpandedBaseContentHeight(
                        measuredHeight,
                        sessionIDs: sessionIDs
                    )
                },
                onOpenSettings: self?.onOpenSettings ?? {},
                onContextMenuCommand: { [weak self] command in
                    self?.onContextMenuCommand(command)
                },
                onSelectSession: { [weak self] in self?.selectSession($0) },
                onJumpToSession: { [weak self] in self?.jumpToSession($0) },
                onToggleManualExpansion: { [weak self] in self?.toggleManualSessionExpansion($0) },
                onNavigateSwitcher: { [weak self] in self?.onNavigateSwitcher($0) },
                onSubmitSwitcher: { [weak self] in self?.onSubmitSwitcher() },
                onCollapseSwitcher: { [weak self] in self?.onCollapseSwitcher() },
                onRequestFocus: self?.onRequestFocus ?? {},
                onReleaseFocus: self?.onReleaseFocus ?? {},
                onExpandedContentHoverChange: self?.onExpandedContentHoverChange ?? { _ in },
                onCompletionContentHeightChange: { [weak self] measuredHeight, sessionIDs in
                    self?.replaceMeasuredExpandedCompletionContentHeight(
                        measuredHeight,
                        sessionIDs: sessionIDs
                    )
                },
                onSubmitActionResolution: { [weak self] in
                    self?.submitActionResolution($0) ?? false
                }
            )
        }

        if let model, let container, hostingView != nil {
            model.replace(
                presentation,
                rootAnimationInputs: rootAnimationInputs(from: renderList)
            )
            model.replaceActionRequests(actionRequests(in: renderList))
            // The retained root observes the model. Replacing this entire
            // SwiftUI tree for every hook event discards list scroll and
            // layout state, even when the presentation is unchanged.
            return container
        }

        let model = OriginalUnifiedIslandHostingModel(
            presentation: presentation,
            actionRequests: actionRequests(in: renderList),
            rootAnimationInputs: rootAnimationInputs(from: renderList)
        )
        let rootView = makeRootView(model)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        let panelSize = OriginalIslandGeometryResolver.panelSize
        let container = MyVibeIslandAppKitHitTestView(frame: NSRect(
            x: 0,
            y: 0,
            width: panelSize.width,
            height: panelSize.height
        ))
        container.identifier = NSUserInterfaceItemIdentifier("my-vibe-island.container")
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        hostingView.frame = container.bounds
        container.addSubview(hostingView)

        self.model = model
        self.hostingView = hostingView
        self.container = container
        if let interactionGeometry {
            applyVisibleSurfaceHostLayout(interactionGeometry)
        }
        return container
    }

    public func refreshScreen(_ screen: OriginalNSScreenMetricsInput) -> NSView? {
        guard let lastRenderList else { return nil }
        return render(lastRenderList, screen: screen)
    }

    public func renderPeek(
        _ state: OriginalPeekDisplayState,
        compactRenderList: IslandSurfaceRenderList,
        screen: OriginalNSScreenMetricsInput
    ) -> NSView? {
        guard case .peek = state,
              let container = render(compactRenderList, screen: screen),
              case let .compact(compact) = model?.presentation
        else {
            return nil
        }

        let descriptor = OriginalPeekHostingDescriptor(
            compactSurfaceSize: compact.surfaceSize,
            screenWidth: screen.screenFrame.width
        )
        let presentation = OriginalUnifiedIslandPresentation.peek(
            compact: compact,
            descriptor: descriptor,
            state: state
        )
        model?.replace(presentation)
        updateInteractionGeometry(for: presentation, screen: screen)
        return container
    }

    func selectSession(_ sessionID: String) {
        onSelectSession(sessionID)
    }

    func jumpToSession(_ sessionID: String) {
        onJumpToSession(sessionID)
    }

    public func setManualSessionExpansionHandler(_ handler: @escaping (String) -> Void) {
        onToggleManualExpansion = handler
    }

    func toggleManualSessionExpansion(_ sessionID: String) {
        onToggleManualExpansion(sessionID)
    }

    public func navigateSwitcher(_ direction: SwitcherNavigationDirection, reverse: Bool) {
        onNavigateSwitcher(reverse ? (direction == .up ? .down : .up) : direction)
    }

    public func submitHighlightedSwitcher() {
        onSubmitSwitcher()
    }

    public func collapseSwitcher() {
        onCollapseSwitcher()
    }

    public func requestSwitcherFocus() {
        onRequestFocus()
    }

    public func releaseSwitcherFocus() {
        onReleaseFocus()
    }

    public func replaceSwitcherState(_ state: SwitcherRuntimeState) {
        guard state.isOpen,
              case let .switcher(descriptor) = model?.presentation
        else {
            switcherHighlightedID = nil
            return
        }
        switcherHighlightedID = state.highlightedID
        model?.replace(.switcher(descriptor.replacingHighlight(
            index: state.highlightedIndex,
            id: state.highlightedID
        )))
    }

    func submitActionResolution(_ resolution: ActionResolution) -> Bool {
        onSubmitActionResolution(resolution)
    }

    func replaceMeasuredExpandedContentHeight(
        _ measuredHeight: Double,
        sessionIDs: [String]? = nil
    ) {
        let measuredSessionIDs = sessionIDs ?? measuredExpandedSessionIDs
        guard let renderList = lastRenderList,
              let screen = lastScreen,
              renderList.sections.rootContentStatus == .expanded,
              measuredSessionIDs == measuredExpandedSessionIDs,
              measuredSessionIDs == expandedSessionIDs(in: renderList)
        else {
            return
        }

        switch OriginalSessionsListMeasuredHeightDecision.resolve(
            measured: measuredHeight,
            current: measuredExpandedContentHeight
        ) {
        case .unchanged:
            return
        case let .replace(height):
            measuredExpandedContentHeight = height
        }

        guard let presentation = presentation(
            from: renderList,
            screen: screen,
            measuredContentHeight: measuredExpandedContentHeight
        ) else {
            return
        }
        // A measured-height publication is one root writer. Preserve the
        // independently published compact/minimized/layout inputs.
        model?.replace(
            presentation,
            rootAnimationInputs: rootAnimationInputs(from: renderList)
        )
        updateInteractionGeometry(for: presentation, screen: screen)
    }

    func replaceMeasuredExpandedBaseContentHeight(
        _ measuredHeight: Double,
        sessionIDs: [String]? = nil
    ) {
        let measuredSessionIDs = sessionIDs ?? measuredExpandedSessionIDs
        guard canApplyExpandedMeasurement(for: measuredSessionIDs) else {
            return
        }

        switch OriginalSessionsListMeasuredHeightDecision.resolve(
            measured: measuredHeight,
            current: measuredExpandedBaseContentHeight
        ) {
        case .unchanged:
            return
        case let .replace(height):
            measuredExpandedBaseContentHeight = height
        }
        logExpandedHeightMeasurement(kind: "base", measured: measuredHeight)
        publishCombinedExpandedContentHeight(sessionIDs: measuredSessionIDs)
    }

    func replaceMeasuredExpandedCompletionContentHeight(
        _ measuredHeight: Double,
        sessionIDs: [String]? = nil
    ) {
        let measuredSessionIDs = sessionIDs ?? measuredExpandedSessionIDs
        guard canApplyExpandedMeasurement(for: measuredSessionIDs) else {
            return
        }

        let normalized = max(0, measuredHeight)
        guard measuredExpandedCompletionContentHeight.map({
            abs($0 - normalized) > 0.5
        }) ?? true else {
            return
        }
        measuredExpandedCompletionContentHeight = normalized
        logExpandedHeightMeasurement(kind: "completion", measured: measuredHeight)
        publishCombinedExpandedContentHeight(sessionIDs: measuredSessionIDs)
    }

    private func canApplyExpandedMeasurement(for sessionIDs: [String]?) -> Bool {
        guard let renderList = lastRenderList,
              renderList.sections.rootContentStatus == .expanded,
              sessionIDs == measuredExpandedSessionIDs,
              sessionIDs == expandedSessionIDs(in: renderList)
        else {
            return false
        }
        return true
    }

    private func publishCombinedExpandedContentHeight(sessionIDs: [String]?) {
        guard let baseHeight = measuredExpandedBaseContentHeight else {
            return
        }
        let totalHeight = OriginalExpandedContentHeight.resolve(
            baseListHeight: baseHeight,
            completionSiblingHeight: measuredExpandedCompletionContentHeight ?? 0
        )
        SessionCompletionTraceLog.append(
            stage: "render.expanded.height_measurement",
            sessionId: nil,
            metadata: [
                "base": String(baseHeight),
                "completion": String(measuredExpandedCompletionContentHeight ?? 0),
                "combined": String(totalHeight),
                "currentSurface": String(currentExpandedSurfaceHeight ?? 0),
            ]
        )
        replaceMeasuredExpandedContentHeight(totalHeight, sessionIDs: sessionIDs)
    }

    private var currentExpandedSurfaceHeight: Double? {
        guard case let .expanded(descriptor) = model?.presentation else { return nil }
        return descriptor.surfaceSize.height
    }

    private func logExpandedHeightMeasurement(kind: String, measured: Double) {
        SessionCompletionTraceLog.append(
            stage: "render.expanded.height_measurement_input",
            sessionId: nil,
            metadata: [
                "kind": kind,
                "measured": String(measured),
                "base": String(measuredExpandedBaseContentHeight ?? 0),
                "completion": String(measuredExpandedCompletionContentHeight ?? 0),
                "currentSurface": String(currentExpandedSurfaceHeight ?? 0),
            ]
        )
    }

    private func expandedSessionIDs(in renderList: IslandSurfaceRenderList) -> [String] {
        guard let item = renderList.items.first(where: { $0.section == .sessionCards }) else {
            return []
        }
        let rows = OriginalExpandedHostingDescriptorAdapter.resolveSessionRows(
            previews: item.sessionPreviews,
            sessions: item.sessions
        )
        return OriginalExpandedContentPlan(
            sessionRows: rows,
            highlightedID: nil
        ).displayRows.map(\.id)
    }

    private func actionRequests(in renderList: IslandSurfaceRenderList) -> [ActionRequestPreview] {
        renderList.items.first(where: { $0.section == .actionRequests })?.actionRequestPreviews ?? []
    }

    private func rootAnimationInputs(
        from renderList: IslandSurfaceRenderList
    ) -> OriginalUnifiedIslandRootAnimationInputs {
        OriginalUnifiedIslandRootAnimationInputs(
            isMinimized: renderList.sections.originalCompactRuntimeState.isMinimized,
            isHovering: renderList.sections.isHovering,
            layoutMode: renderList.sections.layoutMode,
            notchHeightOffset: renderList.sections.originalCompactRuntimeState.notchHeightOffset,
            completionFlashTick: renderList.sections.originalCompactRuntimeState.completionFlashTick
        )
    }

    private func logRootHoverInputIfChanged(_ renderList: IslandSurfaceRenderList) {
        let isHovering = renderList.sections.isHovering
        guard lastLoggedRootHoverInput != isHovering else { return }
        lastLoggedRootHoverInput = isHovering
        SessionCompletionTraceLog.append(
            stage: "hover.renderer_input",
            sessionId: nil,
            metadata: [
                "isHovering": String(isHovering),
                "displayStatus": renderList.sections.displayStatus.rawValue,
                "layoutMode": String(describing: renderList.sections.layoutMode),
            ]
        )
    }

    private func logCompletionFlashTickIfChanged(_ renderList: IslandSurfaceRenderList) {
        let tick = renderList.sections.originalCompactRuntimeState.completionFlashTick
        guard lastLoggedCompletionFlashTick != tick else { return }
        lastLoggedCompletionFlashTick = tick
        SessionCompletionTraceLog.append(
            stage: "completion.renderer_input",
            sessionId: nil,
            metadata: [
                "flashTick": String(tick),
                "displayStatus": renderList.sections.displayStatus.rawValue,
                "layoutMode": String(describing: renderList.sections.layoutMode),
            ]
        )
    }

    private func updateInteractionGeometry(
        for presentation: OriginalUnifiedIslandPresentation,
        screen: OriginalNSScreenMetricsInput
    ) {
        geometryRevision += 1
        let panelSize = OriginalIslandGeometryResolver.panelSize
        let panelFrame = DisplayFrame(
            x: screen.screenFrame.x + (screen.screenFrame.width - panelSize.width) / 2,
            y: screen.screenFrame.y + screen.screenFrame.height - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
        let current = interactionGeometry

        switch presentation {
        case let .compact(descriptor):
            let layoutPlan = descriptor.rootLayoutPlan
            let visibleWidth = descriptor.surfaceSize.width
                + 2 * layoutPlan.outerHorizontalInset
                + 2 * layoutPlan.innerHorizontalBottomPadding
            let compactFrame = DisplayFrame(
                x: panelFrame.x + (panelFrame.width - visibleWidth) / 2
                    + layoutPlan.physicalHorizontalOffset,
                y: panelFrame.y + panelFrame.height - descriptor.surfaceSize.height,
                width: visibleWidth,
                height: descriptor.surfaceSize.height
            )
            interactionGeometry = MyVibeIslandAppKitPanelInteractionGeometry(
                compactFrame: compactFrame,
                hostingFrame: panelFrame,
                visibleFrame: compactFrame,
                expandedFrame: current?.expandedFrame ?? panelFrame
            )

        case let .peek(_, descriptor, _):
            let surfaceSize = descriptor.surfaceSize
            let peekFrame = DisplayFrame(
                x: panelFrame.x + (panelFrame.width - surfaceSize.width) / 2,
                y: panelFrame.y + panelFrame.height - surfaceSize.height,
                width: surfaceSize.width,
                height: surfaceSize.height
            )
            interactionGeometry = MyVibeIslandAppKitPanelInteractionGeometry(
                compactFrame: current?.compactFrame ?? panelFrame,
                hostingFrame: panelFrame,
                visibleFrame: peekFrame,
                expandedFrame: peekFrame
            )

        case let .expanded(descriptor):
            let surfaceFrame = descriptor.geometry.surfaceFrame
            interactionGeometry = MyVibeIslandAppKitPanelInteractionGeometry(
                compactFrame: current?.compactFrame ?? panelFrame,
                hostingFrame: panelFrame,
                visibleFrame: DisplayFrame(
                    x: descriptor.geometry.panelFrame.x + surfaceFrame.x,
                    y: descriptor.geometry.panelFrame.y + surfaceFrame.y,
                    width: surfaceFrame.width,
                    height: surfaceFrame.height
                ),
                expandedFrame: DisplayFrame(
                    x: descriptor.geometry.panelFrame.x + surfaceFrame.x,
                    y: descriptor.geometry.panelFrame.y + surfaceFrame.y,
                    width: surfaceFrame.width,
                    height: surfaceFrame.height
                )
            )

        case let .switcher(descriptor):
            interactionGeometry = MyVibeIslandAppKitPanelInteractionGeometry(
                compactFrame: current?.compactFrame ?? panelFrame,
                hostingFrame: panelFrame,
                visibleFrame: DisplayFrame(
                    x: descriptor.geometry.panelFrame.x + descriptor.geometry.surfaceFrame.x,
                    y: descriptor.geometry.panelFrame.y + descriptor.geometry.surfaceFrame.y,
                    width: descriptor.geometry.surfaceFrame.width,
                    height: descriptor.geometry.surfaceFrame.height
                ),
                expandedFrame: DisplayFrame(
                    x: descriptor.geometry.panelFrame.x + descriptor.geometry.surfaceFrame.x,
                    y: descriptor.geometry.panelFrame.y + descriptor.geometry.surfaceFrame.y,
                    width: descriptor.geometry.surfaceFrame.width,
                    height: descriptor.geometry.surfaceFrame.height
                )
            )
        }
        if let interactionGeometry {
            applyVisibleSurfaceHostLayout(interactionGeometry)
            SessionCompletionTraceLog.append(
                stage: "panel.geometry.emit",
                sessionId: nil,
                metadata: [
                    "presentation": String(describing: presentation.displayState),
                    "compactFrame": geometryDescription(interactionGeometry.compactFrame),
                    "expandedFrame": geometryDescription(interactionGeometry.expandedFrame),
                    "visibleFrame": geometryDescription(interactionGeometry.visibleFrame),
                    "containerFrame": container.map { nsRectDescription($0.frame) } ?? "nil",
                    "hostingFrame": hostingView.map { nsRectDescription($0.frame) } ?? "nil",
                    "hostingBounds": hostingView.map { nsRectDescription($0.bounds) } ?? "nil",
                    "renderRevision": String(renderRevision),
                    "geometryRevision": String(geometryRevision),
                ]
            )
            onInteractionGeometryChange(interactionGeometry)
        }
    }

    private func applyVisibleSurfaceHostLayout(
        _ geometry: MyVibeIslandAppKitPanelInteractionGeometry
    ) {
        guard let container, let hostingView else { return }

        SessionCompletionTraceLog.append(
            stage: "render.host_layout.before",
            sessionId: nil,
            metadata: [
                "renderRevision": String(renderRevision),
                "geometryRevision": String(geometryRevision),
                "container": nsRectDescription(container.frame),
                "hosting": nsRectDescription(hostingView.frame),
                "visible": geometryDescription(geometry.visibleFrame),
                "hostingFrame": geometryDescription(geometry.hostingFrame),
            ]
        )

        let sourceOriginX = geometry.visibleFrame.x - geometry.hostingFrame.x
        let sourceOriginY = geometry.visibleFrame.y - geometry.hostingFrame.y
        container.frame = NSRect(
            x: 0,
            y: 0,
            width: geometry.visibleFrame.width,
            height: geometry.visibleFrame.height
        )
        hostingView.frame = NSRect(
            x: -sourceOriginX,
            y: -sourceOriginY,
            width: geometry.hostingFrame.width,
            height: geometry.hostingFrame.height
        )
        hostingView.autoresizingMask = []
        SessionCompletionTraceLog.append(
            stage: "render.host_layout.after",
            sessionId: nil,
            metadata: [
                "renderRevision": String(renderRevision),
                "geometryRevision": String(geometryRevision),
                "container": nsRectDescription(container.frame),
                "hosting": nsRectDescription(hostingView.frame),
                "hostingBounds": nsRectDescription(hostingView.bounds),
            ]
        )
    }

    private func screenDescription(_ screen: OriginalNSScreenMetricsInput) -> String {
        "screen=\(geometryDescription(screen.screenFrame)),visible=\(geometryDescription(screen.visibleFrame)),safeTop=\(screen.safeAreaTopInset)"
    }

    private func geometryDescription(_ frame: DisplayFrame) -> String {
        "x=\(frame.x),y=\(frame.y),w=\(frame.width),h=\(frame.height)"
    }

    private func nsRectDescription(_ rect: NSRect) -> String {
        "x=\(rect.origin.x),y=\(rect.origin.y),w=\(rect.size.width),h=\(rect.size.height)"
    }

    private func presentation(
        from renderList: IslandSurfaceRenderList,
        screen: OriginalNSScreenMetricsInput,
        measuredContentHeight: Double?
    ) -> OriginalUnifiedIslandPresentation? {
        if let descriptor = OriginalCompactHostingDescriptorBuilder.makeDescriptor(
            from: renderList,
            screen: screen
        ) {
            return .compact(descriptor)
        }
        if let descriptor = OriginalSwitcherHostingDescriptorAdapter.makeDescriptor(
            from: renderList,
            screen: screen,
            preferredHighlightedID: switcherHighlightedID
        ) {
            switcherHighlightedID = descriptor.highlightedID
            return .switcher(descriptor)
        }
        switcherHighlightedID = nil
        if let descriptor = OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
            from: renderList,
            screen: screen,
            measuredContentHeight: measuredContentHeight
        ) {
            logExpandedFirstCard(descriptor, renderList: renderList)
            return .expanded(descriptor)
        }
        return nil
    }

    private func logExpandedFirstCard(
        _ descriptor: OriginalExpandedHostingDescriptor,
        renderList: IslandSurfaceRenderList
    ) {
        guard let first = descriptor.contentPlan.displayRows.first else { return }
        let cardPresentation = OriginalExpandedSessionCardPresentation.resolve(row: first)
        let header = cardPresentation.header
        let body = cardPresentation.body
        let rows = descriptor.contentPlan.displayRows.map(\.id).joined(separator: ",")
        let sessionCardsItem = renderList.items.first { $0.section == .sessionCards }
        let snapshotSessionIDs = renderList.sections.sessions.map(\.id).joined(separator: ",")
        let presentationSessionIDs = renderList.sections.primarySessionIds.joined(separator: ",")
        let sessionCardItemIDs = sessionCardsItem?.sessionIds.joined(separator: ",") ?? "none"
        let sessionCardItemSessionIDs = sessionCardsItem?.sessions.map(\.id).joined(separator: ",") ?? "none"
        let notifications = renderList.sections.notificationSessionIds.joined(separator: ",")
        let primaries = renderList.sections.primarySessionIds.joined(separator: ",")
        let completionBodyRowID = descriptor.contentPlan.completionBodyRowID
        let mountedCompletion = completionBodyRowID == first.id
        let requests = actionRequests(in: renderList)
        let permissionRequests = requests.filter { $0.kind == .permission }
        let requestIDs = requests.map(\.requestId).joined(separator: ",")
        let requestSessionIDs = requests.map(\.sessionId).joined(separator: ",")
        let permissionRequestIDs = permissionRequests.map(\.requestId).joined(separator: ",")
        let locallyResolvablePermissionCount = permissionRequests.filter(\.canResolveLocally).count
        let shouldRenderCompletionBody = OriginalExpandedCompletionBodyPlan.shouldRender(
            isMounted: mountedCompletion,
            status: first.status,
            hasUnreadCompletion: cardPresentation.hasUnreadCompletion,
            assistantMessage: cardPresentation.completionAssistantMessage
        )
        let metadata: [String: String] = [
            "displayStatus": renderList.sections.displayStatus.rawValue,
            "surfaceWidth": String(descriptor.surfaceSize.width),
            "surfaceHeight": String(descriptor.surfaceSize.height),
            "hostWidth": String(descriptor.hostSize.width),
            "hostHeight": String(descriptor.hostSize.height),
            "focusedSessionId": renderList.sections.focusedSessionId ?? "nil",
            "notificationSessionIds": notifications.isEmpty ? "none" : notifications,
            "primarySessionIds": primaries.isEmpty ? "none" : primaries,
            "snapshotSessionCount": String(renderList.sections.sessions.count),
            "snapshotSessionIDs": snapshotSessionIDs.isEmpty ? "none" : snapshotSessionIDs,
            "presentationSessionCount": String(renderList.sections.primarySessionIds.count),
            "presentationSessionIDs": presentationSessionIDs.isEmpty ? "none" : presentationSessionIDs,
            "sessionCardsItemCount": String(sessionCardsItem?.sessions.count ?? 0),
            "sessionCardsItemIDs": sessionCardItemIDs,
            "sessionCardsItemSessionIDs": sessionCardItemSessionIDs,
            "descriptorRowCount": String(descriptor.contentPlan.displayRows.count),
            "displayRowIds": rows.isEmpty ? "none" : rows,
            "completionBodyRowID": completionBodyRowID ?? "nil",
            "firstIsCompletionMounted": String(mountedCompletion),
            "firstStatus": String(first.status.rawValue),
            "firstUnread": String(first.session.hasUnreadCompletion),
            "headerTitle": snippet(header.title),
            "headerPrompt": snippet(header.prompt),
            "sourceLabel": header.sourceLabel ?? "nil",
            "terminalLabel": header.terminalLabel ?? "nil",
            "ageLabel": header.ageLabel ?? "nil",
            "bodyDisplayTitle": snippet(body.displayTitle),
            "latestPrompt": snippet(body.latestPrompt),
            "activityToolLabel": body.activityToolLabel ?? "nil",
            "activityContent": snippet(body.activityContent),
            "activityLine": snippet(body.activityLine),
            "assistantMessage": snippet(body.assistantMessage),
            "shouldRenderCompletionBody": String(shouldRenderCompletionBody),
            "actionRequestCount": String(requests.count),
            "actionRequestIDs": requestIDs.isEmpty ? "none" : requestIDs,
            "actionRequestSessionIDs": requestSessionIDs.isEmpty ? "none" : requestSessionIDs,
            "permissionRequestCount": String(permissionRequests.count),
            "permissionRequestIDs": permissionRequestIDs.isEmpty ? "none" : permissionRequestIDs,
            "locallyResolvablePermissionCount": String(locallyResolvablePermissionCount),
        ]

        SessionCompletionTraceLog.append(
            stage: "render.expanded.first_card",
            sessionId: first.id,
            metadata: metadata
        )
    }

    private func snippet(_ value: String?, limit: Int = 160) -> String {
        guard let value, !value.isEmpty else { return "nil" }
        let normalized = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        if normalized.count <= limit { return normalized }
        return String(normalized.prefix(limit))
    }

}
