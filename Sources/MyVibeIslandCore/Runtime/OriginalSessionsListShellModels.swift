public struct OriginalSessionsListShellPlan: Equatable, Sendable {
    public enum ScrollAxis: Equatable, Sendable {
        case vertical
    }

    public enum StackAlignment: Equatable, Sendable {
        case center
    }

    public enum PaddingPass: Equatable, Sendable {
        case horizontal(Double)
        case top(Double)
        case bottom(Double)
    }

    public let scrollAxis: ScrollAxis
    public let showsIndicators: Bool
    public let stackAlignment: StackAlignment
    public let stackSpacing: Double
    public let paddingPasses: [PaddingPass]
    public let highlightedIDChangeInitial: Bool

    public static let original = Self(
        scrollAxis: .vertical,
        showsIndicators: false,
        stackAlignment: .center,
        stackSpacing: 4,
        paddingPasses: [.horizontal(8), .top(4), .bottom(6)],
        highlightedIDChangeInitial: false
    )
}

public enum OriginalSessionsListHighlightedIDDecision: Equatable, Sendable {
    public enum Anchor: Equatable, Sendable {
        case center
    }

    public enum Animation: Equatable, Sendable {
        case easeOut(duration: Double)
    }

    case unchanged
    case scrollTo(id: String, anchor: Anchor, animation: Animation)

    public static func resolve(_ highlightedID: String?) -> Self {
        guard let highlightedID else {
            return .unchanged
        }

        return .scrollTo(
            id: highlightedID,
            anchor: .center,
            animation: .easeOut(duration: 0.18)
        )
    }
}

public enum OriginalSessionsListMeasuredHeightDecision: Equatable, Sendable {
    case unchanged
    case replace(with: Double)

    public static func resolve(measured: Double, current: Double?) -> Self {
        abs(measured - (current ?? 0)) > 0.5
            ? .replace(with: measured)
            : .unchanged
    }
}
