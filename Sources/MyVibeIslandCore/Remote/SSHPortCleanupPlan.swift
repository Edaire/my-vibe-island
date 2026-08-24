public enum SSHPortCleanupAction: String, Codable, Equatable, Sendable {
    case noCleanupNeeded
    case cleanupSameUserStaleSSHD
    case failClosed
}

public struct SSHPortCleanupPlan: Codable, Equatable, Sendable {
    public let hostId: String
    public let port: Int
    public let action: SSHPortCleanupAction
    public let pidsEligibleForCleanup: [Int]
    public let requiresManualCleanup: Bool
    public let diagnosticSummary: String

    public init(conflict: SSHPortConflict) {
        hostId = conflict.hostId
        port = conflict.port

        if Self.canCleanup(conflict) {
            action = .cleanupSameUserStaleSSHD
            pidsEligibleForCleanup = conflict.sameUserSSHPids.sorted()
            requiresManualCleanup = false
            diagnosticSummary = "\(conflict.hostId) port \(conflict.port) cleanup limited to same-user stale sshd"
        } else if conflict.decision == .free {
            action = .noCleanupNeeded
            pidsEligibleForCleanup = []
            requiresManualCleanup = false
            diagnosticSummary = "\(conflict.hostId) port \(conflict.port) is free"
        } else {
            action = .failClosed
            pidsEligibleForCleanup = []
            requiresManualCleanup = true
            diagnosticSummary = "\(conflict.hostId) port \(conflict.port) cleanup requires manual review"
        }
    }

    private static func canCleanup(_ conflict: SSHPortConflict) -> Bool {
        conflict.decision == .sameUserStaleSSHDCleanupAllowed
            && conflict.checkedByLsof
            && conflict.checkedBySS
            && !conflict.sameUserSSHPids.isEmpty
            && conflict.liveEstablishedPids.isEmpty
            && conflict.foreignOwners.isEmpty
    }
}
