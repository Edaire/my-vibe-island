import MyVibeIslandCore
import SwiftUI

public struct OriginalCompactRowView: View {
    public let displayClass: OriginalCompactBaseLayoutPlan.DisplayClass
    public let contentPlan: OriginalCompactContentPlan
    public let layoutPlan: OriginalCompactBaseLayoutPlan
    public let rightPresentationPlan: OriginalCompactRightPresentationPlan
    public let layoutMode: OriginalNotchLayoutMode
    public let isMinimized: Bool
    public let completionFlashProgress: Double

    public init(
        displayClass: OriginalCompactBaseLayoutPlan.DisplayClass,
        contentPlan: OriginalCompactContentPlan,
        layoutPlan: OriginalCompactBaseLayoutPlan,
        rightPresentationPlan: OriginalCompactRightPresentationPlan,
        layoutMode: OriginalNotchLayoutMode,
        isMinimized: Bool,
        completionFlashProgress: Double
    ) {
        self.displayClass = displayClass
        self.contentPlan = contentPlan
        self.layoutPlan = layoutPlan
        self.rightPresentationPlan = rightPresentationPlan
        self.layoutMode = layoutMode
        self.isMinimized = isMinimized
        self.completionFlashProgress = completionFlashProgress
    }

    @ViewBuilder
    public var body: some View {
        Group {
            switch displayClass {
            case .physicalNotch:
                if let leadingPadding = layoutPlan.leadingPadding,
                   let centerNotchWidth = layoutPlan.centerNotchWidth {
                    HStack(alignment: .center, spacing: CGFloat(layoutPlan.rootHorizontalSpacing)) {
                        Group {
                            OriginalCompactStatusContainerView(
                                status: contentPlan.status,
                                isMinimized: isMinimized,
                                completionFlashProgress: completionFlashProgress
                            )
                            if layoutPlan.titleVisible, let title = contentPlan.title {
                                OriginalCompactTitleView(plan: title, style: layoutPlan.titleStyle)
                            }
                        }
                        .padding(.leading, CGFloat(leadingPadding))
                        .frame(width: CGFloat(layoutPlan.statusRegionWidth), alignment: .leading)

                        Spacer().frame(minWidth: CGFloat(centerNotchWidth))

                        if let rightRegionWidth = layoutPlan.rightRegionWidth {
                            HStack(alignment: .center, spacing: CGFloat(layoutPlan.rightInnerSpacing)) {
                                OriginalCompactRightPresentationView(plan: rightPresentationPlan)
                            }
                            .padding(.trailing, CGFloat(layoutPlan.rightTrailingPadding))
                            .frame(width: CGFloat(rightRegionWidth), alignment: .trailing)
                        }
                    }
                }

            case .nonNotched:
                HStack(alignment: .center, spacing: CGFloat(layoutPlan.rootHorizontalSpacing)) {
                    OriginalCompactStatusContainerView(
                        status: contentPlan.status,
                        isMinimized: isMinimized,
                        completionFlashProgress: completionFlashProgress
                    )
                    .frame(width: CGFloat(layoutPlan.statusRegionWidth), alignment: .center)

                    if let title = contentPlan.title {
                        OriginalCompactTitleView(plan: title, style: layoutPlan.titleStyle)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.trailing, CGFloat(layoutPlan.titleTrailingPadding!))
                    }

                    HStack(alignment: .center, spacing: CGFloat(layoutPlan.rightInnerSpacing)) {
                        OriginalCompactRightPresentationView(plan: rightPresentationPlan)
                    }
                    .padding(.trailing, CGFloat(layoutPlan.rightTrailingPadding))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: isMinimized)
        .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: layoutMode)
    }
}
