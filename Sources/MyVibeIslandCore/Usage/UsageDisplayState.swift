import Foundation

public enum UsageDisplayStatus: String, Codable, Equatable, Sendable {
    case hidden
    case unavailable
    case waiting
    case error
    case available
}

public struct UsageDisplayState: Codable, Equatable, Sendable {
    public let status: UsageDisplayStatus
    public let providerId: UsageProviderIdentifier?
    public let providerDisplayName: String
    public let displayStyle: UsageDisplayStyle
    public let valueMode: UsageValueMode
    public let title: String
    public let primaryText: String?
    public let secondaryText: String?
    public let percent: Double?
    public let freshness: UsageSnapshotFreshness?
    public let bridgeHint: UsageBridgeHint?

    public init(
        status: UsageDisplayStatus,
        providerId: UsageProviderIdentifier? = nil,
        providerDisplayName: String,
        displayStyle: UsageDisplayStyle,
        valueMode: UsageValueMode,
        title: String,
        primaryText: String? = nil,
        secondaryText: String? = nil,
        percent: Double? = nil,
        freshness: UsageSnapshotFreshness? = nil,
        bridgeHint: UsageBridgeHint? = nil
    ) {
        self.status = status
        self.providerId = providerId
        self.providerDisplayName = providerDisplayName
        self.displayStyle = displayStyle
        self.valueMode = valueMode
        self.title = title
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.percent = percent
        self.freshness = freshness
        self.bridgeHint = bridgeHint
    }

    public static func make(
        snapshot: UsageSnapshot?,
        settings: UsageSettingsSnapshot,
        providerDisplayName: String
    ) -> UsageDisplayState {
        if settings.displayStyle == .hidden {
            return UsageDisplayState(
                status: .hidden,
                providerDisplayName: providerDisplayName,
                displayStyle: settings.displayStyle,
                valueMode: settings.valueMode,
                title: providerDisplayName
            )
        }

        guard let snapshot else {
            return UsageDisplayState(
                status: .unavailable,
                providerDisplayName: providerDisplayName,
                displayStyle: settings.displayStyle,
                valueMode: settings.valueMode,
                title: providerDisplayName,
                primaryText: "Usage unavailable"
            )
        }

        if let waitingHint = snapshot.waitingHint {
            return displayState(
                status: .waiting,
                snapshot: snapshot,
                settings: settings,
                providerDisplayName: providerDisplayName,
                primaryText: waitingHint.text
            )
        }

        if let error = snapshot.error {
            return displayState(
                status: .error,
                snapshot: snapshot,
                settings: settings,
                providerDisplayName: providerDisplayName,
                primaryText: error.rawValue
            )
        }

        return displayState(
            status: .available,
            snapshot: snapshot,
            settings: settings,
            providerDisplayName: providerDisplayName,
            primaryText: primaryText(for: snapshot.primaryWindow, valueMode: settings.valueMode),
            percent: snapshot.primaryWindow?.usedPercent
        )
    }

    private static func displayState(
        status: UsageDisplayStatus,
        snapshot: UsageSnapshot,
        settings: UsageSettingsSnapshot,
        providerDisplayName: String,
        primaryText: String?,
        percent: Double? = nil
    ) -> UsageDisplayState {
        UsageDisplayState(
            status: status,
            providerId: snapshot.providerId,
            providerDisplayName: providerDisplayName,
            displayStyle: settings.displayStyle,
            valueMode: settings.valueMode,
            title: providerDisplayName,
            primaryText: primaryText,
            percent: percent,
            freshness: snapshot.freshness,
            bridgeHint: snapshot.bridgeHint
        )
    }

    private static func primaryText(
        for window: UsageLimitWindow?,
        valueMode: UsageValueMode
    ) -> String? {
        guard let window else {
            return nil
        }

        switch valueMode {
        case .used:
            guard let usedPercent = window.usedPercent else {
                return nil
            }
            return "\(Int(usedPercent.rounded()))% used"
        case .remaining:
            guard let remaining = window.remaining else {
                return nil
            }
            return "\(formatAmountValue(remaining.value)) \(remaining.unit) remaining"
        case .resetCountdown:
            guard let resetInSeconds = window.resetInSeconds else {
                return nil
            }
            return "Resets in \(resetInSeconds)s"
        }
    }

    private static func formatAmountValue(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(value)
    }
}

public struct UsageInfoBar: Codable, Equatable, Sendable {
    public let status: UsageDisplayStatus
    public let title: String
    public let primaryText: String?
    public let secondaryText: String?
    public let providerDisplayName: String

    public init(
        status: UsageDisplayStatus,
        title: String,
        primaryText: String? = nil,
        secondaryText: String? = nil,
        providerDisplayName: String
    ) {
        self.status = status
        self.title = title
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.providerDisplayName = providerDisplayName
    }

    public static func make(displayState: UsageDisplayState) -> UsageInfoBar {
        UsageInfoBar(
            status: displayState.status,
            title: displayState.title,
            primaryText: displayState.primaryText,
            secondaryText: displayState.secondaryText,
            providerDisplayName: displayState.providerDisplayName
        )
    }
}

public struct UsageRingBadge: Codable, Equatable, Sendable {
    public let status: UsageDisplayStatus
    public let title: String
    public let percent: Double?
    public let providerDisplayName: String

    public init(
        status: UsageDisplayStatus,
        title: String,
        percent: Double? = nil,
        providerDisplayName: String
    ) {
        self.status = status
        self.title = title
        self.percent = percent
        self.providerDisplayName = providerDisplayName
    }

    public static func make(displayState: UsageDisplayState) -> UsageRingBadge {
        UsageRingBadge(
            status: displayState.status,
            title: displayState.title,
            percent: displayState.percent,
            providerDisplayName: displayState.providerDisplayName
        )
    }
}
