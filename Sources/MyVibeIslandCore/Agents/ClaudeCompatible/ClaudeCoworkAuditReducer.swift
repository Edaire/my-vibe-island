import Foundation

public struct ClaudeCoworkAuditResult: Equatable, Sendable {
    public var lastTurnType: String?
    public var isError: Bool
    public var lastUserMessage: String?
    public var lastAssistantMessage: String?
    public var latestTimestamp: Date?
    public var hasAnyTurn: Bool
    public var pendingQuestionInput: BridgeJSONValue?

    public init(
        lastTurnType: String? = nil,
        isError: Bool = false,
        lastUserMessage: String? = nil,
        lastAssistantMessage: String? = nil,
        latestTimestamp: Date? = nil,
        hasAnyTurn: Bool = false,
        pendingQuestionInput: BridgeJSONValue? = nil
    ) {
        self.lastTurnType = lastTurnType
        self.isError = isError
        self.lastUserMessage = lastUserMessage
        self.lastAssistantMessage = lastAssistantMessage
        self.latestTimestamp = latestTimestamp
        self.hasAnyTurn = hasAnyTurn
        self.pendingQuestionInput = pendingQuestionInput
    }
}

public enum ClaudeCoworkAuditReducer {
    public static func apply(
        row: ClaudeCoworkAuditRow,
        to result: inout ClaudeCoworkAuditResult
    ) {
        if let timestamp = parseTimestamp(row.auditTimestamp),
           result.latestTimestamp.map({ timestamp > $0 }) ?? true {
            result.latestTimestamp = timestamp
        }

        switch row.type {
        case "user":
            result.lastUserMessage = nonEmpty(row.message?.content.text)
            result.pendingQuestionInput = nil
            result.lastTurnType = "user"
            result.hasAnyTurn = true
        case "assistant":
            result.lastAssistantMessage = nonEmpty(row.message?.content.text)
            result.pendingQuestionInput = row.message?.content.askQuestionInput
            result.lastTurnType = "assistant"
            result.hasAnyTurn = true
        case "result":
            result.lastAssistantMessage = nonEmpty(row.result)
            result.isError = row.isError ?? false
            result.pendingQuestionInput = nil
            result.lastTurnType = "result"
            result.hasAnyTurn = true
        default:
            break
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func parseTimestamp(_ value: String?) -> Date? {
        guard let value = nonEmpty(value) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: value)
        }()
    }
}
