import Foundation

/// Runtime adapter between the published session snapshot and the V3 root
/// response selector. It owns only notification coordination state; session
/// retention and rendering remain owned by their existing components.
public struct V3RootResponseNotificationProducer: Sendable {
    public struct Emission: Equatable, Sendable {
        public let sessionId: String
        public let effect: V3RootResponseNotificationEffect

        public init(sessionId: String, effect: V3RootResponseNotificationEffect) {
            self.sessionId = sessionId
            self.effect = effect
        }
    }

    private var states: [String: V3RootResponseNotificationState] = [:]
    private var previousUnreadBySessionID: [String: Bool] = [:]
    private var seenSessionIDs: Set<String> = []
    private var childObservations: [String: ChildObservation] = [:]
    private var pendingRetrySessionIDs: Set<String> = []
    private var hasEstablishedBaseline = false

    public init() {}

    public mutating func ingest(
        _ snapshot: IslandRuntimeSnapshot,
        mode: V3RootResponseNotificationMode = .rootResponse,
        now: Date = Date()
    ) -> [Emission] {
        let sessionsByID = Dictionary(uniqueKeysWithValues: snapshot.sessions.map { ($0.id, $0) })
        let previewsByID = Dictionary(uniqueKeysWithValues: snapshot.sessionPreviews.map { ($0.sessionId, $0) })
        let currentIDs = Set(previewsByID.keys)

        for session in snapshot.sessions {
            observeChildren(of: session)
        }

        guard hasEstablishedBaseline else {
            hasEstablishedBaseline = true
            previousUnreadBySessionID = Dictionary(
                uniqueKeysWithValues: snapshot.sessionPreviews.map {
                    ($0.sessionId, $0.unreadCompletionMarker)
                }
            )
            seenSessionIDs.formUnion(currentIDs)
            return []
        }

        // The unread marker is consumed by the presentation layer. When it
        // clears, the next completion is a new response opportunity even if
        // the source did not provide a new timestamp in its fallback payload.
        for preview in snapshot.sessionPreviews where !preview.unreadCompletionMarker {
            guard previousUnreadBySessionID[preview.sessionId] == true,
                  var state = states[preview.sessionId] else { continue }
            state.lastResponseIdentity = nil
            state.lastViewedRevision = state.responseRevision
            states[preview.sessionId] = state
        }

        var emissions: [Emission] = []
        for preview in snapshot.sessionPreviews {
            guard preview.unreadCompletionMarker else { continue }
            let previous = previousUnreadBySessionID[preview.sessionId]
            let isNewSession = previous == nil && !seenSessionIDs.contains(preview.sessionId)
            let shouldRetry = pendingRetrySessionIDs.contains(preview.sessionId)
            guard previous == false || isNewSession || shouldRetry else { continue }
            let session = sessionsByID[preview.sessionId] ?? AgentSession(
                id: preview.sessionId,
                source: preview.sourceBadge,
                cwd: preview.localCwdDisplay,
                activitySummary: preview.activitySummary,
                lastAssistantMessage: preview.activitySummary,
                hasUnreadCompletion: preview.unreadCompletionMarker
            )

            let observation = snapshot.v3NotificationMetadata[session.id].map {
                ChildObservation(
                    generation: $0.childTreeGeneration,
                    lifecycleRevision: $0.childLifecycleRevision,
                    runningCount: $0.runningAuthoritativeChildCount,
                    hasAuthoritativeChildren: $0.childTreeHasAuthoritativeChildren
                )
            } ?? childObservations[session.id] ?? ChildObservation()
            var state = states[session.id] ?? makeInitialState(for: session)
            if shouldRetry {
                state.lastResponseIdentity = nil
            }
            let context = V3RootResponseNotificationContext(
                sessionId: session.id,
                runtimeInstanceId: state.runtimeInstanceId,
                responseIdentity: responseIdentity(for: session, preview: preview),
                mode: mode,
                childTreeGeneration: observation.generation,
                childLifecycleRevision: observation.lifecycleRevision,
                childTreeHasAuthoritativeChildren: observation.hasAuthoritativeChildren,
                runningAuthoritativeChildCount: observation.runningCount,
                hasSameTreeAttention: snapshot.v3NotificationMetadata[session.id]?.hasSameTreeAttention
                    ?? hasSameTreeAttention(for: session)
            )
            let selection = V3RootResponseNotificationSelector.select(
                context: context,
                state: state,
                now: now
            )
            states[session.id] = selection.state
            switch selection.effect {
            case .deferForAttention:
                pendingRetrySessionIDs.insert(session.id)
            case .updateOnly where observation.runningCount > 0:
                pendingRetrySessionIDs.insert(session.id)
            case .revealProgress, .revealFinal:
                pendingRetrySessionIDs.remove(session.id)
            case .updateOnly:
                break
            case .duplicate, .none:
                break
            }
            if let effect = selection.effect,
               effect == .revealProgress || effect == .revealFinal {
                emissions.append(Emission(sessionId: session.id, effect: effect))
                break
            }
        }

        previousUnreadBySessionID = Dictionary(
            uniqueKeysWithValues: snapshot.sessionPreviews.map {
                ($0.sessionId, $0.unreadCompletionMarker)
            }
        )
        seenSessionIDs.formUnion(currentIDs)
        previousUnreadBySessionID = previousUnreadBySessionID.filter { currentIDs.contains($0.key) }
        return emissions
    }

