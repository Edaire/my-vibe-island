public struct OriginalCompactRuntimeState: Codable, Equatable, Sendable {
    public let isMinimized: Bool
    public let notchWidthOffset: Double
    public let notchHeightOffset: Double
    public let completionFlashTick: Int

    public init(
        isMinimized: Bool = false,
        notchWidthOffset: Double = 0,
        notchHeightOffset: Double = 0,
        completionFlashTick: Int = 0
    ) {
        self.isMinimized = isMinimized
        self.notchWidthOffset = notchWidthOffset
        self.notchHeightOffset = notchHeightOffset
        self.completionFlashTick = completionFlashTick
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isMinimized: try container.decodeIfPresent(Bool.self, forKey: .isMinimized) ?? false,
            notchWidthOffset: try container.decodeIfPresent(Double.self, forKey: .notchWidthOffset) ?? 0,
            notchHeightOffset: try container.decodeIfPresent(Double.self, forKey: .notchHeightOffset) ?? 0,
            completionFlashTick: try container.decodeIfPresent(Int.self, forKey: .completionFlashTick) ?? 0
        )
    }
}
