import Foundation
import XCTest
@testable import MyVibeIslandSetup

final class SetupInstallerLifecycleTests: XCTestCase {

    func testHermesInstallCreatesOriginalStylePluginDirectoryWithLocalBridge() throws {
        let home = try makeTemporaryHome()

        let result = try SetupInstaller().install(sourceId: "hermes", homeDirectory: home)
        let pluginDirectory = home.appendingPathComponent(".hermes/plugins/vibe-island")
        let manifest = try String(contentsOf: pluginDirectory.appendingPathComponent("plugin.yaml"), encoding: .utf8)
        let plugin = try String(contentsOf: pluginDirectory.appendingPathComponent("__init__.py"), encoding: .utf8)

        XCTAssertTrue(result.changed)
        XCTAssertTrue(manifest.contains("on_session_finalize"))
        XCTAssertTrue(plugin.contains("~/.my-vibe-island/bin/my-vibe-island-bridge"))
        XCTAssertTrue(plugin.contains("--source\", \"hermes\""))
        XCTAssertTrue(plugin.contains("--wait-for-ack"))
        XCTAssertTrue(plugin.contains("post_llm_call"))
        XCTAssertTrue(try SetupInstaller().verify(sourceId: "hermes", homeDirectory: home))
    }
    func testCanonicalEventsAndCompleteLifecycleForEverySource() throws {
        let home = try makeTemporaryHome()
        let jsonSources = Set(["claude", "qwen", "qoder", "factory", "codebuddy", "codex", "cursor", "gemini"])
        let canonicalEvents = try frozenCanonicalEvents()

        for source in SetupIntegrationScanner.defaultSources {
            if source.id == "kimi" {
                try write("name = \"kimi\"\n", to: home.appendingPathComponent(source.relativePath))
            }

            XCTAssertTrue(try SetupInstaller().install(sourceId: source.id, homeDirectory: home).changed, source.id)
            XCTAssertTrue(try SetupInstaller().verify(sourceId: source.id, homeDirectory: home), source.id)
            XCTAssertFalse(try SetupInstaller().repair(sourceId: source.id, homeDirectory: home).changed, source.id)

            let manifest = try SetupManifestStore(homeDirectory: home).load(sourceId: source.id)
            if jsonSources.contains(source.id) {
                XCTAssertEqual(manifest?.eventNames, canonicalEvents[source.id], source.id)
            } else {
                XCTAssertNil(manifest, source.id)
            }

            XCTAssertTrue(try SetupInstaller().uninstall(sourceId: source.id, homeDirectory: home).changed, source.id)
        }
    }

