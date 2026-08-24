public enum TerminalResolutionProvenance: String, Codable, Equatable, Sendable {
    case transcriptMetadata
    case hookEnvironment
    case processObservation
    case windowProbe
    case manualSelection

    var priority: Int {
        switch self {
        case .transcriptMetadata:
            return 0
        case .hookEnvironment:
            return 1
        case .processObservation:
            return 2
        case .windowProbe:
            return 3
        case .manualSelection:
            return 4
        }
    }
}

public enum TerminalTargetStrength: Int, Codable, Equatable, Comparable, Sendable {
    case unknown = 0
    case weak = 1
    case strong = 2
    case exact = 3

    public static func < (lhs: TerminalTargetStrength, rhs: TerminalTargetStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct TerminalResolvedTarget: Codable, Equatable, Sendable {
    public let input: JumpInput
    public let provenance: TerminalResolutionProvenance
    public let strength: TerminalTargetStrength
    public let plannedHandlerId: String
    public let plannedPrecision: JumpPrecision
    public let capabilityDescriptor: TerminalCapabilityDescriptor?
    public let diagnosticSummary: String
}

public struct TerminalResolver: Sendable {
    public let registry: TerminalRegistry
    public let router: TerminalJumpRouter

    public init(
        registry: TerminalRegistry = .default,
        router: TerminalJumpRouter = TerminalJumpRouter()
    ) {
        self.registry = registry
        self.router = router
    }

    public func resolve(
        _ input: JumpInput,
        provenance: TerminalResolutionProvenance = .hookEnvironment
    ) -> TerminalResolvedTarget {
        let enriched = enrich(input)
        let result = router.planJump(enriched)
        let strength = targetStrength(enriched)
        let descriptor = registry.descriptor(for: result.handlerId)

        return TerminalResolvedTarget(
            input: enriched,
            provenance: provenance,
            strength: strength,
            plannedHandlerId: result.handlerId,
            plannedPrecision: result.precision,
            capabilityDescriptor: descriptor,
            diagnosticSummary: "\(result.handlerId): \(strength)"
        )
    }

    public func prefer(
        stored: TerminalResolvedTarget?,
        candidate: TerminalResolvedTarget
    ) -> TerminalResolvedTarget {
        guard let stored else {
            return candidate
        }

        if candidateContainsRemoteIdentity(candidate.input)
            && stored.input.isSSHRemote != true
            && candidate.input.isSSHRemote != true {
            return stored
        }

        if candidate.strength != stored.strength {
            return candidate.strength > stored.strength ? candidate : stored
        }

        if candidate.provenance.priority != stored.provenance.priority {
            return candidate.provenance.priority > stored.provenance.priority ? candidate : stored
        }

        return candidate
    }

    private func enrich(_ input: JumpInput) -> JumpInput {
        let fingerprint = input.terminalFingerprint ?? fingerprint(from: input)
        let focusIdentity = input.terminalFocusIdentity ?? focusIdentity(from: input)

        return JumpInput(
            sessionId: input.sessionId,
            source: input.source,
            bundleId: input.bundleId,
            cwd: input.cwd,
            cliSessionId: input.cliSessionId,
            pid: input.pid,
            tty: input.tty,
            customJumpURL: input.customJumpURL,
            isGhosttyFamilyHost: input.isGhosttyFamilyHost,
            supportsGhosttyPrivateFocus: input.supportsGhosttyPrivateFocus,
            isIDEHost: input.isIDEHost,
            parentId: input.parentId,
            inferredParentId: input.inferredParentId,
            openCodeParentID: input.openCodeParentID,
            codexThreadId: input.codexThreadId,
            isSSHRemote: input.isSSHRemote,
            sshLocalBundleIdentifier: input.sshLocalBundleIdentifier,
            isInTmux: input.isInTmux,
            tmuxPane: input.tmuxPane,
            tmuxSocketPath: input.tmuxSocketPath,
            tmuxHasAttachedClient: input.tmuxHasAttachedClient,
            tmuxClientTTY: input.tmuxClientTTY,
            zellijSessionName: input.zellijSessionName,
            zellijPaneId: input.zellijPaneId,
            itermSessionId: input.itermSessionId,
            cmuxWorkspaceId: input.cmuxWorkspaceId,
            cmuxSurfaceId: input.cmuxSurfaceId,
            cmuxSocketPath: input.cmuxSocketPath,
            terminalFocusIdentity: focusIdentity,
            warpPaneUUID: input.warpPaneUUID,
            warpFocusURL: input.warpFocusURL,
            kittyWindowId: input.kittyWindowId,
            kittyListenOn: input.kittyListenOn,
            weztermSocket: input.weztermSocket,
            weztermPane: input.weztermPane,
            ottySocket: input.ottySocket,
            ottyPaneId: input.ottyPaneId,
            ideWindowId: input.ideWindowId,
            createdAt: input.createdAt,
            terminalFingerprint: fingerprint,
            termSessionId: input.termSessionId,
            supacodeWorktreeId: input.supacodeWorktreeId,
            supacodeTabId: input.supacodeTabId,
            supacodeSurfaceId: input.supacodeSurfaceId,
            supacodeSocketPath: input.supacodeSocketPath,
            sshConnection: input.sshConnection,
            sshTTY: input.sshTTY,
            remoteHostId: input.remoteHostId,
            remoteCwd: input.remoteCwd
        )
    }

    private func fingerprint(from input: JumpInput) -> TerminalFingerprint {
        TerminalFingerprint(
            sessionId: input.sessionId,
            source: input.source,
            cwd: input.cwd,
            tty: input.tty,
            termSessionId: input.termSessionId ?? input.cliSessionId,
            itermSessionId: input.itermSessionId,
            tmuxPane: input.tmuxPane,
            zellijSessionName: input.zellijSessionName,
            zellijPaneId: input.zellijPaneId,
            kittyWindowId: input.kittyWindowId,
            cmuxWorkspaceId: input.cmuxWorkspaceId,
            cmuxSurfaceId: input.cmuxSurfaceId,
            cmuxSocketPath: input.cmuxSocketPath,
            weztermPane: input.weztermPane,
            sshTTY: input.sshTTY,
            bundleId: input.bundleId
        )
    }

    private func focusIdentity(from input: JumpInput) -> TerminalFocusIdentity {
        TerminalFocusIdentity(
            supacode: input.supacodeSurfaceId ?? input.supacodeTabId ?? input.supacodeWorktreeId,
            bundleId: input.bundleId,
            processId: input.pid,
            paneId: strongestPaneId(from: input),
            tty: input.tty,
            cwd: input.cwd,
            externalSessionId: strongestExternalSessionId(from: input),
            confidence: focusConfidence(from: input),
            observedAt: input.createdAt
        )
    }

    private func focusConfidence(from input: JumpInput) -> TerminalFocusConfidence {
        switch targetStrength(input) {
        case .exact:
            return .exact
        case .strong:
            return .strong
        case .weak:
            return .weak
        case .unknown:
            return .unknown
        }
    }

    private func targetStrength(_ input: JumpInput) -> TerminalTargetStrength {
        let structuralStrength = structuralTargetStrength(input)
        let focusStrength = focusStrength(input.terminalFocusIdentity)
        return max(structuralStrength, focusStrength)
    }

    private func structuralTargetStrength(_ input: JumpInput) -> TerminalTargetStrength {
        if input.customJumpURL != nil
            || input.codexThreadId != nil
            || input.supacodeSurfaceId != nil
            || input.supacodeTabId != nil
            || input.supacodeWorktreeId != nil
            || (input.cmuxSurfaceId != nil && input.cmuxSocketPath != nil)
            || input.tmuxPane != nil
            || input.zellijPaneId != nil
            || input.weztermPane != nil
            || input.ottyPaneId != nil
            || input.itermSessionId != nil {
            return .exact
        }

        if input.kittyWindowId != nil
            || input.warpFocusURL != nil
            || input.warpPaneUUID != nil
            || (input.tty != nil && input.bundleId != nil)
            || input.sshConnection != nil
            || input.sshTTY != nil
            || input.remoteHostId != nil {
            return .strong
        }

        if input.cwd != nil || input.bundleId != nil || input.remoteCwd != nil {
            return .weak
        }

        return .unknown
    }

    private func focusStrength(_ identity: TerminalFocusIdentity?) -> TerminalTargetStrength {
        switch identity?.confidence {
        case .exact:
            return .exact
        case .strong:
            return .strong
        case .weak:
            return .weak
        case .unknown, nil:
            return .unknown
        }
    }

    private func strongestPaneId(from input: JumpInput) -> String? {
        input.cmuxSurfaceId
            ?? input.tmuxPane
            ?? input.zellijPaneId
            ?? input.weztermPane
            ?? input.ottyPaneId
            ?? input.kittyWindowId
            ?? input.warpPaneUUID
    }

    private func strongestExternalSessionId(from input: JumpInput) -> String? {
        input.itermSessionId
            ?? input.termSessionId
            ?? input.cliSessionId
            ?? input.cmuxWorkspaceId
            ?? input.zellijSessionName
            ?? input.remoteHostId
    }

    private func candidateContainsRemoteIdentity(_ input: JumpInput) -> Bool {
        input.sshConnection != nil
            || input.sshTTY != nil
            || input.remoteHostId != nil
            || input.remoteCwd != nil
    }
}
