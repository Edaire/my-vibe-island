import Foundation

public struct KimiUsageDetail: Codable, Equatable, Sendable {
    public let limit: Double?
    public let used: Double?
    public let remaining: Double?
    public let resetTime: String?

    public init(
        limit: Double? = nil,
        used: Double? = nil,
        remaining: Double? = nil,
        resetTime: String? = nil
    ) {
        self.limit = limit
        self.used = used
        self.remaining = remaining
        self.resetTime = resetTime
    }

    private enum CodingKeys: String, CodingKey {
        case limit
        case used
        case remaining
        case resetTime = "reset_time"
    }
}

public struct KimiUsageWindow: Codable, Equatable, Sendable {
    public let duration: Int?
    public let timeUnit: String?

    public init(
        duration: Int? = nil,
        timeUnit: String? = nil
    ) {
        self.duration = duration
        self.timeUnit = timeUnit
    }

    private enum CodingKeys: String, CodingKey {
        case duration
        case timeUnit = "time_unit"
    }
}

public struct KimiRateLimit: Codable, Equatable, Sendable {
    public let window: KimiUsageWindow?
    public let detail: KimiUsageDetail?

    public init(
        window: KimiUsageWindow? = nil,
        detail: KimiUsageDetail? = nil
    ) {
        self.window = window
        self.detail = detail
    }
}

public struct KimiParallelQuota: Codable, Equatable, Sendable {
    public let limit: Double?
    public let used: Double?
    public let remaining: Double?
    public let resetTime: String?

    public init(
        limit: Double? = nil,
        used: Double? = nil,
        remaining: Double? = nil,
        resetTime: String? = nil
    ) {
        self.limit = limit
        self.used = used
        self.remaining = remaining
        self.resetTime = resetTime
    }

    private enum CodingKeys: String, CodingKey {
        case limit
        case used
        case remaining
        case resetTime = "reset_time"
    }
}

public struct KimiCodingUsageResponse: Codable, Equatable, Sendable {
    public let usage: KimiUsageDetail?
    public let limits: [KimiRateLimit]?
    public let totalQuota: KimiUsageDetail?
    public let parallel: KimiParallelQuota?
    public let subType: String?
    public let authentication: String?

    public init(
        usage: KimiUsageDetail? = nil,
        limits: [KimiRateLimit]? = nil,
        totalQuota: KimiUsageDetail? = nil,
        parallel: KimiParallelQuota? = nil,
        subType: String? = nil,
        authentication: String? = nil
    ) {
        self.usage = usage
        self.limits = limits
        self.totalQuota = totalQuota
        self.parallel = parallel
        self.subType = subType
        self.authentication = authentication
    }

    private enum CodingKeys: String, CodingKey {
        case usage
        case limits
        case totalQuota = "total_quota"
        case parallel
        case subType = "sub_type"
        case authentication
    }
}

public struct KimiBillingUsage: Codable, Equatable, Sendable {
    public let scope: String?
    public let detail: KimiUsageDetail?
    public let limits: [KimiRateLimit]?

    public init(
        scope: String? = nil,
        detail: KimiUsageDetail? = nil,
        limits: [KimiRateLimit]? = nil
    ) {
        self.scope = scope
        self.detail = detail
        self.limits = limits
    }
}

public struct KimiBillingUsageResponse: Codable, Equatable, Sendable {
    public let usages: [KimiBillingUsage]?

    public init(usages: [KimiBillingUsage]? = nil) {
        self.usages = usages
    }
}

public struct KimiUsageProbeState: Codable, Equatable, Sendable {
    public let cachedResult: KimiCodingUsageResponse?
    public let isProbing: Bool

    public init(
        cachedResult: KimiCodingUsageResponse? = nil,
        isProbing: Bool = false
    ) {
        self.cachedResult = cachedResult
        self.isProbing = isProbing
    }

    public func updatingCachedResult(_ cachedResult: KimiCodingUsageResponse?) -> KimiUsageProbeState {
        KimiUsageProbeState(cachedResult: cachedResult, isProbing: isProbing)
    }

    public func updatingProbeStatus(isProbing: Bool) -> KimiUsageProbeState {
        KimiUsageProbeState(cachedResult: cachedResult, isProbing: isProbing)
    }
}

public extension ProviderQuotaSnapshot {
    init(
        kimiCodingUsage: KimiCodingUsageResponse,
        accountId: UsageAccountID? = nil,
        collectedAt: String? = nil,
        freshness: UsageSnapshotFreshness = .fresh
    ) {
        let primaryWindow = kimiCodingUsage.totalQuota.map {
            UsageLimitWindow(kimiDetail: $0, id: "total-quota", label: "Kimi total quota", kind: .totalQuota)
        }
        let secondaryWindow = kimiCodingUsage.parallel.map {
            UsageLimitWindow(kimiParallelQuota: $0, id: "parallel", label: "Kimi parallel quota")
        }
        let extraWindows = (kimiCodingUsage.limits ?? []).enumerated().compactMap { index, rateLimit in
            UsageLimitWindow(kimiRateLimit: rateLimit, index: index)
        }
        let hasUsageWindows = primaryWindow != nil || secondaryWindow != nil || !extraWindows.isEmpty

        self.init(
            providerId: .kimiUsage,
            accountId: accountId,
            source: .providerReported,
            collectedAt: collectedAt,
            freshness: hasUsageWindows ? freshness : .unavailable,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            extraWindows: extraWindows,
            extraUsage: kimiCodingUsage.providerMetadataItems,
            failure: hasUsageWindows ? nil : .noUsageWindows,
            privacyLevel: .redacted
        )
    }

