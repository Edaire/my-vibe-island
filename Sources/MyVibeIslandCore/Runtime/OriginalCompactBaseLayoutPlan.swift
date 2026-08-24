public enum OriginalNotchLayoutMode: Int, Codable, CaseIterable, Equatable, Sendable {
    case compact = 0
    case normal = 1
}

public struct OriginalCompactBaseLayoutPlan: Codable, Equatable, Sendable {
    public enum DisplayClass: String, Codable, CaseIterable, Equatable, Sendable {
        case physicalNotch
        case nonNotched
    }

    public enum IconKind: String, Codable, Equatable, Sendable {
        case pixelStatusIconCompact
        case pixelStatusIcon
    }

    public enum FontWeight: String, Codable, Equatable, Sendable {
        case medium
    }

    public enum FontDesign: String, Codable, Equatable, Sendable {
        case monospaced
    }

    public enum TruncationMode: String, Codable, Equatable, Sendable {
        case tail
    }

    public struct Glow: Codable, Equatable, Sendable {
        public let opacity: Double
        public let radius: Double

        public init(opacity: Double, radius: Double) {
            self.opacity = opacity
            self.radius = radius
        }
    }

    public struct CompletionFlash: Codable, Equatable, Sendable {
        public let glows: [Glow]
        public let scale: Double

        public init(glows: [Glow], scale: Double) {
            self.glows = glows
            self.scale = scale
        }
    }

    public struct TitleStyle: Codable, Equatable, Sendable {
        public let fontSize: Double
        public let fontWeight: FontWeight
        public let fontDesign: FontDesign
        public let foregroundOpacity: Double
        public let lineLimit: Int?
        public let truncationMode: TruncationMode?

        public init(
            fontSize: Double,
            fontWeight: FontWeight,
            fontDesign: FontDesign,
            foregroundOpacity: Double,
            lineLimit: Int?,
            truncationMode: TruncationMode?
        ) {
            self.fontSize = fontSize
            self.fontWeight = fontWeight
            self.fontDesign = fontDesign
            self.foregroundOpacity = foregroundOpacity
            self.lineLimit = lineLimit
            self.truncationMode = truncationMode
        }
    }

    public let usesCompactArrangement: Bool
    public let iconKind: IconKind
    public let iconFrame: DisplaySize
    public let innerGlows: [Glow]
    public let completionFlash: CompletionFlash
    public let rootHorizontalSpacing: Double
    public let statusRegionWidth: Double
    public let titleVisible: Bool
    public let titleFlexesToMaximumWidth: Bool
    public let titleStyle: TitleStyle
    public let leadingPadding: Double?
    public let titleTrailingPadding: Double?
    public let centerNotchWidth: Double?
    public let rightRegionWidth: Double?
    public let rightInnerSpacing: Double
    public let rightTrailingPadding: Double

    public static func resolve(
        displayClass: DisplayClass,
        layoutMode: OriginalNotchLayoutMode,
        isMinimized: Bool,
        hasActionableCount: Bool,
        hasSessions: Bool,
        screenNotchWidth: Double,
        notchWidthOffset: Double,
        completionFlashProgress: Double
    ) -> Self {
        let usesCompactArrangement = isMinimized || layoutMode == .compact
        let iconKind: IconKind = isMinimized ? .pixelStatusIconCompact : .pixelStatusIcon
        let iconFrame = DisplaySize(width: isMinimized ? 20 : 32, height: 20)
        let innerGlows = isMinimized
            ? [Glow(opacity: 0.5, radius: 2), Glow(opacity: 0.25, radius: 6)]
            : [Glow(opacity: 0.5, radius: 3), Glow(opacity: 0.2, radius: 8)]
        let completionFlash = CompletionFlash(
            glows: [
                Glow(opacity: completionFlashProgress, radius: 7),
                Glow(opacity: 0.6 * completionFlashProgress, radius: 13),
            ],
            scale: 1 + 0.18 * completionFlashProgress
        )

        switch displayClass {
        case .physicalNotch:
            return Self(
                usesCompactArrangement: usesCompactArrangement,
                iconKind: iconKind,
                iconFrame: iconFrame,
                innerGlows: innerGlows,
                completionFlash: completionFlash,
                rootHorizontalSpacing: 6,
                statusRegionWidth: isMinimized ? 22 : layoutMode == .compact ? 36 : 100,
                titleVisible: !usesCompactArrangement,
                titleFlexesToMaximumWidth: false,
                titleStyle: TitleStyle(
                    fontSize: 10,
                    fontWeight: .medium,
                    fontDesign: .monospaced,
                    foregroundOpacity: 0.9,
                    lineLimit: 1,
                    truncationMode: .tail
                ),
                leadingPadding: usesCompactArrangement ? 2 : 8,
                titleTrailingPadding: nil,
                centerNotchWidth: max(screenNotchWidth + notchWidthOffset, 40),
                rightRegionWidth: isMinimized
                    ? 22
                    : layoutMode == .compact ? hasActionableCount ? 36 : 18 : 100,
                rightInnerSpacing: usesCompactArrangement ? 2 : 6,
                rightTrailingPadding: usesCompactArrangement ? 2 : 8
            )

        case .nonNotched:
            return Self(
                usesCompactArrangement: usesCompactArrangement,
                iconKind: iconKind,
                iconFrame: iconFrame,
                innerGlows: innerGlows,
                completionFlash: completionFlash,
                rootHorizontalSpacing: 0,
                statusRegionWidth: isMinimized ? 28 : layoutMode == .compact ? 36 : 60,
                titleVisible: true,
                titleFlexesToMaximumWidth: true,
                titleStyle: TitleStyle(
                    fontSize: 11,
                    fontWeight: .medium,
                    fontDesign: .monospaced,
                    foregroundOpacity: hasSessions ? 1 : 0.6,
                    lineLimit: hasSessions ? 1 : nil,
                    truncationMode: hasSessions ? .tail : nil
                ),
                leadingPadding: nil,
                titleTrailingPadding: 8,
                centerNotchWidth: nil,
                rightRegionWidth: nil,
                rightInnerSpacing: usesCompactArrangement ? 2 : 6,
                rightTrailingPadding: 8
            )
        }
    }
}
