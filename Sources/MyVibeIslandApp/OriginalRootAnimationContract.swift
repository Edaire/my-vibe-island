import MyVibeIslandCore

/// The root animation keys recovered from the original Notch root.
///
/// The original binds layout mode twice: once to select the geometry curve,
/// then again with the minimized-layout curve. It also keeps expanded and
/// compact height targets as separate animation values.
struct OriginalRootAnimationContract: Equatable {
    struct Spring: Equatable {
        let response: Double
        let dampingFraction: Double
    }

    enum Curve: Equatable {
        case expanded
        case nonExpanded
    }

    let displayStatusTarget: OriginalIslandDisplayState
    let displayStatusCurve: Curve
    let expandedWidthTarget: Double
    let expandedHeightTarget: Double
    let visibleSurfaceHeightTarget: Double

    /// Recovered from V3 `NotchContentView.body` (`sub_1006C5718`):
    /// `Animation.spring(0.25, 0.7, 0)` bound to `NotchViewModel._isHovering`.
    static let rootHoverSpring = Spring(response: 0.25, dampingFraction: 0.7)

    static func resolve(
        displayState: OriginalIslandDisplayState,
        fittingWidth: Double,
        fittingHeight: Double,
        visibleSurfaceHeight: Double? = nil
    ) -> Self {
        Self(
            displayStatusTarget: displayState,
            displayStatusCurve: displayState == .expanded ? .expanded : .nonExpanded,
            expandedWidthTarget: fittingWidth,
            expandedHeightTarget: fittingHeight,
            visibleSurfaceHeightTarget: visibleSurfaceHeight ?? fittingHeight
        )
    }
}