    private mutating func observeChildren(of session: AgentSession) {
        let authoritative = session.subagents.filter(\ .hasLifecycleSignal)
        let running = authoritative.filter {
            $0.status != SubagentLifecycleUpdate.Status.completed.rawValue
        }.count
        let fingerprint = authoritative.map {
            [$0.id, $0.status ?? "", $0.currentActivity ?? ""].joined(separator: "|")
        }.joined(separator: "\n")
        var observation = childObservations[session.id] ?? ChildObservation()
        if observation.fingerprint != fingerprint {
            observation.lifecycleRevision += 1
        }
        if running > 0 && observation.runningCount == 0 {
            observation.generation += 1
        }
        observation.fingerprint = fingerprint
        observation.runningCount = running
        observation.hasAuthoritativeChildren = !authoritative.isEmpty
        childObservations[session.id] = observation
    }

    private func makeInitialState(for session: AgentSession) -> V3RootResponseNotificationState {
        V3RootResponseNotificationState(
            runtimeInstanceId: stableRuntimeInstanceId(session.id),
            responseRevision: 0,
            lastResponseIdentity: nil,
            lastNotifiedRevision: 0,
            lastViewedRevision: 0,
            becameUnreadAt: Date.distantPast,
            rootTurnGeneration: 0,
            finalNotifiedChildGeneration: nil,
            finalNotifiedRootTurnGeneration: nil
        )
    }

    private func responseIdentity(
        for session: AgentSession,
        preview: SessionCardPreview
    ) -> String {
        [
            session.id,
            session.updatedAt.map(String.init(describing:)) ?? "",
            session.lastAssistantMessage ?? "",
            preview.activitySummary ?? "",
            preview.statusBadge,
        ].joined(separator: "\u{1f}")
    }

    private func hasSameTreeAttention(for session: AgentSession) -> Bool {
        switch session.originalStatus {
        case .waitingForApproval, .question:
            return true
        default:
            return !session.pendingRequestIds.isEmpty || !session.actionableRequests.isEmpty
        }
    }

    private func stableRuntimeInstanceId(_ value: String) -> Int {
        var result: UInt64 = 1469598103934665603
        for byte in value.utf8 {
            result ^= UInt64(byte)
            result &*= 1099511628211
        }
        return Int(result & 0x7fff_ffff_ffff_ffff)
    }

    private struct ChildObservation: Sendable {
        var fingerprint = ""
        var generation: Int = 0
        var lifecycleRevision: Int = 0
        var runningCount: Int = 0
        var hasAuthoritativeChildren = false

        init(
            fingerprint: String = "",
            generation: Int = 0,
            lifecycleRevision: Int = 0,
            runningCount: Int = 0,
            hasAuthoritativeChildren: Bool = false
        ) {
            self.fingerprint = fingerprint
            self.generation = generation
            self.lifecycleRevision = lifecycleRevision
            self.runningCount = runningCount
            self.hasAuthoritativeChildren = hasAuthoritativeChildren
        }
    }
}
