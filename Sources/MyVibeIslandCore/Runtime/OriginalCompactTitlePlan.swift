public struct OriginalCompactTitlePlan: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        case localized(key: String, englishFallback: String, formatArgument: String?)
        case verbatim(String)
    }

    public enum PostLocalizationTransform: Equatable, Sendable {
        case none
        case physicalCompact

        public func apply(to concrete: String) -> String {
            guard self == .physicalCompact, concrete.count > 25 else {
                return concrete
            }

            return String(concrete.prefix(22)) + "..."
        }
    }

    public let content: Content
    public let transform: PostLocalizationTransform

    public init(content: Content, transform: PostLocalizationTransform = .none) {
        self.content = content
        self.transform = transform
    }
}
