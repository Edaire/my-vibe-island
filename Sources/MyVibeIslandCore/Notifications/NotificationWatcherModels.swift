public enum NotificationWatcherAuthorizationStatus: String, Codable, Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

public enum NotificationWatcherSource: String, Codable, Equatable, Sendable {
    case runtime
    case ida
    case openBaseline
    case planned
    case future
}

public enum NotificationWatcherSuppressionReason: String, Codable, Equatable, Sendable {
    case notAuthorized
    case notObserving
}

public struct NotificationWatcherEvent: Codable, Equatable, Sendable {
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
    public let source: NotificationWatcherSource

    public var peekNotification: PeekNotification {
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
            source: source.rawValue
        )
    }

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
        dwellSeconds: Double = 6.0,
        dedupeKey: String? = nil,
        soundCategory: NotificationSoundCategory? = nil,
        source: NotificationWatcherSource
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
    }
}

public struct NotificationWatcherState: Codable, Equatable, Sendable {
    public let authorizationStatus: NotificationWatcherAuthorizationStatus
    public let isObserving: Bool
    public let pendingPeekIds: [String]

    public init(
        authorizationStatus: NotificationWatcherAuthorizationStatus = .notDetermined,
        isObserving: Bool = false,
        pendingPeekIds: [String] = []
    ) {
        self.authorizationStatus = authorizationStatus
        self.isObserving = isObserving
        self.pendingPeekIds = Self.unique(pendingPeekIds)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

public enum NotificationWatcherCommand: Equatable, Sendable {
    case start
    case stop
    case authorizationChanged(NotificationWatcherAuthorizationStatus)
    case receive(NotificationWatcherEvent)
}

public enum NotificationWatcherAction: Equatable, Sendable {
    case requestAuthorization
    case registerObserver
    case unregisterObserver
    case publishPeek(PeekNotification)
    case suppress(eventId: String, reason: NotificationWatcherSuppressionReason)
}

public struct NotificationWatcherPlan: Equatable, Sendable {
    public let nextState: NotificationWatcherState
    public let actions: [NotificationWatcherAction]

    public init(
        nextState: NotificationWatcherState,
        actions: [NotificationWatcherAction]
    ) {
        self.nextState = nextState
        self.actions = actions
    }
}

public struct NotificationWatcherModel: Sendable {
    public init() {}

    public func plan(
        _ command: NotificationWatcherCommand,
        from state: NotificationWatcherState
    ) -> NotificationWatcherPlan {
        switch command {
        case .start:
            return start(from: state)
        case .stop:
            return stop(from: state)
        case let .authorizationChanged(status):
            return authorizationChanged(status, from: state)
        case let .receive(event):
            return receive(event, from: state)
        }
    }

    private func start(from state: NotificationWatcherState) -> NotificationWatcherPlan {
        switch state.authorizationStatus {
        case .authorized:
            return NotificationWatcherPlan(
                nextState: replacing(state, isObserving: true),
                actions: state.isObserving ? [] : [.registerObserver]
            )
        case .notDetermined:
            return NotificationWatcherPlan(nextState: state, actions: [.requestAuthorization])
        case .denied:
            return NotificationWatcherPlan(nextState: state, actions: [])
        }
    }

    private func stop(from state: NotificationWatcherState) -> NotificationWatcherPlan {
        NotificationWatcherPlan(
            nextState: replacing(state, isObserving: false),
            actions: state.isObserving ? [.unregisterObserver] : []
        )
    }

    private func authorizationChanged(
        _ status: NotificationWatcherAuthorizationStatus,
        from state: NotificationWatcherState
    ) -> NotificationWatcherPlan {
        let nextState = replacing(
            state,
            authorizationStatus: status,
            isObserving: status == .authorized ? state.isObserving : false
        )
        return NotificationWatcherPlan(
            nextState: nextState,
            actions: status == .authorized && state.isObserving ? [.registerObserver] : []
        )
    }

    private func receive(
        _ event: NotificationWatcherEvent,
        from state: NotificationWatcherState
    ) -> NotificationWatcherPlan {
        guard state.authorizationStatus == .authorized else {
            return NotificationWatcherPlan(
                nextState: state,
                actions: [.suppress(eventId: event.id, reason: .notAuthorized)]
            )
        }
        guard state.isObserving else {
            return NotificationWatcherPlan(
                nextState: state,
                actions: [.suppress(eventId: event.id, reason: .notObserving)]
            )
        }

        return NotificationWatcherPlan(
            nextState: replacing(
                state,
                pendingPeekIds: state.pendingPeekIds + [event.id]
            ),
            actions: [.publishPeek(event.peekNotification)]
        )
    }

    private func replacing(
        _ state: NotificationWatcherState,
        authorizationStatus: NotificationWatcherAuthorizationStatus? = nil,
        isObserving: Bool? = nil,
        pendingPeekIds: [String]? = nil
    ) -> NotificationWatcherState {
        NotificationWatcherState(
            authorizationStatus: authorizationStatus ?? state.authorizationStatus,
            isObserving: isObserving ?? state.isObserving,
            pendingPeekIds: pendingPeekIds ?? state.pendingPeekIds
        )
    }
}
