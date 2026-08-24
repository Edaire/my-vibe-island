import Foundation

public struct KanbanBrowserJumpTargetEnricher: Sendable {
    public static let localGatewayBaseURL = URL(string: "http://127.0.0.1:8766/")!

    private let tmuxSessionName: @Sendable (String, String) -> String?

    public init() {
        tmuxSessionName = Self.systemTmuxSessionName
    }

    public init(
        tmuxSessionName: @escaping @Sendable (String, String) -> String?
    ) {
        self.tmuxSessionName = tmuxSessionName
    }

    public static func gatewayURL(tmuxSessionName: String) -> URL? {
        guard let taskID = taskID(from: tmuxSessionName) else { return nil }
        return localGatewayBaseURL.appending(path: "s").appending(path: taskID)
    }

    public func enrich(_ input: JumpInput) -> JumpInput {
        guard input.customJumpURL == nil,
              let socketPath = input.tmuxSocketPath,
              let pane = input.tmuxPane,
              let sessionName = tmuxSessionName(socketPath, pane),
              let url = Self.gatewayURL(tmuxSessionName: sessionName)
        else {
            return input
        }
        return input.replacingCustomJumpURL(url.absoluteString)
    }

    private static func taskID(from tmuxSessionName: String) -> String? {
        for provider in ["codex", "claude", "hermes"] {
            let prefix = "kanban-\(provider)-"
            guard tmuxSessionName.hasPrefix(prefix) else { continue }
            let taskID = String(tmuxSessionName.dropFirst(prefix.count))
            guard taskID.hasPrefix("t_"),
                  taskID.count > 2,
                  taskID.unicodeScalars.allSatisfy({ scalar in
                      scalar == "_" || scalar.isASCII && (scalar.properties.isAlphabetic || scalar.properties.numericType != nil)
                  })
            else {
                return nil
            }
            return taskID
        }
        return nil
    }

    private static func systemTmuxSessionName(socketPath: String, pane: String) -> String? {
        let candidates = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return nil
        }
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-S", socketPath, "display-message", "-p", "-t", pane, "#{session_name}"]
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0,
              let value = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension JumpInput {
    func replacingCustomJumpURL(_ customJumpURL: String) -> JumpInput {
        JumpInput(
            sessionId: sessionId,
            source: source,
            bundleId: bundleId,
            cwd: cwd,
            cliSessionId: cliSessionId,
            pid: pid,
            tty: tty,
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
            zellijSessionName: zellijSessionName,
            zellijPaneId: zellijPaneId,
            itermSessionId: itermSessionId,
            cmuxWorkspaceId: cmuxWorkspaceId,
            cmuxSurfaceId: cmuxSurfaceId,
            cmuxSocketPath: cmuxSocketPath,
            terminalFocusIdentity: terminalFocusIdentity,
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
            terminalFingerprint: terminalFingerprint,
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
}
