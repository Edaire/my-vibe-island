public enum EventSchedulerTaskKind: String, Codable, Equatable, Sendable {
    case debounce
    case timeout
    case cleanup
    case throttle
}

public struct EventSchedulerTask: Codable, Equatable, Sendable {
    public let id: String
    public let key: String
    public let kind: EventSchedulerTaskKind
    public let dueAtMillis: Int
    public let sourceId: String?
    public let sessionId: String?
    public let requestId: String?

    public init(
        id: String,
        key: String,
        kind: EventSchedulerTaskKind,
        dueAtMillis: Int,
        sourceId: String? = nil,
        sessionId: String? = nil,
        requestId: String? = nil
    ) {
        self.id = id
        self.key = key
        self.kind = kind
        self.dueAtMillis = dueAtMillis
        self.sourceId = sourceId
        self.sessionId = sessionId
        self.requestId = requestId
    }
}

public struct EventSchedulerState: Codable, Equatable, Sendable {
    public let pendingTasks: [EventSchedulerTask]

    public init(pendingTasks: [EventSchedulerTask] = []) {
        self.pendingTasks = pendingTasks.sorted { lhs, rhs in
            if lhs.dueAtMillis == rhs.dueAtMillis {
                return lhs.id < rhs.id
            }
            return lhs.dueAtMillis < rhs.dueAtMillis
        }
    }
}

public enum EventSchedulerCommand: Equatable, Sendable {
    case scheduleDebounce(key: String, delayMillis: Int, sourceId: String?)
    case scheduleBlockingTimeout(requestId: String, delayMillis: Int, sourceId: String?)
    case scheduleSessionCleanup(sessionId: String, delayMillis: Int, sourceId: String?)
    case openThrottleWindow(key: String, intervalMillis: Int, sourceId: String?)
    case cancel(key: String)
    case collectDue
}

public struct EventSchedulerPlan: Equatable, Sendable {
    public let nextState: EventSchedulerState
    public let emittedTasks: [EventSchedulerTask]
    public let canceledTaskIds: [String]

    public init(
        nextState: EventSchedulerState,
        emittedTasks: [EventSchedulerTask] = [],
        canceledTaskIds: [String] = []
    ) {
        self.nextState = nextState
        self.emittedTasks = emittedTasks
        self.canceledTaskIds = canceledTaskIds
    }
}

public struct EventScheduler: Sendable {
    public init() {}

    public func plan(
        _ command: EventSchedulerCommand,
        from state: EventSchedulerState,
        nowMillis: Int
    ) -> EventSchedulerPlan {
        switch command {
        case let .scheduleDebounce(key, delayMillis, sourceId):
            let dueAtMillis = nowMillis + max(0, delayMillis)
            let canceled = state.pendingTasks
                .filter { $0.kind == .debounce && $0.key == key }
                .map(\.id)
            let retained = state.pendingTasks.filter { !canceled.contains($0.id) }
            let task = EventSchedulerTask(
                id: "debounce:\(key):\(dueAtMillis)",
                key: key,
                kind: .debounce,
                dueAtMillis: dueAtMillis,
                sourceId: sourceId
            )
            return EventSchedulerPlan(
                nextState: EventSchedulerState(pendingTasks: retained + [task]),
                canceledTaskIds: canceled
            )

        case let .scheduleBlockingTimeout(requestId, delayMillis, sourceId):
            let dueAtMillis = nowMillis + max(0, delayMillis)
            let task = EventSchedulerTask(
                id: "timeout:\(requestId):\(dueAtMillis)",
                key: requestId,
                kind: .timeout,
                dueAtMillis: dueAtMillis,
                sourceId: sourceId,
                requestId: requestId
            )
            return EventSchedulerPlan(nextState: EventSchedulerState(pendingTasks: state.pendingTasks + [task]))

        case let .scheduleSessionCleanup(sessionId, delayMillis, sourceId):
            let dueAtMillis = nowMillis + max(0, delayMillis)
            let task = EventSchedulerTask(
                id: "cleanup:\(sessionId):\(dueAtMillis)",
                key: sessionId,
                kind: .cleanup,
                dueAtMillis: dueAtMillis,
                sourceId: sourceId,
                sessionId: sessionId
            )
            return EventSchedulerPlan(nextState: EventSchedulerState(pendingTasks: state.pendingTasks + [task]))

        case let .openThrottleWindow(key, intervalMillis, sourceId):
            let hasActiveWindow = state.pendingTasks.contains {
                $0.kind == .throttle && $0.key == key && $0.dueAtMillis > nowMillis
            }
            if hasActiveWindow {
                return EventSchedulerPlan(nextState: state)
            }

            let windowDueAtMillis = nowMillis + max(0, intervalMillis)
            let retained = state.pendingTasks.filter { !($0.kind == .throttle && $0.key == key) }
            let emitted = EventSchedulerTask(
                id: "throttle:\(key):\(nowMillis)",
                key: key,
                kind: .throttle,
                dueAtMillis: nowMillis,
                sourceId: sourceId
            )
            let window = EventSchedulerTask(
                id: "throttle:\(key):\(windowDueAtMillis)",
                key: key,
                kind: .throttle,
                dueAtMillis: windowDueAtMillis,
                sourceId: sourceId
            )
            return EventSchedulerPlan(
                nextState: EventSchedulerState(pendingTasks: retained + [window]),
                emittedTasks: [emitted]
            )

        case let .cancel(key):
            let canceled = state.pendingTasks.filter { $0.key == key }.map(\.id).sorted()
            let retained = state.pendingTasks.filter { $0.key != key }
            return EventSchedulerPlan(
                nextState: EventSchedulerState(pendingTasks: retained),
                canceledTaskIds: canceled
            )

        case .collectDue:
            let dueTasks = state.pendingTasks.filter { $0.dueAtMillis <= nowMillis }
            let futureTasks = state.pendingTasks.filter { $0.dueAtMillis > nowMillis }
            let emitted = dueTasks.filter { $0.kind != .throttle }
            return EventSchedulerPlan(
                nextState: EventSchedulerState(pendingTasks: futureTasks),
                emittedTasks: emitted
            )
        }
    }
}
