public struct OriginalSessionCardShellPlan: Equatable, Sendable {
    public enum Axis: Equatable, Sendable {
        case horizontal
        case vertical
    }

    public enum Alignment: Equatable, Sendable {
        case center
    }

    public enum PaddingPass: Equatable, Sendable {
        case horizontal(Double)
        case vertical(Double)
    }

    public enum CornerStyle: Equatable, Sendable {
        case continuous
    }

    public enum Animation: Equatable, Sendable {
        case easeInOut(duration: Double)
    }

    public let axis: Axis
    let alignment: Alignment
    let spacing: Double
    let paddingPasses: [PaddingPass]
    let cornerStyle: CornerStyle
    let cornerRadius: Double
    let strokeWidth: Double
    let animation: Animation

    private static let branchAnimation = Animation.easeInOut(duration: 0.15)

    public static let horizontalBranch = Self(
        axis: .horizontal,
        alignment: .center,
        spacing: 8,
        paddingPasses: [.horizontal(8), .vertical(6)],
        cornerStyle: .continuous,
        cornerRadius: 10,
        strokeWidth: 1,
        animation: branchAnimation
    )

    public static let verticalBranch = Self(
        axis: .vertical,
        alignment: .center,
        spacing: 8,
        paddingPasses: [.horizontal(8), .vertical(8)],
        cornerStyle: .continuous,
        cornerRadius: 10,
        strokeWidth: 1,
        animation: branchAnimation
    )
}

public enum OriginalSessionCardShellColor: Equatable, Sendable {
    case clear
    case white(opacity: Double)
}

public struct OriginalSessionCardHorizontalVisualDecision: Equatable, Sendable {
    public let isHighlighted: Bool
    public let emphasized: Bool
    public let fill: OriginalSessionCardShellColor
    public let stroke: OriginalSessionCardShellColor
    public let animationValue: Bool
    public let animation: OriginalSessionCardShellPlan.Animation

    public static func resolve(
        isHovered: Bool,
        cardID: String,
        highlightedID: String?
    ) -> Self {
        let isHighlighted = highlightedID != nil && highlightedID == cardID
        let emphasized = isHovered || isHighlighted

        return Self(
            isHighlighted: isHighlighted,
            emphasized: emphasized,
            fill: emphasized ? .white(opacity: 0.08) : .clear,
            stroke: isHighlighted
                ? .white(opacity: 0.25)
                : isHovered ? .white(opacity: 0.06) : .clear,
            animationValue: emphasized,
            animation: OriginalSessionCardShellPlan.horizontalBranch.animation
        )
    }
}

public struct OriginalSessionCardVerticalVisualDecision: Equatable, Sendable {
    public let isHighlighted: Bool
    public let emphasized: Bool
    public let fill: OriginalSessionCardShellColor
    public let stroke: OriginalSessionCardShellColor
    public let animationValue: Bool
    public let animation: OriginalSessionCardShellPlan.Animation

    public static func resolve(
        isHovered: Bool,
        isApprovalHovered: Bool,
        cardID: String,
        highlightedID: String?
    ) -> Self {
        let isHighlighted = highlightedID != nil && highlightedID == cardID
        let emphasized = (isHovered && isApprovalHovered) || isHighlighted

        return Self(
            isHighlighted: isHighlighted,
            emphasized: emphasized,
            fill: emphasized ? .white(opacity: 0.10) : .clear,
            stroke: isHighlighted
                ? .white(opacity: 0.25)
                : isHovered && !isApprovalHovered
                    ? .white(opacity: 0.08)
                    : .clear,
            animationValue: emphasized,
            animation: OriginalSessionCardShellPlan.verticalBranch.animation
        )
    }
}
