import Foundation
@testable import MyVibeIslandCore
import XCTest

final class SessionCompletionTraceLogTests: XCTestCase {
    func testAppendIncludesFractionalSecondsForTraceOrdering() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("trace.log")
        defer { try? FileManager.default.removeItem(at: directory) }

        SessionCompletionTraceLog.append(
            stage: "hover.tick",
            sessionId: "session-a",
            fileURL: fileURL,
            now: Date(timeIntervalSince1970: 1_787_033_361.123)
        )

        let contents = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(contents.hasPrefix("2026-08-18T"))
        XCTAssertTrue(contents.contains(".123Z"))
    }

    func testAppendRotatesLargeMetadataValuesAndKeepsTheActiveTraceFileBounded() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("trace.log")
        defer { try? FileManager.default.removeItem(at: directory) }

        let oversizedValue = String(repeating: "x", count: 512)
        SessionCompletionTraceLog.append(
            stage: "first",
            sessionId: "session-a",
            metadata: ["message": oversizedValue],
            fileURL: fileURL,
            maximumFileBytes: 120,
            maximumMetadataValueCharacters: 24
        )
        SessionCompletionTraceLog.append(
            stage: "second",
            sessionId: "session-b",
            metadata: ["message": oversizedValue],
            fileURL: fileURL,
            maximumFileBytes: 120,
            maximumMetadataValueCharacters: 24
        )

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let previousContents = try String(contentsOf: fileURL.appendingPathExtension("1"), encoding: .utf8)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)

        XCTAssertLessThanOrEqual(attributes[.size] as? Int ?? .max, 120)
        XCTAssertTrue(contents.contains("stage=second"))
        XCTAssertFalse(contents.contains("stage=first"))
        XCTAssertTrue(previousContents.contains("stage=first"))
        XCTAssertTrue(contents.contains("message=xxxxxxxxxxxxxxxxxxxxxxxx..."))
    }

    func testAppendIncludesOriginatingProcessID() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("trace.log")
        defer { try? FileManager.default.removeItem(at: directory) }

        SessionCompletionTraceLog.append(
            stage: "origin",
            sessionId: "session-a",
            fileURL: fileURL
        )

        let contents = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(contents.contains("pid=\(ProcessInfo.processInfo.processIdentifier)"))
    }
}
