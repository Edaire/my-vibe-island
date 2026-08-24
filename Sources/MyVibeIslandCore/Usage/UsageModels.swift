import Foundation

public enum UsageAmountPrecision: String, Codable, Equatable, Sendable {
    case exact
    case approximate
    case unknown
}

public enum UsageDisplayBucket: String, Codable, Equatable, Sendable {
    case none
    case low
    case medium
    case high
    case exhausted
    case unlimited
}

public struct UsageAmount: Codable, Equatable, Sendable {
    public let value: Double
    public let unit: String
    public let precision: UsageAmountPrecision
    public let displayBucket: UsageDisplayBucket

    public init(
        value: Double,
        unit: String,
        precision: UsageAmountPrecision = .exact,
        displayBucket: UsageDisplayBucket = .none
    ) {
        self.value = value
        self.unit = unit
        self.precision = precision
        self.displayBucket = displayBucket
    }

    public func usedPercent(of limit: UsageAmount?) -> Double? {
        guard let limit, limit.value > 0 else {
            return nil
        }

        return value / limit.value * 100
    }
}

public enum UsageProviderIdentifier: String, Codable, Equatable, Sendable {
    case codexRateLimits
    case kimiUsage
    case kimiBillingUsage
    case zaiQuota
    case claudeStatusLine
    case localParsedUsage
}

public enum UsageProviderCapability: String, Codable, Equatable, Sendable {
    case localAppServer
    case localCache
    case userOwnedCredential
    case statusLinePayload
    case normalizedSnapshotOnly
}

public enum UsageProviderAvailability: String, Codable, Equatable, Sendable {
    case available
    case unavailable
    case disabled
    case needsPermission
    case needsConfiguration
    case backoffActive
}

public enum UsageProviderAccountOrigin: String, Codable, Equatable, Sendable {
    case localApp
    case localConfig
    case environment
    case statusLine
    case cache
    case manual
}

public enum UsageAccountCategory: String, Codable, Equatable, Sendable {
    case providerAccount
    case localCache
    case statusLine
    case manual
}

public enum UsageWindowKind: String, Codable, Equatable, Sendable {
    case fiveHour
    case sevenDay
    case daily
    case monthly
    case totalQuota
    case parallelQuota
    case providerSpecific
}

public enum UsageLimitWindowSlot: String, Codable, Equatable, Sendable {
    case primary
    case secondary
    case extra
}

public enum UsageSnapshotFreshness: String, Codable, Equatable, Sendable {
    case fresh
    case stale
    case unavailable
}

public enum UsageSourceConfidence: String, Codable, Equatable, Sendable {
    case providerReported
    case parsed
    case cached
    case estimated
    case unknown
}

public struct UsageLimitSource: Codable, Equatable, Sendable {
    public let providerId: UsageProviderIdentifier
    public let confidence: UsageSourceConfidence
    public let accountId: UsageAccountID?
    public let collectedAt: String?
    public let redactedDetail: String?

    public init(
        providerId: UsageProviderIdentifier,
        confidence: UsageSourceConfidence,
        accountId: UsageAccountID? = nil,
        collectedAt: String? = nil,
        redactedDetail: String? = nil
    ) {
        self.providerId = providerId
        self.confidence = confidence
        self.accountId = accountId
        self.collectedAt = collectedAt
        self.redactedDetail = redactedDetail
    }
}

public enum UsageRefreshTrigger: String, Codable, Equatable, Sendable {
    case usageDisplayOpened
    case focusedSessionChanged
    case providerPreferenceChanged
    case providerRateLimitUpdated
    case resetTimerFired
    case manualRefresh
}

public enum UsagePrivacyLevel: String, Codable, Equatable, Sendable {
    case redacted
    case localOnly
    case sensitive
}

public enum UsageFailureCategory: String, Codable, Equatable, Sendable {
    case disabledBySetting
    case providerUnavailable
    case credentialMissing
    case authorizationExpired
    case localBridgeUnavailable
    case responseParseFailed
    case noUsageWindows
    case staleResetTime
    case backoffActive
    case sleepPaused
}

public enum UsageBridgeHintSeverity: String, Codable, Equatable, Sendable {
    case info
    case warning
    case error
}

public enum UsageBridgeHintAction: String, Codable, Equatable, Sendable {
    case none
    case openSettings
    case authorizeProvider
    case retry
}

public enum UsageWaitingHintReason: String, Codable, Equatable, Sendable {
    case refreshInProgress
    case minimumIntervalActive
    case backoffActive
    case sleepPaused
    case providerUnavailable
    case needsConfiguration
}

public enum UsageDisplayStyle: String, Codable, Equatable, Sendable {
    case hidden
    case ringBadge
    case infoBar
    case compactHint
}

public enum UsageValueMode: String, Codable, Equatable, Sendable {
    case used
    case remaining
    case resetCountdown
}

public struct UsageProviderDescriptor: Codable, Equatable, Sendable {
    public let id: UsageProviderIdentifier
    public let displayName: String
    public let capabilities: [UsageProviderCapability]
    public let minimumRefreshIntervalSeconds: Int
    public let availability: UsageProviderAvailability

