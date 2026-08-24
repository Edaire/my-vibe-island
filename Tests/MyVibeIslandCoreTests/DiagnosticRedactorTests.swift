import XCTest
@testable import MyVibeIslandCore

final class DiagnosticRedactorTests: XCTestCase {
    func testDiagnosticRedactorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DiagnosticRedactorMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/redactor-matrix")
        )
        let redactor = DiagnosticRedactor()

        let textCases = [
            DiagnosticRedactorTextCase(
                name: "home-paths",
                input: "opened /Users/admin/project/file.swift from /Users/admin",
                output: redactor.redactText("opened /Users/admin/project/file.swift from /Users/admin")
            ),
            DiagnosticRedactorTextCase(
                name: "assignment-values",
                input: "provider credential=abc123 and session_token: xyz987",
                output: redactor.redactText("provider credential=abc123 and session_token: xyz987")
            ),
            DiagnosticRedactorTextCase(
                name: "comma-delimited-values",
                input: "token=first, secret:second; cwd=/Users/admin/project",
                output: redactor.redactText("token=first, secret:second; cwd=/Users/admin/project")
            )
        ]
        let fieldCases = [
            DiagnosticRedactorFieldCase(
                name: "policy-and-forbidden-fields",
                forbiddenFields: ["credential"],
                input: [
                    "cwd": "/Users/admin/project",
                    "credential": "abc123",
                    "apiKey": "fixture-value",
                    "count": "2"
                ],
                output: redactor.redactFields(
                    [
                        "cwd": "/Users/admin/project",
                        "credential": "abc123",
                        "apiKey": "fixture-value",
                        "count": "2"
                    ],
                    forbiddenFields: ["credential"]
                )
            ),
            DiagnosticRedactorFieldCase(
                name: "case-insensitive-forbidden-fields",
                forbiddenFields: ["SESSION_TOKEN"],
                input: [
                    "session_token": "xyz987",
                    "path": "/Users/admin/.config/my-vibe-island"
                ],
                output: redactor.redactFields(
                    [
                        "session_token": "xyz987",
                        "path": "/Users/admin/.config/my-vibe-island"
                    ],
                    forbiddenFields: ["SESSION_TOKEN"]
                )
            )
        ]

        XCTAssertEqual(textCases, expected.textCases)
        XCTAssertEqual(fieldCases, expected.fieldCases)
    }

    func testRedactsUserHomePathsInDiagnosticText() {
        let redactor = DiagnosticRedactor()

        let redacted = redactor.redactText("opened /Users/admin/project/file.swift from /Users/admin")

        XCTAssertEqual(redacted, "opened /Users/<user>/project/file.swift from /Users/<user>")
    }

    func testRedactsCredentialLikeAssignmentsInDiagnosticText() {
        let redactor = DiagnosticRedactor()

        let redacted = redactor.redactText("provider credential=abc123 and session_token: xyz987")

        XCTAssertEqual(redacted, "provider credential=<redacted> and session_token: <redacted>")
    }

    func testRedactsForbiddenFieldValuesAndAllowedPathValues() {
        let redactor = DiagnosticRedactor()

        let fields = redactor.redactFields(
            [
                "cwd": "/Users/admin/project",
                "credential": "abc123",
                "count": "2"
            ],
            forbiddenFields: ["credential"]
        )

        XCTAssertEqual(fields["cwd"], "/Users/<user>/project")
        XCTAssertEqual(fields["credential"], "<redacted>")
        XCTAssertEqual(fields["count"], "2")
    }

    private struct DiagnosticRedactorMatrixFixture: Codable, Equatable {
        let textCases: [DiagnosticRedactorTextCase]
        let fieldCases: [DiagnosticRedactorFieldCase]
    }

    private struct DiagnosticRedactorTextCase: Codable, Equatable {
        let name: String
        let input: String
        let output: String
    }

    private struct DiagnosticRedactorFieldCase: Codable, Equatable {
        let name: String
        let forbiddenFields: [String]
        let input: [String: String]
        let output: [String: String]
    }
}
