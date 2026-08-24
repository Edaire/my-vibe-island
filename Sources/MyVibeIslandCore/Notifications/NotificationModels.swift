import Foundation

public enum NotificationEventCategory: String, Codable, Equatable, Sendable {
    case permissionRequested
    case questionAsked
    case sessionCompleted
    case sessionFailed
    case agentWarning
    case usageThreshold
    case usageLimit
    case usageReset
    case integrationRepairNeeded
    case remoteDisconnected
    case activityUpdate
}

public enum NotificationSeverity: String, Codable, Equatable, Sendable {
    case info
    case warning
    case blocking
    case failure
}

public enum NotificationAction: String, Codable, Equatable, Sendable {
    case approve
    case deny
    case answer
    case jump
    case dismiss
    case silence
    case openSettings
    case repairIntegration
}

public enum NotificationSoundCategory: String, Codable, Equatable, CaseIterable, Sendable {
    case permission
    case question
    case completion
    case failure
    case warning
    case usage
    case remote
}

public struct PeekNotification: Codable, Equatable, Sendable {
    public let id: String
    public let category: NotificationEventCategory
    public let sessionId: String?
    public let agent: String?
    public let title: String
    public let body: String
    public let severity: NotificationSeverity
    public let primaryAction: NotificationAction?
    public let secondaryAction: NotificationAction?
    public let createdAt: String
    public let expiresAt: String?
    public let dwellSeconds: Double
    public let dedupeKey: String?
    public let soundCategory: NotificationSoundCategory?
    public let source: String
    /// V3 root-response effect, when this notification originated from the
    /// root-response coordinator. Nil preserves the legacy notification wire
    /// shape for all other categories.
    public let rootResponseEffect: V3RootResponseNotificationEffect?

    public init(
        id: String,
        category: NotificationEventCategory,
        sessionId: String? = nil,
        agent: String? = nil,
        title: String,
        body: String,
        severity: NotificationSeverity,
        primaryAction: NotificationAction? = nil,
        secondaryAction: NotificationAction? = nil,
        createdAt: String,
        expiresAt: String? = nil,
        dwellSeconds: Double,
        dedupeKey: String? = nil,
        soundCategory: NotificationSoundCategory? = nil,
        source: String,
        rootResponseEffect: V3RootResponseNotificationEffect? = nil
    ) {
        self.id = id
        self.category = category
        self.sessionId = sessionId
        self.agent = agent
        self.title = title
        self.body = body
        self.severity = severity
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.dwellSeconds = dwellSeconds
        self.dedupeKey = dedupeKey
        self.soundCategory = soundCategory
        self.source = source
        self.rootResponseEffect = rootResponseEffect
    }

    private enum CodingKeys: String, CodingKey {
        case id, category, sessionId, agent, title, body, severity
        case primaryAction, secondaryAction, createdAt, expiresAt, dwellSeconds
        case dedupeKey, soundCategory, source, rootResponseEffect
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            category: try container.decode(NotificationEventCategory.self, forKey: .category),
            sessionId: try container.decodeIfPresent(String.self, forKey: .sessionId),
            agent: try container.decodeIfPresent(String.self, forKey: .agent),
            title: try container.decode(String.self, forKey: .title),
            body: try container.decode(String.self, forKey: .body),
            severity: try container.decode(NotificationSeverity.self, forKey: .severity),
            primaryAction: try container.decodeIfPresent(NotificationAction.self, forKey: .primaryAction),
            secondaryAction: try container.decodeIfPresent(NotificationAction.self, forKey: .secondaryAction),
            createdAt: try container.decode(String.self, forKey: .createdAt),
            expiresAt: try container.decodeIfPresent(String.self, forKey: .expiresAt),
            dwellSeconds: try container.decode(Double.self, forKey: .dwellSeconds),
            dedupeKey: try container.decodeIfPresent(String.self, forKey: .dedupeKey),
            soundCategory: try container.decodeIfPresent(NotificationSoundCategory.self, forKey: .soundCategory),
            source: try container.decode(String.self, forKey: .source),
            rootResponseEffect: try container.decodeIfPresent(
                V3RootResponseNotificationEffect.self,
                forKey: .rootResponseEffect
            )
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(agent, forKey: .agent)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(severity, forKey: .severity)
        try container.encodeIfPresent(primaryAction, forKey: .primaryAction)
        try container.encodeIfPresent(secondaryAction, forKey: .secondaryAction)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encode(dwellSeconds, forKey: .dwellSeconds)
        try container.encodeIfPresent(dedupeKey, forKey: .dedupeKey)
        try container.encodeIfPresent(soundCategory, forKey: .soundCategory)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(rootResponseEffect, forKey: .rootResponseEffect)
    }

    public func replacingSoundCategory(
        _ soundCategory: NotificationSoundCategory?
    ) -> PeekNotification {
        PeekNotification(
            id: id,
            category: category,
            sessionId: sessionId,
            agent: agent,
            title: title,
            body: body,
            severity: severity,
            primaryAction: primaryAction,
            secondaryAction: secondaryAction,
            createdAt: createdAt,
            expiresAt: expiresAt,
            dwellSeconds: dwellSeconds,
            dedupeKey: dedupeKey,
            soundCategory: soundCategory,
            source: source,
            rootResponseEffect: rootResponseEffect
        )
    }
}

public enum NotchPeekPresentation: String, Codable, Equatable, Sendable {
    case compact
    case expanded
}

public enum NotificationsPaneFocusedField: String, Codable, Equatable, Sendable {
    case none
    case title
    case body
    case primaryAction
    case secondaryAction
}

public struct NotchPeekNotification: Codable, Equatable, Sendable {
    public let notification: PeekNotification
    public let presentation: NotchPeekPresentation
    public let focusedField: NotificationsPaneFocusedField

    public init(
        notification: PeekNotification,
        presentation: NotchPeekPresentation = .compact,
        focusedField: NotificationsPaneFocusedField? = nil
    ) {
        self.notification = notification
        self.presentation = presentation
        self.focusedField = focusedField ?? Self.defaultFocusedField(for: notification)
    }

    private static func defaultFocusedField(
        for notification: PeekNotification
    ) -> NotificationsPaneFocusedField {
        if notification.primaryAction != nil {
            return .primaryAction
        }
        if notification.secondaryAction != nil {
            return .secondaryAction
        }
        return .title
    }
}

public struct PeekNotificationRow: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String?
    public let severity: NotificationSeverity
    public let primaryAction: NotificationAction?
    public let secondaryAction: NotificationAction?
    public let focusedField: NotificationsPaneFocusedField

    public init(notification: NotchPeekNotification) {
        let peek = notification.notification
        id = peek.id
        title = peek.title
        body = notification.presentation == .expanded ? peek.body : nil
        severity = peek.severity
        primaryAction = peek.primaryAction
        secondaryAction = peek.secondaryAction
        focusedField = notification.focusedField
    }
}
