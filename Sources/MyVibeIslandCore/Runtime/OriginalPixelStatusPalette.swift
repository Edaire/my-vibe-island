public struct OriginalPixelStatusPalette: Equatable, Sendable {
    public let primary: OriginalPixelColor
    public let secondary: OriginalPixelColor

    public init(primary: OriginalPixelColor, secondary: OriginalPixelColor) {
        self.primary = primary
        self.secondary = secondary
    }

    public static func colors(for status: OriginalPixelStatusCompact) -> Self {
        switch status {
        case .waitingForInput:
            Self(primary: color(0.13, 0.77, 0.37), secondary: color(0.29, 0.87, 0.5))
        case .processing, .runningTool:
            Self(primary: color(0.23, 0.51, 0.96), secondary: color(0.38, 0.65, 0.98))
        case .thinking, .compacting:
            Self(primary: color(0.66, 0.33, 0.97), secondary: color(0.75, 0.52, 0.99))
        case .waitingForApproval, .question:
            Self(primary: color(0.98, 0.45, 0.09), secondary: color(0.98, 0.57, 0.24))
        case .ended, .unknown:
            Self(primary: color(0.45, 0.45, 0.45), secondary: color(0.6, 0.6, 0.6))
        }
    }

    private static func color(_ red: Double, _ green: Double, _ blue: Double) -> OriginalPixelColor {
        OriginalPixelColor(red: red, green: green, blue: blue)
    }
}
