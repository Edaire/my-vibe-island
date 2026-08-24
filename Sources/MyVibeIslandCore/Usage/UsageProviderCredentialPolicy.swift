import Foundation

public enum UsageCredentialTokenExportPolicy: String, Codable, Equatable, Sendable {
    case never
    case redactedOnly
}

public enum UsageCredentialDiagnosticsRedactionPolicy: String, Codable, Equatable, Sendable {
    case providerAndPresenceOnly
    case redactedPathAndPresence
}

public struct UsageProviderCredentialPolicy: Codable, Equatable, Sendable {
    public let providerId: UsageProviderIdentifier
    public let allowedConfigPathHints: [String]
    public let allowedEnvironmentKeyHints: [String]
    public let tokenExportPolicy: UsageCredentialTokenExportPolicy
    public let diagnosticsRedactionPolicy: UsageCredentialDiagnosticsRedactionPolicy

    public init(
        providerId: UsageProviderIdentifier,
        allowedConfigPathHints: [String] = [],
        allowedEnvironmentKeyHints: [String] = [],
        tokenExportPolicy: UsageCredentialTokenExportPolicy,
        diagnosticsRedactionPolicy: UsageCredentialDiagnosticsRedactionPolicy
    ) {
        self.providerId = providerId
        self.allowedConfigPathHints = allowedConfigPathHints
        self.allowedEnvironmentKeyHints = allowedEnvironmentKeyHints
        self.tokenExportPolicy = tokenExportPolicy
        self.diagnosticsRedactionPolicy = diagnosticsRedactionPolicy
    }
}

public enum UsageProviderCredentialPolicyCatalog {
    public static let defaultPolicies: [UsageProviderCredentialPolicy] = [
        UsageProviderCredentialPolicy(
            providerId: .codexRateLimits,
            tokenExportPolicy: .never,
            diagnosticsRedactionPolicy: .providerAndPresenceOnly
        ),
        UsageProviderCredentialPolicy(
            providerId: .kimiUsage,
            allowedConfigPathHints: ["~/.kimi/config.json"],
            allowedEnvironmentKeyHints: ["KIMI_USAGE_TOKEN"],
            tokenExportPolicy: .never,
            diagnosticsRedactionPolicy: .redactedPathAndPresence
        ),
        UsageProviderCredentialPolicy(
            providerId: .zaiQuota,
            allowedConfigPathHints: ["~/.zai/config.json"],
            allowedEnvironmentKeyHints: ["ZAI_USAGE_TOKEN"],
            tokenExportPolicy: .never,
            diagnosticsRedactionPolicy: .redactedPathAndPresence
        ),
        UsageProviderCredentialPolicy(
            providerId: .claudeStatusLine,
            tokenExportPolicy: .never,
            diagnosticsRedactionPolicy: .providerAndPresenceOnly
        ),
        UsageProviderCredentialPolicy(
            providerId: .localParsedUsage,
            tokenExportPolicy: .never,
            diagnosticsRedactionPolicy: .providerAndPresenceOnly
        )
    ]

    public static func policy(for providerId: UsageProviderIdentifier) -> UsageProviderCredentialPolicy? {
        defaultPolicies.first { $0.providerId == providerId }
    }
}
