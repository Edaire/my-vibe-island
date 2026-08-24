import XCTest
@testable import MyVibeIslandCore

final class HookHealthCheckModelsTests: XCTestCase {
    func testHookHealthCheckMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            HookHealthCheckMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/hook-health-check-matrix")
        )

        let checks = [
            HookHealthCheck(
                sourceID: "codex",
                status: .trusted,
                observedAt: "2026-07-08T12:00:00Z",
                provenance: ProvenanceAssessment(status: .trustedManaged),
                redactedConfigPath: "/Users/<user>/.codex/config.toml"
            ),
            HookHealthCheck(
                sourceID: "claude-code",
                status: .mismatched,
                observedAt: "2026-07-08T12:01:00Z",
                provenance: ProvenanceAssessment(
                    status: .pathMismatch,
                    reason: "command path differs from expected helper"
                ),
                redactedConfigPath: "/Users/<user>/.claude/settings.json"
            ),
            HookHealthCheck(
                sourceID: "opencode",
                status: .blocked,
                observedAt: "2026-07-08T12:02:00Z",
                provenance: ProvenanceAssessment(
                    status: .missingMarker,
                    reason: "managed marker missing"
                ),
                redactedConfigPath: "/Users/<user>/.config/opencode/config.json"
            ),
            HookHealthCheck(sourceID: "gemini", status: .unknown),
            HookHealthCheck(sourceID: "cursor", status: .unmanaged)
        ]
        let repairHints = checks.map { check in
            HookHealthRepairHintProjection(
                sourceID: check.sourceID,
                status: check.status,
                repairHint: check.repairHint
            )
        }

        XCTAssertEqual(checks, expected.checks)
        XCTAssertEqual(repairHints, expected.repairHints)
    }

    func testHookHealthCheckRoundTripsStatusAndRedactedEvidence() throws {
        let check = HookHealthCheck(
            sourceID: "codex",
            status: .mismatched,
            observedAt: "2026-07-08T12:00:00Z",
            provenance: ProvenanceAssessment(
                status: .pathMismatch,
                reason: "command path differs from expected helper"
            ),
            redactedConfigPath: "/Users/<user>/.codex/config.toml"
        )

        let data = try JSONEncoder().encode(check)
        let decoded = try JSONDecoder().decode(HookHealthCheck.self, from: data)

        XCTAssertEqual(decoded, check)
        XCTAssertEqual(decoded.status, .mismatched)
        XCTAssertEqual(decoded.redactedConfigPath, "/Users/<user>/.codex/config.toml")
    }

    func testHookHealthCheckDerivesRepairHintForMismatchedAndBlockedStatuses() {
        let mismatched = HookHealthCheck(sourceID: "claude-code", status: .mismatched)
        let blocked = HookHealthCheck(sourceID: "codex", status: .blocked)
        let trusted = HookHealthCheck(sourceID: "gemini", status: .trusted)

        XCTAssertEqual(mismatched.repairHint?.source, "claude-code")
        XCTAssertEqual(mismatched.repairHint?.repairability, .appCanRepairManagedBlock)
        XCTAssertEqual(mismatched.repairHint?.severity, .repairable)

        XCTAssertEqual(blocked.repairHint?.repairability, .userActionRequired)
        XCTAssertEqual(blocked.repairHint?.severity, .blocking)

        XCTAssertNil(trusted.repairHint)
    }

    private struct HookHealthCheckMatrixFixture: Codable, Equatable {
        let checks: [HookHealthCheck]
        let repairHints: [HookHealthRepairHintProjection]
    }

    private struct HookHealthRepairHintProjection: Codable, Equatable {
        let sourceID: String
        let status: HookHealthStatus
        let repairHint: DiagnosticRepairHint?
    }
}
