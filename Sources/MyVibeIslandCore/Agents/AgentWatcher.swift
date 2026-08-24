import Foundation

public enum AgentWatcherScheduledEventKind: String, Codable, Equatable, Sendable {
    case rescan
}

public struct AgentWatcherScheduledEvent: Codable, Equatable, Sendable {
    public let id: String
    public let sourceId: String
    public let kind: AgentWatcherScheduledEventKind
    public let scheduledAt: String

    public init(
        id: String,
        sourceId: String,
        kind: AgentWatcherScheduledEventKind,
        scheduledAt: String
    ) {
        self.id = id
        self.sourceId = sourceId
        self.kind = kind
        self.scheduledAt = scheduledAt
    }
}

public struct AgentWatcherState: Codable, Equatable, Sendable {
    public let watchedSourceIds: [String]
    public let isRunning: Bool
    public let pendingEvents: [AgentWatcherScheduledEvent]
    public let lastScanAt: String?

    public init(
        watchedSourceIds: [String] = [],
        isRunning: Bool = false,
        pendingEvents: [AgentWatcherScheduledEvent] = [],
        lastScanAt: String? = nil
    ) {
        self.watchedSourceIds = Array(Set(watchedSourceIds)).sorted()
        self.isRunning = isRunning
        self.pendingEvents = pendingEvents.sorted { lhs, rhs in
            if lhs.scheduledAt == rhs.scheduledAt {
                return lhs.id < rhs.id
            }
            return lhs.scheduledAt < rhs.scheduledAt
        }
        self.lastScanAt = lastScanAt
    }
}

public enum AgentWatcherCommand: Equatable, Sendable {
    case start
    case stop
    case rescan(sourceId: String, at: String)
}

public enum AgentWatcherPlanAction: String, Codable, Equatable, Sendable {
    case start
    case stop
    case rescan
    case ignoreUnknownSource
}

public struct AgentWatcherPlan: Codable, Equatable, Sendable {
    public let action: AgentWatcherPlanAction
    public let nextState: AgentWatcherState
    public let emittedEvents: [AgentWatcherScheduledEvent]

    public init(
        action: AgentWatcherPlanAction,
        nextState: AgentWatcherState,
        emittedEvents: [AgentWatcherScheduledEvent] = []
    ) {
        self.action = action
        self.nextState = nextState
        self.emittedEvents = emittedEvents
    }
}

public struct AgentWatcher: Sendable {
    public let sourceIds: [String]

    public init(sourceIds: [String]) {
        self.sourceIds = Array(Set(sourceIds)).sorted()
    }

    public func plan(_ command: AgentWatcherCommand, from state: AgentWatcherState) -> AgentWatcherPlan {
        switch command {
        case .start:
            return AgentWatcherPlan(
                action: .start,
                nextState: AgentWatcherState(
                    watchedSourceIds: sourceIds,
                    isRunning: true,
                    pendingEvents: state.pendingEvents,
                    lastScanAt: state.lastScanAt
                )
            )
        case .stop:
            return AgentWatcherPlan(
                action: .stop,
                nextState: AgentWatcherState(
                    watchedSourceIds: state.watchedSourceIds,
                    isRunning: false,
                    pendingEvents: [],
                    lastScanAt: state.lastScanAt
                )
            )
        case let .rescan(sourceId, at):
            guard state.watchedSourceIds.contains(sourceId) || sourceIds.contains(sourceId) else {
                return AgentWatcherPlan(action: .ignoreUnknownSource, nextState: state)
            }

            let event = AgentWatcherScheduledEvent(
                id: "rescan:\(sourceId):\(at)",
                sourceId: sourceId,
                kind: .rescan,
                scheduledAt: at
            )
            return AgentWatcherPlan(
                action: .rescan,
                nextState: AgentWatcherState(
                    watchedSourceIds: state.watchedSourceIds.isEmpty ? sourceIds : state.watchedSourceIds,
                    isRunning: state.isRunning,
                    pendingEvents: state.pendingEvents,
                    lastScanAt: at
                ),
                emittedEvents: [event]
            )
        }
    }
}
