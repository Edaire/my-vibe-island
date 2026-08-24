import Foundation

public struct TerminalPermissionStatus: Codable, Equatable, Sendable {
    public let hostId: String
    public let permissionType: TerminalPermissionRequirement
    public let state: OnboardingPermissionState
    public let repairAction: String?
    public let lastCheckedAt: String?

    public var needsRepair: Bool {
        state == .denied || state == .notDetermined
    }

    public init(
        hostId: String,
        permissionType: TerminalPermissionRequirement,
        state: OnboardingPermissionState,
        repairAction: String? = nil,
        lastCheckedAt: String? = nil
    ) {
        self.hostId = hostId
        self.permissionType = permissionType
        self.state = state
        self.repairAction = repairAction
        self.lastCheckedAt = lastCheckedAt
    }
}

public struct TerminalPermissionStatusModel: Sendable {
    public init() {}

    public func statuses(
        for descriptor: TerminalCapabilityDescriptor,
        grantedPermissions: Set<TerminalPermissionRequirement>,
        lastCheckedAt: String?
    ) -> [TerminalPermissionStatus] {
        descriptor.permissionRequirements.map { requirement in
            let state: OnboardingPermissionState
            let repairAction: String?

            if requirement == .none {
                state = .notRequired
                repairAction = nil
            } else if grantedPermissions.contains(requirement) {
                state = .granted
                repairAction = nil
            } else {
                state = .denied
                repairAction = Self.repairAction(
                    for: requirement,
                    displayName: descriptor.displayName
                )
            }

            return TerminalPermissionStatus(
                hostId: descriptor.id,
                permissionType: requirement,
                state: state,
                repairAction: repairAction,
                lastCheckedAt: lastCheckedAt
            )
        }
    }

    private static func repairAction(
        for requirement: TerminalPermissionRequirement,
        displayName: String
    ) -> String {
        switch requirement {
        case .automation:
            return "Grant Automation permission for \(displayName)"
        case .accessibility:
            return "Grant Accessibility permission for \(displayName)"
        case .cli:
            return "Install CLI dependency for \(displayName)"
        case .socket:
            return "Enable socket access for \(displayName)"
        case .urlScheme:
            return "Register URL scheme for \(displayName)"
        case .none:
            return ""
        }
    }
}
