import Foundation

public struct MainThreadHangSnapshot: Codable, Equatable, Sendable {
    public let detectedAt: String
    public let durationMilliseconds: Int
    public let threadStateSummary: String
    public let recentEventCount: Int
    public let redactedStackAvailable: Bool
    public let recoveredAt: String?
    public let peakLagMilliseconds: Int?

    public init(
        detectedAt: String,
        durationMilliseconds: Int,
        threadStateSummary: String,
        recentEventCount: Int,
        redactedStackAvailable: Bool,
        recoveredAt: String? = nil,
        peakLagMilliseconds: Int? = nil
    ) {
        self.detectedAt = detectedAt
        self.durationMilliseconds = durationMilliseconds
        self.threadStateSummary = threadStateSummary
        self.recentEventCount = recentEventCount
        self.redactedStackAvailable = redactedStackAvailable
        self.recoveredAt = recoveredAt
        self.peakLagMilliseconds = peakLagMilliseconds
    }
}
