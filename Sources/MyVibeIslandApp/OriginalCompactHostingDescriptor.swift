import MyVibeIslandCore

public struct OriginalCompactHostingDescriptor: Equatable, Sendable {
    public let displayClass: OriginalCompactBaseLayoutPlan.DisplayClass
    public let contentPlan: OriginalCompactContentPlan
    public let sessionInputs: [OriginalCompactContentPlan.SessionInput]
    public let compactLayoutPlan: OriginalCompactBaseLayoutPlan
    public let rightPresentationPlan: OriginalCompactRightPresentationPlan
    public let rootLayoutPlan: OriginalRootSurfaceLayoutPlan
    public let layoutMode: OriginalNotchLayoutMode
    public let isMinimized: Bool
    public let isHovering: Bool
    public let rootNotchHeightOffset: Double
    public let surfaceSize: DisplaySize
    public let displayState: OriginalIslandDisplayState
    public let completionFlashTick: Int

    init(
        displayClass: OriginalCompactBaseLayoutPlan.DisplayClass,
        contentPlan: OriginalCompactContentPlan,
        sessionInputs: [OriginalCompactContentPlan.SessionInput],
        compactLayoutPlan: OriginalCompactBaseLayoutPlan,
        rightPresentationPlan: OriginalCompactRightPresentationPlan,
        rootLayoutPlan: OriginalRootSurfaceLayoutPlan,
        layoutMode: OriginalNotchLayoutMode,
        isMinimized: Bool,
        isHovering: Bool = false,
        rootNotchHeightOffset: Double = 0,
        surfaceSize: DisplaySize,
        displayState: OriginalIslandDisplayState,
        completionFlashTick: Int
    ) {
        self.displayClass = displayClass
        self.contentPlan = contentPlan
        self.sessionInputs = sessionInputs
        self.compactLayoutPlan = compactLayoutPlan
        self.rightPresentationPlan = rightPresentationPlan
        self.rootLayoutPlan = rootLayoutPlan
        self.layoutMode = layoutMode
        self.isMinimized = isMinimized
        self.isHovering = isHovering
        self.rootNotchHeightOffset = rootNotchHeightOffset
        self.surfaceSize = surfaceSize
        self.displayState = displayState
        self.completionFlashTick = completionFlashTick
    }
}

public enum OriginalCompactHostingDescriptorBuilder {
    public static func makeDescriptor(
        from renderList: IslandSurfaceRenderList,
        screen: OriginalNSScreenMetricsInput?
    ) -> OriginalCompactHostingDescriptor? {
        guard let screen,
              !renderList.sections.rootContentStatus.usesExpandedContent,
              renderList.items.allSatisfy({ $0.section == .compactPill || $0.section == .usageInfo }),
              let item = renderList.items.first(where: { $0.section == .compactPill })
        else {
            return nil
        }
        let displayClass: OriginalCompactBaseLayoutPlan.DisplayClass = screen.safeAreaTopInset > 0
            ? .physicalNotch
            : .nonNotched
        guard displayClass == .physicalNotch || screen.hasValidDisplayFrames else {
            return nil
        }
        guard item.displayStatus == .closed
                || (displayClass == .physicalNotch && item.displayStatus == .opening)
        else {
            return nil
        }

        let layoutMode: OriginalNotchLayoutMode
        switch item.layoutMode {
        case .compact:
            layoutMode = .compact
        case .regular:
            layoutMode = .normal
        case .expanded:
            return nil
        }

        let displaySessions = prioritizedSessions(item.sessions)
        let sessionInputs = displaySessions.map(OriginalCompactSessionAdapter.resolve)
        let contentPlan = OriginalCompactContentPlan.resolve(
            displayClass: displayClass == .physicalNotch ? .physicalNotch : .nonNotched,
            sessions: sessionInputs
        )
        let runtimeState = item.originalCompactRuntimeState
        let compactLayoutPlan = OriginalCompactBaseLayoutPlan.resolve(
            displayClass: displayClass,
            layoutMode: layoutMode,
            isMinimized: runtimeState.isMinimized,
            hasActionableCount: contentPlan.rightCount?.source == .actionable,
            hasSessions: !item.sessions.isEmpty,
            screenNotchWidth: displayClass == .physicalNotch
                ? OriginalNSScreenMetricsResolver().resolve(screen).notchWidth
                : 0,
            notchWidthOffset: runtimeState.notchWidthOffset,
            completionFlashProgress: 0
        )

        let rightPresentationPlan = OriginalCompactRightPresentationPlan.resolve(
            rightCount: contentPlan.rightCount,
            usesCompactArrangement: compactLayoutPlan.usesCompactArrangement,
            showsUnreadCompletionOverview: item.isCompletionUnreadOverviewVisible
        )
        let rootLayoutPlan = OriginalRootSurfaceLayoutPlan.resolve(
            displayState: .compact,
            isHovering: item.isHovering,
            safeAreaTopInset: screen.safeAreaTopInset,
            leftStatusSlotWidth: compactLayoutPlan.statusRegionWidth,
            rightStatusSlotWidth: compactLayoutPlan.rightRegionWidth
                ?? compactLayoutPlan.statusRegionWidth
        )
        let surfaceSize: DisplaySize
        switch displayClass {
        case .physicalNotch:
            guard let centerNotchWidth = compactLayoutPlan.centerNotchWidth,
                  let rightRegionWidth = compactLayoutPlan.rightRegionWidth
            else {
                return nil
            }
            surfaceSize = DisplaySize(
                width: compactLayoutPlan.statusRegionWidth + centerNotchWidth + rightRegionWidth,
                height: OriginalNSScreenMetricsResolver().compactPhysicalSurfaceHeight(
                    for: screen,
                    notchHeightOffset: runtimeState.notchHeightOffset
                )
            )
        case .nonNotched:
            surfaceSize = OriginalIslandGeometryResolver().resolve(OriginalIslandGeometryInput(
                screenFrame: screen.screenFrame,
                visibleFrame: screen.visibleFrame,
                safeAreaTopInset: screen.safeAreaTopInset,
                displayState: .compact,
                compactIntrinsicWidth: nonNotchedCompactIntrinsicWidth(
                    layoutMode: layoutMode,
                    isMinimized: runtimeState.isMinimized
                ),
                notchWidthOffset: runtimeState.notchWidthOffset,
                notchHeightOffset: runtimeState.notchHeightOffset
            )).surfaceSize
        }

        return OriginalCompactHostingDescriptor(
            displayClass: displayClass,
            contentPlan: contentPlan,
            sessionInputs: sessionInputs,
            compactLayoutPlan: compactLayoutPlan,
            rightPresentationPlan: rightPresentationPlan,
            rootLayoutPlan: rootLayoutPlan,
            layoutMode: layoutMode,
            isMinimized: runtimeState.isMinimized,
            isHovering: item.isHovering,
            rootNotchHeightOffset: runtimeState.notchHeightOffset,
            surfaceSize: surfaceSize,
            displayState: .compact,
            completionFlashTick: runtimeState.completionFlashTick
        )
    }

    private static func nonNotchedCompactIntrinsicWidth(
        layoutMode: OriginalNotchLayoutMode,
        isMinimized: Bool
    ) -> Double {
        if isMinimized {
            return 154
        }
        return layoutMode == .compact ? 206 : 340
    }

    private static func prioritizedSessions(_ sessions: [AgentSession]) -> [AgentSession] {
        OriginalSessionDisplayOrder.sort(sessions)
    }
}
