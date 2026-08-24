public struct RemoteDiagnosticsSnapshot: Codable, Equatable, Sendable {
    public let hostId: String
    public let hostAlias: String
    public let redactedSSHOptionsSummary: String
    public let redactedSSHCommand: String
    public let redactedSocketPath: String?
    public let hasUIDMismatch: Bool
    public let helperVersion: String?
    public let lastHeartbeatAt: String?
    public let tunnelKind: SSHTunnelKind
    public let tunnelStatus: TunnelStatus?
    public let reconnectAttempt: Int
    public let redactedDeployStep: String?
    public let redactedCommandOutputTail: SSHCommandOutputBuffer
    public let portConflictDecision: SSHPortConflictDecision?
    public let containsRawSSHOptions: Bool

    public init(
        host: SSHHostStoreHost,
        deployResult: SSHDeployResult? = nil,
        commandOutput: SSHCommandOutputBuffer? = nil,
        portConflict: SSHPortConflict? = nil,
        reachabilityObserver: SSHReachabilityObserver? = nil,
        tunnelStatus: TunnelStatus? = nil,
        redactor: DiagnosticRedactor = DiagnosticRedactor()
    ) {
        hostId = host.id
        hostAlias = host.hostAlias
        redactedSSHOptionsSummary = host.sshOptions.isEmpty ? "" : "<redacted>"
        redactedSSHCommand = redactor.redactText("ssh \(host.hostAlias)")
        redactedSocketPath = Self.redactedSocketPath(for: host, redactor: redactor)
        hasUIDMismatch = host.remoteUID != nil && host.localUID != nil && host.remoteUID != host.localUID
        helperVersion = host.hookVersion
        lastHeartbeatAt = reachabilityObserver?.lastSuccessAt
        tunnelKind = host.tunnelKind
        self.tunnelStatus = tunnelStatus
        reconnectAttempt = reachabilityObserver?.reconnectAttempt ?? 0
        redactedDeployStep = deployResult?.step.map(redactor.redactText)
        redactedCommandOutputTail = Self.redactedOutput(commandOutput, redactor: redactor)
        portConflictDecision = portConflict?.decision
        containsRawSSHOptions = false
    }

    private static func redactedSocketPath(
        for host: SSHHostStoreHost,
        redactor: DiagnosticRedactor
    ) -> String? {
        switch host.tunnelKind {
        case .uds:
            return host.remoteSocketPath.map(redactor.redactText)
        case .tcp:
            guard let tcpPort = host.tcpPort else {
                return nil
            }
            return "tcp:\(tcpPort)"
        }
    }

    private static func redactedOutput(
        _ output: SSHCommandOutputBuffer?,
        redactor: DiagnosticRedactor
    ) -> SSHCommandOutputBuffer {
        guard let output else {
            return SSHCommandOutputBuffer(stdout: "", stderr: "", maxBytes: 0, redactionApplied: true)
        }

        return SSHCommandOutputBuffer(
            stdout: redactor.redactText(output.stdoutTail),
            stderr: redactor.redactText(output.stderrTail),
            maxBytes: output.maxBytes,
            exitCode: output.exitCode,
            durationMs: output.durationMs,
            redactionApplied: true
        )
    }
}
