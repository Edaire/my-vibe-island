public struct JumpInput: Codable, Equatable, Sendable {
    public let sessionId: String
    public let source: String
    public let bundleId: String?
    public let cwd: String?
    public let cliSessionId: String?
    public let pid: Int?
    public let tty: String?
    public let termProgram: String?
    public let customJumpURL: String?
    public let isGhosttyFamilyHost: Bool?
    public let supportsGhosttyPrivateFocus: Bool?
    public let isIDEHost: Bool?
    public let parentId: String?
    public let inferredParentId: String?
    public let openCodeParentID: String?
    public let codexThreadId: String?
    public let isSSHRemote: Bool?
    public let sshLocalBundleIdentifier: String?
    public let isInTmux: Bool?
    public let tmuxPane: String?
    public let tmuxSocketPath: String?
    public let tmuxHasAttachedClient: Bool?
    public let tmuxClientTTY: String?
    public let zellijSessionName: String?
    public let zellijPaneId: String?
    public let itermSessionId: String?
    public let cmuxWorkspaceId: String?
    public let cmuxSurfaceId: String?
    public let cmuxSocketPath: String?
    public let terminalFocusIdentity: TerminalFocusIdentity?
    public let warpPaneUUID: String?
    public let warpFocusURL: String?
    public let kittyWindowId: String?
    public let kittyListenOn: String?
    public let weztermSocket: String?
    public let weztermPane: String?
    public let ottySocket: String?
    public let ottyPaneId: String?
    public let ideWindowId: String?
    public let createdAt: String?
    public let terminalFingerprint: TerminalFingerprint?
    public let termSessionId: String?
    public let supacodeWorktreeId: String?
    public let supacodeTabId: String?
    public let supacodeSurfaceId: String?
    public let supacodeSocketPath: String?
    public let sshConnection: String?
    public let sshTTY: String?
    public let remoteHostId: String?
    public let remoteCwd: String?

    public init(
        sessionId: String,
        source: String,
        bundleId: String? = nil,
        cwd: String? = nil,
        cliSessionId: String? = nil,
        pid: Int? = nil,
        tty: String? = nil,
        termProgram: String? = nil,
        customJumpURL: String? = nil,
        isGhosttyFamilyHost: Bool? = nil,
        supportsGhosttyPrivateFocus: Bool? = nil,
        isIDEHost: Bool? = nil,
        parentId: String? = nil,
        inferredParentId: String? = nil,
        openCodeParentID: String? = nil,
        codexThreadId: String? = nil,
        isSSHRemote: Bool? = nil,
        sshLocalBundleIdentifier: String? = nil,
        isInTmux: Bool? = nil,
        tmuxPane: String? = nil,
        tmuxSocketPath: String? = nil,
        tmuxHasAttachedClient: Bool? = nil,
        tmuxClientTTY: String? = nil,
        zellijSessionName: String? = nil,
        zellijPaneId: String? = nil,
        itermSessionId: String? = nil,
        cmuxWorkspaceId: String? = nil,
        cmuxSurfaceId: String? = nil,
        cmuxSocketPath: String? = nil,
        terminalFocusIdentity: TerminalFocusIdentity? = nil,
        warpPaneUUID: String? = nil,
        warpFocusURL: String? = nil,
        kittyWindowId: String? = nil,
        kittyListenOn: String? = nil,
        weztermSocket: String? = nil,
        weztermPane: String? = nil,
        ottySocket: String? = nil,
        ottyPaneId: String? = nil,
        ideWindowId: String? = nil,
        createdAt: String? = nil,
        terminalFingerprint: TerminalFingerprint? = nil,
        termSessionId: String? = nil,
        supacodeWorktreeId: String? = nil,
        supacodeTabId: String? = nil,
        supacodeSurfaceId: String? = nil,
        supacodeSocketPath: String? = nil,
        sshConnection: String? = nil,
        sshTTY: String? = nil,
        remoteHostId: String? = nil,
        remoteCwd: String? = nil
    ) {
        self.sessionId = sessionId
        self.source = source
        self.bundleId = TerminalModelNormalization.nonEmpty(bundleId)
        self.cwd = TerminalModelNormalization.nonEmpty(cwd)
        self.cliSessionId = TerminalModelNormalization.nonEmpty(cliSessionId)
        self.pid = pid
        self.tty = TerminalModelNormalization.nonEmpty(tty)
        self.termProgram = TerminalModelNormalization.nonEmpty(termProgram)
        self.customJumpURL = TerminalModelNormalization.nonEmpty(customJumpURL)
        self.isGhosttyFamilyHost = isGhosttyFamilyHost
        self.supportsGhosttyPrivateFocus = supportsGhosttyPrivateFocus
        self.isIDEHost = isIDEHost
        self.parentId = TerminalModelNormalization.nonEmpty(parentId)
        self.inferredParentId = TerminalModelNormalization.nonEmpty(inferredParentId)
        self.openCodeParentID = TerminalModelNormalization.nonEmpty(openCodeParentID)
        self.codexThreadId = TerminalModelNormalization.nonEmpty(codexThreadId)
        self.isSSHRemote = isSSHRemote
        self.sshLocalBundleIdentifier = TerminalModelNormalization.nonEmpty(sshLocalBundleIdentifier)
        self.isInTmux = isInTmux
        self.tmuxPane = TerminalModelNormalization.nonEmpty(tmuxPane)
        self.tmuxSocketPath = TerminalModelNormalization.nonEmpty(tmuxSocketPath)
        self.tmuxHasAttachedClient = tmuxHasAttachedClient
        self.tmuxClientTTY = TerminalModelNormalization.nonEmpty(tmuxClientTTY)
        self.zellijSessionName = TerminalModelNormalization.nonEmpty(zellijSessionName)
        self.zellijPaneId = TerminalModelNormalization.nonEmpty(zellijPaneId)
        self.itermSessionId = TerminalModelNormalization.nonEmpty(itermSessionId)
        self.cmuxWorkspaceId = TerminalModelNormalization.nonEmpty(cmuxWorkspaceId)
        self.cmuxSurfaceId = TerminalModelNormalization.nonEmpty(cmuxSurfaceId)
        self.cmuxSocketPath = TerminalModelNormalization.nonEmpty(cmuxSocketPath)
        self.terminalFocusIdentity = terminalFocusIdentity
        self.warpPaneUUID = TerminalModelNormalization.nonEmpty(warpPaneUUID)
        self.warpFocusURL = TerminalModelNormalization.nonEmpty(warpFocusURL)
        self.kittyWindowId = TerminalModelNormalization.nonEmpty(kittyWindowId)
        self.kittyListenOn = TerminalModelNormalization.nonEmpty(kittyListenOn)
        self.weztermSocket = TerminalModelNormalization.nonEmpty(weztermSocket)
        self.weztermPane = TerminalModelNormalization.nonEmpty(weztermPane)
        self.ottySocket = TerminalModelNormalization.nonEmpty(ottySocket)
        self.ottyPaneId = TerminalModelNormalization.nonEmpty(ottyPaneId)
        self.ideWindowId = TerminalModelNormalization.nonEmpty(ideWindowId)
        self.createdAt = TerminalModelNormalization.nonEmpty(createdAt)
        self.terminalFingerprint = terminalFingerprint
        self.termSessionId = TerminalModelNormalization.nonEmpty(termSessionId)
        self.supacodeWorktreeId = TerminalModelNormalization.nonEmpty(supacodeWorktreeId)
        self.supacodeTabId = TerminalModelNormalization.nonEmpty(supacodeTabId)
        self.supacodeSurfaceId = TerminalModelNormalization.nonEmpty(supacodeSurfaceId)
        self.supacodeSocketPath = TerminalModelNormalization.nonEmpty(supacodeSocketPath)
        self.sshConnection = TerminalModelNormalization.nonEmpty(sshConnection)
        self.sshTTY = TerminalModelNormalization.nonEmpty(sshTTY)
        self.remoteHostId = TerminalModelNormalization.nonEmpty(remoteHostId)
        self.remoteCwd = TerminalModelNormalization.nonEmpty(remoteCwd)
    }

    public static func fromHookEnvironment(
        sessionId: String,
        source: String,
        environment: HookEnvironment,
        createdAt: String? = nil
    ) -> JumpInput {
        let isInTmux = environment.tmux != nil || environment.tmuxPane != nil
        let isSSHRemote = environment.sshConnection != nil || environment.sshTTY != nil
        let bundleId = environment.cfBundleIdentifier
        let tmuxSocketPath = tmuxSocketPath(from: environment.tmux)
        let tmuxAttachment = TmuxClientAttachmentProbe().probe(
            socketPath: tmuxSocketPath,
            pane: environment.tmuxPane
        )
        return JumpInput(
            sessionId: sessionId,
            source: source,
            bundleId: bundleId,
            cwd: environment.cwd,
            cliSessionId: environment.termSessionId,
            pid: environment.pid,
            tty: environment.tty,
            termProgram: environment.termProgram,
            isSSHRemote: isSSHRemote,
            sshLocalBundleIdentifier: isSSHRemote ? bundleId : nil,
            isInTmux: isInTmux,
            tmuxPane: environment.tmuxPane,
            tmuxSocketPath: tmuxSocketPath,
            tmuxHasAttachedClient: tmuxAttachment?.hasAttachedClient,
            tmuxClientTTY: tmuxAttachment?.clientTTY,
            zellijSessionName: environment.zellijSessionName,
            zellijPaneId: environment.zellijPaneId,
            itermSessionId: environment.itermSessionId,
            cmuxWorkspaceId: environment.cmuxWorkspaceId,
            cmuxSurfaceId: environment.cmuxSurfaceId,
            cmuxSocketPath: environment.cmuxSocketPath,
            terminalFocusIdentity: focusIdentity(from: environment),
            warpPaneUUID: environment.warpTerminalSessionUUID,
            warpFocusURL: environment.warpFocusURL,
            kittyWindowId: environment.kittyWindowId,
            kittyListenOn: environment.kittyListenOn,
            weztermSocket: environment.weztermSocket,
            weztermPane: environment.weztermPane,
            ottySocket: environment.ottySocket,
            ottyPaneId: environment.ottyPaneId,
            createdAt: createdAt,
            terminalFingerprint: TerminalFingerprint.fromHookEnvironment(
                sessionId: sessionId,
                source: source,
                environment: environment
            ),
            termSessionId: environment.termSessionId,
            supacodeWorktreeId: environment.supacodeWorktreeId,
            supacodeTabId: environment.supacodeTabId,
            supacodeSurfaceId: environment.supacodeSurfaceId,
            supacodeSocketPath: environment.supacodeSocketPath,
            sshConnection: environment.sshConnection,
            sshTTY: environment.sshTTY
        )
    }

    public func replacingProcessObservation(pid: Int, tty: String?) -> JumpInput {
        let normalizedTTY = TerminalModelNormalization.nonEmpty(tty)
        return JumpInput(
            sessionId: sessionId,
            source: source,
            bundleId: bundleId,
            cwd: cwd,
            cliSessionId: cliSessionId,
            pid: pid,
            tty: normalizedTTY,
            termProgram: termProgram,
            customJumpURL: customJumpURL,
            isGhosttyFamilyHost: isGhosttyFamilyHost,
            supportsGhosttyPrivateFocus: supportsGhosttyPrivateFocus,
            isIDEHost: isIDEHost,
            parentId: parentId,
            inferredParentId: inferredParentId,
            openCodeParentID: openCodeParentID,
            codexThreadId: codexThreadId,
            isSSHRemote: isSSHRemote,
            sshLocalBundleIdentifier: sshLocalBundleIdentifier,
            isInTmux: isInTmux,
            tmuxPane: tmuxPane,
            tmuxSocketPath: tmuxSocketPath,
            tmuxHasAttachedClient: tmuxHasAttachedClient,
            tmuxClientTTY: tmuxClientTTY,
            zellijSessionName: zellijSessionName,
            zellijPaneId: zellijPaneId,
            itermSessionId: itermSessionId,
            cmuxWorkspaceId: cmuxWorkspaceId,
            cmuxSurfaceId: cmuxSurfaceId,
            cmuxSocketPath: cmuxSocketPath,
            terminalFocusIdentity: refreshedFocusIdentity(pid: pid, tty: normalizedTTY),
            warpPaneUUID: warpPaneUUID,
            warpFocusURL: warpFocusURL,
            kittyWindowId: kittyWindowId,
            kittyListenOn: kittyListenOn,
            weztermSocket: weztermSocket,
            weztermPane: weztermPane,
            ottySocket: ottySocket,
            ottyPaneId: ottyPaneId,
            ideWindowId: ideWindowId,
            createdAt: createdAt,
            terminalFingerprint: refreshedFingerprint(tty: normalizedTTY),
            termSessionId: termSessionId,
            supacodeWorktreeId: supacodeWorktreeId,
            supacodeTabId: supacodeTabId,
            supacodeSurfaceId: supacodeSurfaceId,
            supacodeSocketPath: supacodeSocketPath,
            sshConnection: sshConnection,
            sshTTY: sshTTY,
            remoteHostId: remoteHostId,
            remoteCwd: remoteCwd
        )
    }

    private func refreshedFocusIdentity(pid: Int, tty: String?) -> TerminalFocusIdentity? {
        guard let identity = terminalFocusIdentity else { return nil }
        return TerminalFocusIdentity(
            supacode: identity.supacode,
            bundleId: identity.bundleId,
            processId: pid,
            windowId: identity.windowId,
            tabId: identity.tabId,
            paneId: identity.paneId,
            tty: tty,
            cwd: identity.cwd,
            externalSessionId: identity.externalSessionId,
            confidence: identity.confidence,
            observedAt: identity.observedAt
        )
    }

    private func refreshedFingerprint(tty: String?) -> TerminalFingerprint? {
        guard let fingerprint = terminalFingerprint else { return nil }
        return TerminalFingerprint(
            sessionId: fingerprint.sessionId,
            source: fingerprint.source,
            cwd: fingerprint.cwd,
            tty: tty,
            termSessionId: fingerprint.termSessionId,
            itermSessionId: fingerprint.itermSessionId,
            tmuxPane: fingerprint.tmuxPane,
            zellijSessionName: fingerprint.zellijSessionName,
            zellijPaneId: fingerprint.zellijPaneId,
            kittyWindowId: fingerprint.kittyWindowId,
            cmuxWorkspaceId: fingerprint.cmuxWorkspaceId,
            cmuxSurfaceId: fingerprint.cmuxSurfaceId,
            cmuxSocketPath: fingerprint.cmuxSocketPath,
            isOpenCodeSubagent: fingerprint.isOpenCodeSubagent,
            isCodexThreadSpawnSubagent: fingerprint.isCodexThreadSpawnSubagent,
            weztermPane: fingerprint.weztermPane,
            sshTTY: fingerprint.sshTTY,
            bundleId: fingerprint.bundleId
        )
    }

    private static func tmuxSocketPath(from tmux: String?) -> String? {
        guard let tmux = TerminalModelNormalization.nonEmpty(tmux) else {
            return nil
        }

        return TerminalModelNormalization.nonEmpty(String(tmux.split(separator: ",", omittingEmptySubsequences: false).first ?? ""))
    }

    private static func focusIdentity(from environment: HookEnvironment) -> TerminalFocusIdentity {
        TerminalFocusIdentity(
            supacode: strongestSupacodeIdentity(from: environment),
            bundleId: environment.cfBundleIdentifier,
            processId: environment.pid,
            paneId: strongestPaneId(from: environment),
            cwd: environment.cwd,
            externalSessionId: strongestExternalSessionId(from: environment),
            confidence: focusConfidence(from: environment)
        )
    }

    private static func focusConfidence(from environment: HookEnvironment) -> TerminalFocusConfidence {
        if strongestSupacodeIdentity(from: environment) != nil {
            return .exact
        }

        if strongestPaneId(from: environment) != nil || strongestExternalSessionId(from: environment) != nil {
            return .strong
        }

        if environment.cwd != nil || environment.cfBundleIdentifier != nil {
            return .weak
        }

        return .unknown
    }

    private static func strongestSupacodeIdentity(from environment: HookEnvironment) -> String? {
        environment.supacodeSurfaceId ?? environment.supacodeTabId ?? environment.supacodeWorktreeId
    }

    private static func strongestPaneId(from environment: HookEnvironment) -> String? {
        environment.cmuxSurfaceId
            ?? environment.tmuxPane
            ?? environment.zellijPaneId
            ?? environment.kittyWindowId
            ?? environment.weztermPane
            ?? environment.ottyPaneId
            ?? environment.warpTerminalSessionUUID
    }

    private static func strongestExternalSessionId(from environment: HookEnvironment) -> String? {
        environment.itermSessionId
            ?? environment.termSessionId
            ?? environment.warpSessionId
            ?? environment.cmuxWorkspaceId
            ?? environment.zellijSessionName
    }
}
