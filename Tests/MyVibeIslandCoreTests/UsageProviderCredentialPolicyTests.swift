import XCTest
@testable import MyVibeIslandCore

final class UsageProviderCredentialPolicyTests: XCTestCase {
    func testDefaultCredentialPolicyCatalogMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsageProviderCredentialPolicyCatalogFixture.self,
            from: try FixtureLoader.data("usage/provider-credential-policies")
        )
        let policies = UsageProviderCredentialPolicyCatalog.defaultPolicies

        let actual = UsageProviderCredentialPolicyCatalogFixture(
            policies: policies,
            providerIds: policies.map(\.providerId),
            policySummaries: policies.map {
                UsageProviderCredentialPolicySummary(
                    providerId: $0.providerId,
                    tokenExportPolicy: $0.tokenExportPolicy,
                    diagnosticsRedactionPolicy: $0.diagnosticsRedactionPolicy,
                    declaresCredentialHints: !$0.allowedConfigPathHints.isEmpty || !$0.allowedEnvironmentKeyHints.isEmpty
                )
            },
            excludedProviderIds: [.kimiBillingUsage].filter {
                UsageProviderCredentialPolicyCatalog.policy(for: $0) == nil
            }
        )

        XCTAssertEqual(actual, expected)
    }

    func testCredentialPolicyRoundTripsThroughJSON() throws {
        let policy = UsageProviderCredentialPolicy(
            providerId: .kimiUsage,
            allowedConfigPathHints: ["~/.kimi/config.json"],
            allowedEnvironmentKeyHints: ["KIMI_USAGE_TOKEN"],
            tokenExportPolicy: .never,
            diagnosticsRedactionPolicy: .redactedPathAndPresence
        )

        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(UsageProviderCredentialPolicy.self, from: data)

        XCTAssertEqual(decoded, policy)
    }

    func testKimiDefaultPolicyAllowsUserOwnedHintsButNeverExportsTokens() throws {
        let policy = try XCTUnwrap(UsageProviderCredentialPolicyCatalog.policy(for: .kimiUsage))

        XCTAssertEqual(policy.providerId, .kimiUsage)
        XCTAssertEqual(policy.allowedConfigPathHints, ["~/.kimi/config.json"])
        XCTAssertEqual(policy.allowedEnvironmentKeyHints, ["KIMI_USAGE_TOKEN"])
        XCTAssertEqual(policy.tokenExportPolicy, .never)
        XCTAssertEqual(policy.diagnosticsRedactionPolicy, .redactedPathAndPresence)
    }

    func testLocalDefaultPoliciesDoNotDeclareCredentialSources() throws {
        let claude = try XCTUnwrap(UsageProviderCredentialPolicyCatalog.policy(for: .claudeStatusLine))
        let local = try XCTUnwrap(UsageProviderCredentialPolicyCatalog.policy(for: .localParsedUsage))

        XCTAssertEqual(claude.allowedConfigPathHints, [])
        XCTAssertEqual(claude.allowedEnvironmentKeyHints, [])
        XCTAssertEqual(claude.tokenExportPolicy, .never)
        XCTAssertEqual(claude.diagnosticsRedactionPolicy, .providerAndPresenceOnly)
        XCTAssertEqual(local.allowedConfigPathHints, [])
        XCTAssertEqual(local.allowedEnvironmentKeyHints, [])
    }

    func testCredentialPolicyCatalogExcludesNonDefaultBillingProvider() {
        XCTAssertNil(UsageProviderCredentialPolicyCatalog.policy(for: .kimiBillingUsage))
    }

    private struct UsageProviderCredentialPolicyCatalogFixture: Codable, Equatable {
        let policies: [UsageProviderCredentialPolicy]
        let providerIds: [UsageProviderIdentifier]
        let policySummaries: [UsageProviderCredentialPolicySummary]
        let excludedProviderIds: [UsageProviderIdentifier]
    }

    private struct UsageProviderCredentialPolicySummary: Codable, Equatable {
        let providerId: UsageProviderIdentifier
        let tokenExportPolicy: UsageCredentialTokenExportPolicy
        let diagnosticsRedactionPolicy: UsageCredentialDiagnosticsRedactionPolicy
        let declaresCredentialHints: Bool
    }
}
