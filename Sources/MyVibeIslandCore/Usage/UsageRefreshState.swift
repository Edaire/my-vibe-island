import Foundation

public enum UsageRefreshDecision: Codable, Equatable, Sendable {
    case allowed
    case refreshInProgress
    case minimumIntervalActive(remainingSeconds: Int)
    case backoffActive(remainingSeconds: Int)
}

public struct UsageRefreshState: Codable, Equatable, Sendable {
    public let lastFetchAttemptSeconds: Int?
    public let lastSuccessfulFetchSeconds: Int?
    public let backoffMultiplier: Int
    public let backoffUntilSeconds: Int?
    public let isRefreshing: Bool

    public init(
        lastFetchAttemptSeconds: Int? = nil,
        lastSuccessfulFetchSeconds: Int? = nil,
        backoffMultiplier: Int = 1,
        backoffUntilSeconds: Int? = nil,
        isRefreshing: Bool = false
    ) {
        self.lastFetchAttemptSeconds = lastFetchAttemptSeconds
        self.lastSuccessfulFetchSeconds = lastSuccessfulFetchSeconds
        self.backoffMultiplier = max(1, backoffMultiplier)
        self.backoffUntilSeconds = backoffUntilSeconds
        self.isRefreshing = isRefreshing
    }

    public func decision(
        nowSeconds: Int,
        minimumRefreshIntervalSeconds: Int
    ) -> UsageRefreshDecision {
        if isRefreshing {
            return .refreshInProgress
        }

        if let backoffUntilSeconds, backoffUntilSeconds > nowSeconds {
            return .backoffActive(remainingSeconds: backoffUntilSeconds - nowSeconds)
        }

        if
            let lastFetchAttemptSeconds,
            minimumRefreshIntervalSeconds > 0
        {
            let nextAllowedAt = lastFetchAttemptSeconds + minimumRefreshIntervalSeconds
            if nextAllowedAt > nowSeconds {
                return .minimumIntervalActive(remainingSeconds: nextAllowedAt - nowSeconds)
            }
        }

        return .allowed
    }

    public func recordingRefreshStart(nowSeconds: Int) -> UsageRefreshState {
        UsageRefreshState(
            lastFetchAttemptSeconds: nowSeconds,
            lastSuccessfulFetchSeconds: lastSuccessfulFetchSeconds,
            backoffMultiplier: backoffMultiplier,
            backoffUntilSeconds: backoffUntilSeconds,
            isRefreshing: true
        )
    }

    public func recordingFailure(
        nowSeconds: Int,
        baseBackoffSeconds: Int,
        maximumBackoffMultiplier: Int
    ) -> UsageRefreshState {
        let maximumMultiplier = max(1, maximumBackoffMultiplier)
        let nextMultiplier = min(maximumMultiplier, max(1, backoffMultiplier + 1))
        let backoffSeconds = max(0, baseBackoffSeconds) * nextMultiplier

        return UsageRefreshState(
            lastFetchAttemptSeconds: nowSeconds,
            lastSuccessfulFetchSeconds: lastSuccessfulFetchSeconds,
            backoffMultiplier: nextMultiplier,
            backoffUntilSeconds: nowSeconds + backoffSeconds,
            isRefreshing: false
        )
    }

    public func recordingSuccess(nowSeconds: Int) -> UsageRefreshState {
        UsageRefreshState(
            lastFetchAttemptSeconds: nowSeconds,
            lastSuccessfulFetchSeconds: nowSeconds,
            backoffMultiplier: 1,
            backoffUntilSeconds: nil,
            isRefreshing: false
        )
    }
}
