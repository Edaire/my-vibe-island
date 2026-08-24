import XCTest
@testable import MyVibeIslandCore

final class EnvironmentScanModelsTests: XCTestCase {
    func testEnvironmentScanModelsMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            EnvironmentScanModelsMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/environment-scan-models-matrix")
        )

        let actual = EnvironmentScanModelsMatrixFixture(rows: [
            row(
                id: "legacy-detected-agent-defaults",
                result: EnvironmentScanResult(
                    scannedAt: "2026-07-09T10:00:00Z",
                    agents: [
                        EnvironmentAgentInfo(id: "codex", name: "Codex CLI", isDetected: true),
                    ],
                    terminals: [
                        EnvironmentTerminalInfo(name: "Terminal", isDetected: true),
                    ]
                )
            ),
            row(
                id: "ready-supported-agent",
                result: EnvironmentScanResult(
                    agents: [
                        EnvironmentAgentInfo(
                            id: "codex",
                            name: "Codex CLI",
                            isDetected: true,
                            supportLevel: .supported,
                            isInstalled: true,
                            isConfigured: true,
                            authorizationState: .authorized,
                            repairability: .notNeeded,
                            lastCheckedAt: "2026-07-09T10:01:00Z"
                        ),
                    ]
                )
            ),
            row(
                id: "repairable-agent-with-undetected-terminal",
                result: EnvironmentScanResult(
                    agents: [
                        EnvironmentAgentInfo(
                            id: "claude",
                            name: "Claude Code",
                            isDetected: true,
                            supportLevel: .supported,
                            isInstalled: true,
                            isConfigured: false,
                            authorizationState: .needsUserApproval,
                            repairability: .repairable
                        ),
                    ],
                    terminals: [
                        EnvironmentTerminalInfo(name: "iTerm2", isDetected: false),
                    ]
                )
            ),
            row(
                id: "manual-denied-agent",
                result: EnvironmentScanResult(
                    agents: [
                        EnvironmentAgentInfo(
                            id: "opencode",
                            name: "OpenCode",
                            isDetected: false,
                            supportLevel: .experimental,
                            isInstalled: false,
                            isConfigured: false,
                            authorizationState: .denied,
                            repairability: .manual
                        ),
                    ]
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testEnvironmentScanResultDecodesObservedAgentAndTerminalFields() throws {
        let json = """
        {
          "scannedAt": "2026-07-08T12:30:00Z",
          "agents": [
            {
              "id": "claude",
              "name": "Claude Code",
              "isDetected": true
            }
          ],
          "terminals": [
            {
              "name": "iTerm2",
              "isDetected": false
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(EnvironmentScanResult.self, from: json)

        XCTAssertEqual(decoded.scannedAt, "2026-07-08T12:30:00Z")
        XCTAssertEqual(decoded.agents.first?.id, "claude")
        XCTAssertEqual(decoded.agents.first?.name, "Claude Code")
        XCTAssertEqual(decoded.agents.first?.isDetected, true)
        XCTAssertEqual(decoded.terminals.first?.name, "iTerm2")
        XCTAssertEqual(decoded.terminals.first?.isDetected, false)
    }

    func testEnvironmentScanResultRoundTripsThroughJSON() throws {
        let result = EnvironmentScanResult(
            scannedAt: "2026-07-08T12:30:00Z",
            agents: [
                EnvironmentAgentInfo(
                    id: "codex",
                    name: "Codex CLI",
                    isDetected: true
                )
            ],
            terminals: [
                EnvironmentTerminalInfo(
                    name: "Terminal",
                    isDetected: true
                )
            ]
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(EnvironmentScanResult.self, from: data)

        XCTAssertEqual(decoded, result)
    }

    func testEnvironmentScanResultExposesObservedNestedInfoNames() throws {
        let result = EnvironmentScanResult(
            agents: [
                EnvironmentScanResult.AgentInfo(
                    id: "opencode",
                    name: "OpenCode",
                    isDetected: false
                )
            ],
            terminals: [
                EnvironmentScanResult.TerminalInfo(
                    name: "Ghostty",
                    isDetected: true
                )
            ]
        )

        XCTAssertEqual(result.agents.first?.id, "opencode")
        XCTAssertEqual(result.terminals.first?.name, "Ghostty")
    }

    func testEnvironmentAgentInfoRoundTripsDesignFields() throws {
        let info = EnvironmentAgentInfo(
            id: "codex",
            name: "Codex CLI",
            isDetected: true,
            supportLevel: .supported,
            isInstalled: true,
            isConfigured: false,
            authorizationState: .needsUserApproval,
            repairability: .repairable,
            lastCheckedAt: "2026-07-08T21:00:00Z"
        )

        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(EnvironmentAgentInfo.self, from: data)

        XCTAssertEqual(decoded, info)
        XCTAssertEqual(decoded.supportLevel, .supported)
        XCTAssertEqual(decoded.authorizationState, .needsUserApproval)
        XCTAssertEqual(decoded.repairability, .repairable)
        XCTAssertEqual(decoded.lastCheckedAt, "2026-07-08T21:00:00Z")
    }

    func testEnvironmentAgentInfoLegacyInitializerProvidesDesignDefaults() {
        let info = EnvironmentAgentInfo(id: "codex", name: "Codex CLI", isDetected: true)

        XCTAssertEqual(info.supportLevel, .unknown)
        XCTAssertEqual(info.isInstalled, true)
        XCTAssertEqual(info.isConfigured, false)
        XCTAssertEqual(info.authorizationState, .unknown)
        XCTAssertEqual(info.repairability, .unknown)
        XCTAssertNil(info.lastCheckedAt)
    }

    func testEnvironmentAgentInfoReadinessAndRepairDerivations() {
        let ready = EnvironmentAgentInfo(
            id: "codex",
            name: "Codex CLI",
            isDetected: true,
            isInstalled: true,
            isConfigured: true,
            authorizationState: .authorized,
            repairability: .notNeeded
        )
        let repairable = EnvironmentAgentInfo(
            id: "codex",
            name: "Codex CLI",
            isDetected: true,
            isInstalled: true,
            isConfigured: false,
            authorizationState: .needsUserApproval,
            repairability: .repairable
        )

        XCTAssertTrue(ready.isReady)
        XCTAssertFalse(repairable.isReady)
        XCTAssertTrue(repairable.canRepair)
    }

    private func row(
        id: String,
        result: EnvironmentScanResult
    ) -> EnvironmentScanModelsRowFixture {
        let firstAgent = result.agents.first
        let firstTerminal = result.terminals.first

        return EnvironmentScanModelsRowFixture(
            id: id,
            scannedAt: result.scannedAt,
            agentCount: result.agents.count,
            terminalCount: result.terminals.count,
            firstAgentId: firstAgent?.id,
            firstAgentName: firstAgent?.name,
            firstAgentDetected: firstAgent?.isDetected,
            firstAgentSupportLevel: firstAgent?.supportLevel.rawValue,
            firstAgentInstalled: firstAgent?.isInstalled,
            firstAgentConfigured: firstAgent?.isConfigured,
            firstAgentAuthorizationState: firstAgent?.authorizationState.rawValue,
            firstAgentRepairability: firstAgent?.repairability.rawValue,
            firstAgentLastCheckedAt: firstAgent?.lastCheckedAt,
            firstAgentReady: firstAgent?.isReady,
            firstAgentCanRepair: firstAgent?.canRepair,
            firstTerminalName: firstTerminal?.name,
            firstTerminalDetected: firstTerminal?.isDetected
        )
    }

    private struct EnvironmentScanModelsMatrixFixture: Codable, Equatable {
        let rows: [EnvironmentScanModelsRowFixture]
    }

    private struct EnvironmentScanModelsRowFixture: Codable, Equatable {
        let id: String
        let scannedAt: String?
        let agentCount: Int
        let terminalCount: Int
        let firstAgentId: String?
        let firstAgentName: String?
        let firstAgentDetected: Bool?
        let firstAgentSupportLevel: String?
        let firstAgentInstalled: Bool?
        let firstAgentConfigured: Bool?
        let firstAgentAuthorizationState: String?
        let firstAgentRepairability: String?
        let firstAgentLastCheckedAt: String?
        let firstAgentReady: Bool?
        let firstAgentCanRepair: Bool?
        let firstTerminalName: String?
        let firstTerminalDetected: Bool?
    }
}
