import Foundation

public enum DiagnosticLogger {
    public static let defaultState = DiagnosticLoggerState(
        logFileURL: nil,
        currentFileSize: 0,
        dateFormatIdentifier: "iso8601"
    )
}

public struct DiagnosticLoggerState: Codable, Equatable, Sendable {
    public let logFileURL: String?
    public let currentFileSize: Int64
    public let dateFormatIdentifier: String

    public init(
        logFileURL: String? = nil,
        currentFileSize: Int64 = 0,
        dateFormatIdentifier: String = "iso8601"
    ) {
        self.logFileURL = logFileURL
        self.currentFileSize = currentFileSize
        self.dateFormatIdentifier = dateFormatIdentifier
    }
}

public enum DiagnosticLogCategory: String, Codable, Equatable, Sendable {
    case runtime
    case hooks
    case environment
    case diagnostics
    case usage
}

public enum DiagnosticLogSeverity: String, Codable, Equatable, Sendable {
    case debug
    case info
    case warning
    case error
}

public struct DiagnosticLogEntry: Codable, Equatable, Sendable {
    public let eventID: String
    public let category: DiagnosticLogCategory
    public let severity: DiagnosticLogSeverity
    public let source: String
    public let redactedMessage: String
    public let redactedMetadata: [String: String]
    public let createdAt: String

    public init(
        eventID: String,
        category: DiagnosticLogCategory,
        severity: DiagnosticLogSeverity,
        source: String,
        redactedMessage: String,
        redactedMetadata: [String: String] = [:],
        createdAt: String
    ) {
        self.eventID = eventID
        self.category = category
        self.severity = severity
        self.source = source
        self.redactedMessage = redactedMessage
        self.redactedMetadata = redactedMetadata
        self.createdAt = createdAt
    }
}
