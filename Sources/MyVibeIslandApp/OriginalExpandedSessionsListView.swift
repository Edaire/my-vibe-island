import MyVibeIslandCore
import SwiftUI

struct OriginalExpandedSessionsListLayoutPlan: Equatable, Sendable {
    let innerHorizontalPadding: Double
    let outerHorizontalPadding: Double
    let usesOuterScrollView: Bool

    static let original = Self(
        // IDA's SessionsListView has one horizontal padding pass on its
        // VStack. The expanded root does not add another list inset.
        innerHorizontalPadding: 8,
        outerHorizontalPadding: 0,
        usesOuterScrollView: true
    )

}

struct OriginalExpandedSessionListVisibilityPlan: Equatable {
    let visibleRows: [OriginalExpandedSessionRow]
    let hiddenSessionCount: Int
    let allSessionCount: Int

    var showsShowAllControl: Bool { hiddenSessionCount > 0 }

    static func resolve(contentPlan: OriginalExpandedContentPlan) -> Self {
        let rows = contentPlan.displayRows

        return Self(
            visibleRows: rows,
            hiddenSessionCount: 0,
            allSessionCount: contentPlan.sessionRows.count
        )
    }
}

struct OriginalExpandedSessionsListView: View {
    let contentPlan: OriginalExpandedContentPlan
    let layoutPlan: OriginalRootSurfaceLayoutPlan
    let actionRequests: [ActionRequestPreview]
    let mountsCompletionBodies: Bool
    let viewportHeight: Double?
    var onSelectSession: (String) -> Void = { _ in }
    var onJumpToSession: (String) -> Void = { _ in }
    var onToggleManualExpansion: (String) -> Void = { _ in }
    var onSubmitActionResolution: (ActionResolution) -> Bool = { _ in false }
    var onMeasuredHeightChange: (Double) -> Void = { _ in }
    init(
        contentPlan: OriginalExpandedContentPlan,
        layoutPlan: OriginalRootSurfaceLayoutPlan = OriginalRootSurfaceLayoutPlan.resolve(
            displayState: .expanded,
            isHovering: false,
            safeAreaTopInset: 0,
            leftStatusSlotWidth: 0,
            rightStatusSlotWidth: 0
        ),
        actionRequests: [ActionRequestPreview] = [],
        mountsCompletionBodies: Bool = true,
        viewportHeight: Double? = nil,
        onSelectSession: @escaping (String) -> Void = { _ in },
        onJumpToSession: @escaping (String) -> Void = { _ in },
        onToggleManualExpansion: @escaping (String) -> Void = { _ in },
        onSubmitActionResolution: @escaping (ActionResolution) -> Bool = { _ in false },
        onMeasuredHeightChange: @escaping (Double) -> Void = { _ in }
    ) {
        self.contentPlan = contentPlan
        self.layoutPlan = layoutPlan
        self.actionRequests = actionRequests
        self.mountsCompletionBodies = mountsCompletionBodies
        self.viewportHeight = viewportHeight
        self.onSelectSession = onSelectSession
        self.onJumpToSession = onJumpToSession
        self.onToggleManualExpansion = onToggleManualExpansion
        self.onSubmitActionResolution = onSubmitActionResolution
        self.onMeasuredHeightChange = onMeasuredHeightChange
    }

    var body: some View {
        let headerLayoutPlan = OriginalExpandedHeaderLayoutPlan.resolve(rootLayoutPlan: layoutPlan)
        let listLayout = OriginalExpandedSessionsListLayoutPlan.original
        let visibility = OriginalExpandedSessionListVisibilityPlan.resolve(contentPlan: contentPlan)
        ScrollViewReader { proxy in
            if listLayout.usesOuterScrollView {
                ScrollView(.vertical, showsIndicators: false) {
                    sessionRows(
                        headerLayoutPlan: headerLayoutPlan,
                        listLayout: listLayout,
                        visibility: visibility
                    )
                }
                // The list is the expanded viewport. Its content may be much
                // taller than the measured surface; the original ScrollView
                // keeps that content inside the surface and exposes it via
                // scrolling instead of allowing the VStack to grow the root.
                .frame(
                    maxWidth: .infinity,
                    maxHeight: viewportHeight.map { CGFloat($0) } ?? .infinity,
                    alignment: .top
                )
                .onChange(of: contentPlan.highlightedID, initial: false) { _, highlightedID in
                    guard case let .center(id, duration) = OriginalSessionsListScrollDecision.resolve(
                        highlightedID: highlightedID
                    ) else {
                        return
                    }
                    withAnimation(.easeOut(duration: duration)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            } else {
                sessionRows(
                    headerLayoutPlan: headerLayoutPlan,
                    listLayout: listLayout,
                    visibility: visibility
                )
            }
        }
        .padding(.horizontal, CGFloat(listLayout.outerHorizontalPadding))
        .padding(.top, CGFloat(headerLayoutPlan.topInset))
        .padding(.vertical, 4)
        .onPreferenceChange(OriginalExpandedMeasuredHeightPreferenceKey.self) { measuredHeight in
            SessionCompletionTraceLog.append(
                stage: "render.expanded.list_measurement",
                sessionId: nil,
                metadata: [
                    "measured": String(measuredHeight),
                    "rowCount": String(describing: visibility.visibleRows.count),
                    "viewportHeight": viewportHeight.map { String(describing: $0) } ?? "nil",
                ]
            )
            guard !visibility.visibleRows.isEmpty, measuredHeight > 0 else { return }
            onMeasuredHeightChange(measuredHeight)
        }
    }

    private func sessionRows(
        headerLayoutPlan: OriginalExpandedHeaderLayoutPlan,
        listLayout: OriginalExpandedSessionsListLayoutPlan,
        visibility: OriginalExpandedSessionListVisibilityPlan
    ) -> some View {
        VStack(alignment: .center, spacing: 4) {
            ForEach(visibility.visibleRows, id: \.id) { row in
                OriginalExpandedSessionCardView(
                    row: row,
                    actionRequests: actionRequests.filter { $0.sessionId == row.id },
                    derivedCollectionCount: contentPlan.sessionRows.count,
                    isFirst: contentPlan.sessionRows.first?.id == row.id,
                    isHighlighted: contentPlan.highlightedID == row.id,
                    mountsCompletionBody: mountsCompletionBodies && contentPlan.completionBodyRowID == row.id,
                    reservesHeaderControls: row.id == visibility.visibleRows.first?.id,
                    onSelectSession: onSelectSession,
                    onJumpToSession: onJumpToSession,
                    onToggleManualExpansion: onToggleManualExpansion,
                    onSubmitActionResolution: onSubmitActionResolution
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CGFloat(listLayout.innerHorizontalPadding))
        .padding(.bottom, 6)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: OriginalExpandedMeasuredHeightPreferenceKey.self,
                    value: Double(geometry.size.height)
                )
            }
        }
    }
}

private struct OriginalExpandedMeasuredHeightPreferenceKey: PreferenceKey {
    static let defaultValue = 0.0

    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}
