public struct TerminalFingerprint: Codable, Equatable, Sendable {
    public let sessionId: String
    public let source: String
    public let cwd: String?
    public let tty: String?
    public let termSessionId: String?
    public let itermSessionId: String?
    public let tmuxPane: String?
    public let zellijSessionName: String?
    public let zellijPaneId: String?
    public let kittyWindowId: String?
    public let cmuxWorkspaceId: String?
    public let cmuxSurfaceId: String?
    public let cmuxSocketPath: String?
    public let isOpenCodeSubagent: Bool
    public let isCodexThreadSpawnSubagent: Bool
    public let weztermPane: String?
    public let sshTTY: String?
    public let bundleId: String?

    public init(
        sessionId: String,
        source: String,
        cwd: String? = nil,
        tty: String? = nil,
        termSessionId: String? = nil,
        itermSessionId: String? = nil,
        tmuxPane: String? = nil,
        zellijSessionName: String? = nil,
        zellijPaneId: String? = nil,
        kittyWindowId: String? = nil,
        cmuxWorkspaceId: String? = nil,
        cmuxSurfaceId: String? = nil,
        cmuxSocketPath: String? = nil,
        isOpenCodeSubagent: Bool = false,
        isCodexThreadSpawnSubagent: Bool = false,
        weztermPane: String? = nil,
        sshTTY: String? = nil,
        bundleId: String? = nil
    ) {
        self.sessionId = sessionId
        self.source = source
        self.cwd = TerminalModelNormalization.nonEmpty(cwd)
        self.tty = TerminalModelNormalization.nonEmpty(tty)
        self.termSessionId = TerminalModelNormalization.nonEmpty(termSessionId)
        self.itermSessionId = TerminalModelNormalization.nonEmpty(itermSessionId)
        self.tmuxPane = TerminalModelNormalization.nonEmpty(tmuxPane)
        self.zellijSessionName = TerminalModelNormalization.nonEmpty(zellijSessionName)
        self.zellijPaneId = TerminalModelNormalization.nonEmpty(zellijPaneId)
        self.kittyWindowId = TerminalModelNormalization.nonEmpty(kittyWindowId)
        self.cmuxWorkspaceId = TerminalModelNormalization.nonEmpty(cmuxWorkspaceId)
        self.cmuxSurfaceId = TerminalModelNormalization.nonEmpty(cmuxSurfaceId)
        self.cmuxSocketPath = TerminalModelNormalization.nonEmpty(cmuxSocketPath)
        self.isOpenCodeSubagent = isOpenCodeSubagent
        self.isCodexThreadSpawnSubagent = isCodexThreadSpawnSubagent
        self.weztermPane = TerminalModelNormalization.nonEmpty(weztermPane)
        self.sshTTY = TerminalModelNormalization.nonEmpty(sshTTY)
        self.bundleId = TerminalModelNormalization.nonEmpty(bundleId)
    }

    public static func fromHookEnvironment(
        sessionId: String,
        source: String,
        environment: HookEnvironment
    ) -> TerminalFingerprint {
        TerminalFingerprint(
            sessionId: sessionId,
            source: source,
            cwd: environment.cwd,
            tty: environment.tty,
            termSessionId: environment.termSessionId,
            itermSessionId: environment.itermSessionId,
            tmuxPane: environment.tmuxPane,
            zellijSessionName: environment.zellijSessionName,
            zellijPaneId: environment.zellijPaneId,
            kittyWindowId: environment.kittyWindowId,
            cmuxWorkspaceId: environment.cmuxWorkspaceId,
            cmuxSurfaceId: environment.cmuxSurfaceId,
            cmuxSocketPath: environment.cmuxSocketPath,
            weztermPane: environment.weztermPane,
            sshTTY: environment.sshTTY,
            bundleId: environment.cfBundleIdentifier
        )
    }
}
