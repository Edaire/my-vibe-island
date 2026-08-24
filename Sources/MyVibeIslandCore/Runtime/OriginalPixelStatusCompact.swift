public enum OriginalPixelStatusCompact: Int, CaseIterable, Codable, Equatable, Sendable {
    case waitingForInput = 0
    case processing = 1
    case thinking = 2
    case runningTool = 3
    case waitingForApproval = 4
    case question = 5
    case compacting = 6
    case ended = 7
    case unknown = 8

    public static let gridWidth = 13
    public static let gridHeight = 8
    public static let frameInterval = 0.15

    public static func frame(for status: Self, at frameIndex: Int) -> OriginalPixelStatusFrame {
        let frame = max(frameIndex, 0)
        let colors = colors(for: status)
        var samples = faceSamples(for: status, frame: frame, colors: colors)
        samples += branchSamples(for: status, frame: frame, colors: colors)
        return OriginalPixelStatusFrame(
            primaryColor: colors.primary,
            secondaryColor: colors.secondary,
            samples: samples,
            statusFlag: statusFlag(for: status, frame: frame)
        )
    }
}

public struct OriginalPixelCoordinate: Codable, Equatable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        x = try values.decode(Int.self)
        y = try values.decode(Int.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.unkeyedContainer()
        try values.encode(x)
        try values.encode(y)
    }
}

public struct OriginalPixelColor: Codable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        red = try values.decode(Double.self)
        green = try values.decode(Double.self)
        blue = try values.decode(Double.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.unkeyedContainer()
        try values.encode(red)
        try values.encode(green)
        try values.encode(blue)
    }
}

public struct OriginalPixelSample: Codable, Equatable, Sendable {
    public let coordinate: OriginalPixelCoordinate
    public let color: OriginalPixelColor
    public let opacity: Double

    public init(coordinate: OriginalPixelCoordinate, color: OriginalPixelColor, opacity: Double = 1) {
        self.coordinate = coordinate
        self.color = color
        self.opacity = opacity
    }

    public init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        coordinate = try values.decode(OriginalPixelCoordinate.self)
        color = try values.decode(OriginalPixelColor.self)
        opacity = try values.decode(Double.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.unkeyedContainer()
        try values.encode(coordinate)
        try values.encode(color)
        try values.encode(opacity)
    }
}

public struct OriginalPixelStatusFrame: Equatable, Sendable {
    public let primaryColor: OriginalPixelColor
    public let secondaryColor: OriginalPixelColor
    public let samples: [OriginalPixelSample]
    public let statusFlag: OriginalPixelStatusFlag?

    public init(
        primaryColor: OriginalPixelColor,
        secondaryColor: OriginalPixelColor,
        samples: [OriginalPixelSample],
        statusFlag: OriginalPixelStatusFlag? = nil
    ) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.samples = samples
        self.statusFlag = statusFlag
    }
}

public struct OriginalPixelStatusFlag: Codable, Equatable, Sendable {
    public let mode: Int
    public let active: Bool

    public init(mode: Int, active: Bool) {
        self.mode = mode
        self.active = active
    }
}

private extension OriginalPixelStatusCompact {
    typealias Colors = (primary: OriginalPixelColor, secondary: OriginalPixelColor)

    static let secondaryPixels = [point(2, 2), point(5, 2)]
    static let upperPrimaryPixels = [
        point(1, 3), point(2, 3), point(3, 3), point(4, 3), point(5, 3), point(6, 3),
        point(1, 4), point(2, 4), point(3, 4), point(4, 4), point(5, 4), point(6, 4)
    ]
    static let lowerDefault = [point(2, 5), point(3, 5), point(5, 5), point(6, 5)]
    static let lowerSetA = [point(2, 5), point(3, 5), point(4, 5), point(5, 5)]
    static let lowerSetB = [point(1, 5), point(2, 5), point(5, 5), point(6, 5)]
    static let black = color(0, 0, 0)
    static let rotatingRing = [
        point(10, 2), point(11, 2), point(12, 3), point(12, 4),
        point(11, 5), point(10, 5), point(9, 4), point(9, 3)
    ]

    static func colors(for status: Self) -> Colors {
        switch status {
        case .waitingForInput:
            (color(0.13, 0.77, 0.37), color(0.29, 0.87, 0.5))
        case .processing, .runningTool:
            (color(0.23, 0.51, 0.96), color(0.38, 0.65, 0.98))
        case .thinking, .compacting:
            (color(0.66, 0.33, 0.97), color(0.75, 0.52, 0.99))
        case .waitingForApproval, .question:
            (color(0.98, 0.45, 0.09), color(0.98, 0.57, 0.24))
        case .ended, .unknown:
            (color(0.45, 0.45, 0.45), color(0.6, 0.6, 0.6))
        }
    }

