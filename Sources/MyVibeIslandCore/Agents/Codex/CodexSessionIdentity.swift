import Foundation

enum CodexSessionIdentity {
    static let prefix = "codex-"

    static func prefixed(_ sessionId: String) -> String {
        sessionId.hasPrefix(prefix) ? sessionId : "\(prefix)\(sessionId)"
    }

    static func rawThreadId(_ sessionId: String) -> String {
        sessionId.hasPrefix(prefix) ? String(sessionId.dropFirst(prefix.count)) : sessionId
    }

    static func canonicalSessionId(sessionId: String, codexThreadId: String? = nil) -> String {
        prefixed(codexThreadId.flatMap(nonEmpty) ?? rawThreadId(sessionId))
    }

    static func canonicalThreadKey(sessionId: String, codexThreadId: String? = nil) -> String {
        codexThreadId.flatMap(nonEmpty) ?? rawThreadId(sessionId)
    }

    static func canonicalJumpInput(_ jumpInput: JumpInput?, fallbackSessionId: String) -> JumpInput? {
        guard let jumpInput else { return nil }
        let rawThreadId = jumpInput.codexThreadId ?? rawThreadId(fallbackSessionId)
        let canonicalSessionId = canonicalSessionId(sessionId: jumpInput.sessionId, codexThreadId: rawThreadId)
        return JumpInput(
            sessionId: canonicalSessionId,
            source: jumpInput.source,
            bundleId: jumpInput.bundleId,
            cwd: jumpInput.cwd,
            cliSessionId: jumpInput.cliSessionId,
            pid: jumpInput.pid,
            tty: jumpInput.tty,
            termProgram: jumpInput.termProgram,
            customJumpURL: jumpInput.customJumpURL,
            isGhosttyFamilyHost: jumpInput.isGhosttyFamilyHost,
            supportsGhosttyPrivateFocus: jumpInput.supportsGhosttyPrivateFocus,
            isIDEHost: jumpInput.isIDEHost,
            parentId: jumpInput.parentId,
            inferredParentId: jumpInput.inferredParentId,
            openCodeParentID: jumpInput.openCodeParentID,
            codexThreadId: rawThreadId,
            isSSHRemote: jumpInput.isSSHRemote,
            sshLocalBundleIdentifier: jumpInput.sshLocalBundleIdentifier,
            isInTmux: jumpInput.isInTmux,
            tmuxPane: jumpInput.tmuxPane,
            tmuxSocketPath: jumpInput.tmuxSocketPath,
            zellijSessionName: jumpInput.zellijSessionName,
            zellijPaneId: jumpInput.zellijPaneId,
            itermSessionId: jumpInput.itermSessionId,
            cmuxWorkspaceId: jumpInput.cmuxWorkspaceId,
            cmuxSurfaceId: jumpInput.cmuxSurfaceId,
            cmuxSocketPath: jumpInput.cmuxSocketPath,
            terminalFocusIdentity: jumpInput.terminalFocusIdentity,
            warpPaneUUID: jumpInput.warpPaneUUID,
            warpFocusURL: jumpInput.warpFocusURL,
            kittyWindowId: jumpInput.kittyWindowId,
            kittyListenOn: jumpInput.kittyListenOn,
            weztermSocket: jumpInput.weztermSocket,
            weztermPane: jumpInput.weztermPane,
            ottySocket: jumpInput.ottySocket,
            ottyPaneId: jumpInput.ottyPaneId,
            ideWindowId: jumpInput.ideWindowId,
            createdAt: jumpInput.createdAt,
            terminalFingerprint: jumpInput.terminalFingerprint,
            termSessionId: jumpInput.termSessionId,
            supacodeWorktreeId: jumpInput.supacodeWorktreeId,
            supacodeTabId: jumpInput.supacodeTabId,
            supacodeSurfaceId: jumpInput.supacodeSurfaceId,
            supacodeSocketPath: jumpInput.supacodeSocketPath,
            sshConnection: jumpInput.sshConnection,
            sshTTY: jumpInput.sshTTY,
            remoteHostId: jumpInput.remoteHostId,
            remoteCwd: jumpInput.remoteCwd
        )
    }

