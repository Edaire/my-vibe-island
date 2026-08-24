/// IDA confirms `NotchShape` stores top at `+0` and bottom at `+8`.
/// Original collapsed-alpha geometry independently runtime-confirms the
/// compact payload as top `6` and bottom `14`.
public struct OriginalNotchShapeParameters: Equatable, Sendable {
    public static let fieldMappingIsRuntimeConfirmed = true

    public let topCornerRadius: Double
    public let bottomCornerRadius: Double

    public init(topCornerRadius: Double, bottomCornerRadius: Double) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }
}

public struct OriginalNotchShapeParametersResolver: Sendable {
    public init() {}

    public func resolve(_ displayState: OriginalIslandDisplayState) -> OriginalNotchShapeParameters {
        // These are the shape payload pairs, not the horizontal edge insets.
        switch displayState {
        case .compact:
            OriginalNotchShapeParameters(topCornerRadius: 6, bottomCornerRadius: 14)
        case .peek:
            OriginalNotchShapeParameters(topCornerRadius: 10, bottomCornerRadius: 20)
        case .expanded:
            OriginalNotchShapeParameters(topCornerRadius: 19, bottomCornerRadius: 24)
        }
    }
}
