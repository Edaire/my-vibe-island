import XCTest
@testable import MyVibeIslandSetup

final class SetupIntegrationScannerTests: XCTestCase {
    func testDefaultSourcesMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            [DefaultSetupSourceFixture].self,
            from: try SetupFixtureLoader.data("setup/default-sources")
        )
        let actual = SetupIntegrationScanner.defaultSources.map(DefaultSetupSourceFixture.init(source:))

        XCTAssertEqual(actual, expected)
    }

    func testMissingConfigsAreReportedWithoutCreatingFiles() throws {
        let home = try makeTemporaryHome()
        let statuses = SetupIntegrationScanner().scan(homeDirectory: home)

        XCTAssertEqual(statuses.count, 11)
        XCTAssertEqual(statuses.first(where: { $0.sourceId == "claude" })?.issues, [.configMissing])
        XCTAssertEqual(statuses.first(where: { $0.sourceId == "opencode" })?.issues, [.pluginMissing])
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".claude").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".config").path))
    }

    func testHermesPluginDirectoryPresenceIsReported() throws {
        let home = try makeTemporaryHome()
        let plugin = home.appendingPathComponent(".hermes/plugins/vibe-island")
        try write("name: vibe-island\n", to: plugin.appendingPathComponent("plugin.yaml"))
        try write("def register(ctx): pass\n", to: plugin.appendingPathComponent("__init__.py"))

        let status = try XCTUnwrap(SetupIntegrationScanner().scan(homeDirectory: home).first { $0.sourceId == "hermes" })

        XCTAssertEqual(status.issues, [.pluginUnmanaged])
        XCTAssertTrue(status.exists)
    }

    func testJsonConfigWithTopLevelHooksReportsHooksDetected() throws {
        let home = try makeTemporaryHome()
        try write("{\"hooks\":{}}", to: home.appendingPathComponent(".codex/hooks.json"))

        let status = try XCTUnwrap(SetupIntegrationScanner().scan(homeDirectory: home).first { $0.sourceId == "codex" })

        XCTAssertEqual(status.issues, [.hooksDetected])
        XCTAssertTrue(status.exists)
        XCTAssertFalse(status.malformed)
    }

    func testMalformedJsonConfigReportsConfigMalformed() throws {
        let home = try makeTemporaryHome()
        try write("{\"hooks\":", to: home.appendingPathComponent(".cursor/hooks.json"))

        let status = try XCTUnwrap(SetupIntegrationScanner().scan(homeDirectory: home).first { $0.sourceId == "cursor" })

        XCTAssertEqual(status.issues, [.configMalformed])
        XCTAssertTrue(status.exists)
        XCTAssertTrue(status.malformed)
    }

    func testKimiTomlHooksTextReportsHooksDetected() throws {
        let home = try makeTemporaryHome()
        try write("[[hooks]]\nname = \"my-vibe-island\"\n", to: home.appendingPathComponent(".kimi/config.toml"))

        let status = try XCTUnwrap(SetupIntegrationScanner().scan(homeDirectory: home).first { $0.sourceId == "kimi" })

        XCTAssertEqual(status.issues, [.hooksDetected])
        XCTAssertTrue(status.exists)
    }

    func testOpenCodePluginFilePresenceIsReported() throws {
        let home = try makeTemporaryHome()
        try write(OpenCodePluginTemplate.contents, to: home.appendingPathComponent(".config/opencode/plugins/open-island.js"))

        let status = try XCTUnwrap(SetupIntegrationScanner().scan(homeDirectory: home).first { $0.sourceId == "opencode" })

        XCTAssertEqual(status.issues, [.managed])
        XCTAssertTrue(status.exists)
    }

    func testManagedConfigurationsAreReportedAsManaged() throws {
        let home = try makeTemporaryHome()
        _ = try SetupInstaller().install(sourceId: "codex", homeDirectory: home)
        try write("name = \"kimi\"\n", to: home.appendingPathComponent(".kimi/config.toml"))
        _ = try SetupInstaller().install(sourceId: "kimi", homeDirectory: home)

        let statuses = SetupIntegrationScanner().scan(homeDirectory: home)

        XCTAssertEqual(statuses.first(where: { $0.sourceId == "codex" })?.issues, [.managed])
        XCTAssertEqual(statuses.first(where: { $0.sourceId == "kimi" })?.issues, [.managed])
    }

    func testUnmanagedOpenCodePluginFileIsReported() throws {
        let home = try makeTemporaryHome()
        try write("export default {};\n", to: home.appendingPathComponent(".config/opencode/plugins/open-island.js"))

        let status = try XCTUnwrap(SetupIntegrationScanner().scan(homeDirectory: home).first { $0.sourceId == "opencode" })

        XCTAssertEqual(status.issues, [.pluginUnmanaged])
    }

    func testOpenCodeScannerIgnoresAllConfigRegistrationFiles() throws {
        let home = try makeTemporaryHome()
        try write("{\"plugin\":", to: home.appendingPathComponent(".config/opencode/config.json"))
        try write(OpenCodePluginTemplate.contents, to: home.appendingPathComponent(".config/opencode/plugins/open-island.js"))
        let status = try XCTUnwrap(SetupIntegrationScanner().scan(homeDirectory: home).first { $0.sourceId == "opencode" })

        XCTAssertEqual(status.issues, [.managed])
        XCTAssertFalse(status.malformed)
    }

    func testKimiUnknownTomlIsNotClaimedMalformed() throws {
        let home = try makeTemporaryHome()
        try write("inline = { nested = [1, 2] }\nunknown syntax stays verbatim\n", to: home.appendingPathComponent(".kimi/config.toml"))

        let status = try XCTUnwrap(SetupIntegrationScanner().scan(homeDirectory: home).first { $0.sourceId == "kimi" })

        XCTAssertFalse(status.malformed)
        XCTAssertFalse(status.issues.contains(.configMalformed))
    }

    func testCodexScannerDoesNotUseConfigTomlAsHookOwnership() throws {
        let home = try makeTemporaryHome()
        _ = try SetupInstaller().install(sourceId: "codex", homeDirectory: home)
        try FileManager.default.removeItem(at: home.appendingPathComponent(".codex/config.toml"))

        let status = try XCTUnwrap(SetupIntegrationScanner().scan(homeDirectory: home).first { $0.sourceId == "codex" })

        XCTAssertEqual(status.issues, [.managed])
    }

    private func makeTemporaryHome() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-setup-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.data(using: .utf8)?.write(to: url)
    }

    private struct DefaultSetupSourceFixture: Codable, Equatable {
        let id: String
        let displayName: String
        let relativePath: String
        let format: String

        init(id: String, displayName: String, relativePath: String, format: String) {
            self.id = id
            self.displayName = displayName
            self.relativePath = relativePath
            self.format = format
        }

        init(source: SetupIntegrationSource) {
            id = source.id
            displayName = source.displayName
            relativePath = source.relativePath
            format = source.format.rawValue
        }
    }
}
