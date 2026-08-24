public struct OriginalPixelStatusIconCompact: Equatable, Sendable {
    public static let gridWidth = 8
    public static let gridHeight = 8
    public static let frameWidth = 20
    public static let frameHeight = 20

    public let status: OriginalPixelStatusCompact

    public init(status: OriginalPixelStatusCompact) {
        self.status = status
    }

    public var frame: OriginalPixelStatusIconCompactFrame {
        let primaryColor = OriginalPixelStatusPalette.colors(for: status).primary
        return OriginalPixelStatusIconCompactFrame(
            primaryColor: primaryColor,
            blackSamples: Self.blackCoordinates.map {
                OriginalPixelSample(coordinate: $0, color: Self.black)
            },
            primarySamples: Self.primaryCoordinates.map {
                OriginalPixelSample(coordinate: $0, color: primaryColor)
            }
        )
    }

    public static func pixelRect(
        for coordinate: OriginalPixelCoordinate,
        canvasWidth: Double,
        canvasHeight: Double
    ) -> OriginalPixelRect {
        let unit = min(canvasWidth, canvasHeight) / Double(gridWidth)
        let originX = (canvasWidth - Double(gridWidth) * unit) / 2
        let originY = (canvasHeight - Double(gridHeight) * unit) / 2
        return OriginalPixelRect(
            x: originX + Double(coordinate.x) * unit + 0.15,
            y: originY + Double(coordinate.y) * unit + 0.15,
            width: unit - 0.3,
            height: unit - 0.3
        )
    }

    private static let black = OriginalPixelColor(red: 0, green: 0, blue: 0)
    private static let blackCoordinates = [
        OriginalPixelCoordinate(x: 2, y: 2),
        OriginalPixelCoordinate(x: 5, y: 2),
        OriginalPixelCoordinate(x: 2, y: 3),
        OriginalPixelCoordinate(x: 5, y: 3)
    ]
    private static let primaryCoordinates = [
        OriginalPixelCoordinate(x: 1, y: 3),
        OriginalPixelCoordinate(x: 2, y: 3),
        OriginalPixelCoordinate(x: 3, y: 3),
        OriginalPixelCoordinate(x: 4, y: 3),
        OriginalPixelCoordinate(x: 5, y: 3),
        OriginalPixelCoordinate(x: 6, y: 3),
        OriginalPixelCoordinate(x: 1, y: 4),
        OriginalPixelCoordinate(x: 2, y: 4),
        OriginalPixelCoordinate(x: 3, y: 4),
        OriginalPixelCoordinate(x: 4, y: 4),
        OriginalPixelCoordinate(x: 5, y: 4),
        OriginalPixelCoordinate(x: 6, y: 4),
        OriginalPixelCoordinate(x: 2, y: 5),
        OriginalPixelCoordinate(x: 3, y: 5),
        OriginalPixelCoordinate(x: 5, y: 5),
        OriginalPixelCoordinate(x: 6, y: 5)
    ]
}

public struct OriginalPixelStatusIconCompactFrame: Equatable, Sendable {
    public let primaryColor: OriginalPixelColor
    public let blackSamples: [OriginalPixelSample]
    public let primarySamples: [OriginalPixelSample]

    public init(
        primaryColor: OriginalPixelColor,
        blackSamples: [OriginalPixelSample],
        primarySamples: [OriginalPixelSample]
    ) {
        self.primaryColor = primaryColor
        self.blackSamples = blackSamples
        self.primarySamples = primarySamples
    }
}

public struct OriginalPixelRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
