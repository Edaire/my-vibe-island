import Foundation

public enum SessionSummaryCompletionOutcome: String, Codable, Equatable, Sendable {
    case unknown
    case succeeded
    case failed
    case cancelled
}

public enum SessionSummaryStatus: String, Codable, Equatable, Sendable {
    case unknown
    case active
    case waiting
    case completed
    case failed
    case idle
}

public enum SessionSummaryDurationBucket: String, Codable, Equatable, Sendable {
    case instant
    case seconds
    case minutes
    case hours
}

public enum SessionSummaryEventCountBucket: String, Codable, Equatable, Sendable {
    case none
    case low
    case medium
    case high
}

public struct SessionSummaryTelemetry: Codable, Equatable, Sendable {
    public let sessionId: String
    public let agentSource: String
    public let modelFamily: String?
    public let permissionMode: String?
    public let everBypassed: Bool
    public let codexReviewer: String?
    public let surface: String?
    public let codexOrigin: String?
    public let claudeOrigin: String?
    public let multiplexer: String?
    public let isSSHRemote: Bool
    public let isIDEExtension: Bool
    public let isTeamMember: Bool
    public let wasRestored: Bool
    public let durationSeconds: Int
    public let turnCount: Int
    public let toolUseCount: Int
    public let taskCount: Int
    public let approvalCount: Int
    public let subagentCount: Int
    public let status: SessionSummaryStatus
    public let completionOutcome: SessionSummaryCompletionOutcome
    public let redactionLevel: RedactionLevel

    public var source: String {
        agentSource
    }

    public var durationBucket: SessionSummaryDurationBucket {
        switch durationSeconds {
        case 0:
            return .instant
        case 1..<60:
            return .seconds
        case 60..<3_600:
            return .minutes
        default:
            return .hours
        }
    }

    public var eventCountBucket: SessionSummaryEventCountBucket {
        let count = turnCount + toolUseCount + taskCount + approvalCount + subagentCount
        switch count {
        case 0:
            return .none
        case 1..<10:
            return .low
        case 10..<100:
            return .medium
        default:
            return .high
        }
    }

    public init(
        sessionId: String,
        agentSource: String,
        modelFamily: String? = nil,
        permissionMode: String? = nil,
        everBypassed: Bool = false,
        codexReviewer: String? = nil,
        surface: String? = nil,
        codexOrigin: String? = nil,
        claudeOrigin: String? = nil,
        multiplexer: String? = nil,
        isSSHRemote: Bool = false,
        isIDEExtension: Bool = false,
        isTeamMember: Bool = false,
        wasRestored: Bool = false,
        durationSeconds: Int = 0,
        turnCount: Int = 0,
        toolUseCount: Int = 0,
        taskCount: Int = 0,
        approvalCount: Int = 0,
        subagentCount: Int = 0,
        status: SessionSummaryStatus = .unknown,
        completionOutcome: SessionSummaryCompletionOutcome = .unknown,
        redactionLevel: RedactionLevel = .metadataOnly
    ) {
        self.sessionId = sessionId
        self.agentSource = agentSource
        self.modelFamily = modelFamily
        self.permissionMode = permissionMode
        self.everBypassed = everBypassed
        self.codexReviewer = codexReviewer
        self.surface = surface
        self.codexOrigin = codexOrigin
        self.claudeOrigin = claudeOrigin
        self.multiplexer = multiplexer
        self.isSSHRemote = isSSHRemote
        self.isIDEExtension = isIDEExtension
        self.isTeamMember = isTeamMember
        self.wasRestored = wasRestored
        self.durationSeconds = max(durationSeconds, 0)
        self.turnCount = max(turnCount, 0)
        self.toolUseCount = max(toolUseCount, 0)
        self.taskCount = max(taskCount, 0)
        self.approvalCount = max(approvalCount, 0)
        self.subagentCount = max(subagentCount, 0)
        self.status = status
        self.completionOutcome = completionOutcome
        self.redactionLevel = redactionLevel
    }
}
