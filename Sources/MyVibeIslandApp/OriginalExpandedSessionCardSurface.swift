import MyVibeIslandCore
import SwiftUI

struct OriginalExpandedSessionCardSurface<Content: View>: View {
    let plan: OriginalSessionCardShellPlan
    let fill: OriginalSessionCardShellColor
    let stroke: OriginalSessionCardShellColor
    let animationValue: Bool
    private let content: Content

    init(
        plan: OriginalSessionCardShellPlan,
        fill: OriginalSessionCardShellColor,
        stroke: OriginalSessionCardShellColor,
        animationValue: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.plan = plan
        self.fill = fill
        self.stroke = stroke
        self.animationValue = animationValue
        self.content = content()
    }

    var body: some View {
        OriginalCardContainerView(
            plan: plan,
            fill: fill,
            stroke: stroke,
            animationValue: animationValue
        ) {
            content
        }
    }
}
