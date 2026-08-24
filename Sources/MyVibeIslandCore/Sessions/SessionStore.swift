import Foundation

public struct SessionStoreSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let sessions: [AgentSession]
    public let activeSessionId: String?
    public let summarizedSessionIds: [String]
    public let questionSelections: [String: String]

    public init(
        schemaVersion: Int = 1,
        sessions: [AgentSession] = [],
        activeSessionId: String? = nil,
        summarizedSessionIds: [String] = [],
        questionSelections: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.sessions = sessions
        self.activeSessionId = activeSessionId
        self.summarizedSessionIds = summarizedSessionIds
        self.questionSelections = questionSelections
    }
}

public protocol SessionStore: Sendable {
    func loadSnapshot() -> SessionStoreSnapshot
    func replaceSnapshot(_ snapshot: SessionStoreSnapshot)
    func mergeSessions(_ sessions: [AgentSession])
    func upsert(_ session: AgentSession)
    func remove(sessionId: String)
    func setActiveSessionId(_ sessionId: String?)
    func markSummarized(sessionId: String)
    func setQuestionSelection(_ selection: String, forRequestId requestId: String)
}

public final class InMemorySessionStore: SessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var schemaVersion: Int
    private var sessions: [String: AgentSession]
    private var activeSessionId: String?
    private var summarizedSessionIds: Set<String>
    private var questionSelections: [String: String]

    public init(snapshot: SessionStoreSnapshot = SessionStoreSnapshot()) {
        schemaVersion = snapshot.schemaVersion
        sessions = Dictionary(uniqueKeysWithValues: CodexSessionIdentity.normalizedSessions(snapshot.sessions).map { ($0.id, $0) })
        activeSessionId = snapshot.activeSessionId
        summarizedSessionIds = Set(snapshot.summarizedSessionIds)
        questionSelections = snapshot.questionSelections
    }

    public func loadSnapshot() -> SessionStoreSnapshot {
        lock.lock()
        defer {
            lock.unlock()
        }

        return snapshotLocked()
    }

    public func replaceSnapshot(_ snapshot: SessionStoreSnapshot) {
        lock.lock()
        defer {
            lock.unlock()
        }

        schemaVersion = snapshot.schemaVersion
        sessions = Dictionary(uniqueKeysWithValues: CodexSessionIdentity.normalizedSessions(snapshot.sessions).map { ($0.id, $0) })
        activeSessionId = snapshot.activeSessionId
        summarizedSessionIds = Set(snapshot.summarizedSessionIds)
        questionSelections = snapshot.questionSelections
    }

    public func upsert(_ session: AgentSession) {
        lock.lock()
        defer {
            lock.unlock()
        }

        let canonical = CodexSessionIdentity.canonicalAgentSession(session)
        sessions[canonical.id] = canonical
    }

    public func mergeSessions(_ sessions: [AgentSession]) {
        lock.lock()
        defer { lock.unlock() }
        self.sessions = Dictionary(uniqueKeysWithValues: CodexSessionIdentity.normalizedSessions(sessions).map { ($0.id, $0) })
    }

    public func remove(sessionId: String) {
        lock.lock()
        defer {
            lock.unlock()
        }

        sessions.removeValue(forKey: sessionId)
        summarizedSessionIds.remove(sessionId)
        if activeSessionId == sessionId {
            activeSessionId = nil
        }
    }

    public func setActiveSessionId(_ sessionId: String?) {
        lock.lock()
        defer {
            lock.unlock()
        }

        activeSessionId = sessionId
    }

    public func markSummarized(sessionId: String) {
        lock.lock()
        defer {
            lock.unlock()
        }

        summarizedSessionIds.insert(sessionId)
    }

    public func setQuestionSelection(_ selection: String, forRequestId requestId: String) {
        lock.lock()
        defer {
            lock.unlock()
        }

        questionSelections[requestId] = selection
    }

    private func snapshotLocked() -> SessionStoreSnapshot {
        SessionStoreSnapshot(
            schemaVersion: schemaVersion,
            sessions: sessions.values.sorted { $0.id < $1.id },
            activeSessionId: activeSessionId,
            summarizedSessionIds: summarizedSessionIds.sorted(),
            questionSelections: questionSelections
        )
    }
}
