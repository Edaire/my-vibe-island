public enum OriginalCompactTitleOverrides {
    public enum Mode: Equatable, Sendable {
        case physicalNotch
        case nonNotched
    }

    public struct Title: Equatable, Sendable {
        public let localizationKey: String
        public let englishFallback: String
        public let formatArgument: String?

        public init(
            localizationKey: String,
            englishFallback: String,
            formatArgument: String? = nil
        ) {
            self.localizationKey = localizationKey
            self.englishFallback = englishFallback
            self.formatArgument = formatArgument
        }
    }

    public static func resolve(
        for status: OriginalPixelStatusCompact,
        mode: Mode,
        detail: String? = nil
    ) -> Title? {
        switch status {
        case .thinking:
            guard mode == .nonNotched, let detail else {
                return Title(
                    localizationKey: "tool.thinkingEllipsis",
                    englishFallback: "Thinking..."
                )
            }
            return Title(
                localizationKey: "tool.thinkingDetail",
                englishFallback: "Thinking: %@",
                formatArgument: detail.count > 25
                    ? String(detail.prefix(25)) + "..."
                    : detail
            )
        case .compacting:
            return Title(
                localizationKey: "status.compacting",
                englishFallback: "Compacting"
            )
        case .waitingForInput, .processing, .runningTool, .waitingForApproval,
             .question, .ended, .unknown:
            return nil
        }
    }
}
