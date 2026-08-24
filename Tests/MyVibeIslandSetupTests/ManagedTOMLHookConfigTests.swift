import Foundation
import XCTest
@testable import MyVibeIslandSetup

final class ManagedTOMLHookConfigTests: XCTestCase {
    func testBoundedFencePreservesUnknownTOMLVerbatimAndUninstallsOnlyOwnedContent() throws {
        let original = "title = \"user\"\ninline = { nested = [1, 2, 3] }\n\n[[foreign.hooks]]\ncommand = \"user-hook\"\n\n"
        let config = try ManagedTOMLHookConfig(contents: original)
        let installed = try config.install(sourceId: "kimi", events: ["SessionStart"], helperCommand: "helper", version: 1)
        XCTAssertTrue(installed.contains("inline = { nested = [1, 2, 3] }"))
        XCTAssertTrue(installed.contains("[[foreign.hooks]]"))
        XCTAssertTrue(installed.contains(ManagedTOMLHookConfig.beginMarker))
        XCTAssertTrue(try ManagedTOMLHookConfig(contents: installed).verify(sourceId: "kimi", events: ["SessionStart"], helperCommand: "helper", version: 1))
        XCTAssertEqual(try ManagedTOMLHookConfig(contents: installed).uninstall(), original)
    }

    func testOnlyUnsafeOwnedBoundariesFailClosed() throws {
        XCTAssertNoThrow(try ManagedTOMLHookConfig(contents: "[[hooks]\nunknown syntax stays verbatim\n"))
        XCTAssertThrowsError(try ManagedTOMLHookConfig(contents: "\(ManagedTOMLHookConfig.beginMarker)\nmanaged_by = \"my-vibe-island\"\n"))
        XCTAssertThrowsError(try ManagedTOMLHookConfig(contents: "\(ManagedTOMLHookConfig.beginMarker)\nname = \"foreign\"\n\(ManagedTOMLHookConfig.endMarker)\n"))
    }

    func testCanonicalKimiBlockIncludesTimeoutAndEveryRequestedEventExactlyOnce() throws {
        let events = ["SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop", "Notification"]
        let installed = try ManagedTOMLHookConfig(contents: "").install(sourceId: "kimi", events: events, helperCommand: "helper", version: 1)

        XCTAssertEqual(installed.components(separatedBy: "timeout = 30").count - 1, events.count)
        for event in events {
            XCTAssertEqual(installed.components(separatedBy: "event = \"\(event)\"").count - 1, 1)
        }
    }
}
