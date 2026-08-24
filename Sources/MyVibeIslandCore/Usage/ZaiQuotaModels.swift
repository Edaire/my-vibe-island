import Foundation

public struct ZaiLimit: Codable, Equatable, Sendable {
    public let type: String?
    public let percentage: Double?
    public let usage: Double?
    public let currentValue: Double?
    public let remaining: Double?
    public let nextResetTime: String?
    public let unit: String?
    public let number: Double?

    public init(
        type: String? = nil,
        percentage: Double? = nil,
        usage: Double? = nil,
        currentValue: Double? = nil,
        remaining: Double? = nil,
        nextResetTime: String? = nil,
        unit: String? = nil,
        number: Double? = nil
    ) {
        self.type = type
        self.percentage = percentage
        self.usage = usage
        self.currentValue = currentValue
        self.remaining = remaining
        self.nextResetTime = nextResetTime
        self.unit = unit
        self.number = number
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case percentage
        case usage
        case currentValue = "current_value"
        case remaining
        case nextResetTime = "next_reset_time"
        case unit
        case number
    }
}

public struct ZaiQuotaData: Codable, Equatable, Sendable {
    public let limits: [ZaiLimit]?
    public let planName: String?

    public init(
        limits: [ZaiLimit]? = nil,
        planName: String? = nil
    ) {
        self.limits = limits
        self.planName = planName
    }

    private enum CodingKeys: String, CodingKey {
        case limits
        case planName = "plan_name"
    }
}

public struct ZaiQuotaResponse: Codable, Equatable, Sendable {
    public let code: Int?
    public let success: Bool?
    public let data: ZaiQuotaData?

    public init(
        code: Int? = nil,
        success: Bool? = nil,
        data: ZaiQuotaData? = nil
    ) {
        self.code = code
        self.success = success
        self.data = data
    }
}

public struct ZaiAccountPeriodEntry: Codable, Equatable, Sendable {
    public let productName: String?
    public let nextRenewTime: String?
    public let inCurrentPeriod: Bool?

    public init(
        productName: String? = nil,
        nextRenewTime: String? = nil,
        inCurrentPeriod: Bool? = nil
    ) {
        self.productName = productName
        self.nextRenewTime = nextRenewTime
        self.inCurrentPeriod = inCurrentPeriod
    }

    private enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case nextRenewTime = "next_renew_time"
        case inCurrentPeriod = "in_current_period"
    }
}

public struct ZaiAccountPeriodResponse: Codable, Equatable, Sendable {
    public let code: Int?
    public let success: Bool?
    public let data: [ZaiAccountPeriodEntry]?

    public init(
        code: Int? = nil,
        success: Bool? = nil,
        data: [ZaiAccountPeriodEntry]? = nil
    ) {
        self.code = code
        self.success = success
        self.data = data
    }
}

public struct ZaiQuotaConfigState: Codable, Equatable, Sendable {
    public enum Availability: String, Codable, Equatable, Sendable {
        case unknown
        case available
        case unavailable
    }

    public let configChecked: Bool
    public let cachedConfigAvailability: Availability

    public init(
        configChecked: Bool = false,
        cachedConfigAvailability: Availability = .unknown
    ) {
        self.configChecked = configChecked
        self.cachedConfigAvailability = cachedConfigAvailability
    }

    public func markingChecked(availability: Availability) -> ZaiQuotaConfigState {
        ZaiQuotaConfigState(configChecked: true, cachedConfigAvailability: availability)
    }

    public func resettingCheck() -> ZaiQuotaConfigState {
        ZaiQuotaConfigState()
    }
}

