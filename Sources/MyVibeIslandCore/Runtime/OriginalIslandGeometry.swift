public enum OriginalIslandDisplayState: String, Codable, Equatable, Sendable {
    case compact
    case peek
    case expanded
}

public struct OriginalIslandGeometryInput: Equatable, Sendable {
    public let screenFrame: DisplayFrame
    public let visibleFrame: DisplayFrame
    public let safeAreaTopInset: Double
    public let auxiliaryNotchGap: Double?
    public let displayState: OriginalIslandDisplayState
    public let compactIntrinsicWidth: Double
    public let leftStatusSlotWidth: Double
    public let rightStatusSlotWidth: Double
    public let measuredContentHeight: Double
    public let sessionCount: Int
    public let focusedSpecialSession: Bool
    public let maxExpandedWidth: Double
    public let maxExpandedHeight: Double
    public let notchWidthOffset: Double
    public let notchHeightOffset: Double

    public init(
        screenFrame: DisplayFrame,
        visibleFrame: DisplayFrame,
        safeAreaTopInset: Double = 0,
        auxiliaryNotchGap: Double? = nil,
        displayState: OriginalIslandDisplayState,
        compactIntrinsicWidth: Double,
        leftStatusSlotWidth: Double = 36,
        rightStatusSlotWidth: Double = 36,
        measuredContentHeight: Double = 0,
        sessionCount: Int = 0,
        focusedSpecialSession: Bool = false,
        maxExpandedWidth: Double = 640,
        maxExpandedHeight: Double = 560,
        notchWidthOffset: Double = 0,
        notchHeightOffset: Double = 0
    ) {
        self.screenFrame = screenFrame
        self.visibleFrame = visibleFrame
        self.safeAreaTopInset = safeAreaTopInset
        self.auxiliaryNotchGap = auxiliaryNotchGap
        self.displayState = displayState
        self.compactIntrinsicWidth = compactIntrinsicWidth
        self.leftStatusSlotWidth = leftStatusSlotWidth
        self.rightStatusSlotWidth = rightStatusSlotWidth
        self.measuredContentHeight = measuredContentHeight
        self.sessionCount = sessionCount
        self.focusedSpecialSession = focusedSpecialSession
        self.maxExpandedWidth = maxExpandedWidth
        self.maxExpandedHeight = maxExpandedHeight
        self.notchWidthOffset = notchWidthOffset
        self.notchHeightOffset = notchHeightOffset
    }
}

public struct OriginalIslandGeometry: Equatable, Sendable {
    public let panelFrame: DisplayFrame
    public let surfaceFrame: DisplayFrame

    public var surfaceSize: DisplaySize {
        DisplaySize(width: surfaceFrame.width, height: surfaceFrame.height)
    }

    public init(panelFrame: DisplayFrame, surfaceFrame: DisplayFrame) {
        self.panelFrame = panelFrame
        self.surfaceFrame = surfaceFrame
    }
}

public struct OriginalIslandGeometryResolver: Sendable {
    public static let panelSize = DisplaySize(width: 680, height: 580)

    public init() {}

    public func resolve(_ input: OriginalIslandGeometryInput) -> OriginalIslandGeometry {
        let panelFrame = DisplayFrame(
            x: input.screenFrame.x + (input.screenFrame.width - Self.panelSize.width) / 2,
            y: input.screenFrame.y + input.screenFrame.height - Self.panelSize.height,
            width: Self.panelSize.width,
            height: Self.panelSize.height
        )
        let compactSize = compactSize(input)
        let surfaceSize: DisplaySize

        switch input.displayState {
        case .compact:
            surfaceSize = compactSize
        case .peek:
            surfaceSize = DisplaySize(
                width: min(compactSize.width + 88, expandedWidth(input)),
                height: compactSize.height + 38
            )
        case .expanded:
            surfaceSize = DisplaySize(
                width: expandedWidth(input),
                height: expandedHeight(input)
            )
        }

        return OriginalIslandGeometry(
            panelFrame: panelFrame,
            surfaceFrame: DisplayFrame(
                x: (Self.panelSize.width - surfaceSize.width) / 2,
                y: Self.panelSize.height - surfaceSize.height,
                width: surfaceSize.width,
                height: surfaceSize.height
            )
        )
    }

    private func compactSize(_ input: OriginalIslandGeometryInput) -> DisplaySize {
        let menuBarGap = input.screenFrame.y + input.screenFrame.height
            - (input.visibleFrame.y + input.visibleFrame.height)
        let physicalHeight: Double
        if input.safeAreaTopInset > 0 {
            physicalHeight = abs(input.safeAreaTopInset - menuBarGap) >= 0.5
                ? menuBarGap
                : input.safeAreaTopInset
        } else {
            physicalHeight = max(24, menuBarGap)
        }

        let width: Double
        if let auxiliaryNotchGap = input.auxiliaryNotchGap {
            width = input.leftStatusSlotWidth
                + max(auxiliaryNotchGap + input.notchWidthOffset, 40)
                + input.rightStatusSlotWidth
        } else {
            width = max(input.compactIntrinsicWidth + input.notchWidthOffset, 60)
        }

        return DisplaySize(
            width: width,
            height: max(physicalHeight + input.notchHeightOffset, 8)
        )
    }

    private func expandedWidth(_ input: OriginalIslandGeometryInput) -> Double {
        // V3 NotchContentView clamps against `screen.frame.width - 40`.
        min(input.screenFrame.width - 40, input.maxExpandedWidth)
    }

    private func expandedHeight(_ input: OriginalIslandGeometryInput) -> Double {
        if input.measuredContentHeight > 0 {
            return min(input.maxExpandedHeight, input.measuredContentHeight + 40)
        }
        if input.sessionCount == 0 {
            return 124
        }
        if input.focusedSpecialSession {
            return min(input.maxExpandedHeight, 160)
        }
        return min(input.maxExpandedHeight, Double(min(input.sessionCount, 4)) * 120 + 40)
    }
}
