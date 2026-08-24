import MyVibeIslandCore
import SwiftUI

public struct OriginalCompactRightPresentationView: View {
    public let plan: OriginalCompactRightPresentationPlan

    public init(plan: OriginalCompactRightPresentationPlan) {
        self.plan = plan
    }

    public var body: some View {
        HStack(alignment: .center, spacing: CGFloat(plan.horizontalSpacing)) {
            switch plan {
            case .none:
                EmptyView()

            case let .actionable(actionable):
                HStack(alignment: .center, spacing: CGFloat(plan.horizontalSpacing)) {
                    Image(systemName: actionable.symbolName)
                        .font(.system(size: CGFloat(actionable.symbolSystemSize)))

                    if let countText = actionable.countText,
                       let countFont = actionable.countFont {
                        Text(countText)
                            .font(countFont.swiftUIFont)
                    }
                }
                .foregroundStyle(Color(
                    red: actionable.foregroundColor.red,
                    green: actionable.foregroundColor.green,
                    blue: actionable.foregroundColor.blue,
                    opacity: actionable.foregroundColor.opacity
                ))
                .padding(.horizontal, CGFloat(actionable.horizontalPadding))
                .padding(.vertical, CGFloat(actionable.verticalPadding))
                .background(
                    Color(
                        red: actionable.backgroundColor.red,
                        green: actionable.backgroundColor.green,
                        blue: actionable.backgroundColor.blue,
                        opacity: actionable.backgroundColor.opacity
                    ),
                    in: Capsule(style: .continuous)
                )

            case let .completionIndicator(completion):
                Color(
                    red: completion.color.red,
                    green: completion.color.green,
                    blue: completion.color.blue,
                    opacity: completion.color.opacity
                )
                .frame(
                    width: CGFloat(completion.frame.width),
                    height: CGFloat(completion.frame.height)
                )
                .shadow(
                    color: Color(
                        red: completion.glow.color.red,
                        green: completion.glow.color.green,
                        blue: completion.glow.color.blue,
                        opacity: completion.glow.color.opacity
                    ),
                    radius: CGFloat(completion.glow.radius),
                    x: 0,
                    y: 0
                )
                .transition(
                    .scale(
                        scale: CGFloat(completion.transition.initialScale),
                        anchor: .center
                    )
                    .combined(with: .opacity)
                )

            case let .sessions(sessions):
                Text(sessions.countText)
                    .font(sessions.countFont.swiftUIFont)
                    .foregroundStyle(Color(
                        red: sessions.countColor.red,
                        green: sessions.countColor.green,
                        blue: sessions.countColor.blue,
                        opacity: sessions.countColor.opacity
                    ))

                if let label = sessions.label {
                    Text(NSLocalizedString(
                        label.key,
                        bundle: Bundle.module,
                        value: label.englishFallback,
                        comment: ""
                    ))
                    .font(label.font.swiftUIFont)
                    .foregroundStyle(Color(
                        red: label.color.red,
                        green: label.color.green,
                        blue: label.color.blue,
                        opacity: label.color.opacity
                    ))
                }
            }
        }
    }
}

private extension OriginalCompactRightPresentationPlan.Font {
    var swiftUIFont: SwiftUI.Font {
        let swiftUIWeight: SwiftUI.Font.Weight
        switch weight {
        case .medium: swiftUIWeight = .medium
        case .semibold: swiftUIWeight = .semibold
        }

        return .system(
            size: CGFloat(size),
            weight: swiftUIWeight,
            design: .monospaced
        )
    }
}
