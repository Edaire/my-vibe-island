import XCTest
@testable import MyVibeIslandCore

final class RemoteHookUninstallPlanTests: XCTestCase {
    func testRemoteHookUninstallPlanMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteHookUninstallPlanMatrixFixture.self,
            from: try FixtureLoader.data("remote/hook-uninstall-plan-matrix")
        )

        let actual = RemoteHookUninstallPlanMatrixFixture(rows: [
            row(
                id: "mixed-origins-managed-tunnel",
                plan: RemoteHookUninstallPlan(
                    hostId: "devbox",
                    probes: [
                        probe(key: "z-managed-stop", config: "~/.codex/config.toml", origin: .managed, status: .trusted),
                        probe(key: "a-managed-stop", config: "~/.claude/settings.json", origin: .managed, status: .trusted),
                        probe(key: "codex-user", config: "~/.codex/config.toml", origin: .userAuthored, status: .unmanaged),
                        probe(key: "codex-unknown", config: "~/.codex/config.toml", origin: .unknown, status: .unknown),
                        probe(key: "claude-disabled", config: "~/.claude/settings.json", origin: .disabled, status: .blocked),
                    ],
                    tunnelProcess: tunnel(hostId: "devbox", processId: 1234)
                )
            ),
            row(
                id: "piggyback-tunnel-preserved",
                plan: RemoteHookUninstallPlan(
                    hostId: "devbox",
                    probes: [
                        probe(key: "managed-only", config: "~/.codex/config.toml", origin: .managed, status: .trusted),
                    ],
                    tunnelProcess: tunnel(hostId: "devbox", processId: 2222, isPiggybackMode: true)
                )
            ),
            row(
                id: "foreign-tunnel-preserved",
                plan: RemoteHookUninstallPlan(
                    hostId: "devbox",
                    probes: [
                        probe(key: "managed-only", config: "~/.codex/config.toml", origin: .managed, status: .trusted),
                    ],
                    tunnelProcess: tunnel(hostId: "otherbox", processId: 3333)
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRemoteHookUninstallPlanPreservesUserAuthoredHooksAndRemoteFiles() throws {
        let managed = HookOriginProbe(
            key: "codex-pre-tool-use",
            sourceConfigPath: "~/.codex/config.toml",
            eventName: "PreToolUse",
            origin: .managed,
            status: .trusted
        )
        let userAuthored = HookOriginProbe(
            key: "codex-user-prompt-submit",
            sourceConfigPath: "~/.codex/config.toml",
            eventName: "UserPromptSubmit",
            origin: .userAuthored,
            status: .unmanaged
        )

        let plan = RemoteHookUninstallPlan(
            hostId: "devbox",
            probes: [managed, userAuthored],
            tunnelProcess: SSHTunnelProcess(
                processId: 1234,
                hostId: "devbox",
                tunnelKind: .uds,
                localSocketPath: "/tmp/local.sock",
                remoteSocketPath: "/tmp/remote.sock",
                startedAt: "2026-07-09T09:30:00Z",
                lastStatus: .connected,
                generation: 3
            )
        )
        let decoded = try JSONDecoder().decode(RemoteHookUninstallPlan.self, from: try JSONEncoder().encode(plan))

        XCTAssertEqual(decoded, plan)
        XCTAssertEqual(plan.hostId, "devbox")
        XCTAssertEqual(plan.managedHookKeysToRemove, ["codex-pre-tool-use"])
        XCTAssertEqual(plan.userAuthoredHookKeysToPreserve, ["codex-user-prompt-submit"])
        XCTAssertEqual(plan.configPathsToEdit, ["~/.codex/config.toml"])
        XCTAssertEqual(plan.filesToDelete, [])
        XCTAssertEqual(plan.stopTunnelProcessIds, [1234])
        XCTAssertTrue(plan.preservesUserAuthoredHooks)
        XCTAssertTrue(plan.preservesUnrelatedRemoteFiles)
    }

    private func probe(
        key: String,
        config: String?,
        origin: HookCommandOrigin,
        status: HookOriginValidationStatus
    ) -> HookOriginProbe {
        HookOriginProbe(
            key: key,
            sourceConfigPath: config,
            eventName: "PreToolUse",
            origin: origin,
            status: status
        )
    }

    private func tunnel(
        hostId: String,
        processId: Int,
        isPiggybackMode: Bool = false
    ) -> SSHTunnelProcess {
        SSHTunnelProcess(
            processId: processId,
            hostId: hostId,
            tunnelKind: .uds,
            localSocketPath: "/tmp/local.sock",
            remoteSocketPath: "/tmp/remote.sock",
            startedAt: "2026-07-09T09:30:00Z",
            lastStatus: .connected,
            generation: 3,
            isPiggybackMode: isPiggybackMode
        )
    }

    private func row(id: String, plan: RemoteHookUninstallPlan) -> RemoteHookUninstallPlanRowFixture {
        RemoteHookUninstallPlanRowFixture(
            id: id,
            hostId: plan.hostId,
            managedHookKeysToRemove: plan.managedHookKeysToRemove,
            userAuthoredHookKeysToPreserve: plan.userAuthoredHookKeysToPreserve,
            unknownHookKeysToPreserve: plan.unknownHookKeysToPreserve,
            configPathsToEdit: plan.configPathsToEdit,
            filesToDelete: plan.filesToDelete,
            stopTunnelProcessIds: plan.stopTunnelProcessIds,
            preservesUserAuthoredHooks: plan.preservesUserAuthoredHooks,
            preservesUnrelatedRemoteFiles: plan.preservesUnrelatedRemoteFiles
        )
    }

    private struct RemoteHookUninstallPlanMatrixFixture: Codable, Equatable {
        let rows: [RemoteHookUninstallPlanRowFixture]
    }

    private struct RemoteHookUninstallPlanRowFixture: Codable, Equatable {
        let id: String
        let hostId: String
        let managedHookKeysToRemove: [String]
        let userAuthoredHookKeysToPreserve: [String]
        let unknownHookKeysToPreserve: [String]
        let configPathsToEdit: [String]
        let filesToDelete: [String]
        let stopTunnelProcessIds: [Int]
        let preservesUserAuthoredHooks: Bool
        let preservesUnrelatedRemoteFiles: Bool
    }
}