    public init(
        id: UsageProviderIdentifier,
        displayName: String,
        capabilities: [UsageProviderCapability],
        minimumRefreshIntervalSeconds: Int,
        availability: UsageProviderAvailability
    ) {
        self.id = id
        self.displayName = displayName
        self.capabilities = capabilities
        self.minimumRefreshIntervalSeconds = minimumRefreshIntervalSeconds
        self.availability = availability
    }
}

public struct UsageAccountID: Codable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func redacted(rawValue: String) -> UsageAccountID {
        UsageAccountID(rawValue: "redacted-\(fnv1a64Hex(rawValue))")
    }

    private static func fnv1a64Hex(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

public struct UsageLimitWindow: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let kind: UsageWindowKind
    public let used: UsageAmount?
    public let limit: UsageAmount?
    public let remaining: UsageAmount?
    public let usedPercent: Double?
    public let resetAt: String?
    public let resetInSeconds: Int?
    public let isUnlimited: Bool
    public let sourceConfidence: UsageSourceConfidence

    public init(
        id: String,
        label: String,
        kind: UsageWindowKind,
        used: UsageAmount? = nil,
        limit: UsageAmount? = nil,
        remaining: UsageAmount? = nil,
        usedPercent: Double? = nil,
        resetAt: String? = nil,
        resetInSeconds: Int? = nil,
        isUnlimited: Bool = false,
        sourceConfidence: UsageSourceConfidence = .unknown
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.used = used
        self.limit = limit
        self.remaining = remaining
        self.usedPercent = usedPercent
        self.resetAt = resetAt
        self.resetInSeconds = resetInSeconds
        self.isUnlimited = isUnlimited
        self.sourceConfidence = sourceConfidence
    }
}

public struct UsageExtraUsageItem: Codable, Equatable, Sendable {
    public let key: String
    public let value: String
    public let isEnabled: Bool
    public let utilization: Double?
    public let monthlyLimit: UsageAmount?
    public let usedCredits: UsageAmount?
    public let currency: String?

    public init(
        key: String,
        value: String,
        isEnabled: Bool = true,
        utilization: Double? = nil,
        monthlyLimit: UsageAmount? = nil,
        usedCredits: UsageAmount? = nil,
        currency: String? = nil
    ) {
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
        self.utilization = utilization
        self.monthlyLimit = monthlyLimit
        self.usedCredits = usedCredits
        self.currency = currency
    }
}

public struct UsageBridgeHint: Codable, Equatable, Sendable {
    public let providerId: UsageProviderIdentifier
    public let severity: UsageBridgeHintSeverity
    public let title: String
    public let action: UsageBridgeHintAction
    public let redactedDetail: String?

    public init(
        providerId: UsageProviderIdentifier,
        severity: UsageBridgeHintSeverity,
        title: String,
        action: UsageBridgeHintAction,
        redactedDetail: String? = nil
    ) {
        self.providerId = providerId
        self.severity = severity
        self.title = title
        self.action = action
        self.redactedDetail = redactedDetail
    }
}

public struct UsageWaitingHint: Codable, Equatable, Sendable {
    public let providerId: UsageProviderIdentifier
    public let reason: UsageWaitingHintReason
    public let severity: UsageBridgeHintSeverity
    public let text: String
    public let retryAfterSeconds: Int?
    public let action: UsageBridgeHintAction
    public let redactedDetail: String?

    public init(
        providerId: UsageProviderIdentifier,
        reason: UsageWaitingHintReason,
        severity: UsageBridgeHintSeverity,
        text: String,
        retryAfterSeconds: Int? = nil,
        action: UsageBridgeHintAction,
        redactedDetail: String? = nil
    ) {
        self.providerId = providerId
        self.reason = reason
        self.severity = severity
        self.text = text
        self.retryAfterSeconds = retryAfterSeconds
        self.action = action
        self.redactedDetail = redactedDetail
    }

    public init(from decoder: Decoder) throws {
        if let legacyText = try? decoder.singleValueContainer().decode(String.self) {
            self.init(
                providerId: .localParsedUsage,
                reason: .providerUnavailable,
                severity: .info,
                text: legacyText,
                action: .none
            )
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            providerId: try container.decode(UsageProviderIdentifier.self, forKey: .providerId),
            reason: try container.decode(UsageWaitingHintReason.self, forKey: .reason),
            severity: try container.decode(UsageBridgeHintSeverity.self, forKey: .severity),
            text: try container.decode(String.self, forKey: .text),
            retryAfterSeconds: try container.decodeIfPresent(Int.self, forKey: .retryAfterSeconds),
            action: try container.decode(UsageBridgeHintAction.self, forKey: .action),
            redactedDetail: try container.decodeIfPresent(String.self, forKey: .redactedDetail)
        )
    }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let providerId: UsageProviderIdentifier
    public let accountId: UsageAccountID?
    public let source: UsageSourceConfidence
    public let collectedAt: String?
    public let freshness: UsageSnapshotFreshness
    public let primaryWindow: UsageLimitWindow?
    public let secondaryWindow: UsageLimitWindow?
    public let extraWindows: [UsageLimitWindow]
    public let extraUsage: [UsageExtraUsageItem]
    public let bridgeHint: UsageBridgeHint?
    public let waitingHint: UsageWaitingHint?
    public let error: UsageFailureCategory?
    public let privacyLevel: UsagePrivacyLevel

