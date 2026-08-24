import Foundation
import XCTest
@testable import MyVibeIslandCore

final class ClaudeCoworkSessionDiscoveryTests: XCTestCase {
    func testDefaultRootUsesClaudeApplicationSupportDirectory() throws {
        let applicationSupport = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: applicationSupport) }

        let discovery = ClaudeCoworkSessionDiscovery(applicationSupportDirectory: applicationSupport)

        XCTAssertEqual(
            discovery.rootURL,
            applicationSupport.appendingPathComponent("Claude/local-agent-mode-sessions", isDirectory: true)
        )
    }

    func testInjectedHomeDirectoryControlsApplicationSupportRoot() throws {
        let home = try makeTemporaryDirectory()

        let discovery = ClaudeCoworkSessionDiscovery(homeDirectory: home)

        XCTAssertEqual(
            discovery.rootURL,
            home.appendingPathComponent("Library/Application Support/Claude/local-agent-mode-sessions", isDirectory: true)
        )
    }

    func testDiscoverOnlyAcceptsLocalMetadataFilesAndDerivesAuditLogPath() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try write(
            "{\"title\":\"Fix parser\",\"cwd\":\"/tmp/project\",\"model\":\"claude-sonnet\",\"cliSessionId\":\"cli-1\",\"isArchived\":false,\"lastActivityAt\":\"2026-07-20T01:02:03Z\"}",
            to: root.appendingPathComponent("_local-session-1.json")
        )
        try write("{}", to: root.appendingPathComponent("history.json"))
        try write("{}", to: root.appendingPathComponent("_local-invalid.json"))
        try write("{}", to: root.appendingPathComponent("_local-not-json.txt"))

        let result = ClaudeCoworkSessionDiscovery(rootURL: root).discover()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].sessionId, "-session-1")
        XCTAssertEqual(result[0].metadata.title, "Fix parser")
        XCTAssertEqual(result[0].metadata.cwd, "/tmp/project")
        XCTAssertEqual(result[0].metadata.cliSessionId, "cli-1")
        XCTAssertEqual(
            result[0].auditLogURL,
            result[0].metadataURL.deletingPathExtension().appendingPathComponent("audit.log")
        )
    }

    func testLastActivityAtAcceptsMillisecondsAndRejectsEmptyTitles() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try write(
            "{\"title\":\"\",\"lastActivityAt\":1752973323000}",
            to: root.appendingPathComponent("_local-empty.json")
        )
        try write(
            "{\"title\":\"Numeric time\",\"lastActivityAt\":1752973323000}",
            to: root.appendingPathComponent("_local-numeric.json")
        )

        let result = ClaudeCoworkSessionDiscovery(rootURL: root).discover()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].metadata.title, "Numeric time")
        XCTAssertEqual(result[0].metadata.lastActivityAt, Date(timeIntervalSince1970: 1_752_973_323))
    }

    func testDiscoveryIsRecursiveAndCappedAtTwoThousandFiles() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        for index in 0..<2_001 {
            try write(
                "{\"title\":\"Session \(index)\"}",
                to: nested.appendingPathComponent("_local-\(String(format: "%04d", index)).json")
            )
        }

        XCTAssertEqual(ClaudeCoworkSessionDiscovery(rootURL: root).discover().count, 2_000)
    }

    private func write(_ string: String, to url: URL) throws {
        try Data(string.utf8).write(to: url)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-cowork-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
