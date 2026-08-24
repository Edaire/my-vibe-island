public struct UpdateCheckerSettings: Codable, Equatable, Sendable {
    public let automaticChecksEnabled: Bool
    public let automaticInstallEnabled: Bool

    public init(
        automaticChecksEnabled: Bool = false,
        automaticInstallEnabled: Bool = false
    ) {
        self.automaticChecksEnabled = automaticChecksEnabled
        self.automaticInstallEnabled = automaticInstallEnabled
    }
}

public enum UpdateCheckKind: String, Codable, Equatable, Sendable {
    case manual
    case background
}

public struct UpdateCheckRequest: Codable, Equatable, Sendable {
    public let kind: UpdateCheckKind
    public let currentVersion: String
    public let automaticInstallAllowed: Bool

    public init(
        kind: UpdateCheckKind,
        currentVersion: String,
        automaticInstallAllowed: Bool
    ) {
        self.kind = kind
        self.currentVersion = currentVersion
        self.automaticInstallAllowed = automaticInstallAllowed
    }
}

public enum UpdateCheckerCommand: Equatable, Sendable {
    case manualCheck(currentVersion: String)
    case backgroundCheck(currentVersion: String)
}

public enum UpdateCheckerAction: String, Codable, Equatable, Sendable {
    case startManualCheck
    case startBackgroundCheck
    case skipBackgroundCheck
    case updatesUnavailable
}

public struct UpdateCheckerPlan: Equatable, Sendable {
    public let action: UpdateCheckerAction
    public let request: UpdateCheckRequest?

    public init(action: UpdateCheckerAction, request: UpdateCheckRequest? = nil) {
        self.action = action
        self.request = request
    }
}

public struct UpdateChecker: Sendable {
    public init() {}

    public func plan(
        _ command: UpdateCheckerCommand,
        settings: UpdateCheckerSettings
    ) -> UpdateCheckerPlan {
        switch command {
        case let .manualCheck(currentVersion):
            return UpdateCheckerPlan(
                action: .startManualCheck,
                request: UpdateCheckRequest(
                    kind: .manual,
                    currentVersion: currentVersion,
                    automaticInstallAllowed: false
                )
            )

        case let .backgroundCheck(currentVersion):
            guard settings.automaticChecksEnabled else {
                return UpdateCheckerPlan(action: .skipBackgroundCheck)
            }

            return UpdateCheckerPlan(
                action: .startBackgroundCheck,
                request: UpdateCheckRequest(
                    kind: .background,
                    currentVersion: currentVersion,
                    automaticInstallAllowed: settings.automaticInstallEnabled
                )
            )
        }
    }
}
