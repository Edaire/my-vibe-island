import Foundation

public struct HookEnvironment: Codable, Equatable, Sendable {
    public let cwd: String?
    public let shell: String?
    public let terminal: String?
    public let pid: Int?
    public let tty: String?
    public let user: String?
    public let termProgram: String?
    public let itermSessionId: String?
    public let termSessionId: String?
    public let warpSessionId: String?
    public let warpTerminalSessionUUID: String?
    public let warpFocusURL: String?
    public let tmux: String?
    public let tmuxPane: String?
    public let kittyWindowId: String?
    public let kittyListenOn: String?
    public let zellijSessionName: String?
    public let zellijPaneId: String?
    public let cfBundleIdentifier: String?
    public let cursorTraceId: String?
    public let conductorWorkspaceName: String?
    public let conductorPort: String?
    public let cmuxWorkspaceId: String?
    public let cmuxSurfaceId: String?
    public let cmuxSocketPath: String?
    public let supacodeWorktreeId: String?
    public let supacodeTabId: String?
    public let supacodeSurfaceId: String?
    public let supacodeSocketPath: String?
    public let weztermSocket: String?
    public let weztermPane: String?
    public let ottySocket: String?
    public let ottyPaneId: String?
    public let sshConnection: String?
    public let sshTTY: String?

    public var diagnosticSummary: HookEnvironmentDiagnosticSummary {
        HookEnvironmentDiagnosticSummary(environment: self)
    }

    public init(
        cwd: String? = nil,
        shell: String? = nil,
        terminal: String? = nil,
        pid: Int? = nil,
        tty: String? = nil,
        user: String? = nil,
        termProgram: String? = nil,
        itermSessionId: String? = nil,
        termSessionId: String? = nil,
        warpSessionId: String? = nil,
        warpTerminalSessionUUID: String? = nil,
        warpFocusURL: String? = nil,
        tmux: String? = nil,
        tmuxPane: String? = nil,
        kittyWindowId: String? = nil,
        kittyListenOn: String? = nil,
        zellijSessionName: String? = nil,
        zellijPaneId: String? = nil,
        cfBundleIdentifier: String? = nil,
        cursorTraceId: String? = nil,
        conductorWorkspaceName: String? = nil,
        conductorPort: String? = nil,
        cmuxWorkspaceId: String? = nil,
        cmuxSurfaceId: String? = nil,
        cmuxSocketPath: String? = nil,
        supacodeWorktreeId: String? = nil,
        supacodeTabId: String? = nil,
        supacodeSurfaceId: String? = nil,
        supacodeSocketPath: String? = nil,
        weztermSocket: String? = nil,
        weztermPane: String? = nil,
        ottySocket: String? = nil,
        ottyPaneId: String? = nil,
        sshConnection: String? = nil,
        sshTTY: String? = nil
    ) {
        self.cwd = Self.nonEmpty(cwd)
        self.shell = Self.nonEmpty(shell)
        self.terminal = Self.nonEmpty(terminal)
        self.pid = pid
        self.tty = Self.nonEmpty(tty)
        self.user = Self.nonEmpty(user)
        self.termProgram = Self.nonEmpty(termProgram)
        self.itermSessionId = Self.nonEmpty(itermSessionId)
        self.termSessionId = Self.nonEmpty(termSessionId)
        self.warpSessionId = Self.nonEmpty(warpSessionId)
        self.warpTerminalSessionUUID = Self.nonEmpty(warpTerminalSessionUUID)
        self.warpFocusURL = Self.nonEmpty(warpFocusURL)
        self.tmux = Self.nonEmpty(tmux)
        self.tmuxPane = Self.nonEmpty(tmuxPane)
        self.kittyWindowId = Self.nonEmpty(kittyWindowId)
        self.kittyListenOn = Self.nonEmpty(kittyListenOn)
        self.zellijSessionName = Self.nonEmpty(zellijSessionName)
        self.zellijPaneId = Self.nonEmpty(zellijPaneId)
        self.cfBundleIdentifier = Self.nonEmpty(cfBundleIdentifier)
        self.cursorTraceId = Self.nonEmpty(cursorTraceId)
        self.conductorWorkspaceName = Self.nonEmpty(conductorWorkspaceName)
        self.conductorPort = Self.nonEmpty(conductorPort)
        self.cmuxWorkspaceId = Self.nonEmpty(cmuxWorkspaceId)
        self.cmuxSurfaceId = Self.nonEmpty(cmuxSurfaceId)
        self.cmuxSocketPath = Self.nonEmpty(cmuxSocketPath)
        self.supacodeWorktreeId = Self.nonEmpty(supacodeWorktreeId)
        self.supacodeTabId = Self.nonEmpty(supacodeTabId)
        self.supacodeSurfaceId = Self.nonEmpty(supacodeSurfaceId)
        self.supacodeSocketPath = Self.nonEmpty(supacodeSocketPath)
        self.weztermSocket = Self.nonEmpty(weztermSocket)
        self.weztermPane = Self.nonEmpty(weztermPane)
        self.ottySocket = Self.nonEmpty(ottySocket)
        self.ottyPaneId = Self.nonEmpty(ottyPaneId)
        self.sshConnection = Self.nonEmpty(sshConnection)
        self.sshTTY = Self.nonEmpty(sshTTY)
    }

