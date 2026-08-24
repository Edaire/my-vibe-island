import XCTest
@testable import MyVibeIslandSetup

final class SetupInstallerTests: XCTestCase {
    func testClaudeUsesLocallyInstalledBridge() {
        XCTAssertEqual(
            SetupInstaller.helperCommand(for: "claude"),
            "$HOME/.my-vibe-island/bin/my-vibe-island-bridge"
        )
    }

    func testCodexCanonicalEventsMatchOriginalBridgeRegistrationMatrix() {
        XCTAssertEqual(
            SetupInstaller.canonicalEvents(for: "codex"),
            [
                "PermissionRequest",
                "PostToolUse",
                "SessionEnd",
                "SessionStart",
                "Stop",
                "SubagentStop",
                "UserPromptSubmit",
            ]
        )
    }

    func testInstallCodexUsesOriginalNestedHookGroupContract() throws {
        let home = try makeTemporaryHome()

        _ = try SetupInstaller().install(sourceId: "codex", homeDirectory: home)

        let configURL = home.appendingPathComponent(".codex/hooks.json")
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as? [String: Any]
        )
        let hooks = try XCTUnwrap(object["hooks"] as? [String: [[String: Any]]])
        let group = try XCTUnwrap(hooks["SessionStart"]?.first)
        let nestedHooks = try XCTUnwrap(group["hooks"] as? [[String: Any]])
        let command = try XCTUnwrap(nestedHooks.first?["command"] as? String)
        XCTAssertEqual(
            command,
            "$HOME/.my-vibe-island/bin/my-vibe-island-hooks --source codex"
        )
        XCTAssertEqual(nestedHooks.first?["type"] as? String, "command")
        XCTAssertEqual(nestedHooks.first?["timeout"] as? Int, 5)
        XCTAssertEqual(group["matcher"] as? String, "startup|resume|clear")

        let sessionEndGroup = try XCTUnwrap(hooks["SessionEnd"]?.first)
        let sessionEndHooks = try XCTUnwrap(sessionEndGroup["hooks"] as? [[String: Any]])
        XCTAssertEqual(sessionEndHooks.first?["timeout"] as? Int, 1)
    }

    func testInstallCodexReplacesLegacyVibeIslandHooksAndPreservesUnrelatedHooks() throws {
        let home = try makeTemporaryHome()
        let configURL = home.appendingPathComponent(".codex/hooks.json")
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try #"""
        {
          "hooks": {
            "SessionStart": [
              {"hooks": [{"type": "command", "command": "'/Users/test/.my-vibe-island/bin/my-vibe-island-hooks' --source codex", "timeout": 5}]},
              {"hooks": [{"type": "command", "command": "'/Users/test/.vibe-island/bin/vibe-island-bridge' --source codex", "timeout": 5}]}
            ],
            "SessionEnd": [
              {"hooks": [{"type": "command", "command": "'/Users/test/.vibe-island/bin/vibe-island-bridge' --source codex", "timeout": 3}]}
            ],
            "Audit": [
              {"type": "command", "command": "audit-hook --event SessionStart"}
            ]
          }
        }
        """#.write(to: configURL, atomically: true, encoding: .utf8)

        _ = try SetupInstaller().install(sourceId: "codex", homeDirectory: home)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as? [String: Any]
        )
        let hooks = try XCTUnwrap(object["hooks"] as? [String: [[String: Any]]])
        XCTAssertEqual(hooks["SessionStart"]?.count, 1)
        XCTAssertEqual(hooks["SessionEnd"]?.count, 1)
        XCTAssertEqual(
            ((hooks["SessionEnd"]?.first?["hooks"] as? [[String: Any]])?.first?["timeout"] as? Int),
            1
        )
        XCTAssertEqual(
            ((hooks["SessionStart"]?.first { ($0["managedBy"] as? String) == "my-vibe-island" }?["hooks"] as? [[String: Any]])?.first?["command"] as? String),
            "$HOME/.my-vibe-island/bin/my-vibe-island-hooks --source codex"
        )
        XCTAssertEqual(
            hooks["Audit"]?.first { ($0["command"] as? String) == "audit-hook --event SessionStart" }?["command"] as? String,
            "audit-hook --event SessionStart"
        )
        let commands = hooks.values.flatMap { $0 }.flatMap { entry -> [String] in
            if let command = entry["command"] as? String { return [command] }
            return ((entry["hooks"] as? [[String: Any]]) ?? []).compactMap { $0["command"] as? String }
        }
        XCTAssertFalse(commands.contains { $0.contains(".vibe-island/bin/vibe-island-bridge") })
        XCTAssertFalse(commands.contains { $0.contains(".my-vibe-island/bin/my-vibe-island-hooks") && !$0.contains("$HOME/") })
    }

    func testOpenCodePluginTemplateContainsManagedBridgeMarkers() {
        let contents = OpenCodePluginTemplate.contents

        XCTAssertTrue(contents.contains("MY_VIBE_ISLAND_MANAGED_OPENCODE_PLUGIN"))
        XCTAssertTrue(contents.contains("MyVibeIslandOpenCodePlugin"))
        XCTAssertTrue(contents.contains("my-vibe-island-hooks"))
        XCTAssertTrue(contents.contains("hook-event"))
        XCTAssertTrue(contents.contains(#"source: "opencode""#))
        XCTAssertTrue(contents.contains("permission.asked"))
        XCTAssertTrue(contents.contains("MY_VIBE_ISLAND_SOCKET_PATH"))
        XCTAssertTrue(contents.contains("VIBE_ISLAND_SOCKET_PATH"))
        XCTAssertTrue(contents.contains("process.getuid()"))
    }

    func testInstallOpenCodeWritesManagedPluginFile() throws {
        let home = try makeTemporaryHome()

        let result = try SetupInstaller().install(sourceId: "opencode", homeDirectory: home)

        let pluginURL = home.appendingPathComponent(".config/opencode/plugins/open-island.js")
        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.relativePath, ".config/opencode/plugins/open-island.js")
        XCTAssertTrue(FileManager.default.fileExists(atPath: pluginURL.path))
        XCTAssertEqual(try String(contentsOf: pluginURL, encoding: .utf8), OpenCodePluginTemplate.contents)
    }

    func testInstallOpenCodeIsIdempotentForExistingManagedPlugin() throws {
        let home = try makeTemporaryHome()
        _ = try SetupInstaller().install(sourceId: "opencode", homeDirectory: home)

        let result = try SetupInstaller().install(sourceId: "opencode", homeDirectory: home)

        XCTAssertFalse(result.changed)
        XCTAssertTrue(result.message.contains("already installed"))
    }

    func testInstallOpenCodeDoesNotOverwriteExistingUnmanagedPlugin() throws {
        let home = try makeTemporaryHome()
        let pluginURL = home.appendingPathComponent(".config/opencode/plugins/open-island.js")
        try FileManager.default.createDirectory(at: pluginURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "export const Existing = async () => ({})\n".write(to: pluginURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "opencode", homeDirectory: home))
        XCTAssertEqual(try String(contentsOf: pluginURL, encoding: .utf8), "export const Existing = async () => ({})\n")
    }

    func testInstallUnknownSourceDoesNotCreateConfigDirectory() throws {
        let home = try makeTemporaryHome()

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "unknown", homeDirectory: home))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".config").path))
    }

    private func makeTemporaryHome() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-setup-installer-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
