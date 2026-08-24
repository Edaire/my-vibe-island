import Foundation

public final class JSONSessionStore: SessionStore, SessionStoreDiagnosticsProviding, @unchecked Sendable {
    private let lock = NSLock()
    private let fileURL: URL
    private var snapshot: SessionStoreSnapshot
    private var storedError: Error?

    public var lastError: Error? {
        lock.lock()
        defer {
            lock.unlock()
        }

        return storedError
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(SessionStoreSnapshot.self, from: data)
            let normalized = JSONSessionStore.normalized(decoded)
            snapshot = normalized
            storedError = nil
            if normalized != decoded {
                persistLocked()
            }
        } catch CocoaError.fileReadNoSuchFile {
            snapshot = SessionStoreSnapshot()
            storedError = nil
        } catch {
            snapshot = SessionStoreSnapshot()
            storedError = error
        }
    }

    public func loadSnapshot() -> SessionStoreSnapshot {
        lock.lock()
        defer {
            lock.unlock()
        }

        return snapshot
    }

    public func diagnostics() -> SessionStoreDiagnostics {
        lock.lock()
        defer {
            lock.unlock()
        }

        return SessionStoreDiagnostics(
            kind: "json",
            filePath: fileURL.path,
            lastErrorDescription: storedError.map { String(describing: $0) },
            sessionCount: snapshot.sessions.count
        )
    }

    public func replaceSnapshot(_ snapshot: SessionStoreSnapshot) {
        lock.lock()
        defer {
            lock.unlock()
        }

        self.snapshot = Self.normalized(snapshot)
        persistLocked()
    }

    public func upsert(_ session: AgentSession) {
        lock.lock()
        defer {
            lock.unlock()
        }

        var sessions = Dictionary(uniqueKeysWithValues: snapshot.sessions.map { ($0.id, $0) })
        sessions[session.id] = session
        snapshot = Self.normalized(SessionStoreSnapshot(
            schemaVersion: snapshot.schemaVersion,
            sessions: Array(sessions.values),
            activeSessionId: snapshot.activeSessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds,
            questionSelections: snapshot.questionSelections
        ))
        persistLocked()
    }

    public func mergeSessions(_ sessions: [AgentSession]) {
        lock.lock()
        defer { lock.unlock() }
        snapshot = Self.normalized(SessionStoreSnapshot(
            schemaVersion: snapshot.schemaVersion,
            sessions: sessions,
            activeSessionId: snapshot.activeSessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds,
            questionSelections: snapshot.questionSelections
        ))
        persistLocked()
    }

    public func remove(sessionId: String) {
        lock.lock()
        defer {
            lock.unlock()
        }

        snapshot = Self.normalized(SessionStoreSnapshot(
            schemaVersion: snapshot.schemaVersion,
            sessions: snapshot.sessions.filter { $0.id != sessionId },
            activeSessionId: snapshot.activeSessionId == sessionId ? nil : snapshot.activeSessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds.filter { $0 != sessionId },
            questionSelections: snapshot.questionSelections
        ))
        persistLocked()
    }

    public func setActiveSessionId(_ sessionId: String?) {
        lock.lock()
        defer {
            lock.unlock()
        }

        snapshot = Self.normalized(SessionStoreSnapshot(
            schemaVersion: snapshot.schemaVersion,
            sessions: snapshot.sessions,
            activeSessionId: sessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds,
            questionSelections: snapshot.questionSelections
        ))
        persistLocked()
    }

    public func markSummarized(sessionId: String) {
        lock.lock()
        defer {
            lock.unlock()
        }

        snapshot = Self.normalized(SessionStoreSnapshot(
            schemaVersion: snapshot.schemaVersion,
            sessions: snapshot.sessions,
            activeSessionId: snapshot.activeSessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds + [sessionId],
            questionSelections: snapshot.questionSelections
        ))
        persistLocked()
    }

    public func setQuestionSelection(_ selection: String, forRequestId requestId: String) {
        lock.lock()
        defer {
            lock.unlock()
        }

        var questionSelections = snapshot.questionSelections
        questionSelections[requestId] = selection
        snapshot = Self.normalized(SessionStoreSnapshot(
            schemaVersion: snapshot.schemaVersion,
            sessions: snapshot.sessions,
            activeSessionId: snapshot.activeSessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds,
            questionSelections: questionSelections
        ))
        persistLocked()
    }

    private func persistLocked() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
            storedError = nil
        } catch {
            storedError = error
        }
    }

    private static func normalized(_ snapshot: SessionStoreSnapshot) -> SessionStoreSnapshot {
        SessionStoreSnapshot(
            schemaVersion: snapshot.schemaVersion,
            sessions: CodexSessionIdentity.normalizedSessions(snapshot.sessions),
            activeSessionId: snapshot.activeSessionId,
            summarizedSessionIds: Array(Set(snapshot.summarizedSessionIds)).sorted(),
            questionSelections: snapshot.questionSelections
        )
    }
}
