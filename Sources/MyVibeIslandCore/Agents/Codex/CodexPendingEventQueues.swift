public enum CodexPendingEventQueueKind: String, Codable, Equatable, Sendable {
    case delta
    case desktopHook
}

public struct CodexPendingEvent: Codable, Equatable, Sendable {
    public let id: String
    public let sessionId: String?
    public let receivedAtMillis: Int

    public init(id: String, sessionId: String? = nil, receivedAtMillis: Int) {
        self.id = id
        self.sessionId = sessionId
        self.receivedAtMillis = receivedAtMillis
    }
}

public struct CodexPendingEventQueues: Codable, Equatable, Sendable {
    public let pendingCodexDeltas: [CodexPendingEvent]
    public let pendingCodexDeltaTimeout: EventSchedulerTask?
    public let pendingCodexDesktopHooks: [CodexPendingEvent]
    public let pendingCodexDesktopHookTimeout: EventSchedulerTask?

    public var diagnosticSummary: CodexPendingEventQueueSummary {
        CodexPendingEventQueueSummary(queues: self)
    }

    public init(
        pendingCodexDeltas: [CodexPendingEvent] = [],
        pendingCodexDeltaTimeout: EventSchedulerTask? = nil,
        pendingCodexDesktopHooks: [CodexPendingEvent] = [],
        pendingCodexDesktopHookTimeout: EventSchedulerTask? = nil
    ) {
        self.pendingCodexDeltas = pendingCodexDeltas.sortedByReceipt()
        self.pendingCodexDeltaTimeout = pendingCodexDeltaTimeout
        self.pendingCodexDesktopHooks = pendingCodexDesktopHooks.sortedByReceipt()
        self.pendingCodexDesktopHookTimeout = pendingCodexDesktopHookTimeout
    }

    public func enqueue(
        _ event: CodexPendingEvent,
        in kind: CodexPendingEventQueueKind,
        timeout: EventSchedulerTask?
    ) -> CodexPendingEventQueues {
        switch kind {
        case .delta:
            CodexPendingEventQueues(
                pendingCodexDeltas: pendingCodexDeltas + [event],
                pendingCodexDeltaTimeout: timeout,
                pendingCodexDesktopHooks: pendingCodexDesktopHooks,
                pendingCodexDesktopHookTimeout: pendingCodexDesktopHookTimeout
            )

        case .desktopHook:
            CodexPendingEventQueues(
                pendingCodexDeltas: pendingCodexDeltas,
                pendingCodexDeltaTimeout: pendingCodexDeltaTimeout,
                pendingCodexDesktopHooks: pendingCodexDesktopHooks + [event],
                pendingCodexDesktopHookTimeout: timeout
            )
        }
    }
}

public struct CodexPendingEventQueueSummary: Codable, Equatable, Sendable {
    public let pendingDeltaCount: Int
    public let pendingDesktopHookCount: Int
    public let hasDeltaTimeout: Bool
    public let hasDesktopHookTimeout: Bool
    public let pendingTotalCount: Int

    public init(queues: CodexPendingEventQueues) {
        pendingDeltaCount = queues.pendingCodexDeltas.count
        pendingDesktopHookCount = queues.pendingCodexDesktopHooks.count
        hasDeltaTimeout = queues.pendingCodexDeltaTimeout != nil
        hasDesktopHookTimeout = queues.pendingCodexDesktopHookTimeout != nil
        pendingTotalCount = pendingDeltaCount + pendingDesktopHookCount
    }
}

private extension Array where Element == CodexPendingEvent {
    func sortedByReceipt() -> [CodexPendingEvent] {
        sorted { lhs, rhs in
            if lhs.receivedAtMillis == rhs.receivedAtMillis {
                return lhs.id < rhs.id
            }
            return lhs.receivedAtMillis < rhs.receivedAtMillis
        }
    }
}