    static func faceSamples(for status: Self, frame: Int, colors: Colors) -> [OriginalPixelSample] {
        samples(at: secondaryPixels, color: colors.secondary)
            + samples(at: upperPrimaryPixels + lowerPixels(for: status, frame: frame), color: colors.primary)
            + blackOverlaySamples(for: status, frame: frame)
    }

    static func lowerPixels(for status: Self, frame: Int) -> [OriginalPixelCoordinate] {
        switch status {
        case .processing:
            return switch frame % 4 {
            case 1: lowerSetB
            case 3: lowerSetA
            default: lowerDefault
            }
        case .thinking, .question:
            return ((frame / 3) & 1) == 0 ? lowerDefault : lowerSetB
        case .runningTool, .waitingForApproval:
            return frame % 3 == 1 ? lowerSetB : lowerDefault
        case .waitingForInput, .compacting, .ended, .unknown:
            return lowerDefault
        }
    }

    static func blackOverlaySamples(for status: Self, frame: Int) -> [OriginalPixelSample] {
        let pixels: [OriginalPixelCoordinate]
        switch status {
        case .waitingForInput:
            if frame % 16 < 2 {
                pixels = []
            } else if (50...52).contains(frame) {
                pixels = [point(3, 3), point(6, 3)]
            } else {
                pixels = [point(2, 3), point(5, 3)]
            }
        case .processing, .runningTool:
            pixels = frame & 4 == 0
                ? [point(3, 3), point(6, 3)]
                : [point(1, 3), point(4, 3)]
        case .thinking, .question:
            pixels = []
        case .waitingForApproval, .compacting, .ended, .unknown:
            pixels = []
        }
        return samples(at: pixels, color: black)
    }

    static func branchSamples(for status: Self, frame: Int, colors: Colors) -> [OriginalPixelSample] {
        switch status {
        case .waitingForInput:
            return frame % 8 < 5
                ? samples(at: [point(10, 2), point(11, 2), point(10, 3), point(11, 3), point(10, 4), point(11, 4), point(10, 5), point(11, 5)], color: colors.primary)
                : []
        case .processing, .runningTool:
            return ringSamples(frame: frame, colors: colors)
        case .thinking:
            let opacity = frame % 6 < 3 ? 1.0 : 0.6
            return samples(at: [
                point(10, 2), point(11, 2), point(9, 3), point(10, 3), point(11, 3), point(12, 3),
                point(9, 4), point(10, 4), point(11, 4), point(12, 4), point(10, 5), point(11, 5)
            ], color: colors.primary, opacity: opacity)
        case .waitingForApproval, .question, .unknown:
            var pixels = [point(10, 1), point(11, 1), point(9, 2), point(12, 2), point(12, 3), point(11, 4)]
            if frame % 6 <= 3 {
                pixels += [point(10, 6), point(11, 6)]
            }
            return samples(at: pixels, color: colors.primary)
        case .compacting:
            return (0..<4).map { index in
                let pixel = rotatingRing[(frame - index).modulo(rotatingRing.count)]
                return OriginalPixelSample(
                    coordinate: pixel,
                    color: colors.primary,
                    opacity: 1 - Double(index) * 0.25
                )
            }
        case .ended:
            return samples(at: [
                point(9, 2), point(12, 2), point(10, 3), point(11, 3),
                point(10, 4), point(11, 4), point(9, 5), point(12, 5)
            ], color: colors.primary)
        }
    }

    static func statusFlag(for status: Self, frame: Int) -> OriginalPixelStatusFlag? {
        switch status {
        case .waitingForApproval:
            OriginalPixelStatusFlag(mode: 3, active: frame % 8 <= 3)
        case .question:
            OriginalPixelStatusFlag(mode: 2, active: frame % 8 < 4)
        case .unknown:
            OriginalPixelStatusFlag(mode: 0, active: false)
        case .waitingForInput, .processing, .thinking, .runningTool, .compacting, .ended:
            nil
        }
    }

    static func ringSamples(frame: Int, colors: Colors) -> [OriginalPixelSample] {
        (0..<rotatingRing.count).map { index in
            OriginalPixelSample(
                coordinate: rotatingRing[(frame - index).modulo(rotatingRing.count)],
                color: colors.primary,
                opacity: Double(100 - index * 12) / 100
            )
        } + samples(at: [point(10, 3), point(11, 3), point(10, 4), point(11, 4)], color: colors.secondary)
    }

    static func samples(
        at coordinates: [OriginalPixelCoordinate],
        color: OriginalPixelColor,
        opacity: Double = 1
    ) -> [OriginalPixelSample] {
        coordinates.map { OriginalPixelSample(coordinate: $0, color: color, opacity: opacity) }
    }

    static func point(_ x: Int, _ y: Int) -> OriginalPixelCoordinate {
        OriginalPixelCoordinate(x: x, y: y)
    }

    static func color(_ red: Double, _ green: Double, _ blue: Double) -> OriginalPixelColor {
        OriginalPixelColor(red: red, green: green, blue: blue)
    }
}

private extension Int {
    func modulo(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
