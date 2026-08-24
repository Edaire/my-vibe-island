import Foundation
import MyVibeIslandShared

public struct CodexTerminalSessionMapWriteResult: Equatable, Sendable {
    public let totalCount: Int
    public let codexCount: Int
    public let fileURL: URL
}

public struct CodexTerminalSessionMapWriter: Sendable {
    public init() {}

    @discardableResult
    public func write(sessions: [SessionState], to fileURL: URL) throws -> CodexTerminalSessionMapWriteResult {
        var merged: [String: SessionState] = [:]
        for session in sessions where Self.shouldWrite(session) {
            let key = key(for: session)
            if let existing = merged[key], !Self.isNewer(session, than: existing) {
                continue
            }
            merged[key] = session
        }
        let entries = merged.mapValues(Self.entry)

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(to: fileURL, options: .atomic)

        return CodexTerminalSessionMapWriteResult(
            totalCount: entries.count,
            codexCount: entries.count,
            fileURL: fileURL
        )
    }

    private func key(for session: SessionState) -> String {
        session.sessionId.hasPrefix("codex-") ? session.sessionId : "codex-\(session.sessionId)"
    }

    private static func shouldWrite(_ session: SessionState) -> Bool {
        guard session.source == "codex", !session.isRestored else { return false }
        return true
    }

    private static func isNewer(_ candidate: SessionState, than existing: SessionState) -> Bool {
        switch (candidate.updatedAt, existing.updatedAt) {
        case let (candidate?, existing?):
            return candidate >= existing
        case (.some, .none), (.none, .none):
            return true
        case (.none, .some):
            return false
        }
    }

    private static func entry(for session: SessionState) -> TerminalSessionMapEntry {
        let git = gitIdentity(for: session)
        return TerminalSessionMapEntry(
            source: session.source,
            status: status(session),
            currentTool: session.activeTool,
            toolTarget: session.toolTarget ?? session.currentCommandPreview,
            cwd: session.cwd,
            firstUserMessage: session.firstUserMessage.flatMap(SyntheticUserText.unwrappedUserQuery),
            lastUserMessage: session.lastUserMessage.flatMap(SyntheticUserText.unwrappedUserQuery),
            lastAssistantMessage: session.lastAssistantMessage,
            lastAssistantMessageFull: session.lastAssistantMessage,
            hasUnreadCompletion: session.hasUnreadCompletion,
            codexRolloutPath: session.codexRolloutPath,
            lastActivityAt: session.lastActivityAt.timeIntervalSinceReferenceDate,
            bundleIdentifier: session.jumpInput?.bundleId,
            bundleIdentifiers: [session.jumpInput?.bundleId].compactMap { $0 },
            admissionRejection: SessionAdmissionEvaluator.rejection(
                for: SessionAdmissionEvidence(
                    cwd: session.cwd,
                    bundleIdentifiers: [session.jumpInput?.bundleId].compactMap { $0 }
                )
            )?.description,
            gitIdentityStatus: git.status,
            repoName: git.info?.repoName,
            worktreeName: git.info?.worktreeName,
            gitBranch: git.info?.branch,
            termProgram: session.jumpInput?.termProgram,
            tty: session.jumpInput?.tty,
            isInTmux: session.jumpInput?.isInTmux,
            tmuxPane: session.jumpInput?.tmuxPane,
            tmuxSocketPath: session.jumpInput?.tmuxSocketPath,
            ottySocket: session.jumpInput?.ottySocket,
            ottyPaneId: session.jumpInput?.ottyPaneId,
            termSessionId: session.jumpInput?.termSessionId,
            codexNotifyThreadId: session.jumpInput?.codexThreadId
                ?? session.sessionId.strippingPrefix("codex-")
        )
    }

    private static func gitIdentity(for session: SessionState) -> (status: String, info: ProjectGitInfo?) {
        if let repoName = session.repoName, !repoName.isEmpty {
            return ("ok", ProjectGitInfo(repoName: repoName))
        }
        return ("unavailable", nil)
    }

    private static func status(_ session: SessionState) -> String {
        switch session.originalStatus {
        case .runningTool:
            return "running_tool"
        case .waitingForApproval:
            return "waiting_for_approval"
        case .question:
            return "question"
        case .processing, .thinking, .compacting:
            return "working"
        case .ended:
            return "done"
        case .waitingForInput, .unknown:
            break
        }

        switch session.reportedStatus {
        case .active:
            return "working"
        case .waiting:
            return "waiting_for_approval"
        case .completed:
            return "done"
        case .failed:
            return "failed"
        case .idle, .none:
            return "waiting_for_input"
        }
    }
}

private extension String {
    func strippingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
