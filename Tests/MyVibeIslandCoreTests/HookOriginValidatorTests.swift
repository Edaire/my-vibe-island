import XCTest
@testable import MyVibeIslandCore

final class HookOriginValidatorTests: XCTestCase {
    func testHookOriginValidatorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            HookOriginValidatorMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/hook-origin-validator-matrix")
        )

        let snapshot = HookOriginValidatorSnapshot(
            probes: [
                HookOriginProbe(
                    key: "codex:PreToolUse",
                    hookBinaryPath: "/Applications/MyVibeIsland.app/Contents/MacOS/my-vibe-island-hooks",
                    expectedBinaryPath: "/Applications/MyVibeIsland.app/Contents/MacOS/my-vibe-island-hooks",
                    sourceConfigPath: "~/.codex/config.toml",
                    currentHookCommandHash: "sha256:trusted",
                    eventName: "PreToolUse",
                    cwd: "/Users/admin/code/project",
                    sourcePath: "~/.codex/config.toml",
                    processBundleIdentifier: "com.apple.Terminal",
                    origin: .managed,
                    status: .trusted
                ),
                HookOriginProbe(
                    key: "codex:SessionStart",
                    eventName: "SessionStart",
                    origin: .unknown,
                    status: .unknown
                ),
                HookOriginProbe(
                    key: "claude:PermissionRequest",
                    hookBinaryPath: "/usr/local/bin/older-hook",
                    expectedBinaryPath: "/Applications/MyVibeIsland.app/Contents/MacOS/my-vibe-island-hooks",
                    sourceConfigPath: "~/.claude/settings.json",
                    currentHookCommandHash: "sha256:mismatch",
                    eventName: "PermissionRequest",
                    sourcePath: "~/.claude/settings.json",
                    origin: .managed,
                    status: .mismatched
                ),
                HookOriginProbe(
                    key: "opencode:UserPromptSubmit",
                    sourceConfigPath: "~/.config/opencode/config.json",
                    currentHookCommandHash: "sha256:user",
                    eventName: "UserPromptSubmit",
                    origin: .userAuthored,
                    status: .unmanaged
                ),
                HookOriginProbe(
                    key: "codex:Stop",
                    sourceConfigPath: "~/.codex/config.toml",
                    eventName: "Stop",
                    origin: .disabled,
                    status: .blocked
                ),
            ],
            repairableProbeKeys: [
                "claude:PermissionRequest",
                "codex:Stop",
            ]
        )

        let actual = HookOriginValidatorMatrixFixture(snapshot: snapshot)

        XCTAssertEqual(actual, expected)
    }

    func testHookOriginProbeRoundTripsProvenanceFields() throws {
        let probe = HookOriginProbe(
            key: "codex:PermissionRequest",
            hookBinaryPath: "/Applications/MyVibeIsland.app/Contents/MacOS/my-vibe-island-hooks",
            expectedBinaryPath: "/Applications/MyVibeIsland.app/Contents/MacOS/my-vibe-island-hooks",
            sourceConfigPath: "~/.codex/config.toml",
            currentHookCommandHash: "sha256:abc123",
            eventName: "PermissionRequest",
            cwd: "/Users/admin/code/project",
            sourcePath: "~/.codex/config.toml",
            processBundleIdentifier: "com.apple.Terminal",
            origin: .managed,
            status: .trusted
        )

        let decoded = try JSONDecoder().decode(HookOriginProbe.self, from: try JSONEncoder().encode(probe))

        XCTAssertEqual(decoded, probe)
    }

    func testHookOriginValidatorSnapshotRoundTripsAllStatuses() throws {
        let snapshot = HookOriginValidatorSnapshot(
            probes: [
                HookOriginProbe(key: "trusted", eventName: "PreToolUse", origin: .managed, status: .trusted),
                HookOriginProbe(key: "unknown", eventName: "SessionStart", origin: .unknown, status: .unknown),
                HookOriginProbe(key: "mismatch", eventName: "PermissionRequest", origin: .managed, status: .mismatched),
                HookOriginProbe(key: "unmanaged", eventName: "UserPromptSubmit", origin: .userAuthored, status: .unmanaged),
                HookOriginProbe(key: "blocked", eventName: "PreToolUse", origin: .disabled, status: .blocked)
            ],
            repairableProbeKeys: ["mismatch"]
        )

        let decoded = try JSONDecoder().decode(HookOriginValidatorSnapshot.self, from: try JSONEncoder().encode(snapshot))

        XCTAssertEqual(decoded, snapshot)
    }

    private struct HookOriginValidatorMatrixFixture: Codable, Equatable {
        let probes: [HookOriginProbeFixture]
        let repairableProbeKeys: [String]
        let repairableProbeCount: Int
        let statusCounts: [HookOriginStatusCountFixture]

        init(snapshot: HookOriginValidatorSnapshot) {
            probes = snapshot.probes.map(HookOriginProbeFixture.init(probe:))
            repairableProbeKeys = snapshot.repairableProbeKeys
            repairableProbeCount = snapshot.repairableProbeKeys.count
            let statuses: [HookOriginValidationStatus] = [.trusted, .unknown, .mismatched, .unmanaged, .blocked]
            statusCounts = statuses.map { status in
                HookOriginStatusCountFixture(
                    status: status.rawValue,
                    count: snapshot.probes.filter { $0.status == status }.count
                )
            }
        }
    }

    private struct HookOriginProbeFixture: Codable, Equatable {
        let key: String
        let hookBinaryPath: String?
        let expectedBinaryPath: String?
        let sourceConfigPath: String?
        let currentHookCommandHash: String?
        let eventName: String
        let cwd: String?
        let sourcePath: String?
        let processBundleIdentifier: String?
        let origin: String
        let status: String

        init(probe: HookOriginProbe) {
            key = probe.key
            hookBinaryPath = probe.hookBinaryPath
            expectedBinaryPath = probe.expectedBinaryPath
            sourceConfigPath = probe.sourceConfigPath
            currentHookCommandHash = probe.currentHookCommandHash
            eventName = probe.eventName
            cwd = probe.cwd
            sourcePath = probe.sourcePath
            processBundleIdentifier = probe.processBundleIdentifier
            origin = probe.origin.rawValue
            status = probe.status.rawValue
        }
    }

    private struct HookOriginStatusCountFixture: Codable, Equatable {
        let status: String
        let count: Int
    }
}