public extension ProviderQuotaSnapshot {
    init(
        zaiQuotaResponse: ZaiQuotaResponse,
        accountId: UsageAccountID? = nil,
        collectedAt: String? = nil,
        freshness: UsageSnapshotFreshness = .fresh
    ) {
        let windows = (zaiQuotaResponse.data?.limits ?? []).enumerated().map { index, limit in
            UsageLimitWindow(zaiLimit: limit, index: index)
        }
        let primaryWindow = windows.first
        let extraWindows = Array(windows.dropFirst())
        let hasUsageWindows = !windows.isEmpty

        self.init(
            providerId: .zaiQuota,
            accountId: accountId,
            source: .providerReported,
            collectedAt: collectedAt,
            freshness: hasUsageWindows ? freshness : .unavailable,
            primaryWindow: primaryWindow,
            extraWindows: extraWindows,
            extraUsage: zaiQuotaResponse.providerMetadataItems,
            failure: hasUsageWindows ? nil : .noUsageWindows,
            privacyLevel: .redacted
        )
    }

    func addingZaiAccountPeriodMetadata(
        _ response: ZaiAccountPeriodResponse
    ) -> ProviderQuotaSnapshot {
        ProviderQuotaSnapshot(
            providerId: providerId,
            accountId: accountId,
            source: source,
            collectedAt: collectedAt,
            freshness: freshness,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            extraWindows: extraWindows,
            extraUsage: extraUsage + response.providerMetadataItems,
            bridgeHint: bridgeHint,
            waitingHint: waitingHint,
            failure: failure,
            privacyLevel: privacyLevel
        )
    }
}

private extension ZaiQuotaResponse {
    var providerMetadataItems: [UsageExtraUsageItem] {
        [
            data?.planName.map { UsageExtraUsageItem(key: "planName", value: $0) },
            code.map { UsageExtraUsageItem(key: "code", value: String($0)) },
            success.map { UsageExtraUsageItem(key: "success", value: String($0)) }
        ].compactMap { $0 }
    }
}

private extension ZaiAccountPeriodResponse {
    var providerMetadataItems: [UsageExtraUsageItem] {
        let responseItems: [UsageExtraUsageItem?] = [
            code.map { UsageExtraUsageItem(key: "accountPeriodCode", value: String($0)) },
            success.map { UsageExtraUsageItem(key: "accountPeriodSuccess", value: String($0)) }
        ]
        let entryItems = (data ?? []).flatMap(\.providerMetadataItems)

        return responseItems.compactMap { $0 } + entryItems
    }
}

private extension ZaiAccountPeriodEntry {
    var providerMetadataItems: [UsageExtraUsageItem] {
        [
            productName.map { UsageExtraUsageItem(key: "accountPeriodProductName", value: $0) },
            nextRenewTime.map { UsageExtraUsageItem(key: "accountPeriodNextTime", value: $0) },
            inCurrentPeriod.map { UsageExtraUsageItem(key: "accountPeriodCurrent", value: String($0)) }
        ].compactMap { $0 }
    }
}

private extension UsageLimitWindow {
    init(
        zaiLimit: ZaiLimit,
        index: Int
    ) {
        let id = zaiLimit.type ?? "limit-\(index)"
        let unit = zaiLimit.unit ?? "units"

        self.init(
            id: id,
            label: "Z.ai \(id) quota",
            kind: UsageWindowKind(zaiLimitType: zaiLimit.type),
            used: zaiLimit.normalizedUsed.map { UsageAmount(value: $0, unit: unit) },
            limit: zaiLimit.number.map { UsageAmount(value: $0, unit: unit) },
            remaining: zaiLimit.remaining.map { UsageAmount(value: $0, unit: unit) },
            usedPercent: zaiLimit.percentage,
            resetAt: zaiLimit.nextResetTime,
            sourceConfidence: .providerReported
        )
    }
}

private extension ZaiLimit {
    var normalizedUsed: Double? {
        currentValue ?? usage
    }
}

private extension UsageWindowKind {
    init(zaiLimitType: String?) {
        switch zaiLimitType {
        case "daily":
            self = .daily
        case "monthly":
            self = .monthly
        case "total", "total_quota":
            self = .totalQuota
        case "parallel":
            self = .parallelQuota
        default:
            self = .providerSpecific
        }
    }
}
