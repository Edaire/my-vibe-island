import Foundation
import MyVibeIslandShared

public struct CodexActiveSessionListDiagnostics: Equatable, Sendable {
    public let codexProcessCount: Int
    public let correlatedSessionCount: Int
    public let unmatchedCandidateCount: Int

    public init(
        codexProcessCount: Int,
        correlatedSessionCount: Int,
        unmatchedCandidateCount: Int
    ) {
        self.codexProcessCount = codexProcessCount
        self.correlatedSessionCount = correlatedSessionCount
        self.unmatchedCandidateCount = unmatchedCandidateCount
    }
}

public struct CodexActiveSessionListResult: Equatable, Sendable {
    public let sessions: [SessionState]
    public let processCorrelatedSessions: [SessionState]
    public let unmatchedCandidates: [ProcessOnlyAgentCandidate]
    public let diagnostics: CodexActiveSessionListDiagnostics

    public init(
        sessions: [SessionState],
        processCorrelatedSessions: [SessionState]? = nil,
        unmatchedCandidates: [ProcessOnlyAgentCandidate],
        diagnostics: CodexActiveSessionListDiagnostics
    ) {
        self.sessions = sessions
        self.processCorrelatedSessions = processCorrelatedSessions ?? sessions
        self.unmatchedCandidates = unmatchedCandidates
        self.diagnostics = diagnostics
    }
}

public struct CodexActiveSessionListBuilder: Sendable {
    private let processSnapshots: @Sendable () throws -> [LocalProcessSnapshot]
    private let activeTTYs: @Sendable ([AgentSession]) -> Set<String>
    private let admissionRules: @Sendable () -> PersistedSessionAdmissionRulesV1
    private let correlator: AgentProcessCorrelator

    public init(
        processSnapshots: @escaping @Sendable () throws -> [LocalProcessSnapshot] = {
            try LocalProcessSnapshotProvider().snapshot()
        },
        activeTTYs: @escaping @Sendable ([AgentSession]) -> Set<String> = { sessions in
            ActiveCliTTYProvider().activeTTYs(for: sessions)
        },
        admissionRules: @escaping @Sendable () -> PersistedSessionAdmissionRulesV1 = {
            SessionAdmissionConfig.load(from: SessionAdmissionConfig.configURL())
        },
        correlator: AgentProcessCorrelator = AgentProcessCorrelator()
    ) {
        self.processSnapshots = processSnapshots
        self.activeTTYs = activeTTYs
        self.admissionRules = admissionRules
        self.correlator = correlator
    }

    public func build(from store: SessionStore) throws -> CodexActiveSessionListResult {
        let admissionRules = admissionRules()
        let storedSessions = CodexSessionIdentity.normalizedSessions(
            store.loadSnapshot().sessions.filter { $0.source == "codex" }
        ).filter { isAdmitted($0, rules: admissionRules) }
        let candidates = coalescedTTYCandidates(try processSnapshots().compactMap(candidate))
        // Store lifecycle owns admission/removal. The original list builder
        // does not reclassify restored ended sessions at render time; an
        // ended entry remains visible until the normalized SessionEnd path
        // removes it from the store. Process correlation only enriches jump
        // metadata and must not become a second display filter.
        let displayableSessions = storedSessions
        let correlations = correlator.correlate(candidates: candidates, sessions: displayableSessions)
        let correlatedIds = Set(correlations.map(\.sessionId))
        let candidateBySessionId = Dictionary(uniqueKeysWithValues: correlations.map { ($0.sessionId, $0.candidate) })
        let correlatedSessions = displayableSessions
            .filter { correlatedIds.contains($0.id) }
            .sorted(by: OriginalSessionDisplayOrder.precedes)
            .map { session -> SessionState in
                var state = SessionState(agentSession: session)
                if let candidate = candidateBySessionId[session.id], let jumpInput = session.jumpInput {
                    state.updateJumpTarget(
                        jumpInput.replacingProcessObservation(
                            pid: candidate.pid,
                            tty: terminalDeviceTTY(candidate.tty)
                        ),
                        provenance: .processObservation,
                        strength: .strong
                    )
                }
                return state
            }
        let matchedCandidatePIDs = Set(correlations.map(\.candidate.pid))
        let unmatchedCandidates = candidates.filter { !matchedCandidatePIDs.contains($0.pid) }
        var sessions = correlatedSessions
        let correlatedSessionIds = Set(correlatedSessions.map(\.sessionId))
        sessions.append(contentsOf: displayableSessions
            .filter { !correlatedSessionIds.contains($0.id) }
            .map(SessionState.init(agentSession:)))
        sessions = sessions.sorted { lhs, rhs in
            OriginalSessionDisplayOrder.precedes(lhs.agentSession(), rhs.agentSession())
        }

        return CodexActiveSessionListResult(
            sessions: sessions,
            processCorrelatedSessions: correlatedSessions,
            unmatchedCandidates: unmatchedCandidates,
            diagnostics: CodexActiveSessionListDiagnostics(
                codexProcessCount: candidates.count,
                correlatedSessionCount: sessions.count,
                unmatchedCandidateCount: unmatchedCandidates.count
            )
        )
    }

