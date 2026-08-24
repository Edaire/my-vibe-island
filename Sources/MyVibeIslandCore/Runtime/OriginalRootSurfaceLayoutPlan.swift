public struct OriginalRootSurfaceLayoutPlan: Equatable, Sendable {
    public struct Shadow: Codable, Equatable, Sendable {
        public enum ColorKind: String, Codable, Equatable, Sendable {
            case clear
            case black
        }

        public let colorKind: ColorKind
        public let opacity: Double
        public let radius: Double
        public let x: Double
        public let y: Double

        public init(
            colorKind: ColorKind,
            opacity: Double,
            radius: Double,
            x: Double,
            y: Double
        ) {
            self.colorKind = colorKind
            self.opacity = opacity
            self.radius = radius
            self.x = x
            self.y = y
        }
    }

    public let rootStackSpacing: Double
    public let outerHorizontalInset: Double
    public let innerHorizontalBottomPadding: Double
    public let shape: OriginalNotchShapeParameters
    public let shadow: Shadow
    public let hoverScale: Double
    public let physicalHorizontalOffset: Double
    public let topSeamHeight: Double
    public var topSeamHorizontalInset: Double { shape.topCornerRadius }

    public static func resolve(
        displayState: OriginalIslandDisplayState,
        isHovering: Bool,
        safeAreaTopInset: Double,
        leftStatusSlotWidth: Double,
        rightStatusSlotWidth: Double
    ) -> Self {
        let outerHorizontalInset: Double
        let innerHorizontalBottomPadding: Double
        let shadow: Shadow

        switch displayState {
        case .compact:
            outerHorizontalInset = 10
            innerHorizontalBottomPadding = 0
            shadow = isHovering
                ? Shadow(colorKind: .black, opacity: 0.70, radius: 6, x: 0, y: 0)
                : Shadow(colorKind: .clear, opacity: 0, radius: 0, x: 0, y: 0)

        case .peek:
            outerHorizontalInset = 12
            innerHorizontalBottomPadding = 4
            shadow = Shadow(colorKind: .black, opacity: 0.62, radius: 12, x: 0, y: 4)

        case .expanded:
            outerHorizontalInset = 19
            innerHorizontalBottomPadding = 4
            shadow = Shadow(colorKind: .black, opacity: 0.70, radius: 6, x: 0, y: 0)
        }

        let shape = OriginalNotchShapeParametersResolver().resolve(displayState)
        return Self(
            rootStackSpacing: 0,
            outerHorizontalInset: outerHorizontalInset,
            innerHorizontalBottomPadding: innerHorizontalBottomPadding,
            shape: shape,
            shadow: shadow,
            hoverScale: isHovering && displayState != .expanded ? 1.02 : 1,
            physicalHorizontalOffset: 0,
            topSeamHeight: 1
        )
    }
}

extension OriginalRootSurfaceLayoutPlan: Codable {
    private enum CodingKeys: String, CodingKey {
        case rootStackSpacing
        case outerHorizontalInset
        case innerHorizontalBottomPadding
        case shape
        case shadow
        case hoverScale
        case physicalHorizontalOffset
        case topSeamHeight
        case topSeamHorizontalInset
    }

    private struct CodableShape: Codable {
        let topCornerRadius: Double
        let bottomCornerRadius: Double
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let shape = try container.decode(CodableShape.self, forKey: .shape)

        self.init(
            rootStackSpacing: try container.decode(Double.self, forKey: .rootStackSpacing),
            outerHorizontalInset: try container.decode(Double.self, forKey: .outerHorizontalInset),
            innerHorizontalBottomPadding: try container.decode(
                Double.self,
                forKey: .innerHorizontalBottomPadding
            ),
            shape: OriginalNotchShapeParameters(
                topCornerRadius: shape.topCornerRadius,
                bottomCornerRadius: shape.bottomCornerRadius
            ),
            shadow: try container.decode(Shadow.self, forKey: .shadow),
            hoverScale: try container.decode(Double.self, forKey: .hoverScale),
            physicalHorizontalOffset: try container.decode(
                Double.self,
                forKey: .physicalHorizontalOffset
            ),
            topSeamHeight: try container.decode(Double.self, forKey: .topSeamHeight)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(rootStackSpacing, forKey: .rootStackSpacing)
        try container.encode(outerHorizontalInset, forKey: .outerHorizontalInset)
        try container.encode(innerHorizontalBottomPadding, forKey: .innerHorizontalBottomPadding)
        try container.encode(
            CodableShape(
                topCornerRadius: shape.topCornerRadius,
                bottomCornerRadius: shape.bottomCornerRadius
            ),
            forKey: .shape
        )
        try container.encode(shadow, forKey: .shadow)
        try container.encode(hoverScale, forKey: .hoverScale)
        try container.encode(physicalHorizontalOffset, forKey: .physicalHorizontalOffset)
        try container.encode(topSeamHeight, forKey: .topSeamHeight)
        try container.encode(topSeamHorizontalInset, forKey: .topSeamHorizontalInset)
    }
}
