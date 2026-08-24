public enum OriginalPeekSupplementalContentPlan: Codable, Equatable, Sendable {
    case row(OriginalPeekNotification)
    case empty

    public static func resolve(
        _ state: OriginalPeekDisplayState
    ) -> OriginalPeekSupplementalContentPlan {
        switch state {
        case let .peek(notification, _):
            return .row(notification)
        case .blocking, .transient, .closed, .manualExpanded:
            return .empty
        }
    }
}

public struct OriginalPeekHostingDescriptor: Codable, Equatable, Sendable {
    public static let hostSize = DisplaySize(width: 680, height: 580)

    public let compactSurfaceSize: DisplaySize
    public let screenWidth: Double
    public let maxExpandedWidth: Double
    public let surfaceSize: DisplaySize
    public let rootLayoutPlan: OriginalRootSurfaceLayoutPlan
    public let hostSize: DisplaySize

    public init(
        compactSurfaceSize: DisplaySize,
        screenWidth: Double,
        maxExpandedWidth: Double = 640
    ) {
        self.compactSurfaceSize = compactSurfaceSize
        self.screenWidth = screenWidth
        self.maxExpandedWidth = maxExpandedWidth
        self.surfaceSize = DisplaySize(
            width: min(compactSurfaceSize.width + 88, min(screenWidth - 40, maxExpandedWidth)),
            height: compactSurfaceSize.height + 38
        )
        self.rootLayoutPlan = OriginalRootSurfaceLayoutPlan.resolve(
            displayState: .peek,
            isHovering: false,
            safeAreaTopInset: 0,
            leftStatusSlotWidth: 0,
            rightStatusSlotWidth: 0
        )
        self.hostSize = Self.hostSize
    }
}
