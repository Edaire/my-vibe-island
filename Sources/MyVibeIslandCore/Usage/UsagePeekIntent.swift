import Foundation

public enum UsagePeekKind: Codable, Equatable, Sendable {
    case thresholdReached(thresholdPercent: Int)
    case limitReached
    case windowReset(resetAt: String)
}

public struct UsagePeekIntent: Codable, Equatable, Sendable {
    public let providerId: UsageProviderIdentifier
    public let accountId: UsageAccountID?
    public let windowId: String
    public let kind: UsagePeekKind
    public let title: String
    public let message: String
    public let dedupeKey: String

    public init(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil,
        windowId: String,
        kind: UsagePeekKind,
        title: String,
        message: String,
        dedupeKey: String
    ) {
        self.providerId = providerId
        self.accountId = accountId
        self.windowId = windowId
        self.kind = kind
        self.title = title
        self.message = message
        self.dedupeKey = dedupeKey
    }

    public static func make(
        snapshot: UsageSnapshot,
        settings: UsageSettingsSnapshot
    ) -> [UsagePeekIntent] {
        guard
            settings.thresholdPeeksEnabled,
            snapshot.freshness == .fresh,
            let window = snapshot.primaryWindow
        else {
            return []
        }

        var intents: [UsagePeekIntent] = []

        if
            let usedPercent = window.usedPercent,
            usedPercent >= Double(settings.thresholdPercent)
        {
            intents.append(
                UsagePeekIntent(
                    providerId: snapshot.providerId,
                    accountId: snapshot.accountId,
                    windowId: window.id,
                    kind: .thresholdReached(thresholdPercent: settings.thresholdPercent),
                    title: "Usage threshold reached",
                    message: "\(window.label) reached \(formatPercent(usedPercent)) used",
                    dedupeKey: "usageThreshold:\(snapshot.providerId.rawValue):\(window.id):\(settings.thresholdPercent)"
                )
            )
        }

        if let usedPercent = window.usedPercent, usedPercent >= 100 {
            intents.append(
                UsagePeekIntent(
                    providerId: snapshot.providerId,
                    accountId: snapshot.accountId,
                    windowId: window.id,
                    kind: .limitReached,
                    title: "Usage limit reached",
                    message: "\(window.label) reached \(formatPercent(usedPercent)) used",
                    dedupeKey: "usageLimit:\(snapshot.providerId.rawValue):\(window.id)"
                )
            )
        }

        if let resetAt = window.resetAt {
            intents.append(
                UsagePeekIntent(
                    providerId: snapshot.providerId,
                    accountId: snapshot.accountId,
                    windowId: window.id,
                    kind: .windowReset(resetAt: resetAt),
                    title: "Usage window reset",
                    message: "\(window.label) resets at \(resetAt)",
                    dedupeKey: "usageReset:\(snapshot.providerId.rawValue):\(resetAt)"
                )
            )
        }

        return intents
    }

    private static func formatPercent(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))%"
        }

        return "\(value)%"
    }
}
