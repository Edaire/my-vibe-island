import XCTest
@testable import MyVibeIslandCore

final class RedactionPolicyTests: XCTestCase {
    func testRedactionPolicyMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RedactionPolicyMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/redaction-policy-matrix")
        )
        let defaultRedactor = DiagnosticRedactor(policy: .default)
        let strictRedactor = DiagnosticRedactor(
            policy: RedactionPolicy(secretMode: .redactAllValues)
        )
        let customRedactor = DiagnosticRedactor(
            policy: RedactionPolicy(sensitiveFieldNames: ["workspaceToken"])
        )

        let actual = RedactionPolicyMatrixFixture(rows: [
            RedactionPolicyMatrixRow(
                id: "default-field-policy",
                policy: .default,
                fields: [
                    "cwd": "/Users/admin/project",
                    "apiKey": "fixture-api-key",
                    "sessionId": "session-1"
                ],
                redactor: defaultRedactor
            ),
            RedactionPolicyMatrixRow(
                id: "assignment-text-redaction",
                policy: .default,
                text: "credential=abc token:xyz secret=qwe cwd=/Users/admin/project",
                redactor: defaultRedactor
            ),
            RedactionPolicyMatrixRow(
                id: "strict-redacts-all-fields",
                policy: RedactionPolicy(secretMode: .redactAllValues),
                fields: [
                    "cwd": "/Users/admin/project",
                    "sessionId": "session-1"
                ],
                redactor: strictRedactor
            ),
            RedactionPolicyMatrixRow(
                id: "forbidden-field-overrides-safe-name",
                policy: .default,
                fields: [
                    "cwd": "/Users/admin/project",
                    "workspace": "/Users/admin/workspace"
                ],
                forbiddenFields: ["workspace"],
                redactor: defaultRedactor
            ),
            RedactionPolicyMatrixRow(
                id: "custom-sensitive-field",
                policy: RedactionPolicy(sensitiveFieldNames: ["workspaceToken"]),
                fields: [
                    "workspaceToken": "fixture-token",
                    "apiKey": "fixture-api-key"
                ],
                redactor: customRedactor
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    func testDefaultPolicyClassifiesSensitiveFields() {
        let policy = RedactionPolicy.default

        XCTAssertTrue(policy.shouldRedactField(named: "credential"))
        XCTAssertTrue(policy.shouldRedactField(named: "SESSION_TOKEN"))
        XCTAssertTrue(policy.shouldRedactField(named: "apiKey"))
        XCTAssertFalse(policy.shouldRedactField(named: "cwd"))
    }

    func testDiagnosticRedactorUsesPolicyForbiddenFields() {
        let redactor = DiagnosticRedactor(policy: RedactionPolicy.default)

        let fields = redactor.redactFields([
            "cwd": "/Users/admin/project",
            "apiKey": "fixture-value",
            "sessionId": "session-1"
        ])

        XCTAssertEqual(fields["cwd"], "/Users/<user>/project")
        XCTAssertEqual(fields["apiKey"], "<redacted>")
        XCTAssertEqual(fields["sessionId"], "session-1")
    }
}

private struct RedactionPolicyMatrixFixture: Codable, Equatable {
    let rows: [RedactionPolicyMatrixRow]
}

private struct RedactionPolicyMatrixRow: Codable, Equatable {
    let id: String
    let pathMode: RedactionPolicy.PathMode
    let secretMode: RedactionPolicy.SecretMode
    let sensitiveFieldNames: [String]
    let redactedText: String?
    let redactedFields: [String: String]?

    init(
        id: String,
        policy: RedactionPolicy,
        text: String? = nil,
        fields: [String: String]? = nil,
        forbiddenFields: [String] = [],
        redactor: DiagnosticRedactor
    ) {
        self.id = id
        pathMode = policy.pathMode
        secretMode = policy.secretMode
        sensitiveFieldNames = policy.sensitiveFieldNames
        redactedText = text.map(redactor.redactText)
        redactedFields = fields.map {
            redactor.redactFields($0, forbiddenFields: forbiddenFields)
        }
    }
}
