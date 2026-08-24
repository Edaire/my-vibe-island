import MyVibeIslandCore

public enum OriginalSessionsListScrollDecision: Equatable, Sendable {
    case none
    case center(id: String, duration: Double)

    public static func resolve(highlightedID: String?) -> Self {
        guard let highlightedID else { return .none }
        return .center(id: highlightedID, duration: 0.18)
    }
}

public struct OriginalSwitcherHostingDescriptor: Equatable, Sendable {
    public let geometry: OriginalIslandGeometry
    public let rootLayoutPlan: OriginalRootSurfaceLayoutPlan
    /// The original switcher drives the ordinary expanded session list through
    /// NotchViewModel._switcherHighlightedId. It is not a separate list UI.
    public let contentPlan: OriginalExpandedContentPlan
    public let highlightedID: String?
    public let highlightedIndex: Int?

    public var surfaceSize: DisplaySize { geometry.surfaceSize }
    public var hostSize: DisplaySize { OriginalIslandGeometryResolver.panelSize }

    init(
        geometry: OriginalIslandGeometry,
        rootLayoutPlan: OriginalRootSurfaceLayoutPlan,
        contentPlan: OriginalExpandedContentPlan,
        highlightedID: String?,
        highlightedIndex: Int?
    ) {
        self.geometry = geometry
        self.rootLayoutPlan = rootLayoutPlan
        self.contentPlan = contentPlan
        self.highlightedID = highlightedID
        self.highlightedIndex = highlightedIndex
    }

    func replacingHighlight(index: Int?, id: String?) -> Self {
        Self(
            geometry: geometry,
            rootLayoutPlan: rootLayoutPlan,
            contentPlan: OriginalExpandedContentPlan(
                sessionRows: contentPlan.sessionRows,
                highlightedID: id
            ),
            highlightedID: id,
            highlightedIndex: index
        )
    }
}

enum OriginalSwitcherHostingDescriptorAdapter {
    static func makeDescriptor(
        from renderList: IslandSurfaceRenderList,
        screen: OriginalNSScreenMetricsInput,
        preferredHighlightedID: String? = nil
    ) -> OriginalSwitcherHostingDescriptor? {
        guard screen.hasValidDisplayFrames,
              renderList.sections.displayStatus == .switcher,
              renderList.sections.visibleSections.contains(.switcher)
        else {
            return nil
        }

        let sessionRows = OriginalExpandedHostingDescriptorAdapter.resolveSessionRows(
            previews: renderList.items.first { $0.section == .sessionCards }?.sessionPreviews,
            sessions: renderList.sections.sessions,
            manuallyExpandedSessionIDs: renderList.sections.manuallyExpandedSessionIDs
        )
        let highlightedID = sessionRows.contains { $0.id == preferredHighlightedID }
            ? preferredHighlightedID
            : sessionRows.contains { $0.id == renderList.sections.focusedSessionId }
                ? renderList.sections.focusedSessionId
                : sessionRows.first?.id
        let contentPlan = OriginalExpandedContentPlan(
            sessionRows: sessionRows,
            highlightedID: highlightedID
        )
        let geometry = OriginalIslandGeometryResolver().resolve(OriginalIslandGeometryInput(
            screenFrame: screen.screenFrame,
            visibleFrame: screen.visibleFrame,
            safeAreaTopInset: screen.safeAreaTopInset,
            displayState: .expanded,
            compactIntrinsicWidth: 0,
            measuredContentHeight: OriginalExpandedNonCommercialMeasurement.measuredContentHeight(
                sessionCount: contentPlan.displayRows.count
            ),
            sessionCount: contentPlan.displayRows.count,
            focusedSpecialSession: false,
            maxExpandedWidth: 640,
            maxExpandedHeight: 560
        ))
        let rootLayoutPlan = OriginalRootSurfaceLayoutPlan.resolve(
            displayState: .expanded,
            isHovering: false,
            safeAreaTopInset: screen.safeAreaTopInset,
            leftStatusSlotWidth: 0,
            rightStatusSlotWidth: 0
        )
        let highlightedIndex = highlightedID.flatMap { highlightedID in
            contentPlan.displayRows.firstIndex { $0.id == highlightedID }
        }

        return OriginalSwitcherHostingDescriptor(
            geometry: geometry,
            rootLayoutPlan: rootLayoutPlan,
            contentPlan: contentPlan,
            highlightedID: highlightedID,
            highlightedIndex: highlightedIndex
        )
    }
}