    func testKimiMissingDirectoryIsNoOp() throws {
        let home = try makeTemporaryHome()

        let result = try SetupInstaller().install(sourceId: "kimi", homeDirectory: home)

        XCTAssertFalse(result.changed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".kimi").path))
    }

    func testOpenCodeOwnsOnlyMarkerPluginAndNeverTouchesConfigOrManifest() throws {
        let home = try makeTemporaryHome()
        let configURL = home.appendingPathComponent(".config/opencode/config.json")
        let originalConfig = #"{"plugin":["foreign-plugin"],"unknown":true}"#
        try write(originalConfig, to: configURL)

        _ = try SetupInstaller().install(sourceId: "opencode", homeDirectory: home)

        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), originalConfig)
        XCTAssertTrue(try SetupInstaller().verify(sourceId: "opencode", homeDirectory: home))
        XCTAssertNil(try SetupManifestStore(homeDirectory: home).load(sourceId: "opencode"))

        _ = try SetupInstaller().uninstall(sourceId: "opencode", homeDirectory: home)
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), originalConfig)
    }

    func testOpenCodeMarkerOwnedStalePluginRepairsButForeignPluginFailsClosed() throws {
        let home = try makeTemporaryHome()
        let pluginURL = home.appendingPathComponent(".config/opencode/plugins/open-island.js")
        let stale = OpenCodePluginTemplate.contents.replacingOccurrences(of: "v1", with: "v0")
        try write(stale, to: pluginURL)

        XCTAssertTrue(try SetupInstaller().repair(sourceId: "opencode", homeDirectory: home).changed)
        XCTAssertEqual(try String(contentsOf: pluginURL, encoding: .utf8), OpenCodePluginTemplate.contents)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pluginURL.path + ".bak"))

        try write("export const foreign = true\n", to: pluginURL)
        XCTAssertThrowsError(try SetupInstaller().repair(sourceId: "opencode", homeDirectory: home)) { error in
            XCTAssertEqual(error as? ManagedHookConfigError, .unmanagedConflict)
        }
        XCTAssertEqual(try String(contentsOf: pluginURL, encoding: .utf8), "export const foreign = true\n")
    }

    func testJSONRepairRebuildsExactCanonicalSetAndPreservesForeignData() throws {
        let home = try makeTemporaryHome()
        let canonicalEvents = try frozenCanonicalEvents()
        let path = home.appendingPathComponent(".gemini/settings.json")
        try write(#"{"unknownRoot":{"keep":true},"hooks":{"ForeignEvent":[{"command":"foreign"}]}}"#, to: path)
        _ = try SetupInstaller().install(sourceId: "gemini", homeDirectory: home)

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        var hooks = try XCTUnwrap(object["hooks"] as? [String: Any])
        hooks["ObsoleteManagedEvent"] = [["managedBy": ManagedJSONHookConfig.marker, "source": "gemini", "version": 0, "command": "old-helper"]]
        object["hooks"] = hooks
        try JSONSerialization.data(withJSONObject: object).write(to: path)

        _ = try SetupInstaller().repair(sourceId: "gemini", homeDirectory: home)

        object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        hooks = try XCTUnwrap(object["hooks"] as? [String: Any])
        let managedEvents = Set(hooks.compactMap { event, value -> String? in
            guard let entries = value as? [[String: Any]], entries.contains(where: { ($0["managedBy"] as? String) == ManagedJSONHookConfig.marker && ($0["source"] as? String) == "gemini" }) else { return nil }
            return event
        })
        XCTAssertEqual(managedEvents, Set(canonicalEvents["gemini"]!))
        XCTAssertEqual((hooks["ForeignEvent"] as? [[String: Any]])?.first?["command"] as? String, "foreign")
        XCTAssertNotNil(object["unknownRoot"])
        XCTAssertNil(hooks["ObsoleteManagedEvent"])
    }

    func testJSONForeignEntryOnCanonicalEventFailsClosedWithoutMutation() throws {
        let home = try makeTemporaryHome()
        let path = home.appendingPathComponent(".codex/hooks.json")
        let original = #"{"hooks":{"SessionStart":[{"command":"foreign"}]}}"#
        try write(original, to: path)

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "codex", homeDirectory: home)) { error in
            XCTAssertEqual(error as? ManagedHookConfigError, .unmanagedConflict)
        }
        XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), original)
    }

    func testKimiPreservesUnknownTOMLCommentsSimpleRootAssignmentAndCreatesDualBackups() throws {
        let home = try makeTemporaryHome()
        let canonicalEvents = try frozenCanonicalEvents()
        let path = home.appendingPathComponent(".kimi/config.toml")
        let original = "# user comment\ninline = { nested = [1, 2] }\nhooks = \"legacy-user-hook\"\n[unknown.section]\nvalue = '''verbatim'''\n"
        try write(original, to: path)

        _ = try SetupInstaller().install(sourceId: "kimi", homeDirectory: home)

        let installed = try String(contentsOf: path, encoding: .utf8)
        XCTAssertTrue(installed.contains("# user comment"))
        XCTAssertTrue(installed.contains("inline = { nested = [1, 2] }"))
        XCTAssertTrue(installed.contains("value = '''verbatim'''"))
        XCTAssertFalse(installed.split(separator: "\n").contains("hooks = \"legacy-user-hook\""))
        XCTAssertTrue(installed.contains("SessionEnd"))
        XCTAssertEqual(installed.components(separatedBy: "timeout = 30").count - 1, canonicalEvents["kimi"]!.count)
        assertDualBackups(for: path)

        _ = try SetupInstaller().uninstall(sourceId: "kimi", homeDirectory: home)
        XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), original)
    }

    func testKimiComplexRootHooksAssignmentIsConflictAndRemainsVerbatim() throws {
        let home = try makeTemporaryHome()
        let path = home.appendingPathComponent(".kimi/config.toml")
        let original = "hooks = [\n  { event = \"Stop\", command = \"user\" }\n]\nunknown syntax remains\n"
        try write(original, to: path)

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "kimi", homeDirectory: home)) { error in
            XCTAssertEqual(error as? ManagedHookConfigError, .unmanagedConflict)
        }
        XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), original)
    }

    func testKimiOwnedStrayLegacyBlockIsRemovedAndForeignBlockIsPreserved() throws {
        let home = try makeTemporaryHome()
        let path = home.appendingPathComponent(".kimi/config.toml")
        let original = "[[hooks]]\nevent = \"Stop\"\ncommand = \"$HOME/.vibe-island/bin/vibe-island-bridge --source kimi --event Stop\"\nmanaged_by = \"my-vibe-island\"\n\n[[hooks]]\nevent = \"Stop\"\ncommand = \"foreign\"\n"
        try write(original, to: path)

        _ = try SetupInstaller().install(sourceId: "kimi", homeDirectory: home)
        let installed = try String(contentsOf: path, encoding: .utf8)
        XCTAssertEqual(installed.components(separatedBy: "--source kimi --event Stop").count - 1, 1)
        XCTAssertTrue(installed.contains("command = \"foreign\""))

        _ = try SetupInstaller().uninstall(sourceId: "kimi", homeDirectory: home)
        let uninstalled = try String(contentsOf: path, encoding: .utf8)
        XCTAssertFalse(uninstalled.contains("--source kimi"))
        XCTAssertTrue(uninstalled.contains("command = \"foreign\""))
    }

    func testKimiVerifyAndScannerRejectEveryNonCanonicalOwnedShape() throws {
        for corruption in KimiCorruption.allCases {
            let home = try makeTemporaryHome()
            let path = home.appendingPathComponent(".kimi/config.toml")
            try write(corruption.apply(to: try canonicalKimiConfig(at: path)), to: path)

            XCTAssertFalse(try SetupInstaller().verify(sourceId: "kimi", homeDirectory: home), corruption.rawValue)
            XCTAssertEqual(
                try SetupInstaller().status(sourceId: "kimi", homeDirectory: home).issues,
                [.managedStale],
                corruption.rawValue
            )
        }
    }

    func testKimiRepairConvergesEveryNonCanonicalOwnedShapeToOneExactFence() throws {
        let canonicalEvents = try frozenCanonicalEvents()
        let expectedEvents = Set(canonicalEvents["kimi"]!)
        for corruption in KimiCorruption.allCases {
            let home = try makeTemporaryHome()
            let path = home.appendingPathComponent(".kimi/config.toml")
            try write(corruption.apply(to: try canonicalKimiConfig(at: path)), to: path)

            XCTAssertTrue(try SetupInstaller().repair(sourceId: "kimi", homeDirectory: home).changed, corruption.rawValue)

            let repaired = try String(contentsOf: path, encoding: .utf8)
            XCTAssertTrue(try SetupInstaller().verify(sourceId: "kimi", homeDirectory: home), corruption.rawValue)
            XCTAssertEqual(repaired.components(separatedBy: ManagedTOMLHookConfig.kimiBeginPrefix).count - 1, 1, corruption.rawValue)
            XCTAssertEqual(repaired.components(separatedBy: ManagedTOMLHookConfig.endMarker).count - 1, 1, corruption.rawValue)
            XCTAssertEqual(Set(ownedKimiEvents(in: repaired)), expectedEvents, corruption.rawValue)
            XCTAssertEqual(ownedKimiEvents(in: repaired).count, 7, corruption.rawValue)
            XCTAssertEqual(repaired.components(separatedBy: "timeout = 30").count - 1, 7, corruption.rawValue)
            XCTAssertTrue(repaired.contains("command = \"foreign-user-hook\""), corruption.rawValue)
        }
    }

    func testCodexHooksUseJSONOnlyAndTerminalTitleInsertionCreatesDualBackups() throws {
        let home = try makeTemporaryHome()
        let configURL = home.appendingPathComponent(".codex/config.toml")
        let original = "unknown = { nested = true }\n[tui]\nother = \"keep\"\n"
        try write(original, to: configURL)

        _ = try SetupInstaller().install(sourceId: "codex", homeDirectory: home)

        let installed = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(installed.contains("unknown = { nested = true }"))
        XCTAssertTrue(installed.contains("[tui]\nterminal_title = []\nother = \"keep\""))
        XCTAssertFalse(installed.contains("MANAGED_CODEX_METADATA"))
        assertDualBackups(for: configURL)
        XCTAssertTrue(try SetupInstaller().verify(sourceId: "codex", homeDirectory: home))

        _ = try SetupInstaller().uninstall(sourceId: "codex", homeDirectory: home)
        XCTAssertTrue(try String(contentsOf: configURL, encoding: .utf8).contains("terminal_title = []"))
    }

    func testCodexPreservesExistingTerminalTitleAndVerifyDoesNotRequireConfigToml() throws {
        let home = try makeTemporaryHome()
        let configURL = home.appendingPathComponent(".codex/config.toml")
        let original = "[tui]\nterminal_title = [\"user\"]\n"
        try write(original, to: configURL)

        _ = try SetupInstaller().install(sourceId: "codex", homeDirectory: home)
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), original)
        try FileManager.default.removeItem(at: configURL)
        XCTAssertTrue(try SetupInstaller().verify(sourceId: "codex", homeDirectory: home))
    }

    func testCodexAppendsTUISectionWhenMissing() throws {
        let home = try makeTemporaryHome()
        let configURL = home.appendingPathComponent(".codex/config.toml")
        try write("model = \"gpt\"\n", to: configURL)

        _ = try SetupInstaller().install(sourceId: "codex", homeDirectory: home)

        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), "model = \"gpt\"\n[tui]\nterminal_title = []\n")
    }

    func testCodexInsertsIntoTUISectionWithTrailingComment() throws {
        let home = try makeTemporaryHome()
        let configURL = home.appendingPathComponent(".codex/config.toml")
        try write("[tui] # user comment\nother = true\n", to: configURL)

        _ = try SetupInstaller().install(sourceId: "codex", homeDirectory: home)

        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), "[tui] # user comment\nterminal_title = []\nother = true\n")
    }

    func testPartialArtifactUninstallRemovesOnlyOwnedArtifacts() throws {
        let home = try makeTemporaryHome()
        _ = try SetupInstaller().install(sourceId: "codex", homeDirectory: home)
        try FileManager.default.removeItem(at: home.appendingPathComponent(".codex/hooks.json"))
        XCTAssertFalse(try SetupInstaller().uninstall(sourceId: "codex", homeDirectory: home).changed)
        XCTAssertNil(try SetupManifestStore(homeDirectory: home).load(sourceId: "codex"))

        _ = try SetupInstaller().install(sourceId: "opencode", homeDirectory: home)
        try FileManager.default.removeItem(at: home.appendingPathComponent(".config/opencode/plugins/open-island.js"))
        XCTAssertFalse(try SetupInstaller().uninstall(sourceId: "opencode", homeDirectory: home).changed)
    }

    func testStatusAndVerifyDoNotTrustManifest() throws {
        let home = try makeTemporaryHome()
        _ = try SetupInstaller().install(sourceId: "gemini", homeDirectory: home)
        try SetupManifestStore(homeDirectory: home).save(SetupManifest(helperBinaryPath: "wrong", managedBlockMarker: "wrong", sourceId: "gemini", eventNames: ["wrong"], installedCommand: "wrong", configPath: "wrong", lastInstalledVersion: "0"))

        XCTAssertTrue(try SetupInstaller().status(sourceId: "gemini", homeDirectory: home).issues.contains(.managed))
        XCTAssertTrue(try SetupInstaller().verify(sourceId: "gemini", homeDirectory: home))
    }

    func testManifestSaveAndRemovalFailuresAreTyped() throws {
        let saveHome = try makeTemporaryHome()
        let blockedParent = saveHome.appendingPathComponent(".config/my-vibe-island")
        try FileManager.default.createDirectory(at: blockedParent.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("blocked".utf8).write(to: blockedParent)
        XCTAssertThrowsError(try SetupManifestStore(homeDirectory: saveHome).save(testManifest)) { error in
            XCTAssertNotNil(error as? SetupManifestStoreError)
        }

        let removeHome = try makeTemporaryHome()
        let manifestURL = removeHome.appendingPathComponent(SetupManifestStore.relativePath)
        try FileManager.default.createDirectory(at: manifestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: manifestURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: manifestURL.deletingLastPathComponent().path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: manifestURL.deletingLastPathComponent().path) }
        XCTAssertThrowsError(try SetupManifestStore(homeDirectory: removeHome).remove(sourceId: "missing")) { error in
            XCTAssertNotNil(error as? SetupManifestStoreError)
        }
    }

    private func assertDualBackups(for url: URL, file: StaticString = #filePath, line: UInt = #line) {
        let canonical = url.appendingPathExtension("backup")
        XCTAssertTrue(FileManager.default.fileExists(atPath: canonical.path), file: file, line: line)
        let prefix = url.lastPathComponent + ".backup."
        let siblings = (try? FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)) ?? []
        XCTAssertTrue(siblings.contains(where: { $0.hasPrefix(prefix) }), file: file, line: line)
    }

    private func makeTemporaryHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("my-vibe-island-managed-redesign").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }
        return home
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
    }

    private func canonicalKimiConfig(at path: URL) throws -> String {
        try write("[[hooks]]\nevent = \"ForeignEvent\"\ncommand = \"foreign-user-hook\"\n", to: path)
        _ = try SetupInstaller().install(sourceId: "kimi", homeDirectory: path.deletingLastPathComponent().deletingLastPathComponent())
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func ownedKimiEvents(in contents: String) -> [String] {
        contents.split(separator: "\n").compactMap { line in
            guard let range = line.range(of: "--source kimi --event ") else { return nil }
            return String(line[range.upperBound...].prefix { $0 != "\"" })
        }
    }

    private func frozenCanonicalEvents() throws -> [String: [String]] {
        try JSONDecoder().decode([String: [String]].self, from: SetupFixtureLoader.data("setup/canonical-events"))
    }

    private enum KimiCorruption: String, CaseIterable {
        case ownedStrayOutsideFence
        case extraOwnedBlockInsideFence
        case nonExactEventSet

        func apply(to canonical: String) -> String {
            switch self {
            case .ownedStrayOutsideFence:
                return canonical + Self.ownedBlock(event: "LegacyOwned")
            case .extraOwnedBlockInsideFence:
                return canonical.replacingOccurrences(
                    of: ManagedTOMLHookConfig.endMarker,
                    with: Self.ownedBlock(event: "DuplicateOwned") + ManagedTOMLHookConfig.endMarker
                )
            case .nonExactEventSet:
                return canonical.replacingOccurrences(of: Self.ownedBlock(event: "SessionEnd"), with: "")
            }
        }

        private static func ownedBlock(event: String) -> String {
            "[[hooks]]\n" +
                "name = \"my-vibe-island\"\n" +
                "source = \"kimi\"\n" +
                "event = \"\(event)\"\n" +
                "command = \"$HOME/.vibe-island/bin/vibe-island-bridge --source kimi --event \(event)\"\n" +
                "timeout = 30\n" +
                "managed_by = \"my-vibe-island\"\n" +
                "version = 1\n\n"
        }
    }

    private var testManifest: SetupManifest {
        SetupManifest(helperBinaryPath: "helper", managedBlockMarker: "marker", sourceId: "codex", eventNames: ["Stop"], installedCommand: "helper", configPath: ".codex/hooks.json")
    }

}
