import Foundation

public enum UsagePeekNotificationCategory: String, Codable, Equatable, Sendable {
    case usageThreshold
    case usageLimit
    case usageReset
}

public enum UsagePeekNotificationSeverity: String, Codable, Equatable, Sendable {
    case info
    case warning
    case critical
}

public enum UsagePeekSoundCategory: String, Codable, Equatable, Sendable {
    case usage
}

public struct UsagePeekNotificationPayload: Codable, Equatable, Sendable {
    public let id: String
    public let category: UsagePeekNotificationCategory
    public let title: String
    public let body: String
    public let severity: UsagePeekNotificationSeverity
    public let dedupeKey: String
    public let soundCategory: UsagePeekSoundCategory?
    public let sourceProviderId: UsageProviderIdentifier
    public let windowId: String
    public let unread: Bool

    public init(
        id: String,
        category: UsagePeekNotificationCategory,
        title: String,
        body: String,
        severity: UsagePeekNotificationSeverity,
        dedupeKey: String,
        soundCategory: UsagePeekSoundCategory? = nil,
        sourceProviderId: UsageProviderIdentifier,
        windowId: String,
        unread: Bool = false
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.body = body
        self.severity = severity
        self.dedupeKey = dedupeKey
        self.soundCategory = soundCategory
        self.sourceProviderId = sourceProviderId
        self.windowId = windowId
        self.unread = unread
    }

    public static func make(
        intents: [UsagePeekIntent],
        soundEnabled: Bool
    ) -> [UsagePeekNotificationPayload] {
        intents.map { intent in
            UsagePeekNotificationPayload(
                id: intent.dedupeKey,
                category: category(for: intent.kind),
                title: intent.title,
                body: intent.message,
                severity: severity(for: intent.kind),
                dedupeKey: intent.dedupeKey,
                soundCategory: soundEnabled ? .usage : nil,
                sourceProviderId: intent.providerId,
                windowId: intent.windowId,
                unread: false
            )
        }
    }

    private static func category(for kind: UsagePeekKind) -> UsagePeekNotificationCategory {
        switch kind {
        case .thresholdReached:
            .usageThreshold
        case .limitReached:
            .usageLimit
        case .windowReset:
            .usageReset
        }
    }

    private static func severity(for kind: UsagePeekKind) -> UsagePeekNotificationSeverity {
        switch kind {
        case .thresholdReached:
            .warning
        case .limitReached:
            .critical
        case .windowReset:
            .info
        }
    }
}
