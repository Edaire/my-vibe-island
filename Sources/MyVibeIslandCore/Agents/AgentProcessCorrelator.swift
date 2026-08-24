import Foundation

public struct AgentProcessCorrelation: Equatable, Sendable {
    public let candidate: ProcessOnlyAgentCandidate
    public let sessionId: String

    public init(candidate: ProcessOnlyAgentCandidate, sessionId: String) {
        self.candidate = candidate
        self.sessionId = sessionId
    }
}

public struct AgentProcessCorrelator: Sendable {
    public init() {}

    public func correlate(
        candidate: ProcessOnlyAgentCandidate,
        sessions: [AgentSession]
    ) -> AgentProcessCorrelation? {
        let matchingSessions = sessions.filter { matches(candidate: candidate, session: $0) }
        guard matchingSessions.count == 1, let session = matchingSessions.first else { return nil }
        return AgentProcessCorrelation(candidate: candidate, sessionId: session.id)
    }

    public func correlate(
        candidates: [ProcessOnlyAgentCandidate],
        sessions: [AgentSession]
    ) -> [AgentProcessCorrelation] {
        let correlations = candidates.compactMap { correlate(candidate: $0, sessions: sessions) }
        let counts = Dictionary(grouping: correlations, by: \.sessionId).mapValues(\.count)
        return correlations.filter { counts[$0.sessionId] == 1 }
    }

    private func matches(candidate: ProcessOnlyAgentCandidate, session: AgentSession) -> Bool {
        guard candidate.source == session.source else { return false }
        if let candidateSessionId = candidate.sessionId {
            return candidateSessionId == session.id
        }
        if candidate.pid == session.jumpInput?.pid {
            return true
        }
        if let candidateTTY = normalizedTTY(candidate.tty) {
            let sessionTTYs = [
                session.jumpInput?.tty,
                session.resolvedJumpTarget?.input.tty,
            ].compactMap(normalizedTTY)
            if sessionTTYs.contains(candidateTTY) {
                return true
            }
        }
        guard let candidateCWD = candidate.cwd, !candidateCWD.isEmpty else { return false }
        return candidateCWD == session.cwd
    }

    private func normalizedTTY(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized != "?", normalized != "??" else { return nil }
        return normalized.hasPrefix("/dev/") ? String(normalized.dropFirst(5)) : normalized
    }
}
