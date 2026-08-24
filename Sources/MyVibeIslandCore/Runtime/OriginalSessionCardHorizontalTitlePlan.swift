public struct OriginalSessionCardHorizontalTitlePlan: Equatable, Sendable {
    public enum Weight: Equatable, Sendable {
        case medium
    }

    public enum Color: Equatable, Sendable {
        case white(opacity: Double)
    }

    public struct Segment: Equatable, Sendable {
        public let prefix: String
        public let value: String
        public let foreground: Color?
    }

    public let systemFontSize: Double
    public let systemFontWeight: Weight
    public let foreground: Color
    public let segments: [Segment]

    public var concatenatedText: String {
        segments.map { $0.prefix + $0.value }.joined()
    }

    public static func resolve(
        baseTitle: String,
        showModelInPanel: Bool,
        modelLabel: String?,
        repositoryLabel: String?
    ) -> Self {
        var segments = [Segment(prefix: "", value: baseTitle, foreground: nil)]

        if showModelInPanel, let modelLabel {
            segments.append(
                Segment(
                    prefix: " ⎇ ",
                    value: modelLabel,
                    foreground: .white(opacity: 0.5)
                )
            )
        }

        if let repositoryLabel {
            segments.append(
                Segment(prefix: " · ", value: repositoryLabel, foreground: nil)
            )
        }

        return Self(
            systemFontSize: 12,
            systemFontWeight: .medium,
            foreground: .white(opacity: 0.7),
            segments: segments
        )
    }
}
