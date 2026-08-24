import XCTest
@testable import MyVibeIslandCore

final class OnboardingReadinessModelsTests: XCTestCase {
    func testOnboardingReadinessMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OnboardingReadinessMatrixFixture.self,
            from: try FixtureLoader.data("settings/onboarding-readiness-matrix")
        )

        let actual = OnboardingReadinessMatrixFixture(rows: [
            row(
                id: "ready-local-agent-and-terminal",
                result: ReadinessScanResult(
                    generatedAt: "2026-07-08T16:55:00Z",
                    agents: [
                        AgentReadiness(
                            agentId: "codex",
                            supportLevel: .supported,
                            installedState: .installed,
                            hookConfiguredState: .configured,
                            watcherAvailableState: .available,
                            lastCheckedAt: "2026-07-08T16:54:00Z"
                        ),
                    ],
                    terminals: [
                        TerminalReadiness(
                            terminalId: "iterm",
                            installedState: .installed,
                            permissionState: .granted,
                            jumpCapabilityState: .available,
                            lastCheckedAt: "2026-07-08T16:54:30Z"
                        ),
                    ],
                    permissions: [
                        PermissionReadiness(
                            permissionKind: .automation,
                            status: .granted,
                            requiredByFeature: "iTerm jump",
                            lastCheckedAt: "2026-07-08T16:54:45Z"
                        ),
                    ]
                )
            ),
            row(
                id: "blocked-denied-permission",
                result: ReadinessScanResult(
                    permissions: [
                        PermissionReadiness(
                            permissionKind: .accessibility,
                            status: .denied,
                            requiredByFeature: "global shortcut repair",
                            repairInstructions: "Open System Settings"
                        ),
                    ]
                )
            ),
            row(
                id: "partial-repairable-agent-and-terminal",
                result: ReadinessScanResult(
                    agents: [
                        AgentReadiness(
                            agentId: "claude",
                            supportLevel: .supported,
                            installedState: .installed,
                            hookConfiguredState: .missing,
                            watcherAvailableState: .available,
                            repairAction: "Install managed hook"
                        ),
                    ],
                    terminals: [
                        TerminalReadiness(
                            terminalId: "terminal",
                            installedState: .installed,
                            permissionState: .notRequired,
                            jumpCapabilityState: .unavailable,
                            repairAction: "Enable terminal integration"
                        ),
                    ]
                )
            ),
            row(
                id: "demo-only-no-local-integrations",
                result: ReadinessScanResult(
                    agents: [
                        AgentReadiness(
                            agentId: "codex",
                            supportLevel: .supported,
                            installedState: .missing,
                            hookConfiguredState: .missing,
                            watcherAvailableState: .unavailable
                        ),
                    ],
                    terminals: [
                        TerminalReadiness(
                            terminalId: "ghostty",
                            installedState: .missing,
                            permissionState: .notRequired,
                            jumpCapabilityState: .unavailable
                        ),
                    ]
                )
            ),
            row(
                id: "environment-scan-blocking-hint",
                result: ReadinessScanResult(
                    agents: [
                        AgentReadiness(
                            agentId: "qwen",
                            supportLevel: .supported,
                            installedState: .installed,
                            hookConfiguredState: .configured,
                            watcherAvailableState: .available,
                            repairAction: "Restart watcher"
                        ),
                    ],
                    environmentScanSummary: DiagnosticReadinessSummary(
                        outcome: .blocked,
                        repairHints: [
                            DiagnosticRepairHint(
                                source: "terminal",
                                message: "Grant Automation permission",
                                repairability: .userActionRequired,
                                severity: .blocking
                            ),
                            DiagnosticRepairHint(
                                source: "watcher",
                                message: "Restart watcher",
                                repairability: .appCanReinstallHelper,
                                severity: .repairable
                            ),
                        ]
                    )
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testReadinessScanResultRoundTripsLocalItemsAndDerivedOutcome() throws {
        let result = ReadinessScanResult(
            generatedAt: "2026-07-08T16:55:00Z",
            agents: [
                AgentReadiness(
                    agentId: "codex",
                    supportLevel: .supported,
                    installedState: .installed,
                    hookConfiguredState: .configured,
                    watcherAvailableState: .available,
                    lastCheckedAt: "2026-07-08T16:54:00Z"
                ),
            ],
            terminals: [
                TerminalReadiness(
                    terminalId: "iterm",
                    installedState: .installed,
                    permissionState: .granted,
                    jumpCapabilityState: .available,
                    lastCheckedAt: "2026-07-08T16:54:30Z"
                ),
            ],
            permissions: [
                PermissionReadiness(
                    permissionKind: .automation,
                    status: .granted,
                    requiredByFeature: "iTerm jump",
                    lastCheckedAt: "2026-07-08T16:54:45Z"
                ),
            ]
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(ReadinessScanResult.self, from: data)

        XCTAssertEqual(decoded, result)
        XCTAssertEqual(decoded.outcome, .ready)
        XCTAssertTrue(decoded.blockingIssues.isEmpty)
    }

    func testReadinessOutcomeIsBlockedByRequiredDeniedPermission() {
        let result = ReadinessScanResult(
            permissions: [
                PermissionReadiness(
                    permissionKind: .accessibility,
                    status: .denied,
                    requiredByFeature: "global shortcut repair",
                    repairInstructions: "Open System Settings"
                ),
            ]
        )

        XCTAssertEqual(result.outcome, .blocked)
        XCTAssertEqual(result.blockingIssues, ["accessibility permission denied for global shortcut repair"])
        XCTAssertEqual(result.repairActions, ["Open System Settings"])
    }

    func testReadinessOutcomeIsPartialWhenRepairableItemsExist() {
        let result = ReadinessScanResult(
            agents: [
                AgentReadiness(
                    agentId: "claude",
                    supportLevel: .supported,
                    installedState: .installed,
                    hookConfiguredState: .missing,
                    watcherAvailableState: .available,
                    repairAction: "Install managed hook"
                ),
            ]
        )

        XCTAssertEqual(result.outcome, .partial)
        XCTAssertEqual(result.repairActions, ["Install managed hook"])
    }

    func testReadinessOutcomeIsDemoOnlyWhenNoLocalIntegrationsAreReady() {
        let result = ReadinessScanResult(
            agents: [
                AgentReadiness(
                    agentId: "codex",
                    supportLevel: .supported,
                    installedState: .missing,
                    hookConfiguredState: .missing,
                    watcherAvailableState: .unavailable
                ),
            ],
            terminals: [
                TerminalReadiness(
                    terminalId: "ghostty",
                    installedState: .missing,
                    permissionState: .notRequired,
                    jumpCapabilityState: .unavailable
                ),
            ]
        )

        XCTAssertEqual(result.outcome, .demoOnly)
    }

    private func row(id: String, result: ReadinessScanResult) -> OnboardingReadinessRowFixture {
        OnboardingReadinessRowFixture(
            id: id,
            generatedAt: result.generatedAt,
            outcome: result.outcome.rawValue,
            readyAgentIds: result.agents.filter(\.isReady).map(\.agentId),
            readyTerminalIds: result.terminals.filter(\.isReady).map(\.terminalId),
            blockingIssues: result.blockingIssues,
            repairActions: result.repairActions
        )
    }

    private struct OnboardingReadinessMatrixFixture: Codable, Equatable {
        let rows: [OnboardingReadinessRowFixture]
    }

    private struct OnboardingReadinessRowFixture: Codable, Equatable {
        let id: String
        let generatedAt: String?
        let outcome: String
        let readyAgentIds: [String]
        let readyTerminalIds: [String]
        let blockingIssues: [String]
        let repairActions: [String]
    }
}
