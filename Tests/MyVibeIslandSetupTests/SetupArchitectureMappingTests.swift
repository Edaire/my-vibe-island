import XCTest
@testable import MyVibeIslandSetup

final class SetupArchitectureMappingTests: XCTestCase {
    func testMyVibeIslandSetupCLIDelegatesToSetupCLI() throws {
        let output = try MyVibeIslandSetupCLI().run(arguments: [])

        XCTAssertTrue(output.contains("My Vibe Island setup"))
        XCTAssertTrue(output.contains("status"))
    }

    func testSetupCommandParsesDocumentedCommands() {
        XCTAssertEqual(SetupCommand(arguments: ["status"])?.operation, .status)
        XCTAssertEqual(SetupCommand(arguments: ["install", "opencode"])?.operation, .install)
        XCTAssertEqual(SetupCommand(arguments: ["uninstall"])?.operation, .uninstall)
        XCTAssertEqual(SetupCommand(arguments: ["repair"])?.operation, .repair)
        XCTAssertEqual(SetupCommand(arguments: ["verify"])?.operation, .verify)
        XCTAssertEqual(SetupCommand(arguments: ["print-manifest"])?.operation, .printManifest)
        XCTAssertNil(SetupCommand(arguments: ["unknown"]))
    }

    func testSetupManifestRoundTripsInstallRecord() throws {
        let manifest = SetupManifest(
            schemaVersion: 2,
            helperBinaryPath: "/tmp/my-vibe-island-hook",
            managedBlockMarker: "my-vibe-island-managed",
            sourceId: "opencode",
            eventNames: ["SessionStart", "PermissionRequest"],
            installedCommand: "my-vibe-island-hooks",
            configPath: ".config/opencode/plugins/open-island.js",
            lastInstalledVersion: "2026.7.8"
        )

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(SetupManifest.self, from: data)

        XCTAssertEqual(decoded, manifest)
    }

    func testHookInstallerUsesExistingInstallSemantics() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-hook-installer-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: home)
        }

        let result = try HookInstaller().install(sourceId: "opencode", homeDirectory: home)

        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.relativePath, ".config/opencode/plugins/open-island.js")
        XCTAssertTrue(FileManager.default.fileExists(atPath: home.appendingPathComponent(result.relativePath).path))
    }
}
