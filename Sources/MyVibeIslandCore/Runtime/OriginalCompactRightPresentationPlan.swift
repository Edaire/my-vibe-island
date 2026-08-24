public enum OriginalCompactRightPresentationPlan: Equatable, Sendable {
    public enum HorizontalAlignment: Equatable, Sendable {
        case center
    }

    public enum FontWeight: Equatable, Sendable {
        case medium
        case semibold
    }

    public enum FontDesign: Equatable, Sendable {
        case monospaced
    }

    public enum CapsuleStyle: Equatable, Sendable {
        case continuous
    }

    public enum ScaleAnchor: Equatable, Sendable {
        case center
    }

    public struct Color: Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let opacity: Double

        public init(red: Double, green: Double, blue: Double, opacity: Double) {
            self.red = red
            self.green = green
            self.blue = blue
            self.opacity = opacity
        }
    }

    public struct Font: Equatable, Sendable {
        public let size: Double
        public let weight: FontWeight
        public let design: FontDesign

        public init(size: Double, weight: FontWeight, design: FontDesign) {
            self.size = size
            self.weight = weight
            self.design = design
        }
    }

    public struct Actionable: Equatable, Sendable {
        public let countText: String?
        public let foregroundColor: Color
        public let backgroundColor: Color
        public let symbolName: String
        public let symbolSystemSize: Double
        public let countFont: Font?
        public let horizontalPadding: Double
        public let verticalPadding: Double
        public let capsuleStyle: CapsuleStyle

        public init(
            countText: String?,
            foregroundColor: Color,
            backgroundColor: Color,
            symbolName: String,
            symbolSystemSize: Double,
            countFont: Font?,
            horizontalPadding: Double,
            verticalPadding: Double,
            capsuleStyle: CapsuleStyle
        ) {
            self.countText = countText
            self.foregroundColor = foregroundColor
            self.backgroundColor = backgroundColor
            self.symbolName = symbolName
            self.symbolSystemSize = symbolSystemSize
            self.countFont = countFont
            self.horizontalPadding = horizontalPadding
            self.verticalPadding = verticalPadding
            self.capsuleStyle = capsuleStyle
        }
    }

    public struct Sessions: Equatable, Sendable {
        public struct Label: Equatable, Sendable {
            public let key: String
            public let englishFallback: String
            public let font: Font
            public let color: Color

            public init(key: String, englishFallback: String, font: Font, color: Color) {
                self.key = key
                self.englishFallback = englishFallback
                self.font = font
                self.color = color
            }
        }

        public let countText: String
        public let countFont: Font
        public let countColor: Color
        public let label: Label?

        public init(countText: String, countFont: Font, countColor: Color, label: Label?) {
            self.countText = countText
            self.countFont = countFont
            self.countColor = countColor
            self.label = label
        }
    }

    public struct CompletionIndicator: Equatable, Sendable {
        public struct Glow: Equatable, Sendable {
            public let color: Color
            public let radius: Double

            public init(color: Color, radius: Double) {
                self.color = color
                self.radius = radius
            }
        }

        public struct Transition: Equatable, Sendable {
            public let scaleAnchor: ScaleAnchor
            public let initialScale: Double
            public let combinesOpacity: Bool

            public init(
                scaleAnchor: ScaleAnchor,
                initialScale: Double,
                combinesOpacity: Bool
            ) {
                self.scaleAnchor = scaleAnchor
                self.initialScale = initialScale
                self.combinesOpacity = combinesOpacity
            }
        }

        public let color: Color
        public let frame: DisplaySize
        public let glow: Glow
        public let transition: Transition

        public init(color: Color, frame: DisplaySize, glow: Glow, transition: Transition) {
            self.color = color
            self.frame = frame
            self.glow = glow
            self.transition = transition
        }
    }

    case none
    case actionable(Actionable)
    case completionIndicator(CompletionIndicator)
    case sessions(Sessions)

    public var horizontalAlignment: HorizontalAlignment { .center }
    public var horizontalSpacing: Double { 3 }

    public static func resolve(
        rightCount: OriginalCompactRightCount?,
        usesCompactArrangement: Bool,
        showsUnreadCompletionOverview: Bool
    ) -> Self {
        guard let rightCount else { return .none }

        switch rightCount.source {
        case .actionable:
            return .actionable(actionablePlan(
                count: rightCount.count,
                usesCompactArrangement: usesCompactArrangement
            ))

        case .sessions where showsUnreadCompletionOverview:
            return .completionIndicator(completionIndicatorPlan)

        case .sessions:
            return .sessions(sessionsPlan(
                count: rightCount.count,
                usesCompactArrangement: usesCompactArrangement
            ))
        }
    }

    private static let orange = Color(red: 0.98, green: 0.45, blue: 0.09, opacity: 1)
    private static let orangeBackground = Color(red: 0.98, green: 0.45, blue: 0.09, opacity: 0.2)
    private static let green = Color(red: 0.13, green: 0.77, blue: 0.37, opacity: 1)
    private static let translucentGreen = Color(red: 0.13, green: 0.77, blue: 0.37, opacity: 0.6)
    private static let white = Color(red: 1, green: 1, blue: 1, opacity: 1)
    private static let translucentWhite = Color(red: 1, green: 1, blue: 1, opacity: 0.7)

    private static func actionablePlan(count: Int, usesCompactArrangement: Bool) -> Actionable {
        Actionable(
            countText: usesCompactArrangement ? nil : String(count),
            foregroundColor: orange,
            backgroundColor: orangeBackground,
            symbolName: "bell.fill",
            symbolSystemSize: usesCompactArrangement ? 9 : 10,
            countFont: usesCompactArrangement
                ? nil
                : Font(size: 10, weight: .medium, design: .monospaced),
            horizontalPadding: usesCompactArrangement ? 2 : 7,
            verticalPadding: 3,
            capsuleStyle: .continuous
        )
    }

    private static func sessionsPlan(count: Int, usesCompactArrangement: Bool) -> Sessions {
        let label: Sessions.Label? = usesCompactArrangement
            ? nil
            : Sessions.Label(
                key: count == 1 ? "content.session" : "content.sessions",
                englishFallback: count == 1 ? "session" : "sessions",
                font: Font(size: 9, weight: .medium, design: .monospaced),
                color: translucentWhite
            )

        return Sessions(
            countText: String(count),
            countFont: Font(size: 11, weight: .semibold, design: .monospaced),
            countColor: white,
            label: label
        )
    }

    private static let completionIndicatorPlan = CompletionIndicator(
        color: green,
        frame: DisplaySize(width: 7, height: 7),
        glow: .init(color: translucentGreen, radius: 3),
        transition: .init(
            scaleAnchor: .center,
            initialScale: 0.00001,
            combinesOpacity: true
        )
    )
}