    public init(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil,
        source: UsageSourceConfidence,
        collectedAt: String? = nil,
        freshness: UsageSnapshotFreshness,
        primaryWindow: UsageLimitWindow? = nil,
        secondaryWindow: UsageLimitWindow? = nil,
        extraWindows: [UsageLimitWindow] = [],
        extraUsage: [UsageExtraUsageItem] = [],
        bridgeHint: UsageBridgeHint? = nil,
        waitingHint: UsageWaitingHint? = nil,
        error: UsageFailureCategory? = nil,
        privacyLevel: UsagePrivacyLevel
    ) {
        self.providerId = providerId
        self.accountId = accountId
        self.source = source
        self.collectedAt = collectedAt
        self.freshness = freshness
        self.primaryWindow = primaryWindow
        self.secondaryWindow = secondaryWindow
        self.extraWindows = extraWindows
        self.extraUsage = extraUsage
        self.bridgeHint = bridgeHint
        self.waitingHint = waitingHint
        self.error = error
        self.privacyLevel = privacyLevel
    }

    public init(providerQuotaSnapshot snapshot: ProviderQuotaSnapshot) {
        self.init(
            providerId: snapshot.providerId,
            accountId: snapshot.accountId,
            source: snapshot.source,
            collectedAt: snapshot.collectedAt,
            freshness: snapshot.freshness,
            primaryWindow: snapshot.primaryWindow,
            secondaryWindow: snapshot.secondaryWindow,
            extraWindows: snapshot.extraWindows,
            extraUsage: snapshot.extraUsage,
            bridgeHint: snapshot.bridgeHint,
            waitingHint: snapshot.waitingHint,
            error: snapshot.failure,
            privacyLevel: snapshot.privacyLevel
        )
    }
}

public struct ProviderQuotaSnapshot: Codable, Equatable, Sendable {
    public let providerId: UsageProviderIdentifier
    public let accountId: UsageAccountID?
    public let source: UsageSourceConfidence
    public let collectedAt: String?
    public let freshness: UsageSnapshotFreshness
    public let primaryWindow: UsageLimitWindow?
    public let secondaryWindow: UsageLimitWindow?
    public let extraWindows: [UsageLimitWindow]
    public let extraUsage: [UsageExtraUsageItem]
    public let bridgeHint: UsageBridgeHint?
    public let waitingHint: UsageWaitingHint?
    public let failure: UsageFailureCategory?
    public let privacyLevel: UsagePrivacyLevel

    public init(
        providerId: UsageProviderIdentifier,
        accountId: UsageAccountID? = nil,
        source: UsageSourceConfidence,
        collectedAt: String? = nil,
        freshness: UsageSnapshotFreshness,
        primaryWindow: UsageLimitWindow? = nil,
        secondaryWindow: UsageLimitWindow? = nil,
        extraWindows: [UsageLimitWindow] = [],
        extraUsage: [UsageExtraUsageItem] = [],
        bridgeHint: UsageBridgeHint? = nil,
        waitingHint: UsageWaitingHint? = nil,
        failure: UsageFailureCategory? = nil,
        privacyLevel: UsagePrivacyLevel
    ) {
        self.providerId = providerId
        self.accountId = accountId
        self.source = source
        self.collectedAt = collectedAt
        self.freshness = freshness
        self.primaryWindow = primaryWindow
        self.secondaryWindow = secondaryWindow
        self.extraWindows = extraWindows
        self.extraUsage = extraUsage
        self.bridgeHint = bridgeHint
        self.waitingHint = waitingHint
        self.failure = failure
        self.privacyLevel = privacyLevel
    }
}

public struct UsageAccountRecord: Codable, Equatable, Sendable {
    public let accountId: UsageAccountID
    public let providerId: UsageProviderIdentifier
    public let category: UsageAccountCategory
    public let origin: UsageProviderAccountOrigin
    public let displayLabel: String
    public let lastSelectedAt: String?
    public let lastSnapshotSummary: String?

    public init(
        accountId: UsageAccountID,
        providerId: UsageProviderIdentifier,
        category: UsageAccountCategory = .providerAccount,
        origin: UsageProviderAccountOrigin,
        displayLabel: String,
        lastSelectedAt: String? = nil,
        lastSnapshotSummary: String? = nil
    ) {
        self.accountId = accountId
        self.providerId = providerId
        self.category = category
        self.origin = origin
        self.displayLabel = displayLabel
        self.lastSelectedAt = lastSelectedAt
        self.lastSnapshotSummary = lastSnapshotSummary
    }
}

public struct UsageAccountStoreSnapshot: Codable, Equatable, Sendable {
    public let accounts: [UsageAccountRecord]

    public init(accounts: [UsageAccountRecord] = []) {
        self.accounts = accounts
    }
}