    public static func capture(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        processIdentifier: Int = Int(ProcessInfo.processInfo.processIdentifier),
        userName: String = NSUserName(),
        ttyResolver: any ProcessTTYResolving = ProcessTTYResolver()
    ) -> HookEnvironment {
        HookEnvironment(
            cwd: nonEmpty(processEnvironment["PWD"]) ?? currentDirectoryPath,
            shell: processEnvironment["SHELL"],
            terminal: processEnvironment["TERM_PROGRAM"],
            pid: processIdentifier,
            tty: processEnvironment["TTY"] ?? ttyResolver.tty(for: processIdentifier),
            user: userName,
            termProgram: processEnvironment["TERM_PROGRAM"],
            itermSessionId: processEnvironment["ITERM_SESSION_ID"],
            termSessionId: processEnvironment["TERM_SESSION_ID"],
            warpSessionId: processEnvironment["WARP_SESSION_ID"],
            warpTerminalSessionUUID: processEnvironment["WARP_TERMINAL_SESSION_UUID"],
            warpFocusURL: processEnvironment["WARP_FOCUS_URL"],
            tmux: processEnvironment["TMUX"],
            tmuxPane: processEnvironment["TMUX_PANE"],
            kittyWindowId: processEnvironment["KITTY_WINDOW_ID"],
            kittyListenOn: processEnvironment["KITTY_LISTEN_ON"],
            zellijSessionName: processEnvironment["ZELLIJ_SESSION_NAME"],
            zellijPaneId: processEnvironment["ZELLIJ_PANE_ID"],
            cfBundleIdentifier: processEnvironment["__CFBundleIdentifier"],
            cursorTraceId: processEnvironment["CURSOR_TRACE_ID"],
            conductorWorkspaceName: processEnvironment["CONDUCTOR_WORKSPACE_NAME"],
            conductorPort: processEnvironment["CONDUCTOR_PORT"],
            cmuxWorkspaceId: processEnvironment["CMUX_WORKSPACE_ID"],
            cmuxSurfaceId: processEnvironment["CMUX_SURFACE_ID"],
            cmuxSocketPath: processEnvironment["CMUX_SOCKET_PATH"],
            supacodeWorktreeId: processEnvironment["SUPACODE_WORKTREE_ID"],
            supacodeTabId: processEnvironment["SUPACODE_TAB_ID"],
            supacodeSurfaceId: processEnvironment["SUPACODE_SURFACE_ID"],
            supacodeSocketPath: processEnvironment["SUPACODE_SOCKET_PATH"],
            weztermSocket: processEnvironment["WEZTERM_UNIX_SOCKET"],
            weztermPane: processEnvironment["WEZTERM_PANE"],
            ottySocket: processEnvironment["OTTY_SOCKET"],
            ottyPaneId: processEnvironment["OTTY_PANE_ID"],
            sshConnection: processEnvironment["SSH_CONNECTION"],
            sshTTY: processEnvironment["SSH_TTY"]
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }
}

public struct HookEnvironmentDiagnosticSummary: Codable, Equatable, Sendable {
    public let hasCwd: Bool
    public let hasShell: Bool
    public let hasTerminal: Bool
    public let hasProcessIdentifier: Bool
    public let hasUser: Bool
    public let hasTerminalSession: Bool
    public let hasMultiplexer: Bool
    public let hasEditorTrace: Bool
    public let hasRemoteSSH: Bool
    public let capturedFieldCount: Int

    public init(environment: HookEnvironment) {
        hasCwd = environment.cwd != nil
        hasShell = environment.shell != nil
        hasTerminal = environment.terminal != nil || environment.termProgram != nil
        hasProcessIdentifier = environment.pid != nil
        hasUser = environment.user != nil
        hasTerminalSession = Self.anyPresent([
            environment.itermSessionId,
            environment.termSessionId,
            environment.warpSessionId,
            environment.warpTerminalSessionUUID,
            environment.kittyWindowId,
            environment.zellijSessionName,
            environment.zellijPaneId,
            environment.weztermPane,
            environment.ottyPaneId,
        ])
        hasMultiplexer = Self.anyPresent([
            environment.tmux,
            environment.tmuxPane,
            environment.cmuxWorkspaceId,
            environment.cmuxSurfaceId,
            environment.cmuxSocketPath,
            environment.supacodeWorktreeId,
            environment.supacodeTabId,
            environment.supacodeSurfaceId,
            environment.supacodeSocketPath,
            environment.weztermSocket,
            environment.ottySocket,
        ])
        hasEditorTrace = Self.anyPresent([
            environment.cfBundleIdentifier,
            environment.cursorTraceId,
            environment.conductorWorkspaceName,
            environment.conductorPort,
            environment.warpFocusURL,
        ])
        hasRemoteSSH = environment.sshConnection != nil || environment.sshTTY != nil
        capturedFieldCount = environment.capturedFieldCount
    }

    private static func anyPresent(_ values: [String?]) -> Bool {
        values.contains { $0 != nil }
    }
}

private extension HookEnvironment {
    var capturedFieldCount: Int {
        var count = pid == nil ? 0 : 1
        count += capturedStringFields.filter { $0 != nil }.count
        return count
    }

    var capturedStringFields: [String?] {
        [
            cwd,
            shell,
            terminal,
            tty,
            user,
            termProgram,
            itermSessionId,
            termSessionId,
            warpSessionId,
            warpTerminalSessionUUID,
            warpFocusURL,
            tmux,
            tmuxPane,
            kittyWindowId,
            kittyListenOn,
            zellijSessionName,
            zellijPaneId,
            cfBundleIdentifier,
            cursorTraceId,
            conductorWorkspaceName,
            conductorPort,
            cmuxWorkspaceId,
            cmuxSurfaceId,
            cmuxSocketPath,
            supacodeWorktreeId,
            supacodeTabId,
            supacodeSurfaceId,
            supacodeSocketPath,
            weztermSocket,
            weztermPane,
            ottySocket,
            ottyPaneId,
            sshConnection,
            sshTTY,
        ]
    }
}
