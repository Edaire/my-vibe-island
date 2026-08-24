import Foundation
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandResourceResolverTests: XCTestCase {
    func testPrefersMainBundleResource() throws {
        let fixture = try ResourceBundleFixture()
        defer { fixture.cleanup() }
        let mainURL = try fixture.write(
            Data("main".utf8),
            named: "community-config.json",
            to: fixture.mainBundle
        )
        try fixture.write(
            Data("module".utf8),
            named: "community-config.json",
            to: fixture.moduleBundle
        )
        let resolver = MyVibeIslandResourceResolver(
            mainBundle: fixture.mainBundle,
            moduleBundle: fixture.moduleBundle
        )

        let resolved = resolver.url(forResource: "community-config", withExtension: "json")

        XCTAssertEqual(resolved?.standardizedFileURL, mainURL.standardizedFileURL)
    }

    func testFallsBackToModuleBundleResourceInSubdirectory() throws {
        let fixture = try ResourceBundleFixture()
        defer { fixture.cleanup() }
        let moduleURL = try fixture.write(
            Data("sound".utf8),
            named: "onboarding-ceremony.wav",
            subdirectory: "Sounds",
            to: fixture.moduleBundle
        )
        let resolver = MyVibeIslandResourceResolver(
            mainBundle: fixture.mainBundle,
            moduleBundle: fixture.moduleBundle
        )

        let resolved = resolver.url(
            forResource: "onboarding-ceremony",
            withExtension: "wav",
            subdirectory: "Sounds"
        )

        XCTAssertEqual(resolved?.standardizedFileURL, moduleURL.standardizedFileURL)
    }
}

private final class ResourceBundleFixture {
    let root: URL
    let mainBundle: Bundle
    let moduleBundle: Bundle

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandResourceResolverTests-" + UUID().uuidString)
        mainBundle = try Self.makeBundle(named: "Main", under: root)
        moduleBundle = try Self.makeBundle(named: "Module", under: root)
    }

    @discardableResult
    func write(
        _ data: Data,
        named name: String,
        subdirectory: String? = nil,
        to bundle: Bundle
    ) throws -> URL {
        var directory = try XCTUnwrap(bundle.resourceURL)
        if let subdirectory {
            directory.appendPathComponent(subdirectory, isDirectory: true)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    private static func makeBundle(named name: String, under root: URL) throws -> Bundle {
        let bundleURL = root.appendingPathComponent(name + ".bundle", isDirectory: true)
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": "app.vibeisland.tests.\(name).\(UUID().uuidString)",
            "CFBundleName": name,
            "CFBundlePackageType": "BNDL",
            "CFBundleVersion": "1"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
        return try XCTUnwrap(Bundle(url: bundleURL))
    }
}
