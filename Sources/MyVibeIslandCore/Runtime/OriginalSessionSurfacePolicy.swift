import Foundation

public struct OriginalSessionSurfaceDecision: Equatable, Sendable {
    public let surfaced: [AgentSession]
    public let deferred: [AgentSession]
    public let spotlightID: String?

    public init(surfaced: [AgentSession], deferred: [AgentSession], spotlightID: String?) {
        self.surfaced = surfaced
        self.deferred = deferred
        self.spotlightID = spotlightID
    }
}

public enum OriginalSessionSurfacePolicy {
    public static func resolve(
        sessions: [AgentSession],
        now: Date = Date(),
        staleCompletedAfter: TimeInterval = 300,
        inactiveLiveAfter: TimeInterval = 1_200,
        focusedID: String? = nil,
        activeCliTTYs: Set<String> = []
    ) -> OriginalSessionSurfaceDecision {
        let uniqueSessions = sessions.reduce(into: [String: AgentSession]()) { result, session in
            if result[session.id] == nil {
                result[session.id] = session
            }
        }.values

        let classified = uniqueSessions.map { session in
            (
                session,
                priority(
                    for: session,
                    now: now,
                    staleCompletedAfter: staleCompletedAfter,
                    inactiveLiveAfter: inactiveLiveAfter
                )
            )
        }
        let surfaced = OriginalSessionDisplayOrder.sort(
            classified
                .filter { $0.1 != nil }
                .map(\.0)
        )
        let deferred = classified
            .filter { $0.1 == nil }
            .sorted { $0.0.id < $1.0.id }
            .map(\.0)

        let normalizedActiveTTYs = Set(activeCliTTYs.compactMap(normalizedTTY))
        let focusedActiveSpotlightID = focusedID.flatMap { id in
            surfaced.first(where: { session in
                guard session.id == id,
                      spotlightPriority(
                          for: session,
                          now: now,
                          staleCompletedAfter: staleCompletedAfter,
                          inactiveLiveAfter: inactiveLiveAfter
                      ) != nil else {
                    return false
                }
                return sessionTTYs(session).contains { normalizedActiveTTYs.contains($0) }
            })?.id
        }
        let spotlightID = focusedActiveSpotlightID ?? surfaced.first(where: { session in
            guard spotlightPriority(
                for: session,
                now: now,
                staleCompletedAfter: staleCompletedAfter,
                inactiveLiveAfter: inactiveLiveAfter
            ) != nil else {
                return false
            }
            return sessionTTYs(session).contains { normalizedActiveTTYs.contains($0) }
        })?.id ?? focusedID.flatMap { id in
            surfaced.first(where: {
                $0.id == id
                    && spotlightPriority(
                        for: $0,
                        now: now,
                        staleCompletedAfter: staleCompletedAfter,
                        inactiveLiveAfter: inactiveLiveAfter
                    ) != nil
            })?.id
        } ?? surfaced.first(where: {
                spotlightPriority(
                    for: $0,
                    now: now,
                    staleCompletedAfter: staleCompletedAfter,
                    inactiveLiveAfter: inactiveLiveAfter
                ) != nil
        })?.id

        return OriginalSessionSurfaceDecision(
            surfaced: surfaced,
            deferred: deferred,
            spotlightID: spotlightID
        )
    }

    private static func sessionTTYs(_ session: AgentSession) -> Set<String> {
        Set([
            session.jumpInput?.tty,
            session.resolvedJumpTarget?.input.tty,
        ].compactMap(normalizedTTY))
    }

    private static func normalizedTTY(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized != "?", normalized != "??" else { return nil }
        return normalized.hasPrefix("/dev/") ? String(normalized.dropFirst(5)) : normalized
    }

    private static func priority(
        for session: AgentSession,
        now: Date,
        staleCompletedAfter: TimeInterval,
        inactiveLiveAfter: TimeInterval
    ) -> Int? {
        if session.source == "claude",
           session.firstUserMessage == nil,
           session.lastUserMessage == nil,
           session.lastAssistantMessage == nil,
           session.activeTool == nil,
           session.activitySummary == nil,
           session.summary == nil,
           session.pendingRequestIds.isEmpty,
           session.actionableRequests.isEmpty,
           session.questionPrompt == nil,
           session.tasks.isEmpty,
           session.todos.isEmpty,
           session.subagents.isEmpty {
            return session.jumpInput != nil || session.resolvedJumpTarget != nil ? 3 : nil
        }
        if isAttention(session) { return 0 }
        if isRunning(session) {
            return session.isRestored ? nil : 1
        }
        if isCompleted(session) {
            guard !isStaleCompleted(session, now: now, threshold: staleCompletedAfter) else { return nil }
            return 2
        }
        guard !session.isRestored else { return nil }
        guard let updatedAt = session.updatedAt else {
            if session.source == "claude" {
                return session.jumpInput != nil || session.resolvedJumpTarget != nil ? 3 : nil
            }
            return 3
        }
        if session.jumpInput != nil || session.resolvedJumpTarget != nil {
            return 3
        }
        if now.timeIntervalSince(updatedAt) >= inactiveLiveAfter { return nil }
        return 3
    }

    private static func spotlightPriority(
        for session: AgentSession,
        now: Date,
        staleCompletedAfter: TimeInterval,
        inactiveLiveAfter: TimeInterval
    ) -> Int? {
        guard let priority = priority(
            for: session,
            now: now,
            staleCompletedAfter: staleCompletedAfter,
            inactiveLiveAfter: inactiveLiveAfter
        ) else {
            return nil
        }
        return priority <= 2 ? priority : nil
    }

    private static func isAttention(_ session: AgentSession) -> Bool {
        !session.pendingRequestIds.isEmpty
            || !session.actionableRequests.isEmpty
            || session.questionPrompt != nil
            || session.originalStatus == .waitingForApproval
            || session.originalStatus == .question
    }

    private static func isRunning(_ session: AgentSession) -> Bool {
        switch session.originalStatus {
        case .processing, .thinking, .runningTool, .compacting:
            return true
        case .waitingForInput, .waitingForApproval, .question, .ended, .unknown:
            return false
        }
    }

    private static func isCompleted(_ session: AgentSession) -> Bool {
        session.originalStatus == .ended || session.hasUnreadCompletion
    }

    private static func isStaleCompleted(
        _ session: AgentSession,
        now: Date,
        threshold: TimeInterval
    ) -> Bool {
        guard let updatedAt = session.updatedAt else { return session.isRestored }
        return now.timeIntervalSince(updatedAt) >= threshold
    }
}
