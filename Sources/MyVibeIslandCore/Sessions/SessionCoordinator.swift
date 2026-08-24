import Foundation

public struct SessionCoordinatorReadSnapshot: Sendable {
    public let revision: UInt64
    public let sessions: [SessionState]

    public init(revision: UInt64, sessions: [SessionState]) {
        self.revision = revision
        self.sessions = sessions
    }

    public var sessionSnapshots: [SessionSnapshot] {
        sessions.map { $0.snapshot() }
    }

    public var actionableRequests: [ActionableRequest] {
        sessions.flatMap(\.actionableRequests)
    }
}

public final class SessionCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private let sessionEndCleanupScheduler: SessionEndCleanupScheduling
    private var sessions: [String: SessionState]
    private var codexCompletionArmedSessionIDs: Set<String> = []
    private var sessionEndCleanupObservers: [UUID: @Sendable () -> Void] = [:]
    private var revision: UInt64 = 0

    public convenience init(sessions: [SessionState] = []) {
        self.init(
            sessions: sessions,
            sessionEndCleanupScheduler: MainActorSessionEndCleanupScheduler()
        )
    }

    public init(
        sessions: [SessionState],
        sessionEndCleanupScheduler: SessionEndCleanupScheduling = MainActorSessionEndCleanupScheduler()
    ) {
        self.sessions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.sessionId, $0) })
        self.sessionEndCleanupScheduler = sessionEndCleanupScheduler
    }

    public func apply(_ event: AgentEvent) {
        apply(event, actionableRequestLifecycleTimestamp: nil)
    }

    public func apply(
        _ event: AgentEvent,
        actionableRequestLifecycleTimestamp: Date?
    ) {
        let endIntent: SessionEndIntent?
        lock.lock()

        switch event {
        case let .sessionStarted(source, sessionId, cwd):
            let existing = sessions[sessionId]
            var nextState = existing ?? SessionState(sessionId: sessionId, source: source, cwd: cwd)
            nextState.beginRuntime(source: source, cwd: cwd, at: Date())
            sessions[sessionId] = nextState
            endIntent = nil
        case let .sessionEnded(_, sessionId):
            endIntent = sessions[sessionId]?.sessionEndIntent()
        case let .sessionActivityUpdated(source, sessionId, activity):
            let normalizedActivity = completionNormalizedActivity(
                activity,
                source: source,
                sessionID: sessionId
            )
            if sessions[sessionId] == nil {
                sessions[sessionId] = SessionState(
                    sessionId: sessionId,
                    source: source,
                    cwd: normalizedActivity.cwd ?? ""
                )
            }
            sessions[sessionId]?.apply(
                .sessionActivityUpdated(
                    source: source,
                    sessionId: sessionId,
                    activity: normalizedActivity
                ),
                actionableRequestLifecycleTimestamp: actionableRequestLifecycleTimestamp
            )
            sessions[sessionId]?.recordLifecycleIngress(isPermission: false, at: Date())
            endIntent = nil
        case let .permissionRequested(source, sessionId, _, _, _),
             let .questionAsked(source, sessionId, _, _, _),
             let .taskUpdated(source, sessionId, _),
             let .todoUpdated(source, sessionId, _),
             let .teamGroupingUpdated(source, sessionId, _),
             let .jumpTargetUpdated(source, sessionId, _):
            if sessions[sessionId] == nil {
                sessions[sessionId] = SessionState(sessionId: sessionId, source: source, cwd: "")
            }
            sessions[sessionId]?.apply(
                event,
                actionableRequestLifecycleTimestamp: actionableRequestLifecycleTimestamp
            )
            sessions[sessionId]?.recordLifecycleIngress(
                isPermission: event.isPermissionLifecycleEvent,
                at: Date()
            )
            endIntent = nil
        case let .actionResolved(resolution):
            sessions[resolution.sessionId]?.apply(event)
            sessions[resolution.sessionId]?.recordLifecycleIngress(isPermission: true, at: Date())
            endIntent = nil
        case let .subagentLifecycleUpdated(source, childSessionId, lifecycle):
            guard source.lowercased() == "codex",
                  let parentThreadId = lifecycle.parentThreadId,
                  !parentThreadId.isEmpty else {
                endIntent = nil
                break
            }
            let parentSessionId = CodexSessionIdentity.prefixed(parentThreadId)
            guard var parent = sessions[parentSessionId] else {
                endIntent = nil
                break
            }
            let existing = parent.subagents.first { $0.id == childSessionId }
            parent.recordAcceptedChildLifecycle(lifecycle)
            parent.upsertSubagent(
                SubagentState(
                    id: childSessionId,
                    source: source,
                    parentSessionId: parentSessionId,
                    parentThreadId: parentThreadId,
                    threadId: CodexSessionIdentity.rawThreadId(childSessionId),
                    kind: lifecycle.kind,
                    nickname: lifecycle.nickname,
                    role: lifecycle.role,
                    status: lifecycle.status.rawValue,
                    sourceDetailId: existing?.sourceDetailId,
                    startedAt: existing?.startedAt ?? lifecycle.observedAt,
                    completedAt: lifecycle.status == .completed ? lifecycle.observedAt : existing?.completedAt,
                    hasLifecycleSignal: true,
                    currentActivity: lifecycle.currentActivity ?? existing?.currentActivity,
                    needsAttention: lifecycle.needsAttention,
                    runtimeProfileModel: lifecycle.runtimeProfileModel ?? existing?.runtimeProfileModel,
                    runtimeProfileReasoningEffort: lifecycle.runtimeProfileReasoningEffort
                        ?? existing?.runtimeProfileReasoningEffort,
                    agentId: lifecycle.agentId ?? existing?.agentId,
                    agentType: lifecycle.agentType ?? existing?.agentType,
                    parentChildId: lifecycle.parentChildId ?? existing?.parentChildId,
                    runtimeSessionId: lifecycle.runtimeSessionId ?? existing?.runtimeSessionId,
                    processIncarnation: lifecycle.processIncarnation ?? existing?.processIncarnation
                )
            )
            parent.recordLifecycleIngress(isPermission: false, at: Date())
            sessions[parentSessionId] = parent
            endIntent = nil
        case .messageReceived:
            endIntent = nil
        }
        revision &+= 1
        lock.unlock()

        guard let endIntent else { return }
        SessionCompletionTraceLog.append(
            stage: "session_end.cleanup_scheduled",
            sessionId: endIntent.sessionId,
            metadata: [
                "retentionSeconds": String(SessionEndLifecycle.completionRetentionWindow),
            ]
        )
        sessionEndCleanupScheduler.schedule(after: SessionEndLifecycle.completionRetentionWindow) { [weak self] in
            _ = self?.applyScheduledSessionEnd(intent: endIntent)
        }
    }

    public func snapshot(sessionId: String) -> SessionState? {
        lock.lock()
        defer {
            lock.unlock()
        }

        return sessions[sessionId]
    }

    public func snapshots() -> [SessionState] {
        lock.lock()
        defer {
            lock.unlock()
        }

        return sessions.values.sorted { $0.sessionId < $1.sessionId }
    }

    @discardableResult
    public func addSessionEndCleanupObserver(
        _ observer: @escaping @Sendable () -> Void
    ) -> UUID {
        let identifier = UUID()
        lock.lock()
        sessionEndCleanupObservers[identifier] = observer
        lock.unlock()
        return identifier
    }

    public func removeSessionEndCleanupObserver(_ identifier: UUID) {
        lock.lock()
        sessionEndCleanupObservers.removeValue(forKey: identifier)
        lock.unlock()
    }

    @discardableResult
    public func applyScheduledSessionEnd(intent: SessionEndIntent) -> Bool {
        lock.lock()
        guard let session = sessions[intent.sessionId], session.matches(intent) else {
            lock.unlock()
            SessionCompletionTraceLog.append(
                stage: "session_end.cleanup_rejected",
                sessionId: intent.sessionId
            )
            return false
        }
        sessions.removeValue(forKey: intent.sessionId)
        codexCompletionArmedSessionIDs.remove(intent.sessionId)
        revision &+= 1
        let observers = Array(sessionEndCleanupObservers.values)
        lock.unlock()
        SessionCompletionTraceLog.append(
            stage: "session_end.cleanup_applied",
            sessionId: intent.sessionId
        )
        observers.forEach { $0() }
        return true
    }

    public func readSnapshot() -> SessionCoordinatorReadSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return SessionCoordinatorReadSnapshot(
            revision: revision,
            sessions: sessions.values.sorted { $0.sessionId < $1.sessionId }
        )
    }

    public func sessionSnapshots() -> [SessionSnapshot] {
        snapshots().map { $0.snapshot() }
    }

    public func sessionPresentations() -> [SessionPresentation] {
        snapshots().map { $0.presentation() }
    }

    public func actionableRequests() -> [ActionableRequest] {
        snapshots().flatMap(\.actionableRequests)
    }

    @discardableResult
    public func resolveAction(_ resolution: ActionResolution) -> Bool {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard var session = sessions[resolution.sessionId] else {
            return false
        }

        let resolved = session.applyResolution(resolution)
        if resolved {
            sessions[resolution.sessionId] = session
            revision &+= 1
        }
        return resolved
    }

    public func storeSnapshot() -> SessionStoreSnapshot {
        SessionStoreSnapshot(sessions: snapshots().map {
            $0.agentSession(includeEphemeralActionState: false)
        })
    }

    public func restore(from snapshot: SessionStoreSnapshot) {
        lock.lock()
        defer {
            lock.unlock()
        }

        sessions = Dictionary(uniqueKeysWithValues: snapshot.sessions.map {
            let state = SessionState(agentSession: $0)
            return (state.sessionId, state)
        })
        revision &+= 1
    }

    public func save(to store: SessionStore) {
        store.mergeSessions(snapshots().map {
            $0.agentSession(includeEphemeralActionState: false)
        })
    }

    @discardableResult
    public func updateJumpTarget(
        sessionId: String,
        jumpInput: JumpInput,
        provenance: TerminalResolutionProvenance,
        strength: TerminalTargetStrength
    ) -> Bool {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard var session = sessions[sessionId] else {
            return false
        }
        session.updateJumpTarget(jumpInput, provenance: provenance, strength: strength)
        sessions[sessionId] = session
        revision &+= 1
        return true
    }

    public func restore(from store: SessionStore) {
        restore(from: store.loadSnapshot())
    }

    private func completionNormalizedActivity(
        _ activity: SessionActivityUpdate,
        source: String,
        sessionID: String
    ) -> SessionActivityUpdate {
        guard source == "codex" else { return activity }

        // Hook events identify a new prompt with the bootstrap marker, while a
        // rollout replay carries the recovered prompt fields instead. Both are
        // the original session-local evidence that a later terminal event can
        // qualify as the completion of a user turn.
        if activity.isBootstrapFirstUserMessage
            || hasPromptLifecycleEvidence(activity) {
            codexCompletionArmedSessionIDs.insert(sessionID)
        }

        let isTerminal = activity.status == .completed || activity.status == .failed
        let mayMarkUnread = activity.hasUnreadCompletion
            && codexCompletionArmedSessionIDs.contains(sessionID)
        if isTerminal {
            codexCompletionArmedSessionIDs.remove(sessionID)
        }
        guard mayMarkUnread != activity.hasUnreadCompletion else { return activity }
        return SessionActivityUpdate(
            status: activity.status,
            summary: activity.summary,
            originalStatus: activity.originalStatus,
            safeTitle: activity.safeTitle,
            cliSessionId: activity.cliSessionId,
            activeTool: activity.activeTool,
            toolInput: activity.toolInput,
            toolTarget: activity.toolTarget,
            lastAssistantMessage: activity.lastAssistantMessage,
            currentCommandPreview: activity.currentCommandPreview,
            updatedAt: activity.updatedAt,
            firstUserMessage: activity.firstUserMessage,
            lastUserMessage: activity.lastUserMessage,
            codexRolloutPath: activity.codexRolloutPath,
            codexOrigin: activity.codexOrigin,
            codexSubagentKind: activity.codexSubagentKind,
            needsAttention: activity.needsAttention,
            hasUnreadCompletion: mayMarkUnread,
            startsNewTurn: activity.startsNewTurn,
            isCompletionFallback: activity.isCompletionFallback,
            isBootstrapFirstUserMessage: activity.isBootstrapFirstUserMessage,
            cwd: activity.cwd
        )
    }

    private func hasPromptLifecycleEvidence(_ activity: SessionActivityUpdate) -> Bool {
        [activity.firstUserMessage, activity.lastUserMessage].contains { value in
            value?.contains(where: { !$0.isWhitespace && !$0.isNewline }) == true
        }
    }
}

private extension AgentEvent {
    var isPermissionLifecycleEvent: Bool {
        switch self {
        case .permissionRequested, .questionAsked, .actionResolved:
            true
        case .sessionStarted,
             .sessionEnded,
             .sessionActivityUpdated,
             .messageReceived,
             .taskUpdated,
             .todoUpdated,
             .teamGroupingUpdated,
             .jumpTargetUpdated,
             .subagentLifecycleUpdated:
            false
        }
    }
}
