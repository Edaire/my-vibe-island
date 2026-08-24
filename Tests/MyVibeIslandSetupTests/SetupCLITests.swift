import XCTest
@testable import MyVibeIslandSetup

final class SetupCLITests: XCTestCase {
    func testStatusOutputIsNonMutating() throws {
        let output = try SetupCLI().run(arguments: ["status"])
        XCTAssertTrue(output.contains("My Vibe Island setup status"))
        XCTAssertTrue(output.contains("no user configuration changed"))
    }

    func testStatusAcceptsHomeAndPrintsSourceRows() throws {
        let home = try makeTemporaryHome()
        try write("{\"hooks\":{}}", to: home.appendingPathComponent(".codex/hooks.json"))

        let output = try SetupCLI().run(arguments: ["status", "--home", home.path])

        XCTAssertTrue(output.contains("My Vibe Island setup status: no user configuration changed"))
        XCTAssertTrue(output.contains("- codex: hooks detected (.codex/hooks.json)"))
        XCTAssertTrue(output.contains("- claude: missing (.claude/settings.json)"))
    }

    func testStatusHomeDoesNotCreateMissingConfigDirectories() throws {
        let home = try makeTemporaryHome()

        _ = try SetupCLI().run(arguments: ["status", "--home", home.path])

        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".claude").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".config").path))
    }

    func testDryRunPrintsPlanRowsAndDoesNotCreateDirectories() throws {
        let home = try makeTemporaryHome()
        try write("{\"hooks\":{}}", to: home.appendingPathComponent(".codex/hooks.json"))

        let output = try SetupCLI().run(arguments: ["dryRun", "--home", home.path])

        XCTAssertTrue(output.contains("My Vibe Island setup dry run: no user configuration changed"))
        XCTAssertTrue(output.contains("- codex: would preserve existing hooks (.codex/hooks.json)"))
        XCTAssertTrue(output.contains("- codex: would register managed hooks (.codex/hooks.json)"))
        XCTAssertTrue(output.contains("- claude: would create config file (.claude/settings.json)"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".claude").path))
    }

    func testDryRunAcceptsKebabCaseAlias() throws {
        let home = try makeTemporaryHome()

        let output = try SetupCLI().run(arguments: ["dry-run", "--home", home.path])

        XCTAssertTrue(output.contains("My Vibe Island setup dry run: no user configuration changed"))
    }

    func testExplainSourcePrintsOnlyRequestedSource() throws {
        let home = try makeTemporaryHome()

        let output = try SetupCLI().run(arguments: ["explain", "codex", "--home", home.path])

        XCTAssertTrue(output.contains("My Vibe Island setup explanation: no user configuration changed"))
        XCTAssertTrue(output.contains("- codex: would create config file (.codex/hooks.json)"))
        XCTAssertFalse(output.contains("- claude:"))
    }

    func testExplainUnknownSourceIsNonMutating() throws {
        let home = try makeTemporaryHome()

        let output = try SetupCLI().run(arguments: ["explain", "unknown", "--home", home.path])

        XCTAssertTrue(output.contains("Unknown setup source: unknown"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".config").path))
    }

    func testInstallOpenCodeWritesManagedPluginFile() throws {
        let home = try makeTemporaryHome()

        let output = try SetupCLI().run(arguments: ["install", "opencode", "--home", home.path])

        let pluginURL = home.appendingPathComponent(".config/opencode/plugins/open-island.js")
        XCTAssertTrue(output.contains("installed managed OpenCode plugin"))
        XCTAssertTrue(output.contains("changed"))
        XCTAssertEqual(try String(contentsOf: pluginURL, encoding: .utf8), OpenCodePluginTemplate.contents)
    }

    func testInstallUnknownSourceFailsClosed() throws {
        let home = try makeTemporaryHome()

        XCTAssertThrowsError(try SetupCLI().run(arguments: ["install", "unknown", "--home", home.path]))

        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".config").path))
    }

    func testLifecycleCommandsMutateOnlyManagedIntegration() throws {
        let home = try makeTemporaryHome()

        _ = try SetupCLI().run(arguments: ["install", "opencode", "--home", home.path])
        let verify = try SetupCLI().run(arguments: ["verify", "opencode", "--home", home.path])
        let repair = try SetupCLI().run(arguments: ["repair", "opencode", "--home", home.path])
        let uninstall = try SetupCLI().run(arguments: ["uninstall", "opencode", "--home", home.path])
        let manifest = try SetupCLI().run(arguments: ["print-manifest", "--home", home.path])

        XCTAssertTrue(uninstall.contains("uninstalled managed OpenCode plugin"))
        XCTAssertTrue(repair.contains("already installed") || repair.contains("healthy"))
        XCTAssertTrue(verify.contains("verified"))
        XCTAssertTrue(manifest.contains("- none"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".config/opencode/plugins/open-island.js").path))
    }

    func testStatusReportsUnmanagedOpenCodePlugin() throws {
        let home = try makeTemporaryHome()
        try write("export default {};\n", to: home.appendingPathComponent(".config/opencode/plugins/open-island.js"))

        let output = try SetupCLI().run(arguments: ["status", "--home", home.path])

        XCTAssertTrue(output.contains("- opencode: unmanaged (.config/opencode/plugins/open-island.js)"))
    }

    func testDryRunBlocksUnmanagedOpenCodePlugin() throws {
        let home = try makeTemporaryHome()
        try write("export default {};\n", to: home.appendingPathComponent(".config/opencode/plugins/open-island.js"))

        let output = try SetupCLI().run(arguments: ["dryRun", "--home", home.path])

        XCTAssertTrue(output.contains("- opencode: blocked: manual repair required for unmanaged plugin (.config/opencode/plugins/open-island.js)"))
    }

    private func makeTemporaryHome() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-setup-cli-tests")
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
}
