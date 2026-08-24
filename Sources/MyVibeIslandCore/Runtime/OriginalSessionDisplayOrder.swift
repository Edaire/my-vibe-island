import Foundation

public enum OriginalSessionDisplayOrder {
    public static func sort(_ sessions: [AgentSession]) -> [AgentSession] {
        sessions.sorted(by: precedes)
    }

    public static func precedes(_ lhs: AgentSession, _ rhs: AgentSession) -> Bool {
        let lhsRank = rank(for: lhs.originalStatus)
        let rhsRank = rank(for: rhs.originalStatus)
        if lhsRank != rhsRank {
            return lhsRank > rhsRank
        }
        return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
    }

    public static func rank(for status: OriginalPixelStatusCompact) -> Int {
        switch status {
        case .waitingForInput:
            60
        case .processing, .runningTool, .compacting:
            80
        case .thinking:
            85
        case .waitingForApproval:
            100
        case .question:
            95
        case .ended:
            0
        case .unknown:
            10
        }
    }
}
