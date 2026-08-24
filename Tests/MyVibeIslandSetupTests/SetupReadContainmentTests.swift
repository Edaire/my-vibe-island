import Foundation
import XCTest
@testable import MyVibeIslandSetup

final class SetupReadContainmentTests: XCTestCase {
    func testManifestLoadAndAllRejectExternalSymlinkWithoutReturningData() throws {
        let (home, outside) = try makeHomeAndOutside()
        let manifestURL = outside.appendingPathComponent(".config/my-vibe-island/setup-manifest.json")
        try writeManifest(to: manifestURL)
        try FileManager.default.createSymbolicLink(
            at: home.appendingPathComponent(".config"),
            withDestinationURL: outside.appendingPathComponent(".config")
        )

        XCTAssertThrowsError(try SetupManifestStore(homeDirectory: home).load(sourceId: "outside")) { error in
            XCTAssertNotNil(error as? SetupPathError)
        }
        XCTAssertThrowsError(try SetupManifestStore(homeDirectory: home).all()) { error in
            XCTAssertNotNil(error as? SetupPathError)
        }
    }

    func testVerifyRejectsExternalSymlinkForEveryConfigFormat() throws {
        for sourceId in ["cursor", "kimi", "opencode"] {
            let (home, _) = try externalManagedSource(sourceId)

            XCTAssertThrowsError(try SetupInstaller().verify(sourceId: sourceId, homeDirectory: home), sourceId) { error in
                XCTAssertNotNil(error as? SetupPathError, sourceId)
            }
        }
    }

    func testStatusReportsExternalSymlinkAsUnreadableForEveryConfigFormat() throws {
        for sourceId in ["cursor", "kimi", "opencode"] {
            let (home, _) = try externalManagedSource(sourceId)

            let status = try SetupInstaller().status(sourceId: sourceId, homeDirectory: home)

            XCTAssertEqual(status.issues, [.configUnreadable], sourceId)
            XCTAssertFalse(status.readable, sourceId)
        }
    }

    func testStatusCLIFailsClosedWithoutReportingExternalManagedConfig() throws {
        let (home, _) = try externalManagedSource("cursor")

        let output = try SetupCLI().run(arguments: ["status", "--home", home.path])

        XCTAssertTrue(output.contains("- cursor: unreadable (.cursor/hooks.json)"))
        XCTAssertFalse(output.contains("- cursor: managed"))
    }

    func testDryRunFailsClosedWithoutPlanningFromExternalConfig() throws {
        let (home, _) = try externalManagedSource("cursor")

        let output = try SetupCLI().run(arguments: ["dry-run", "--home", home.path])

        XCTAssertTrue(output.contains("- cursor: blocked: manual repair required for unreadable config (.cursor/hooks.json)"))
        XCTAssertFalse(output.contains("- cursor: no change needed"))
    }

    func testExplainFailsClosedWithoutPlanningFromExternalConfig() throws {
        let (home, _) = try externalManagedSource("cursor")

        let output = try SetupCLI().run(arguments: ["explain", "cursor", "--home", home.path])

        XCTAssertTrue(output.contains("- cursor: blocked: manual repair required for unreadable config (.cursor/hooks.json)"))
        XCTAssertFalse(output.contains("- cursor: no change needed"))
    }

    func testPrintManifestRejectsExternalSymlinkWithoutPrintingData() throws {
        let (home, outside) = try makeHomeAndOutside()
        try writeManifest(to: outside.appendingPathComponent(".config/my-vibe-island/setup-manifest.json"))
        try FileManager.default.createSymbolicLink(
            at: home.appendingPathComponent(".config"),
            withDestinationURL: outside.appendingPathComponent(".config")
        )

        XCTAssertThrowsError(try SetupCLI().run(arguments: ["print-manifest", "--home", home.path])) { error in
            XCTAssertNotNil(error as? SetupPathError)
        }
    }

    private func externalManagedSource(_ sourceId: String) throws -> (URL, URL) {
        let (home, outside) = try makeHomeAndOutside()
        let source = try XCTUnwrap(SetupIntegrationScanner.defaultSources.first { $0.id == sourceId })
        if sourceId == "kimi" {
            try write("name = \"kimi\"\n", to: outside.appendingPathComponent(source.relativePath))
        }
        _ = try SetupInstaller().install(sourceId: sourceId, homeDirectory: outside)
        let topComponent = try XCTUnwrap(source.relativePath.split(separator: "/").first.map(String.init))
        try FileManager.default.createSymbolicLink(
            at: home.appendingPathComponent(topComponent),
            withDestinationURL: outside.appendingPathComponent(topComponent)
        )
        return (home, outside)
    }

    private func makeHomeAndOutside() throws -> (URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("my-vibe-island-read-containment").appendingPathComponent(UUID().uuidString)
        let home = root.appendingPathComponent("home")
        let outside = root.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (home, outside)
    }

    private func writeManifest(to url: URL) throws {
        let manifest = SetupManifest(
            helperBinaryPath: "outside-helper",
            managedBlockMarker: "outside-marker",
            sourceId: "outside",
            eventNames: ["OutsideEvent"],
            installedCommand: "outside-command",
            configPath: "outside-path"
        )
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode([manifest]).write(to: url)
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
    }
}
