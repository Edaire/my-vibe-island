public struct DisplayPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct DisplaySize: Codable, Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct DisplayFrame: Codable, Equatable, Sendable {
    public static let zero = DisplayFrame(x: 0, y: 0, width: 0, height: 0)

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

public enum DisplayPlacementCollapseReason: String, Codable, Equatable, Sendable {
    case fullscreenHidden
    case onboardingFullscreen
}

public struct DisplayPlacementInput: Codable, Equatable, Sendable {
    public let screenFrame: DisplayFrame
    public let safeAreaTopInset: Double
    public let closedSize: DisplaySize
    public let expandedSize: DisplaySize
    public let maximumExpandedSize: DisplaySize
    public let horizontalMargin: Double
    public let verticalMargin: Double
    public let hideInFullscreen: Bool
    public let activeAppIsFullscreen: Bool
    public let blockingActionVisible: Bool
    public let onboardingFullscreenActive: Bool

    public init(
        screenFrame: DisplayFrame,
        safeAreaTopInset: Double = 0,
        closedSize: DisplaySize,
        expandedSize: DisplaySize,
        maximumExpandedSize: DisplaySize = DisplaySize(width: 640, height: 560),
        horizontalMargin: Double = 16,
        verticalMargin: Double = 16,
        hideInFullscreen: Bool = true,
        activeAppIsFullscreen: Bool = false,
        blockingActionVisible: Bool = false,
        onboardingFullscreenActive: Bool = false
    ) {
        self.screenFrame = screenFrame
        self.safeAreaTopInset = safeAreaTopInset
        self.closedSize = closedSize
        self.expandedSize = expandedSize
        self.maximumExpandedSize = maximumExpandedSize
        self.horizontalMargin = horizontalMargin
        self.verticalMargin = verticalMargin
        self.hideInFullscreen = hideInFullscreen
        self.activeAppIsFullscreen = activeAppIsFullscreen
        self.blockingActionVisible = blockingActionVisible
        self.onboardingFullscreenActive = onboardingFullscreenActive
    }

    public func replacing(
        blockingActionVisible: Bool? = nil,
        activeAppIsFullscreen: Bool? = nil,
        onboardingFullscreenActive: Bool? = nil
    ) -> DisplayPlacementInput {
        DisplayPlacementInput(
            screenFrame: screenFrame,
            safeAreaTopInset: safeAreaTopInset,
            closedSize: closedSize,
            expandedSize: expandedSize,
            maximumExpandedSize: maximumExpandedSize,
            horizontalMargin: horizontalMargin,
            verticalMargin: verticalMargin,
            hideInFullscreen: hideInFullscreen,
            activeAppIsFullscreen: activeAppIsFullscreen ?? self.activeAppIsFullscreen,
            blockingActionVisible: blockingActionVisible ?? self.blockingActionVisible,
            onboardingFullscreenActive: onboardingFullscreenActive ?? self.onboardingFullscreenActive
        )
    }
}

public struct DisplayPlacementPlan: Codable, Equatable, Sendable {
    public let closedFrame: DisplayFrame
    public let expandedFrame: DisplayFrame
    public let anchor: DisplayPoint
    public let safeAreaAdjustment: Double
    public let collapseReason: DisplayPlacementCollapseReason?

    public init(
        closedFrame: DisplayFrame,
        expandedFrame: DisplayFrame,
        anchor: DisplayPoint,
        safeAreaAdjustment: Double,
        collapseReason: DisplayPlacementCollapseReason? = nil
    ) {
        self.closedFrame = closedFrame
        self.expandedFrame = expandedFrame
        self.anchor = anchor
        self.safeAreaAdjustment = safeAreaAdjustment
        self.collapseReason = collapseReason
    }
}

public struct DisplayPlacementResolver: Sendable {
    public init() {}

    public func resolve(_ input: DisplayPlacementInput) -> DisplayPlacementPlan {
        if input.onboardingFullscreenActive {
            return collapsed(input, reason: .onboardingFullscreen)
        }

        if input.hideInFullscreen && input.activeAppIsFullscreen && !input.blockingActionVisible {
            return collapsed(input, reason: .fullscreenHidden)
        }

        let safeTopY = input.screenFrame.y + input.screenFrame.height
        let centerX = input.screenFrame.x + input.screenFrame.width / 2
        let panelSize = OriginalIslandGeometryResolver.panelSize
        let panelFrame = DisplayFrame(
            x: centerX - panelSize.width / 2,
            y: safeTopY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
        let anchor = DisplayPoint(x: centerX, y: safeTopY)

        return DisplayPlacementPlan(
            closedFrame: panelFrame,
            expandedFrame: panelFrame,
            anchor: anchor,
            safeAreaAdjustment: max(0, input.safeAreaTopInset)
        )
    }

    private func collapsed(
        _ input: DisplayPlacementInput,
        reason: DisplayPlacementCollapseReason
    ) -> DisplayPlacementPlan {
        let anchor = DisplayPoint(
            x: input.screenFrame.x + input.screenFrame.width / 2,
            y: input.screenFrame.y
                + input.screenFrame.height
                - max(0, input.safeAreaTopInset)
        )
        return DisplayPlacementPlan(
            closedFrame: .zero,
            expandedFrame: .zero,
            anchor: anchor,
            safeAreaAdjustment: max(0, input.safeAreaTopInset),
            collapseReason: reason
        )
    }
}
