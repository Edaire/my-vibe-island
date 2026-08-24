public enum RemoteRepairCommandKind: String, Codable, Equatable, Sendable {
    case sshConfigSnippet
    case socketCleanup
    case helperReinstall
    case hookStatus
    case tunnel
}

public struct RemoteRepairCommand: Codable, Equatable, Sendable {
    public let kind: RemoteRepairCommandKind
    public let body: String
    public let requiresUserRun: Bool

    public init(
        kind: RemoteRepairCommandKind,
        body: String,
        requiresUserRun: Bool = true
    ) {
        self.kind = kind
        self.body = body
        self.requiresUserRun = requiresUserRun
    }
}

public struct RemoteRepairCommandPanel: Codable, Equatable, Sendable {
    public let hostId: String
    public let hostAlias: String
    public let tunnelKind: SSHTunnelKind
    public let commands: [RemoteRepairCommand]

    public init(host: SSHHostStoreHost) {
        hostId = host.id
        hostAlias = host.hostAlias
        tunnelKind = host.tunnelKind
        commands = Self.commands(for: host)
    }

    public func command(_ kind: RemoteRepairCommandKind) -> RemoteRepairCommand? {
        commands.first { $0.kind == kind }
    }

    private static func commands(for host: SSHHostStoreHost) -> [RemoteRepairCommand] {
        var commands = [
            RemoteRepairCommand(kind: .sshConfigSnippet, body: sshConfigSnippet(for: host))
        ]

        if host.tunnelKind == .uds, let remoteSocketPath = nonEmpty(host.remoteSocketPath) {
            commands.append(RemoteRepairCommand(kind: .socketCleanup, body: "rm -f \(remoteSocketPath)"))
        }

        commands.append(contentsOf: [
            RemoteRepairCommand(
                kind: .helperReinstall,
                body: "scp my-vibe-island-hooks \(host.hostAlias):~/.local/bin/my-vibe-island-hooks"
            ),
            RemoteRepairCommand(
                kind: .hookStatus,
                body: "~/.local/bin/my-vibe-island-hooks health"
            ),
            RemoteRepairCommand(
                kind: .tunnel,
                body: "ssh -N \(host.hostAlias)"
            )
        ])

        return commands
    }

    private static func sshConfigSnippet(for host: SSHHostStoreHost) -> String {
        var lines = [
            "Host \(host.hostAlias)",
            "    HostName \(host.hostName)",
            "    User \(host.user)",
            "    Port \(host.port)"
        ]

        switch host.tunnelKind {
        case .uds:
            if let remoteSocketPath = nonEmpty(host.remoteSocketPath),
               let localSocketPath = nonEmpty(host.localSocketPath) {
                lines.append("    RemoteForward \(remoteSocketPath) \(localSocketPath)")
                if host.remoteUID != nil,
                   host.localUID != nil,
                   host.remoteUID != host.localUID {
                    lines.append("    SetEnv MY_VIBE_ISLAND_SOCKET_PATH=\(remoteSocketPath)")
                    lines.append("    SetEnv VIBE_ISLAND_SOCKET_PATH=\(remoteSocketPath)")
                }
                lines.append("    StreamLocalBindUnlink yes")
            }
        case .tcp:
            if let tcpPort = host.tcpPort {
                lines.append("    RemoteForward \(tcpPort) 127.0.0.1:\(tcpPort)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