    static func canonicalAgentSession(_ session: AgentSession) -> AgentSession {
        guard shouldCanonicalize(session) else { return session }
        let rawThreadId = session.jumpInput?.codexThreadId ?? rawThreadId(session.id)
        let canonicalId = canonicalSessionId(sessionId: session.id, codexThreadId: rawThreadId)
        return AgentSession(
            id: canonicalId,
            source: session.source,
            cwd: session.cwd,
            cliSessionId: session.cliSessionId,
            workspaceName: session.workspaceName,
            model: session.model,
            permissionMode: session.permissionMode,
            activeTool: session.activeTool,
            activitySummary: session.activitySummary,
            safeTitle: session.safeTitle,
            originalStatus: session.originalStatus,
            toolInput: session.toolInput,
            toolTarget: session.toolTarget,
            lastAssistantMessage: session.lastAssistantMessage,
            currentCommandPreview: session.currentCommandPreview,
            updatedAt: session.updatedAt,
            lastActivityAt: session.lastActivityAt,
            repoName: session.repoName,
            customTitle: session.customTitle,
            desktopTitle: session.desktopTitle,
            aiTitle: session.aiTitle,
            summary: session.summary,
            firstUserMessage: session.firstUserMessage,
            lastUserMessage: session.lastUserMessage,
            codexRolloutPath: session.codexRolloutPath,
            codexOrigin: session.codexOrigin,
            codexSubagentKind: session.codexSubagentKind,
            tasks: session.tasks,
            todos: session.todos,
            subagents: session.subagents,
            pendingRequestIds: session.pendingRequestIds,
            actionableRequests: session.actionableRequests,
            questionPrompt: session.questionPrompt,
            isRestored: session.isRestored,
            isRemote: session.isRemote,
            hasUnreadCompletion: session.hasUnreadCompletion,
            jumpInput: canonicalJumpInput(session.jumpInput, fallbackSessionId: session.id),
            resolvedJumpTarget: session.resolvedJumpTarget,
            redactionLevel: session.redactionLevel
        )
    }

    static func preferredAgentSession(_ lhs: AgentSession, _ rhs: AgentSession) -> AgentSession {
        let lhsScore = identityScore(lhs)
        let rhsScore = identityScore(rhs)
        if lhsScore != rhsScore {
            return lhsScore > rhsScore ? lhs : rhs
        }
        switch (lhs.updatedAt, rhs.updatedAt) {
        case let (lhsDate?, rhsDate?):
            return lhsDate >= rhsDate ? lhs : rhs
        case (.some, .none):
            return lhs
        case (.none, .some):
            return rhs
        case (.none, .none):
            return lhs.id <= rhs.id ? lhs : rhs
        }
    }

    static func normalizedSessions(_ sessions: [AgentSession]) -> [AgentSession] {
        var selected: [String: AgentSession] = [:]
        for session in sessions {
            let canonical = canonicalAgentSession(session)
            guard canonical.source == "codex" else {
                selected["source:\(canonical.source):\(canonical.id)"] = canonical
                continue
            }
            let key = "codex:\(canonicalThreadKey(sessionId: canonical.id, codexThreadId: canonical.jumpInput?.codexThreadId))"
            if let existing = selected[key] {
                selected[key] = preferredAgentSession(existing, canonical)
            } else {
                selected[key] = canonical
            }
        }
        return selected.values.sorted { $0.id < $1.id }
    }

    private static func shouldCanonicalize(_ session: AgentSession) -> Bool {
        guard session.source == "codex" else { return false }
        if session.id.hasPrefix(prefix) { return true }
        if session.codexRolloutPath != nil { return true }
        if session.jumpInput?.codexThreadId != nil { return true }
        return looksLikeCodexThreadId(session.id)
    }

    private static func looksLikeCodexThreadId(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.map(\.count) == [8, 4, 4, 4, 12] else { return false }
        return value.allSatisfy { character in
            character == "-" || character.isHexDigit
        }
    }

    private static func identityScore(_ session: AgentSession) -> Int {
        var score = 0
        if session.id.hasPrefix(prefix) { score += 16 }
        if session.codexRolloutPath != nil { score += 8 }
        if session.jumpInput?.codexThreadId != nil { score += 4 }
        if session.jumpInput != nil { score += 2 }
        if session.currentCommandPreview != nil || session.activeTool != nil { score += 1 }
        return score
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
