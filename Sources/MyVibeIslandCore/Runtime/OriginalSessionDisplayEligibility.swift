import Foundation

/// IDA `sub_1000D48E0` reads `sensoryPolicy`, provider/origin metadata, and the
/// `cwd` field through SessionState's dynamic field-offset vector. The local
/// implementation applies the trusted render-admission branches: live
/// lifecycle evidence, Codex internal-origin exclusions, and the cwd
/// consolidation predicate. A restored session is store history, not current
/// runtime evidence, and is admitted again only after a live hook or watcher
/// event clears its restored state.
public enum OriginalSessionDisplayEligibility {
    public static func isEligible(
        _ session: AgentSession,
        liveSessionIDs: Set<String> = []
    ) -> Bool {
        if session.isRestored && !liveSessionIDs.contains(session.id) {
            return false
        }

        let source = session.source.lowercased()
        if source == "codex",
           session.codexOrigin == "subagent",
           let kind = session.codexSubagentKind,
           kind == "/tmp/vibe-island.lastrun" || kind == "guardian" {
            return false
        }

        return !isKnownInternalSessionCWD(session.cwd)
    }

    public static func isKnownInternalSessionCWD(_ cwd: String) -> Bool {
        guard !cwd.isEmpty else { return false }

        var normalized = cwd
        while normalized.count > 1, normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        return normalized.hasSuffix("memory_consolidation")
            || normalized.contains("</conversation_history>")
    }
}
