import Foundation
import SwiftUI
import MyVibeIslandCore

public struct OriginalCompactTitleView: View {
    public let plan: OriginalCompactTitlePlan
    public let style: OriginalCompactBaseLayoutPlan.TitleStyle

    public init(
        plan: OriginalCompactTitlePlan,
        style: OriginalCompactBaseLayoutPlan.TitleStyle
    ) {
        self.plan = plan
        self.style = style
    }

    @ViewBuilder
    public var body: some View {
        let title = Self.concreteTitle(for: plan)
        let text = Text(title)
            .font(.system(size: style.fontSize, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.white.opacity(style.foregroundOpacity))

        if let lineLimit = style.lineLimit {
            if style.truncationMode == .tail {
                text
                    .lineLimit(lineLimit)
                    .truncationMode(.tail)
            } else {
                text.lineLimit(lineLimit)
            }
        } else if style.truncationMode == .tail {
            text.truncationMode(.tail)
        } else {
            text
        }
    }

    static func concreteTitle(for plan: OriginalCompactTitlePlan) -> String {
        let concrete: String
        switch plan.content {
        case let .verbatim(value):
            concrete = value
        case let .localized(key, englishFallback, formatArgument):
            let localized = NSLocalizedString(
                key,
                tableName: nil,
                bundle: .module,
                value: englishFallback,
                comment: ""
            )
            if let formatArgument {
                concrete = String(format: localized, locale: nil, arguments: [formatArgument])
            } else {
                concrete = localized
            }
        }

        return plan.transform.apply(to: concrete)
    }
}
