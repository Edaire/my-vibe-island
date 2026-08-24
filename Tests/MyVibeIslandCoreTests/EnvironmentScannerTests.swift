import XCTest
@testable import MyVibeIslandCore

final class EnvironmentScannerTests: XCTestCase {
    func testEnvironmentScannerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            EnvironmentScannerMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/environment-scanner-matrix")
        )

        let plan = EnvironmentScannerPlan(
            scannedAt: "2026-07-09T06:15:00Z",
            knownConfigPaths: [
                "~/.codex/config.toml",
                "~/.claude/settings.json",
                "~/.config/opencode/config.json"
            ],
            knownCLICommandNames: ["codex", "claude", "opencode"],
            appBundlePresent: true,
            hookBinaryPath: "/Applications/MyVibeIsland.app/Contents/MacOS/my-vibe-island-hooks",
            hookBinaryVersion: "1.4.1",
            terminalObservations: [
                EnvironmentTerminalObservation(name: "Terminal", isRunning: true, activeContextCount: 2),
                EnvironmentTerminalObservation(name: "Ghostty", isRunning: false, activeContextCount: 0),
            ],
            agentObservations: [
                EnvironmentAgentObservation(
                    id: "codex",
                    name: "Codex CLI",
                    isInstalled: true,
                    isConfigured: true,
                    cliVersionSummary: "codex 1.2.3",
                    confidence: .high
                ),
                EnvironmentAgentObservation(
                    id: "opencode",
                    name: "OpenCode",
                    isInstalled: true,
                    isConfigured: false,
                    confidence: .medium,
                    repairHint: "install managed plugin"
                ),
                EnvironmentAgentObservation(
                    id: "gemini",
                    name: "Gemini CLI",
                    isInstalled: false,
                    isConfigured: false,
                    confidence: .low,
                    repairHint: "install CLI"
                ),
            ],
            onboardingContext: "first-launch",
            exportSections: ["config-snapshot.txt", "environment-snapshot.txt"]
        )

        XCTAssertEqual(matrix(from: plan), expected)
    }

    func testEnvironmentScannerPlanRoundTripsKnownInputsAndEvidence() throws {
        let plan = EnvironmentScannerPlan(
            scannedAt: "2026-07-08T23:00:00Z",
            knownConfigPaths: ["~/.codex/config.toml", "~/.claude/settings.json"],
            knownCLICommandNames: ["codex", "claude"],
            appBundlePresent: true,
            hookBinaryPath: "/Applications/MyVibeIsland.app/Contents/MacOS/my-vibe-island-hooks",
            hookBinaryVersion: "1.4.1",
            terminalObservations: [
                EnvironmentTerminalObservation(name: "Terminal", isRunning: true, activeContextCount: 1)
            ],
            agentObservations: [
                EnvironmentAgentObservation(
                    id: "codex",
                    name: "Codex CLI",
                    isInstalled: true,
                    isConfigured: true,
                    cliVersionSummary: "codex 1.2.3",
                    confidence: .high,
                    repairHint: nil
                )
            ],
            onboardingContext: "first-launch",
            exportSections: ["config-snapshot.txt", "environment-snapshot.txt"]
        )

        let decoded = try JSONDecoder().decode(EnvironmentScannerPlan.self, from: try JSONEncoder().encode(plan))

        XCTAssertEqual(decoded, plan)
    }

    func testEnvironmentScannerPlanDerivesEnvironmentScanResultWithoutSessionTruth() {
        let plan = EnvironmentScannerPlan(
            scannedAt: "2026-07-08T23:00:00Z",
            terminalObservations: [
                EnvironmentTerminalObservation(name: "Ghostty", isRunning: false, activeContextCount: 0)
            ],
            agentObservations: [
                EnvironmentAgentObservation(
                    id: "opencode",
                    name: "OpenCode",
                    isInstalled: true,
                    isConfigured: false,
                    cliVersionSummary: nil,
                    confidence: .medium,
                    repairHint: "install managed plugin"
                )
            ]
        )

        let result = plan.scanResult()

        XCTAssertEqual(result.scannedAt, "2026-07-08T23:00:00Z")
        XCTAssertEqual(result.agents.first?.id, "opencode")
        XCTAssertEqual(result.agents.first?.isDetected, true)
        XCTAssertEqual(result.agents.first?.isConfigured, false)
        XCTAssertEqual(result.agents.first?.repairability, .repairable)
        XCTAssertEqual(result.terminals.first?.name, "Ghostty")
        XCTAssertEqual(result.terminals.first?.isDetected, false)
    }

    func testEnvironmentScannerEvidenceConfidenceValuesRoundTrip() throws {
        let values: [EnvironmentScannerEvidenceConfidence] = [
            .low,
            .medium,
            .high
        ]

        let decoded = try JSONDecoder().decode(
            [EnvironmentScannerEvidenceConfidence].self,
            from: try JSONEncoder().encode(values)
        )

        XCTAssertEqual(decoded, values)
    }

    private func matrix(from plan: EnvironmentScannerPlan) -> EnvironmentScannerMatrixFixture {
        let result = plan.scanResult()
        return EnvironmentScannerMatrixFixture(
            scannedAt: plan.scannedAt,
            knownConfigPathCount: plan.knownConfigPaths.count,
            knownCLICommandNames: plan.knownCLICommandNames,
            appBundlePresent: plan.appBundlePresent,
            hasHookBinaryPath: plan.hookBinaryPath != nil,
            hookBinaryVersion: plan.hookBinaryVersion,
            onboardingContext: plan.onboardingContext,
            exportSections: plan.exportSections,
            terminalRows: zip(plan.terminalObservations, result.terminals).map { observation, info in
                EnvironmentScannerTerminalRowFixture(
                    name: observation.name,
                    activeContextCount: observation.activeContextCount,
                    isRunning: observation.isRunning,
                    scanDetected: info.isDetected
                )
            },
            agentRows: zip(plan.agentObservations, result.agents).map { observation, info in
                EnvironmentScannerAgentRowFixture(
                    id: observation.id,
                    isInstalled: observation.isInstalled,
                    isConfigured: observation.isConfigured,
                    hasVersionSummary: observation.cliVersionSummary != nil,
                    confidence: observation.confidence.rawValue,
                    repairHintPresent: observation.repairHint != nil,
                    scanDetected: info.isDetected,
                    repairability: info.repairability.rawValue
                )
            }
        )
    }

    private struct EnvironmentScannerMatrixFixture: Codable, Equatable {
        let scannedAt: String?
        let knownConfigPathCount: Int
        let knownCLICommandNames: [String]
        let appBundlePresent: Bool
        let hasHookBinaryPath: Bool
        let hookBinaryVersion: String?
        let onboardingContext: String?
        let exportSections: [String]
        let terminalRows: [EnvironmentScannerTerminalRowFixture]
        let agentRows: [EnvironmentScannerAgentRowFixture]
    }

    private struct EnvironmentScannerTerminalRowFixture: Codable, Equatable {
        let name: String
        let activeContextCount: Int
        let isRunning: Bool
        let scanDetected: Bool
    }

    private struct EnvironmentScannerAgentRowFixture: Codable, Equatable {
        let id: String
        let isInstalled: Bool
        let isConfigured: Bool
        let hasVersionSummary: Bool
        let confidence: String
        let repairHintPresent: Bool
        let scanDetected: Bool
        let repairability: String
    }
}