    private func coalescedTTYCandidates(_ candidates: [ProcessOnlyAgentCandidate]) -> [ProcessOnlyAgentCandidate] {
        var keyed: [String: ProcessOnlyAgentCandidate] = [:]
        for candidate in candidates {
            let key = normalizedTTY(candidate.tty).map { "tty:\($0)" } ?? "pid:\(candidate.pid)"
            if let existing = keyed[key] {
                keyed[key] = preferred(existing, candidate)
            } else {
                keyed[key] = candidate
            }
        }
        return keyed.values.sorted { lhs, rhs in
            (normalizedTTY(lhs.tty) ?? String(lhs.pid)) < (normalizedTTY(rhs.tty) ?? String(rhs.pid))
        }
    }

    private func preferred(
        _ lhs: ProcessOnlyAgentCandidate,
        _ rhs: ProcessOnlyAgentCandidate
    ) -> ProcessOnlyAgentCandidate {
        if lhs.sessionId == nil, rhs.sessionId != nil { return rhs }
        if lhs.sessionId != nil, rhs.sessionId == nil { return lhs }
        return lhs.pid <= rhs.pid ? lhs : rhs
    }

    private func isAdmitted(_ session: AgentSession, rules: PersistedSessionAdmissionRulesV1) -> Bool {
        let evidence = SessionAdmissionEvidence(
            cwd: session.cwd,
            bundleIdentifiers: [
                session.jumpInput?.bundleId,
                session.resolvedJumpTarget?.input.bundleId,
            ].compactMap { $0 }
        )
        return SessionAdmissionEvaluator.rejection(
            for: evidence,
            userBundleRules: rules.deniedAncestorBundles,
            userCwdRules: rules.deniedCwdPatterns
        ) == nil
    }

    private func candidate(from snapshot: LocalProcessSnapshot) -> ProcessOnlyAgentCandidate? {
        guard isCodexCommand(snapshot.command) else { return nil }
        return ProcessOnlyAgentCandidate(
            source: "codex",
            sessionId: sessionId(fromResumeCommand: snapshot.command),
            pid: snapshot.pid,
            tty: normalizedTTY(snapshot.tty),
            cwd: cwd(from: snapshot.command),
            command: snapshot.command,
            processName: processName(from: snapshot.command),
            detectedAgentKind: "codex-cli",
            confidence: 0.75
        )
    }

    private func isCodexCommand(_ command: String) -> Bool {
        let name = processName(from: command).lowercased()
        return name == "codex"
            || command.contains("/bin/codex")
            || command.contains("@openai/codex")
            || command.contains("com.openai.codex")
    }

    private func processName(from command: String) -> String {
        guard let first = command.split(whereSeparator: \.isWhitespace).first else { return "" }
        return URL(fileURLWithPath: String(first)).lastPathComponent
    }

    private func cwd(from command: String) -> String? {
        let parts = command.split(whereSeparator: \.isWhitespace).map(String.init)
        for index in parts.indices {
            if parts[index] == "--cwd", parts.indices.contains(index + 1) {
                return parts[index + 1]
            }
            if parts[index].hasPrefix("--cwd=") {
                return String(parts[index].dropFirst("--cwd=".count))
            }
        }
        return nil
    }

    private func sessionId(fromResumeCommand command: String) -> String? {
        let parts = command.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let resumeIndex = parts.firstIndex(of: "resume"),
              parts.indices.contains(resumeIndex + 1),
              isCodexThreadID(parts[resumeIndex + 1]) else {
            return nil
        }
        return CodexSessionIdentity.prefixed(parts[resumeIndex + 1])
    }

    private func isCodexThreadID(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.map(\.count) == [8, 4, 4, 4, 12] else { return false }
        return value.allSatisfy { $0 == "-" || $0.isHexDigit }
    }

    private func normalizedTTY(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized != "?", normalized != "??" else { return nil }
        return normalized.hasPrefix("/dev/") ? String(normalized.dropFirst(5)) : normalized
    }

    private func terminalDeviceTTY(_ value: String?) -> String? {
        guard let value = normalizedTTY(value) else { return nil }
        return "/dev/\(value)"
    }
}

/// Process correlation is a fallback beside the bridge-maintained session map.
/// Rebuilding it for every hook publication turns a normal busy system into a
/// continuous full process-table parse, so retain it briefly between reads.
public final class CachedCodexActiveSessionListBuilder: @unchecked Sendable {
    private let builder: CodexActiveSessionListBuilder
    private let minimumRefreshInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let lock = NSLock()
    private var cachedResult: CodexActiveSessionListResult?
    private var cachedAt: Date?

    public init(
        builder: CodexActiveSessionListBuilder = CodexActiveSessionListBuilder(),
        minimumRefreshInterval: TimeInterval = 5,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.builder = builder
        self.minimumRefreshInterval = max(0, minimumRefreshInterval)
        self.now = now
    }

    public func build(from store: SessionStore) throws -> CodexActiveSessionListResult {
        let currentTime = now()
        lock.lock()
        if let cachedResult,
           let cachedAt,
           currentTime.timeIntervalSince(cachedAt) < minimumRefreshInterval {
            lock.unlock()
            return cachedResult
        }
        lock.unlock()

        let result = try builder.build(from: store)
        lock.lock()
        cachedResult = result
        cachedAt = currentTime
        lock.unlock()
        return result
    }
}
