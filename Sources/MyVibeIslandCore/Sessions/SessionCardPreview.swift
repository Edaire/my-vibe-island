public struct SessionCardPreview: Codable, Equatable, Sendable {
    public let sessionId: String
    public let displayTitle: String
    public let sourceBadge: String
    public let statusBadge: String
    public let activeTool: String?
    public let activitySummary: String?
    public let activeTaskSummary: String
    public let todoSummary: String
    public let subagentSummary: String
    public let unreadCompletionMarker: Bool
    public let jumpAvailable: Bool
    public let isRemote: Bool
    public let remoteBadge: String?
    public let remoteHostLabel: String?
    public let remoteSessionIdentity: RemoteSessionIdentity?
    public let localCwdDisplay: String
    public let remoteCwdDisplay: String?
    public let cwdContextSummary: String
    public let remoteJumpHint: String?
    public let redactionLevel: RedactionLevel
    public let restored: Bool

    public init(session: AgentSession, snapshot: SessionSnapshot? = nil) {
        let jumpInput = session.jumpInput ?? snapshot?.jumpInput
        let remote = session.isRemote || jumpInput?.isSSHRemote == true
        let localCwd = Self.localCwdDisplay(session: session, snapshot: snapshot)
        let remoteHost = Self.nonEmpty(jumpInput?.remoteHostId)
        let remoteCwd = Self.nonEmpty(jumpInput?.remoteCwd)
        let hasLocalRemoteIdentity = Self.hasLocalRemoteJumpIdentity(jumpInput)

        sessionId = session.id
        displayTitle = Self.displayTitle(for: session, snapshot: snapshot)
        sourceBadge = session.source
        statusBadge = (snapshot?.status ?? Self.status(for: session)).rawValue
        activeTool = Self.nonEmpty(session.activeTool)
        activitySummary = Self.nonEmpty(session.activitySummary)
        activeTaskSummary = "\(session.tasks.filter { $0.status == .active }.count)/\(session.tasks.count) active tasks"
        todoSummary = "\(session.todos.count) todos"
        subagentSummary = "\(session.subagents.count) subagents"
        unreadCompletionMarker = session.hasUnreadCompletion
        jumpAvailable = Self.jumpAvailable(
            session: session,
            jumpInput: jumpInput,
            remote: remote,
            hasLocalRemoteIdentity: hasLocalRemoteIdentity
        )
        isRemote = remote
        remoteBadge = remote ? "remote" : nil
        remoteHostLabel = remoteHost
        remoteSessionIdentity = jumpInput.flatMap(RemoteSessionIdentity.fromJumpInput)
        localCwdDisplay = localCwd
        remoteCwdDisplay = remoteCwd
        cwdContextSummary = Self.cwdContextSummary(
            isRemote: remote,
            remoteHostLabel: remoteHost,
            remoteCwdDisplay: remoteCwd,
            localCwdDisplay: localCwd
        )
        remoteJumpHint = remote && !hasLocalRemoteIdentity ? "reconnect or repair remote session" : nil
        redactionLevel = Self.redactionLevel(session: session, snapshot: snapshot)
        restored = snapshot?.isRestored ?? session.isRestored
    }

    private static func displayTitle(for session: AgentSession, snapshot: SessionSnapshot?) -> String {
        if let customTitle = nonEmpty(session.customTitle) {
            return customTitle
        }
        if let desktopTitle = nonEmpty(session.desktopTitle) {
            return desktopTitle
        }
        if let aiTitle = nonEmpty(session.aiTitle) {
            return aiTitle
        }
        if let safeTitle = nonEmpty(session.safeTitle) {
            return safeTitle
        }
        if let summary = nonEmpty(session.summary) {
            return summary
        }
        if let firstUserMessage = nonEmpty(session.firstUserMessage) {
            return normalizeMessage(firstUserMessage)
        }
        if let lastUserMessage = nonEmpty(session.lastUserMessage) {
            return normalizeMessage(lastUserMessage)
        }
        if let repoName = nonEmpty(session.repoName) {
            return repoName
        }
        if let workspaceName = nonEmpty(session.workspaceName) {
            return workspaceName
        }
        if let cwdDisplay = nonEmpty(snapshot?.cwdDisplay) {
            return cwdDisplay
        }
        return session.id
    }

    private static func normalizeMessage(_ message: String) -> String {
        message
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func status(for session: AgentSession) -> SessionStatus {
        if !session.pendingRequestIds.isEmpty {
            return .waiting
        }
        if session.tasks.contains(where: { $0.status == .active }) {
            return .active
        }
        if session.tasks.contains(where: { $0.status == .failed }) {
            return .failed
        }
        if !session.tasks.isEmpty && session.tasks.allSatisfy({ $0.status == .completed }) {
            return .completed
        }
        return .idle
    }

    private static func redactionLevel(session: AgentSession, snapshot: SessionSnapshot?) -> RedactionLevel {
        if session.redactionLevel == .redacted || snapshot?.redactionLevel == .redacted {
            return .redacted
        }
        return .metadataOnly
    }

    private static func localCwdDisplay(session: AgentSession, snapshot: SessionSnapshot?) -> String {
        if let cwdDisplay = nonEmpty(snapshot?.cwdDisplay) {
            return cwdDisplay
        }
        return pathLastComponent(session.cwd)
    }

    private static func cwdContextSummary(
        isRemote: Bool,
        remoteHostLabel: String?,
        remoteCwdDisplay: String?,
        localCwdDisplay: String
    ) -> String {
        guard isRemote else {
            return localCwdDisplay
        }
        if let remoteHostLabel, let remoteCwdDisplay {
            return "\(remoteHostLabel):\(remoteCwdDisplay)"
        }
        return remoteCwdDisplay ?? remoteHostLabel ?? localCwdDisplay
    }

    private static func hasLocalRemoteJumpIdentity(_ jumpInput: JumpInput?) -> Bool {
        guard let jumpInput else {
            return false
        }
        return nonEmpty(jumpInput.sshTTY) != nil
            || nonEmpty(jumpInput.tmuxPane) != nil
            || nonEmpty(jumpInput.itermSessionId) != nil
            || nonEmpty(jumpInput.weztermPane) != nil
            || jumpInput.terminalFocusIdentity != nil
    }

    private static func jumpAvailable(
        session: AgentSession,
        jumpInput: JumpInput?,
        remote: Bool,
        hasLocalRemoteIdentity: Bool
    ) -> Bool {
        // IDA: `tmuxNoAttachedClient` is a terminal-focus outcome distinct from
        // `tmuxSelectPane`; do not render a jump affordance for that outcome.
        if jumpInput?.tmuxPane != nil, jumpInput?.tmuxHasAttachedClient == false {
            return false
        }
        return remote ? hasLocalRemoteIdentity : !session.cwd.isEmpty
    }

    private static func pathLastComponent(_ path: String) -> String {
        guard !path.isEmpty, path != "/" else {
            return path
        }
        return String(path.split(separator: "/", omittingEmptySubsequences: true).last ?? Substring(path))
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
