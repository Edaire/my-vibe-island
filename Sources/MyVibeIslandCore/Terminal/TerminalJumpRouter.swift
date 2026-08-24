public struct TerminalJumpRouter: Sendable {
    private let registry: TerminalRegistry

    public init(registry: TerminalRegistry = .default) {
        self.registry = registry
    }

    public func planJump(_ input: JumpInput) -> JumpResult {
        if input.customJumpURL != nil {
            return result(.exactPane, handlerId: "custom-url")
        }

        // A tmux pane has its own PTY. Terminal.app owns the attached client's
        // PTY, so routing the pane through terminal-tty would target the wrong tab.
        if input.tmuxPane != nil, input.tmuxHasAttachedClient == false {
            return result(
                .unsupported,
                handlerId: "tmux",
                failureReason: .tmuxNoAttachedClient,
                repairAction: "Attach the tmux session in Terminal before jumping"
            )
        }

        if input.tmuxPane != nil {
            return result(.exactPane, handlerId: "tmux")
        }

        if input.tty != nil && input.bundleId != nil && input.isSSHRemote != true {
            return result(.exactWindow, handlerId: "terminal-tty")
        }

        if input.codexThreadId != nil {
            return result(.exactPane, handlerId: "codex-deeplink")
        }

        if input.isSSHRemote == true && !hasLocalExactPane(input) {
            return result(
                .remoteHint,
                handlerId: "remote-hint",
                failureReason: .remoteRequiresReconnect,
                repairAction: "Reconnect remote terminal before jumping"
            )
        }

        if input.supacodeSurfaceId != nil || input.supacodeTabId != nil || input.supacodeWorktreeId != nil {
            return result(.exactPane, handlerId: "supacode")
        }

        if input.cmuxSurfaceId != nil && input.cmuxSocketPath != nil {
            return result(.exactPane, handlerId: "cmux")
        }

        if input.zellijPaneId != nil {
            return result(.exactPane, handlerId: "zellij")
        }

        if input.weztermPane != nil {
            return result(.exactPane, handlerId: "wezterm")
        }

        if input.ottyPaneId != nil {
            return result(.exactPane, handlerId: "otty")
        }

        if input.kittyWindowId != nil {
            return result(.exactWindow, handlerId: "kitty")
        }

        if input.warpFocusURL != nil {
            return result(.exactWindow, handlerId: "warp")
        }

        if input.warpPaneUUID != nil {
            return result(.application, handlerId: "application")
        }

        if input.isGhosttyFamilyHost == true {
            return result(.exactWindow, handlerId: "ghostty")
        }

        if input.itermSessionId != nil {
            return result(.exactPane, handlerId: "iterm")
        }

        if input.tty != nil && input.bundleId != nil {
            return result(.exactWindow, handlerId: "terminal-tty")
        }

        if (input.isIDEHost == true || input.ideWindowId != nil || isKnownIDEWorkspaceBundle(input.bundleId))
            && input.cwd != nil {
            return result(.workspace, handlerId: "ide-workspace")
        }

        if input.cwd != nil {
            return result(.workspace, handlerId: "workspace")
        }

        if input.bundleId != nil {
            return result(.application, handlerId: "application")
        }

        return result(
            .unsupported,
            handlerId: "unsupported",
            failureReason: .missingTarget,
            repairAction: "Collect terminal context before jumping"
        )
    }

    private func isKnownIDEWorkspaceBundle(_ bundleId: String?) -> Bool {
        guard let bundleId,
              let descriptor = registry.descriptor(bundleIdentifier: bundleId) else {
            return false
        }

        return descriptor.category == .ide
            && descriptor.supportedPrecisions.contains(.workspace)
    }

    private func hasLocalExactPane(_ input: JumpInput) -> Bool {
        input.supacodeSurfaceId != nil
            || input.supacodeTabId != nil
            || input.supacodeWorktreeId != nil
            || (input.cmuxSurfaceId != nil && input.cmuxSocketPath != nil)
            || input.tmuxPane != nil
            || input.zellijPaneId != nil
            || input.weztermPane != nil
            || input.ottyPaneId != nil
            || input.itermSessionId != nil
    }

    private func result(
        _ precision: JumpPrecision,
        handlerId: String,
        failureReason: JumpFailureReason? = nil,
        repairAction: String? = nil
    ) -> JumpResult {
        JumpResult(
            precision: precision,
            succeeded: failureReason == nil && precision != .unsupported && precision != .remoteHint,
            handlerId: handlerId,
            attemptedMechanism: handlerId,
            failureReason: failureReason,
            repairAction: repairAction,
            diagnosticSummary: diagnosticSummary(precision: precision, handlerId: handlerId, failureReason: failureReason)
        )
    }

    private func diagnosticSummary(
        precision: JumpPrecision,
        handlerId: String,
        failureReason: JumpFailureReason?
    ) -> String {
        if let failureReason {
            return "\(handlerId): \(failureReason.rawValue)"
        }

        return "\(handlerId): \(precision.rawValue)"
    }
}
