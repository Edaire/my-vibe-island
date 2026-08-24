import Foundation

public struct CodexRateLimit: Codable, Equatable, Sendable {
    public let usedPercent: Double?
    public let windowMinutes: Int?
    public let resetsAt: String?
    public let resetsInSeconds: Int?

    public init(
        usedPercent: Double? = nil,
        windowMinutes: Int? = nil,
        resetsAt: String? = nil,
        resetsInSeconds: Int? = nil
    ) {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
        self.resetsInSeconds = resetsInSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetsAt = "resets_at"
        case resetsInSeconds = "resets_in_seconds"
    }
}

public struct CodexRateLimitCredits: Codable, Equatable, Sendable {
    public let hasCredits: Bool?
    public let unlimited: Bool?
    public let balance: Double?

    public init(
        hasCredits: Bool? = nil,
        unlimited: Bool? = nil,
        balance: Double? = nil
    ) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }

    private enum CodingKeys: String, CodingKey {
        case hasCredits = "has_credits"
        case unlimited
        case balance
    }
}

public struct CodexRateLimits: Codable, Equatable, Sendable {
    public enum LimitExhaustionKind: String, Codable, Equatable, Sendable {
        case primary
        case secondary
        case credits
        case unknown
    }

    public let limitId: String?
    public let limitName: String?
    public let planType: String?
    public let primary: CodexRateLimit?
    public let secondary: CodexRateLimit?
    public let credits: CodexRateLimitCredits?
    public let rateLimitReachedType: LimitExhaustionKind?

    public init(
        limitId: String? = nil,
        limitName: String? = nil,
        planType: String? = nil,
        primary: CodexRateLimit? = nil,
        secondary: CodexRateLimit? = nil,
        credits: CodexRateLimitCredits? = nil,
        rateLimitReachedType: LimitExhaustionKind? = nil
    ) {
        self.limitId = limitId
        self.limitName = limitName
        self.planType = planType
        self.primary = primary
        self.secondary = secondary
        self.credits = credits
        self.rateLimitReachedType = rateLimitReachedType
    }

    private enum CodingKeys: String, CodingKey {
        case limitId = "limit_id"
        case limitName = "limit_name"
        case planType = "plan_type"
        case primary
        case secondary
        case credits
        case rateLimitReachedType = "rate_limit_reached_type"
    }
}

public extension ProviderQuotaSnapshot {
    init(
        codexRateLimits: CodexRateLimits,
        accountId: UsageAccountID? = nil,
        collectedAt: String? = nil,
        freshness: UsageSnapshotFreshness = .fresh
    ) {
        let primaryWindow = codexRateLimits.primary.map {
            UsageLimitWindow(codexRateLimit: $0, id: "primary", label: "\(codexRateLimits.displayName) primary")
        }
        let secondaryWindow = codexRateLimits.secondary.map {
            UsageLimitWindow(codexRateLimit: $0, id: "secondary", label: "\(codexRateLimits.displayName) secondary")
        }
        let hasUsageWindows = primaryWindow != nil || secondaryWindow != nil

        self.init(
            providerId: .codexRateLimits,
            accountId: accountId,
            source: .providerReported,
            collectedAt: collectedAt,
            freshness: hasUsageWindows ? freshness : .unavailable,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            extraUsage: codexRateLimits.credits.map { [UsageExtraUsageItem(codexCredits: $0)] } ?? [],
            bridgeHint: UsageBridgeHint(codexReachedType: codexRateLimits.rateLimitReachedType),
            failure: hasUsageWindows ? nil : .noUsageWindows,
            privacyLevel: .redacted
        )
    }
}

private extension CodexRateLimits {
    var displayName: String {
        limitName ?? limitId ?? "Codex"
    }
}

private extension UsageLimitWindow {
    init(
        codexRateLimit: CodexRateLimit,
        id: String,
        label: String
    ) {
        self.init(
            id: id,
            label: label,
            kind: UsageWindowKind(codexWindowMinutes: codexRateLimit.windowMinutes),
            usedPercent: codexRateLimit.usedPercent,
            resetAt: codexRateLimit.resetsAt,
            resetInSeconds: codexRateLimit.resetsInSeconds,
            sourceConfidence: .providerReported
        )
    }
}

private extension UsageWindowKind {
    init(codexWindowMinutes: Int?) {
        switch codexWindowMinutes {
        case 300:
            self = .fiveHour
        case 10_080:
            self = .sevenDay
        default:
            self = .providerSpecific
        }
    }
}

private extension UsageExtraUsageItem {
    init(codexCredits: CodexRateLimitCredits) {
        self.init(
            key: "credits",
            value: codexCredits.balance.map { String($0) } ?? "unknown",
            isEnabled: codexCredits.hasCredits ?? false,
            usedCredits: codexCredits.balance.map { UsageAmount(value: $0, unit: "credits") }
        )
    }
}

private extension UsageBridgeHint {
    init?(codexReachedType: CodexRateLimits.LimitExhaustionKind?) {
        guard let codexReachedType else {
            return nil
        }

        self.init(
            providerId: .codexRateLimits,
            severity: .warning,
            title: "Codex \(codexReachedType.rawValue) limit reached",
            action: .retry,
            redactedDetail: "provider reported rate limit state"
        )
    }
}
