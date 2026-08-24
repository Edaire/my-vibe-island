import Foundation
import XCTest
@testable import MyVibeIslandCore

final class ClaudeCoworkAuditTailReaderTests: XCTestCase {
    func testFileWithinLimitReturnsWholeText() throws {
        let url = try temporaryFile(contents: "first\nsecond\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try ClaudeCoworkAuditTailReader().read(from: url, maximumBytes: 1_024)

        XCTAssertEqual(result, "first\nsecond\n")
    }

    func testTruncatedTailDropsThePartialFirstLine() throws {
        let contents = "first\npartial\nnew line\n"
        let url = try temporaryFile(contents: contents)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try ClaudeCoworkAuditTailReader().read(from: url, maximumBytes: 15)

        XCTAssertEqual(result, "new line\n")
    }

    func testZeroLimitReturnsEmptyText() throws {
        let url = try temporaryFile(contents: "one\n")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try ClaudeCoworkAuditTailReader().read(from: url, maximumBytes: 0)

        XCTAssertEqual(result, "")
    }

    private func temporaryFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-audit-\(UUID().uuidString).log")
        try Data(contents.utf8).write(to: url)
        return url
    }
}
