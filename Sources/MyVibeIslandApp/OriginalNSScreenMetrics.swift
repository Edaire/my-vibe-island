import MyVibeIslandCore

public struct OriginalNSScreenMetricsInput: Equatable, Sendable {
    public let safeAreaTopInset: Double
    public let frameWidth: Double
    public let auxiliaryTopLeftWidth: Double
    public let auxiliaryTopRightWidth: Double
    public let screenFrame: DisplayFrame
    public let visibleFrame: DisplayFrame
    public let hasValidDisplayFrames: Bool

    public init(
        safeAreaTopInset: Double,
        frameWidth: Double,
        auxiliaryTopLeftWidth: Double,
        auxiliaryTopRightWidth: Double,
        screenFrame: DisplayFrame? = nil,
        visibleFrame: DisplayFrame? = nil
    ) {
        let fallbackFrame = DisplayFrame(x: 0, y: 0, width: frameWidth, height: 0)
        self.safeAreaTopInset = safeAreaTopInset
        self.frameWidth = frameWidth
        self.auxiliaryTopLeftWidth = auxiliaryTopLeftWidth
        self.auxiliaryTopRightWidth = auxiliaryTopRightWidth
        self.screenFrame = screenFrame ?? fallbackFrame
        self.visibleFrame = visibleFrame ?? fallbackFrame
        self.hasValidDisplayFrames = Self.hasValidDisplayFrames(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )
    }

    private static func hasValidDisplayFrames(
        screenFrame: DisplayFrame?,
        visibleFrame: DisplayFrame?
    ) -> Bool {
        guard let screenFrame, let visibleFrame else {
            return false
        }
        let values = [
            screenFrame.x,
            screenFrame.y,
            screenFrame.width,
            screenFrame.height,
            visibleFrame.x,
            visibleFrame.y,
            visibleFrame.width,
            visibleFrame.height,
        ]
        let menuBarGap = screenFrame.y + screenFrame.height
            - (visibleFrame.y + visibleFrame.height)
        return values.allSatisfy(\.isFinite)
            && screenFrame.width > 0
            && screenFrame.height > 0
            && visibleFrame.width > 0
            && visibleFrame.height > 0
            && menuBarGap.isFinite
            && menuBarGap >= 0
            && menuBarGap <= screenFrame.height
    }
}

public struct OriginalNSScreenMetrics: Equatable, Sendable {
    public let notchWidth: Double

    public init(notchWidth: Double) {
        self.notchWidth = notchWidth
    }
}

public struct OriginalNSScreenMetricsResolver: Sendable {
    public init() {}

    public func compactPhysicalSurfaceHeight(
        for input: OriginalNSScreenMetricsInput,
        notchHeightOffset: Double = 0
    ) -> Double {
        let gap = input.screenFrame.y + input.screenFrame.height
            - (input.visibleFrame.y + input.visibleFrame.height)
        let baseHeight: Double
        if input.safeAreaTopInset > 0 {
            baseHeight = input.hasValidDisplayFrames
                ? abs((gap - input.safeAreaTopInset) - 1) < 0.5
                    ? gap
                    : input.safeAreaTopInset
                : input.safeAreaTopInset
        } else {
            baseHeight = max(24, gap)
        }
        return max(baseHeight + notchHeightOffset, 8)
    }

    public func resolve(_ input: OriginalNSScreenMetricsInput) -> OriginalNSScreenMetrics {
        let notchWidth: Double
        if input.safeAreaTopInset <= 0 {
            notchWidth = 224
        } else if input.auxiliaryTopLeftWidth > 0, input.auxiliaryTopRightWidth > 0 {
            notchWidth = input.frameWidth
                - input.auxiliaryTopLeftWidth
                - input.auxiliaryTopRightWidth
        } else {
            notchWidth = 180
        }

        return OriginalNSScreenMetrics(notchWidth: notchWidth)
    }
}