    func addingKimiProviderUsageMetadata(
        _ response: KimiBillingUsageResponse
    ) -> ProviderQuotaSnapshot {
        ProviderQuotaSnapshot(
            providerId: providerId,
            accountId: accountId,
            source: source,
            collectedAt: collectedAt,
            freshness: freshness,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            extraWindows: extraWindows + response.providerUsageWindows,
            extraUsage: extraUsage + response.providerMetadataItems,
            bridgeHint: bridgeHint,
            waitingHint: waitingHint,
            failure: failure,
            privacyLevel: privacyLevel
        )
    }
}

private extension KimiCodingUsageResponse {
    var providerMetadataItems: [UsageExtraUsageItem] {
        [
            subType.map { UsageExtraUsageItem(key: "subType", value: $0) },
            authentication.map { UsageExtraUsageItem(key: "authentication", value: $0) }
        ].compactMap { $0 }
    }
}

private extension KimiBillingUsageResponse {
    var providerMetadataItems: [UsageExtraUsageItem] {
        (usages ?? []).flatMap(\.providerMetadataItems)
    }

    var providerUsageWindows: [UsageLimitWindow] {
        (usages ?? []).enumerated().flatMap { index, usage in
            usage.providerUsageWindows(index: index)
        }
    }
}

private extension KimiBillingUsage {
    var providerMetadataItems: [UsageExtraUsageItem] {
        [
            scope.map { UsageExtraUsageItem(key: "providerUsageScope", value: $0) }
        ].compactMap { $0 }
    }

    func providerUsageWindows(index: Int) -> [UsageLimitWindow] {
        let labelSuffix = scope ?? "\(index + 1)"
        let detailWindow = detail.map {
            UsageLimitWindow(
                kimiDetail: $0,
                id: "provider-usage-\(index)",
                label: "Kimi provider usage \(labelSuffix)",
                kind: .providerSpecific
            )
        }
        let limitWindows = (limits ?? []).enumerated().compactMap { limitIndex, rateLimit in
            UsageLimitWindow(
                kimiRateLimit: rateLimit,
                index: limitIndex,
                idPrefix: "provider-usage-\(index)-limit"
            )
        }

        return [detailWindow].compactMap { $0 } + limitWindows
    }
}

private extension UsageLimitWindow {
    init(
        kimiDetail: KimiUsageDetail,
        id: String,
        label: String,
        kind: UsageWindowKind
    ) {
        self.init(
            id: id,
            label: label,
            kind: kind,
            used: kimiDetail.used.map { UsageAmount(value: $0, unit: "tokens") },
            limit: kimiDetail.limit.map { UsageAmount(value: $0, unit: "tokens") },
            remaining: kimiDetail.remaining.map { UsageAmount(value: $0, unit: "tokens") },
            usedPercent: kimiDetail.usedPercent,
            resetAt: kimiDetail.resetTime,
            sourceConfidence: .providerReported
        )
    }

    init(
        kimiParallelQuota: KimiParallelQuota,
        id: String,
        label: String
    ) {
        self.init(
            id: id,
            label: label,
            kind: .parallelQuota,
            used: kimiParallelQuota.used.map { UsageAmount(value: $0, unit: "requests") },
            limit: kimiParallelQuota.limit.map { UsageAmount(value: $0, unit: "requests") },
            remaining: kimiParallelQuota.remaining.map { UsageAmount(value: $0, unit: "requests") },
            usedPercent: kimiParallelQuota.usedPercent,
            resetAt: kimiParallelQuota.resetTime,
            sourceConfidence: .providerReported
        )
    }

    init?(
        kimiRateLimit: KimiRateLimit,
        index: Int
    ) {
        self.init(kimiRateLimit: kimiRateLimit, index: index, idPrefix: "limit")
    }

    init?(
        kimiRateLimit: KimiRateLimit,
        index: Int,
        idPrefix: String
    ) {
        guard let detail = kimiRateLimit.detail else {
            return nil
        }

        self.init(
            kimiDetail: detail,
            id: "\(idPrefix)-\(index)",
            label: kimiRateLimit.window?.displayLabel ?? "Kimi limit \(index + 1)",
            kind: UsageWindowKind(kimiWindow: kimiRateLimit.window)
        )
    }
}

private extension KimiUsageDetail {
    var usedPercent: Double? {
        guard let used, let limit, limit > 0 else {
            return nil
        }
        return used / limit * 100
    }
}

private extension KimiParallelQuota {
    var usedPercent: Double? {
        guard let used, let limit, limit > 0 else {
            return nil
        }
        return used / limit * 100
    }
}

private extension UsageWindowKind {
    init(kimiWindow: KimiUsageWindow?) {
        guard let kimiWindow else {
            self = .providerSpecific
            return
        }

        switch (kimiWindow.duration, kimiWindow.timeUnit) {
        case (1, "day"):
            self = .daily
        case (7, "day"):
            self = .sevenDay
        case (1, "month"):
            self = .monthly
        default:
            self = .providerSpecific
        }
    }
}

private extension KimiUsageWindow {
    var displayLabel: String {
        guard let duration, let timeUnit else {
            return "Kimi limit"
        }
        return "Kimi \(duration) \(timeUnit) limit"
    }
}
