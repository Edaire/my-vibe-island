import Foundation

public struct CrashReportMetadata: Codable, Equatable, Sendable {
    public let reportIDHash: String
    public let processName: String
    public let occurredAt: String
    public let appVersion: String?
    public let redactedExceptionType: String?

    public init(
        reportIDHash: String,
        processName: String,
        occurredAt: String,
        appVersion: String? = nil,
        redactedExceptionType: String? = nil
    ) {
        self.reportIDHash = reportIDHash
        self.processName = processName
        self.occurredAt = occurredAt
        self.appVersion = appVersion
        self.redactedExceptionType = redactedExceptionType
    }
}

public struct CrashReportInclusionPolicy: Codable, Equatable, Sendable {
    public let explicitlyIncluded: Bool

    public init(explicitlyIncluded: Bool) {
        self.explicitlyIncluded = explicitlyIncluded
    }
}

public struct CrashReportInclusionPlan: Codable, Equatable, Sendable {
    public let isIncluded: Bool
    public let reports: [CrashReportMetadata]
    public let excludedReportCount: Int

    public init(
        isIncluded: Bool,
        reports: [CrashReportMetadata],
        excludedReportCount: Int
    ) {
        self.isIncluded = isIncluded
        self.reports = reports
        self.excludedReportCount = excludedReportCount
    }
}

public struct CrashReportCollector: Sendable {
    public let appProcessName: String

    public init(appProcessName: String) {
        self.appProcessName = appProcessName
    }

    public func inclusionPlan(
        reports: [CrashReportMetadata],
        policy: CrashReportInclusionPolicy
    ) -> CrashReportInclusionPlan {
        guard policy.explicitlyIncluded else {
            return CrashReportInclusionPlan(
                isIncluded: false,
                reports: [],
                excludedReportCount: reports.count
            )
        }

        let included = reports.filter { $0.processName == appProcessName }
        return CrashReportInclusionPlan(
            isIncluded: true,
            reports: included,
            excludedReportCount: reports.count - included.count
        )
    }
}
