import Foundation

public enum OriginalPeekProvider: String, CaseIterable, Codable, Equatable, Sendable {
    case anthropic
    case openai
    case google
    case zhipu
    case kimi
}

public enum OriginalPeekLevel: String, CaseIterable, Codable, Equatable, Sendable {
    case info
    case warning
    case critical
}

public struct OriginalPeekNotification: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let provider: OriginalPeekProvider?
    public let level: OriginalPeekLevel

    public init(
        id: String,
        title: String,
        detail: String,
        provider: OriginalPeekProvider?,
        level: OriginalPeekLevel
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.provider = provider
        self.level = level
    }
}

public enum OriginalPeekTransientKind: String, CaseIterable, Codable, Equatable, Sendable {
    case taskComplete
    case statusWarning
}

public enum OriginalPeekDisplayState: Codable, Equatable, Sendable {
    case peek(OriginalPeekNotification, kind: OriginalPeekTransientKind)
    case blocking
    case transient
    case closed
    case manualExpanded
}
