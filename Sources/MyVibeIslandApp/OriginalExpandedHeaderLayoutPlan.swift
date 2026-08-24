import MyVibeIslandCore

struct OriginalExpandedHeaderLayoutPlan: Equatable, Sendable {
    let topInset: Double
    let visualTopOffset: Double
    let statusIconWidth: Double
    let statusIconLeadingCompensation: Double
    let rowSpacing: Double
    let contentSpacing: Double

    static func resolve(rootLayoutPlan: OriginalRootSurfaceLayoutPlan) -> Self {
        Self(
            topInset: rootLayoutPlan.innerHorizontalBottomPadding
                + OriginalExpandedSessionLayoutPlan.original.controlFrame
                + OriginalExpandedSessionLayoutPlan.original.controlSpacing,
            visualTopOffset: rootLayoutPlan.shape.topCornerRadius,
            statusIconWidth: rootLayoutPlan.outerHorizontalInset
                + rootLayoutPlan.innerHorizontalBottomPadding,
            statusIconLeadingCompensation: (rootLayoutPlan.outerHorizontalInset
                + rootLayoutPlan.innerHorizontalBottomPadding) / 2,
            rowSpacing: 8,
            contentSpacing: 4
        )
    }
}
