public struct OriginalPeekTimerState: Codable, Equatable, Sendable {
    public let generation: Int
    public let hasTimer: Bool
    public let autoExpandedAt: Double?

    public init(generation: Int, hasTimer: Bool, autoExpandedAt: Double?) {
        self.generation = generation
        self.hasTimer = hasTimer
        self.autoExpandedAt = autoExpandedAt
    }
}

public enum OriginalPeekTimerOperation: Codable, Equatable, Sendable {
    case invalidateExisting
    case scheduleOneShot(delay: Double, generation: Int)
}

public struct OriginalPeekTimerPlan: Codable, Equatable, Sendable {
    public let state: OriginalPeekTimerState
    public let operations: [OriginalPeekTimerOperation]

    public init(state: OriginalPeekTimerState, operations: [OriginalPeekTimerOperation]) {
        self.state = state
        self.operations = operations
    }

    public static func apply(
        _ policy: OriginalPeekTimerPolicy,
        to state: OriginalPeekTimerState,
        now: Double,
        dwell: Double = 5
    ) -> Self {
        precondition(dwell.isFinite && dwell >= 0)

        switch policy {
        case .unchanged:
            return Self(state: state, operations: [])
        case .cancel:
            return Self(
                state: OriginalPeekTimerState(
                    generation: state.generation &+ 1,
                    hasTimer: false,
                    autoExpandedAt: nil
                ),
                operations: state.hasTimer ? [.invalidateExisting] : []
            )
        case .transient:
            let generation = state.generation &+ 1
            var operations: [OriginalPeekTimerOperation] = state.hasTimer
                ? [.invalidateExisting]
                : []
            operations.append(
                .scheduleOneShot(delay: dwell, generation: generation)
            )
            return Self(
                state: OriginalPeekTimerState(
                    generation: generation,
                    hasTimer: true,
                    autoExpandedAt: now
                ),
                operations: operations
            )
        }
    }
}
