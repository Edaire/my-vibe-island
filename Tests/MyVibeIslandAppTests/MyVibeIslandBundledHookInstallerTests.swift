import Foundation
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandBundledHookInstallerTests: XCTestCase {
    func testInstallCopiesExactHookBytesAndMakesDestinationExecutable() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let sourceData = Data("hook-current-build".utf8)
        try sourceData.write(to: fixture.source)

        let result = try fixture.installer.install()

        XCTAssertEqual(result.sourceURL, fixture.source)
        XCTAssertEqual(result.destinationURL, fixture.destination)
        XCTAssertTrue(result.changed)
        XCTAssertEqual(try Data(contentsOf: fixture.destination), sourceData)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: fixture.destination.path))
    }

    func testInstallDoesNotRewriteMatchingExecutableHook() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let contents = Data("hook-current-build".utf8)
        try contents.write(to: fixture.source)
        try FileManager.default.createDirectory(
            at: fixture.destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: fixture.destination)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fixture.destination.path
        )

        let result = try fixture.installer.install()

        XCTAssertFalse(result.changed)
        XCTAssertEqual(try Data(contentsOf: fixture.destination), contents)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: fixture.destination.path))
    }

    func testCodexPermissionTimeoutInstallerUpdatesOnlyMyNestedPermissionHook() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexPermissionTimeoutInstallerTests-" + UUID().uuidString)
        let configURL = root.appendingPathComponent(".codex/hooks.json")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"""
        {
          "hooks": {
            "PermissionRequest": [
              {"hooks": [{"type": "command", "command": "'/Users/test/.my-vibe-island/bin/my-vibe-island-hooks' --source codex", "timeout": 5}]},
              {"hooks": [{"type": "command", "command": "'/Users/test/.vibe-island/bin/vibe-island-bridge' --source codex", "timeout": 7200}]}
            ],
            "Stop": [
              {"hooks": [{"type": "command", "command": "'/Users/test/.my-vibe-island/bin/my-vibe-island-hooks' --source codex", "timeout": 5}]}
            ]
          }
        }
        """#.write(to: configURL, atomically: true, encoding: .utf8)

        let changed = try CodexPermissionRequestTimeoutInstaller.production(homeDirectory: root).install()

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as? [String: Any]
        )
        let hooks = try XCTUnwrap(object["hooks"] as? [String: [[String: Any]]])
        let permissionEntries = try XCTUnwrap(hooks["PermissionRequest"])
        let myPermissionHook = try XCTUnwrap(
            (permissionEntries[0]["hooks"] as? [[String: Any]])?.first
        )
        let originalPermissionHook = try XCTUnwrap(
            (permissionEntries[1]["hooks"] as? [[String: Any]])?.first
        )
        let myStopHook = try XCTUnwrap(
            (try XCTUnwrap(hooks["Stop"]))[0]["hooks"] as? [[String: Any]]
        ).first

        XCTAssertTrue(changed)
        XCTAssertEqual(myPermissionHook["timeout"] as? Int, 7_200)
        XCTAssertEqual(originalPermissionHook["timeout"] as? Int, 7_200)
        XCTAssertEqual(myStopHook?["timeout"] as? Int, 5)
    }
}

private struct Fixture {
    let root: URL
    let source: URL
    let destination: URL
    let installer: MyVibeIslandBundledHookInstaller

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandBundledHookInstallerTests-" + UUID().uuidString)
        source = root.appendingPathComponent("Vibe Island.app/Contents/Resources/Hooks/my-vibe-island-hooks")
        destination = root.appendingPathComponent("home/.my-vibe-island/bin/my-vibe-island-hooks")
        try FileManager.default.createDirectory(
            at: source.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        installer = MyVibeIslandBundledHookInstaller(
            sourceURL: source,
            destinationURL: destination
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
