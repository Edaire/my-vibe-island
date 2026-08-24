import Foundation

public struct UsageSettingsSnapshot: Codable, Equatable, Sendable {
    public let preferredProviderId: UsageProviderIdentifier?
    public let displayStyle: UsageDisplayStyle
    public let valueMode: UsageValueMode
    public let thresholdPeeksEnabled: Bool
    public let thresholdPercent: Int
    public let usageNotificationsEnabled: Bool
    public let usageSoundEnabled: Bool
    public let labsProviderIds: Set<UsageProviderIdentifier>

    public init(
        preferredProviderId: UsageProviderIdentifier? = nil,
        displayStyle: UsageDisplayStyle = .hidden,
        valueMode: UsageValueMode = .used,
        thresholdPeeksEnabled: Bool = false,
        thresholdPercent: Int = 80,
        usageNotificationsEnabled: Bool = true,
        usageSoundEnabled: Bool = false,
        labsProviderIds: Set<UsageProviderIdentifier> = []
    ) {
        self.preferredProviderId = preferredProviderId
        self.displayStyle = displayStyle
        self.valueMode = valueMode
        self.thresholdPeeksEnabled = thresholdPeeksEnabled
        self.thresholdPercent = min(100, max(0, thresholdPercent))
        self.usageNotificationsEnabled = usageNotificationsEnabled
        self.usageSoundEnabled = usageSoundEnabled
        self.labsProviderIds = labsProviderIds
    }

    public var isUsageDisplayEnabled: Bool {
        displayStyle != .hidden
    }

    public func isLabsProviderEnabled(_ providerId: UsageProviderIdentifier) -> Bool {
        labsProviderIds.contains(providerId)
    }
}
