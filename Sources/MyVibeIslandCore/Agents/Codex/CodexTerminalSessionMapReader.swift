import Foundation
import MyVibeIslandShared

public struct CodexTerminalSessionMapReader: Sendable {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func readSessions() throws -> [SessionState] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let entries = try JSONDecoder().decode([String: TerminalSessionMapEntry].self, from: data)
        return entries.compactMap(session(key:entry:))
            .sorted {
                if $0.updatedAt != $1.updatedAt {
                    return ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
                }
                return $0.sessionId < $1.sessionId
            }
    }

    private func session(key: String, entry: TerminalSessionMapEntry) -> SessionState? {
        let source = entry.source ?? sourceFromKey(key)
        guard source == "codex" else { return nil }
        let threadID = entry.codexNotifyThreadId ?? key.strippingPrefix("codex-")
        let sessionID = CodexSessionIdentity.prefixed(threadID)
        let jumpInput = JumpInput(
            sessionId: sessionID,
            source: source,
            bundleId: entry.bundleIdentifier ?? entry.bundleIdentifiers?.first,
            cwd: entry.cwd,
            tty: entry.tty,
            termProgram: entry.termProgram,
            codexThreadId: threadID,
            isInTmux: entry.isInTmux,
            tmuxPane: entry.tmuxPane,
            tmuxSocketPath: entry.tmuxSocketPath,
            ottySocket: entry.ottySocket,
            ottyPaneId: entry.ottyPaneId,
            termSessionId: entry.termSessionId
        )
        return SessionState(
            sessionId: sessionID,
            source: source,
            cwd: entry.cwd ?? "",
            activeTool: entry.currentTool,
            originalStatus: originalStatus(from: entry.status),
            toolTarget: entry.toolTarget,
            lastAssistantMessage: entry.lastAssistantMessageFull ?? entry.lastAssistantMessage,
            updatedAt: entry.lastActivityAt.map(Date.init(timeIntervalSinceReferenceDate:)),
            lastActivityAt: entry.lastActivityAt.map(Date.init(timeIntervalSinceReferenceDate:)),
            repoName: entry.repoName,
            firstUserMessage: entry.firstUserMessage.flatMap(SyntheticUserText.unwrappedUserQuery),
            lastUserMessage: entry.lastUserMessage.flatMap(SyntheticUserText.unwrappedUserQuery),
            codexRolloutPath: entry.codexRolloutPath,
            reportedStatus: sessionStatus(from: entry.status),
            hasUnreadCompletion: entry.hasUnreadCompletion ?? false,
            jumpInput: jumpInput,
            resolvedJumpTarget: TerminalResolver().resolve(jumpInput, provenance: .transcriptMetadata)
        )
    }

    private func sourceFromKey(_ key: String) -> String {
        key.hasPrefix("codex-") ? "codex" : "unknown"
    }

    private func sessionStatus(from value: String?) -> SessionStatus? {
        switch value {
        case "running_tool", "working", "running", "processing":
            return .active
        case "waiting_for_input", "waiting", "idle":
            return .idle
        case "waiting_for_approval", "question":
            return .waiting
        case "completed", "done":
            return .completed
        case "failed", "error":
            return .failed
        default:
            return nil
        }
    }

    private func originalStatus(from value: String?) -> OriginalPixelStatusCompact {
        switch value {
        case "running_tool":
            return .runningTool
        case "working", "running", "processing":
            return .processing
        case "waiting_for_approval":
            return .waitingForApproval
        case "question":
            return .question
        case "completed", "done":
            return .ended
        case "failed", "error":
            return .ended
        case "waiting_for_input", "waiting", "idle":
            return .waitingForInput
        default:
            return .unknown
        }
    }
}

private extension String {
    func strippingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
