public enum SSHPortConflictDecision: String, Codable, Equatable, Sendable {
    case free
    case sameUserStaleSSHDCleanupAllowed
    case foreignOccupied
    case nonSSHDOccupied
    case liveTunnelOccupied
    case unknownFailClosed
}

public struct SSHPortConflict: Codable, Equatable, Sendable {
    public let hostId: String
    public let port: Int
    public let listenerOwners: [String]
    public let sameUserSSHPids: [Int]
    public let liveEstablishedPids: [Int]
    public let foreignOwners: [String]
    public let checkedByLsof: Bool
    public let checkedBySS: Bool
    public let decision: SSHPortConflictDecision

    public init(
        hostId: String,
        port: Int,
        listenerOwners: [String] = [],
        sameUserSSHPids: [Int] = [],
        liveEstablishedPids: [Int] = [],
        foreignOwners: [String] = [],
        checkedByLsof: Bool,
        checkedBySS: Bool,
        decision: SSHPortConflictDecision
    ) {
        self.hostId = hostId
        self.port = port
        self.listenerOwners = listenerOwners
        self.sameUserSSHPids = sameUserSSHPids
        self.liveEstablishedPids = liveEstablishedPids
        self.foreignOwners = foreignOwners
        self.checkedByLsof = checkedByLsof
        self.checkedBySS = checkedBySS
        self.decision = decision
    }

    public var allowsAutomaticCleanup: Bool {
        decision == .sameUserStaleSSHDCleanupAllowed
    }

    public var failsClosed: Bool {
        decision == .unknownFailClosed
    }
}
