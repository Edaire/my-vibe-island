import Foundation
import XCTest
@testable import MyVibeIslandSetup

final class SetupInstallerQualityTests: XCTestCase {
    func testKimiUnmarkedSourceCommandIsAlwaysPreservedAsForeign() throws {
        let home = try makeTemporaryHome()
        let path = home.appendingPathComponent(".kimi/config.toml")
        let foreign = "[[hooks]]\nevent = \"Stop\"\ncommand = \"foreign-helper --source kimi --event Stop\"\n"
        try write(foreign, to: path)

        _ = try SetupInstaller().install(sourceId: "kimi", homeDirectory: home)
        XCTAssertTrue(try String(contentsOf: path, encoding: .utf8).contains("foreign-helper --source kimi"))

        _ = try SetupInstaller().uninstall(sourceId: "kimi", homeDirectory: home)
        XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), foreign)
    }

    func testCodexInstallRollsBackHooksWhenLaterConfigMutationFails() throws {
        let home = try makeTemporaryHome()
        let hooksURL = home.appendingPathComponent(".codex/hooks.json")
        let configURL = home.appendingPathComponent(".codex/config.toml")
        let original = #"{"custom":true}"#
        try write(original, to: hooksURL)
        try FileManager.default.createDirectory(at: configURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "codex", homeDirectory: home))
        XCTAssertEqual(try String(contentsOf: hooksURL, encoding: .utf8), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: hooksURL.path + ".bak"))
    }

    func testCodexInstallRollsBackAllFilesWhenManifestSaveFailsAndPreservesTypedError() throws {
        let home = try makeTemporaryHome()
        let hooksURL = home.appendingPathComponent(".codex/hooks.json")
        let configURL = home.appendingPathComponent(".codex/config.toml")
        let originalHooks = #"{"custom":true}"#
        let originalConfig = "model = \"gpt\"\n"
        try write(originalHooks, to: hooksURL)
        try write(originalConfig, to: configURL)
        try blockManifestParent(in: home)

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "codex", homeDirectory: home)) { error in
            guard case SetupManifestStoreError.writeFailed = error else {
                return XCTFail("expected typed manifest write failure, got \(error)")
            }
        }
        XCTAssertEqual(try String(contentsOf: hooksURL, encoding: .utf8), originalHooks)
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), originalConfig)
        XCTAssertFalse(FileManager.default.fileExists(atPath: hooksURL.path + ".bak"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: configURL.path + ".backup"))
    }

    func testJSONInstallRollbackRemovesNewConfigAndDirectories() throws {
        let home = try makeTemporaryHome()
        try blockManifestParent(in: home)

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "gemini", homeDirectory: home)) { error in
            guard case SetupManifestStoreError.writeFailed = error else {
                return XCTFail("expected typed manifest write failure, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".gemini/settings.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".gemini").path))
    }

    func testJSONUninstallRollsBackConfigWhenManifestRemovalFailsAndPreservesTypedError() throws {
        let home = try makeTemporaryHome()
        let configURL = home.appendingPathComponent(".gemini/settings.json")
        _ = try SetupInstaller().install(sourceId: "gemini", homeDirectory: home)
        let installed = try Data(contentsOf: configURL)
        let manifestURL = home.appendingPathComponent(SetupManifestStore.relativePath)
        try FileManager.default.removeItem(at: manifestURL)
        try FileManager.default.createDirectory(at: manifestURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(try SetupInstaller().uninstall(sourceId: "gemini", homeDirectory: home)) { error in
            guard case SetupManifestStoreError.removalFailed = error else {
                return XCTFail("expected typed manifest removal failure, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: configURL), installed)
    }

    func testTextBackupsKeepFirstCanonicalCopyAndUseUniqueTimestampNames() throws {
        let home = try makeTemporaryHome()
        let path = home.appendingPathComponent(".kimi/config.toml")
        let original = "name = \"kimi\"\n"
        try write(original, to: path)

        _ = try SetupInstaller().install(sourceId: "kimi", homeDirectory: home)
        let canonicalBackup = path.appendingPathExtension("backup")
        XCTAssertEqual(try String(contentsOf: canonicalBackup, encoding: .utf8), original)

        var stale = try String(contentsOf: path, encoding: .utf8)
        stale = stale.replacingOccurrences(of: ManagedTOMLHookConfig.beginMarker, with: "\(ManagedTOMLHookConfig.kimiBeginPrefix)0")
        try write(stale, to: path)
        _ = try SetupInstaller().repair(sourceId: "kimi", homeDirectory: home)
        XCTAssertEqual(try String(contentsOf: canonicalBackup, encoding: .utf8), original)

        _ = try SetupInstaller().uninstall(sourceId: "kimi", homeDirectory: home)
        XCTAssertEqual(try String(contentsOf: canonicalBackup, encoding: .utf8), original)
        let timestampBackups = try FileManager.default.contentsOfDirectory(atPath: path.deletingLastPathComponent().path)
            .filter { $0.hasPrefix("config.toml.backup.") }
        XCTAssertEqual(timestampBackups.count, 3)
        XCTAssertEqual(Set(timestampBackups).count, 3)
    }

    func testOpenCodeMutationCreatesNoBackupFiles() throws {
        let home = try makeTemporaryHome()
        let pluginURL = home.appendingPathComponent(".config/opencode/plugins/open-island.js")
        try write(OpenCodePluginTemplate.contents.replacingOccurrences(of: "v1", with: "v0"), to: pluginURL)

        _ = try SetupInstaller().repair(sourceId: "opencode", homeDirectory: home)

        let siblings = try FileManager.default.contentsOfDirectory(atPath: pluginURL.deletingLastPathComponent().path)
        XCTAssertEqual(siblings, [pluginURL.lastPathComponent])
    }

    func testJSONMutationRejectsSymlinkEscape() throws {
        let (home, outside) = try makeHomeAndOutside()
        try FileManager.default.createDirectory(at: outside.appendingPathComponent("cursor"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent(".cursor"), withDestinationURL: outside.appendingPathComponent("cursor"))

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "cursor", homeDirectory: home))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("cursor/hooks.json").path))
    }

    func testKimiMutationRejectsSymlinkEscape() throws {
        let (home, outside) = try makeHomeAndOutside()
        let outsideKimi = outside.appendingPathComponent("kimi")
        let outsideConfig = outsideKimi.appendingPathComponent("config.toml")
        try write("name = \"outside\"\n", to: outsideConfig)
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent(".kimi"), withDestinationURL: outsideKimi)

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "kimi", homeDirectory: home))
        XCTAssertEqual(try String(contentsOf: outsideConfig, encoding: .utf8), "name = \"outside\"\n")
    }

    func testOpenCodeMutationRejectsSymlinkEscape() throws {
        let (home, outside) = try makeHomeAndOutside()
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent(".config"), withDestinationURL: outside)

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "opencode", homeDirectory: home))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("opencode/plugins/open-island.js").path))
    }

    func testCodexMutationRejectsSymlinkEscape() throws {
        let (home, outside) = try makeHomeAndOutside()
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent(".codex"), withDestinationURL: outside)

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "codex", homeDirectory: home))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("hooks.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("config.toml").path))
    }

    func testManifestMutationRejectsSymlinkEscapeAndRollsBackConfig() throws {
        let (home, outside) = try makeHomeAndOutside()
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent(".config"), withDestinationURL: outside)

        XCTAssertThrowsError(try SetupInstaller().install(sourceId: "gemini", homeDirectory: home))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".gemini/settings.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("my-vibe-island/setup-manifest.json").path))
    }

    func testDirectManifestStoreRejectsSymlinkEscape() throws {
        let (home, outside) = try makeHomeAndOutside()
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent(".config"), withDestinationURL: outside)

        XCTAssertThrowsError(try SetupManifestStore(homeDirectory: home).save(testManifest))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("my-vibe-island/setup-manifest.json").path))
    }

    func testCanonicalEventMatrixMatchesFrozenFixture() throws {
        let expected = try JSONDecoder().decode([String: [String]].self, from: SetupFixtureLoader.data("setup/canonical-events"))
        let actual = Dictionary(uniqueKeysWithValues: SetupIntegrationScanner.defaultSources.map { source in
            (source.id, SetupInstaller.canonicalEvents(for: source.id))
        })

        XCTAssertEqual(actual, expected)
    }

    private func makeTemporaryHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("my-vibe-island-quality").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }
        return home
    }

    private func makeHomeAndOutside() throws -> (URL, URL) {
        let home = try makeTemporaryHome()
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("my-vibe-island-outside").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: outside) }
        return (home, outside)
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
    }

    private func blockManifestParent(in home: URL) throws {
        let parent = home.appendingPathComponent(SetupManifestStore.relativePath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("blocked".utf8).write(to: parent)
    }

    private var testManifest: SetupManifest {
        SetupManifest(helperBinaryPath: "helper", managedBlockMarker: "marker", sourceId: "codex", eventNames: ["Stop"], installedCommand: "helper", configPath: ".codex/hooks.json")
    }
}
