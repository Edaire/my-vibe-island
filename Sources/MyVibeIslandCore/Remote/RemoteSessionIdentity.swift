public struct RemoteSessionIdentity: Codable, Equatable, Hashable, Sendable {
    public let source: String
    public let remoteSessionId: String
    public let hostId: String

    public var stableLocalSessionId: String {
        [
            "remote",
            normalized(source),
            normalized(hostId),
            normalized(remoteSessionId)
        ].joined(separator: ":")
    }

    public init(source: String, remoteSessionId: String, hostId: String) {
        self.source = source
        self.remoteSessionId = remoteSessionId
        self.hostId = hostId
    }

    public static func fromJumpInput(_ input: JumpInput) -> RemoteSessionIdentity? {
        guard input.isSSHRemote == true,
              let hostId = nonEmpty(input.remoteHostId)
        else {
            return nil
        }

        return RemoteSessionIdentity(
            source: input.source,
            remoteSessionId: input.sessionId,
            hostId: hostId
        )
    }

    private func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "_")
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
