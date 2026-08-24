import Foundation
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandBundledBridgeInstallerTests: XCTestCase {
    func testInstallCopiesExactBytesAndMakesBridgeExecutable() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        try Data("bridge-v1".utf8).write(to: fixture.source)

        let result = try fixture.installer.install()

        XCTAssertTrue(result.changed)
        XCTAssertEqual(try Data(contentsOf: fixture.destination), Data("bridge-v1".utf8))
        XCTAssertEqual(try fixture.mode(), 0o755)
    }

    func testInstallLeavesIdenticalExecutableBridgeUntouched() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let data = Data("bridge-v1".utf8)
        try data.write(to: fixture.source)
        try FileManager.default.createDirectory(
            at: fixture.destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fixture.destination)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fixture.destination.path
        )

        let result = try fixture.installer.install()

        XCTAssertFalse(result.changed)
        XCTAssertEqual(try Data(contentsOf: fixture.destination), data)
    }

    func testInstallMissingBundledBridgeDoesNotCreateDestination() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.source.path))

        XCTAssertThrowsError(try fixture.installer.install())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
    }

}

private struct Fixture {
    let root: URL
    let source: URL
    let destination: URL
    let installer: MyVibeIslandBundledBridgeInstaller

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandBundledBridgeInstallerTests-" + UUID().uuidString)
        source = root.appendingPathComponent("Vibe Island.app/Contents/Helpers/vibe-island-bridge")
        destination = root.appendingPathComponent("home/.vibe-island/bin/vibe-island-bridge")
        try FileManager.default.createDirectory(
            at: source.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        installer = MyVibeIslandBundledBridgeInstaller(
            sourceURL: source,
            destinationURL: destination
        )
    }

    func mode() throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
