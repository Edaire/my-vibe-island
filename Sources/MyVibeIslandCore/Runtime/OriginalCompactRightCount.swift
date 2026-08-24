public struct OriginalCompactRightCount: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case actionable
        case sessions
    }

    public let count: Int
    public let source: Source

    public init(count: Int, source: Source) {
        self.count = count
        self.source = source
    }

    public static func resolve(eligibleStatuses: [OriginalPixelStatusCompact]) -> Self? {
        guard !eligibleStatuses.isEmpty else { return nil }

        let actionableCount = eligibleStatuses.filter {
            $0 == .waitingForApproval || $0 == .question
        }.count

        return actionableCount > 0
            ? Self(count: actionableCount, source: .actionable)
            : Self(count: eligibleStatuses.count, source: .sessions)
    }
}
