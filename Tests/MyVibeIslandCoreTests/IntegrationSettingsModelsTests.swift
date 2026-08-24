import XCTest
@testable import MyVibeIslandCore

final class IntegrationSettingsModelsTests: XCTestCase {
    func testIntegrationSettingsMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            IntegrationSettingsMatrixFixture.self,
            from: try FixtureLoader.data("settings/integration-settings-matrix")
        )

        let coordinatorState = IntegrationCoordinatorState(rows: [
            IntegrationStatusRow(
                sourceId: "opencode",
                displayName: "OpenCode",
                supportLevel: .experimental,
                installState: .needsRepair,
                healthState: .warning,
                repairAction: "Repair hook block",
                diagnostics: ["hook block missing"]
            ),
            IntegrationStatusRow(
                sourceId: "codex",
                displayName: "Codex",
                supportLevel: .supported,
                installState: .installed,
                healthState: .healthy
            ),
            IntegrationStatusRow(
                sourceId: "future-agent",
                displayName: "Future Agent",
                supportLevel: .planned,
                installState: .unsupported,
                healthState: .unknown
            ),
        ], lastCheckedAt: "2026-07-08T12:00:00Z")
        let customPaths = [
            CustomConfigPath(id: "b", sourceId: "fork", rawPath: "/tmp/b", kind: .global, exists: false),
            CustomConfigPath(id: "a", sourceId: "fork", rawPath: "/tmp/a", kind: .global, exists: true),
            CustomConfigPath(
                id: "managed-copy",
                sourceId: "codex",
                rawPath: "/Users/admin/project/.codex/config.toml",
                displayPath: "~/project/.codex/config.toml",
                kind: .project,
                exists: true,
                duplicateStatus: .duplicateOf("managed-codex"),
                lastCheckedAt: "2026-07-08T11:00:00Z"
            ),
        ]
        let repairResults = [
            repairRow(
                id: "successful-repair-requires-restart",
                result: IntegrationRepairResult(
                    integrationId: "codex",
                    operation: .repair,
                    outcome: .succeeded,
                    message: "Updated hook block",
                    configPath: "~/project/.codex/config.toml",
                    changedPaths: ["~/project/.codex/config.toml", "~/project/.codex/config.toml"],
                    hookStatusBefore: .needsRepair,
                    hookStatusAfter: .installed,
                    requiresTerminalRestart: true,
                    diagnosticNotes: ["restart terminal"]
                )
            ),
            repairRow(
                id: "failed-install-sorts-changed-paths",
                result: IntegrationRepairResult(
                    integrationId: "opencode",
                    operation: .install,
                    outcome: .failed,
                    message: "Config block mismatch",
                    changedPaths: ["/tmp/b", "/tmp/a"],
                    hookStatusBefore: .notInstalled,
                    hookStatusAfter: .needsRepair,
                    diagnosticNotes: ["manual review"]
                )
            ),
        ]

        let snapshot = IntegrationSettingsModel().snapshot(
            from: coordinatorState,
            customPaths: customPaths
        )
        let actual = IntegrationSettingsMatrixFixture(
            rows: snapshot.rows.map(Self.rowFixture),
            customPaths: snapshot.customPaths.map(Self.customPathFixture),
            repairResults: repairResults,
            lastCheckedAt: snapshot.lastCheckedAt
        )

        XCTAssertEqual(actual, expected)
    }

    func testIntegrationSettingsRowRoundTripsFullSettingsState() throws {
        let repair = IntegrationRepairResult(
            integrationId: "codex",
            operation: .repair,
            outcome: .succeeded,
            message: "Updated hook block",
            configPath: "~/project/.codex/config.toml",
            changedPaths: ["~/project/.codex/config.toml"],
            hookStatusBefore: .needsRepair,
            hookStatusAfter: .installed,
            requiresTerminalRestart: true,
            diagnosticNotes: ["restart terminal"]
        )
        let row = IntegrationSettingsRow(
            sourceId: "codex",
            displayName: "Codex",
            supportLevel: .supported,
            detectedVersion: "1.2.3",
            configPath: "~/project/.codex/config.toml",
            hookStatus: .installed,
            watcherStatus: .healthy,
            localTrustStatus: .trusted,
            terminalExtensionStatus: .requiresRestart,
            repairResult: repair,
            lastCheckedAt: "2026-07-08T10:00:00Z"
        )

        let decoded = try JSONDecoder().decode(IntegrationSettingsRow.self, from: try JSONEncoder().encode(row))

        XCTAssertEqual(decoded, row)
        XCTAssertTrue(decoded.canRepair)
        XCTAssertEqual(decoded.statusSummary, .needsRestart)
    }

    func testIntegrationRepairResultSummarizesFailureAndChangedPaths() {
        let result = IntegrationRepairResult(
            integrationId: "cursor",
            operation: .install,
            outcome: .failed,
            message: "Config block mismatch",
            changedPaths: ["/tmp/b", "/tmp/a"],
            hookStatusBefore: .notInstalled,
            hookStatusAfter: .needsRepair,
            requiresTerminalRestart: false,
            diagnosticNotes: ["manual review"]
        )

        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.changedPaths, ["/tmp/a", "/tmp/b"])
        XCTAssertEqual(result.statusSummary, .failed)
    }

    func testCustomConfigPathNormalizesDisplayAndDuplicateState() {
        let path = CustomConfigPath(
            id: "custom-1",
            sourceId: "codex-fork",
            rawPath: "/Users/admin/project/.codex/config.toml",
            displayPath: nil,
            kind: .project,
            exists: true,
            duplicateStatus: .duplicateOf("managed-codex"),
            lastCheckedAt: "2026-07-08T11:00:00Z"
        )

        XCTAssertEqual(path.displayPath, "~/project/.codex/config.toml")
        XCTAssertFalse(path.canSave)
        XCTAssertEqual(path.duplicateStatus, .duplicateOf("managed-codex"))
    }

    func testIntegrationSettingsModelBuildsRowsAndCustomPathsInStableOrder() {
        let state = IntegrationCoordinatorState(rows: [
            IntegrationStatusRow(
                sourceId: "opencode",
                displayName: "OpenCode",
                supportLevel: .experimental,
                installState: .needsRepair,
                healthState: .warning,
                repairAction: "Repair hook block"
            ),
            IntegrationStatusRow(
                sourceId: "codex",
                displayName: "Codex",
                supportLevel: .supported,
                installState: .installed,
                healthState: .healthy
            )
        ], lastCheckedAt: "2026-07-08T12:00:00Z")
        let customPaths = [
            CustomConfigPath(id: "b", sourceId: "fork", rawPath: "/tmp/b", kind: .global, exists: false),
            CustomConfigPath(id: "a", sourceId: "fork", rawPath: "/tmp/a", kind: .global, exists: true)
        ]

        let snapshot = IntegrationSettingsModel().snapshot(
            from: state,
            customPaths: customPaths
        )

        XCTAssertEqual(snapshot.rows.map(\.sourceId), ["codex", "opencode"])
        XCTAssertEqual(snapshot.rows.first?.hookStatus, .installed)
        XCTAssertEqual(snapshot.rows.last?.hookStatus, .needsRepair)
        XCTAssertEqual(snapshot.rows.last?.statusSummary, .needsRepair)
        XCTAssertEqual(snapshot.customPaths.map(\.id), ["a", "b"])
    }

    private static func rowFixture(_ row: IntegrationSettingsRow) -> IntegrationSettingsRowFixture {
        IntegrationSettingsRowFixture(
            sourceId: row.sourceId,
            displayName: row.displayName,
            supportLevel: row.supportLevel.rawValue,
            hookStatus: row.hookStatus.rawValue,
            watcherStatus: row.watcherStatus.rawValue,
            localTrustStatus: row.localTrustStatus.rawValue,
            terminalExtensionStatus: row.terminalExtensionStatus.rawValue,
            statusSummary: row.statusSummary.rawValue,
            canRepair: row.canRepair,
            lastCheckedAt: row.lastCheckedAt
        )
    }

    private static func customPathFixture(_ path: CustomConfigPath) -> CustomConfigPathFixture {
        CustomConfigPathFixture(
            id: path.id,
            sourceId: path.sourceId,
            displayPath: path.displayPath,
            kind: path.kind.rawValue,
            exists: path.exists,
            duplicateStatus: path.duplicateStatus.fixtureValue,
            canSave: path.canSave,
            lastCheckedAt: path.lastCheckedAt
        )
    }

    private func repairRow(
        id: String,
        result: IntegrationRepairResult
    ) -> IntegrationRepairResultFixture {
        IntegrationRepairResultFixture(
            id: id,
            integrationId: result.integrationId,
            operation: result.operation.rawValue,
            outcome: result.outcome.rawValue,
            message: result.message,
            configPath: result.configPath,
            changedPaths: result.changedPaths,
            statusSummary: result.statusSummary.rawValue,
            isSuccessful: result.isSuccessful,
            requiresTerminalRestart: result.requiresTerminalRestart,
            diagnosticNotes: result.diagnosticNotes
        )
    }

    private struct IntegrationSettingsMatrixFixture: Codable, Equatable {
        let rows: [IntegrationSettingsRowFixture]
        let customPaths: [CustomConfigPathFixture]
        let repairResults: [IntegrationRepairResultFixture]
        let lastCheckedAt: String?
    }

    private struct IntegrationSettingsRowFixture: Codable, Equatable {
        let sourceId: String
        let displayName: String
        let supportLevel: String
        let hookStatus: String
        let watcherStatus: String
        let localTrustStatus: String
        let terminalExtensionStatus: String
        let statusSummary: String
        let canRepair: Bool
        let lastCheckedAt: String?
    }

    private struct CustomConfigPathFixture: Codable, Equatable {
        let id: String
        let sourceId: String
        let displayPath: String
        let kind: String
        let exists: Bool
        let duplicateStatus: String
        let canSave: Bool
        let lastCheckedAt: String?
    }

    private struct IntegrationRepairResultFixture: Codable, Equatable {
        let id: String
        let integrationId: String
        let operation: String
        let outcome: String
        let message: String
        let configPath: String?
        let changedPaths: [String]
        let statusSummary: String
        let isSuccessful: Bool
        let requiresTerminalRestart: Bool
        let diagnosticNotes: [String]
    }
}

private extension CustomConfigPathDuplicateStatus {
    var fixtureValue: String {
        switch self {
        case .unique:
            return "unique"
        case let .duplicateOf(id):
            return "duplicateOf:\(id)"
        }
    }
}
