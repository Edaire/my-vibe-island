import Foundation
import XCTest
@testable import MyVibeIslandSetup

final class ManagedJSONHookConfigTests: XCTestCase {
    func testClaudeInstallUsesNativeHookGroupsAndPreservesUserGroups() throws {
        let original = #"""
        {
          "hooks": {
            "SessionStart": [{
              "matcher": "startup|resume|clear|compact",
              "hooks": [{"type": "command", "command": "user-session-start"}]
            }],
            "PermissionRequest": [{
              "matcher": "*",
              "hooks": [{"type": "command", "command": "user-permission"}]
            }]
          }
        }
        """#
        let config = try ManagedJSONHookConfig(data: Data(original.utf8))

        let updated = try config.install(
            sourceId: "claude",
            events: ["PermissionRequest", "PreCompact", "SessionStart", "Stop"],
            helperCommand: "helper"
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: updated) as? [String: Any])
        let hooks = try XCTUnwrap(object["hooks"] as? [String: Any])

        let sessionStart = try XCTUnwrap(hooks["SessionStart"] as? [[String: Any]])
        XCTAssertEqual(sessionStart.count, 2)
        XCTAssertEqual(sessionStart[0]["matcher"] as? String, "startup|resume|clear|compact")
        assertClaudeGroup(sessionStart[1], event: "SessionStart", matcher: "startup|resume|clear", timeout: nil)

        let permission = try XCTUnwrap(hooks["PermissionRequest"] as? [[String: Any]])
        XCTAssertEqual(permission.count, 2)
        XCTAssertEqual(
            ((permission[0]["hooks"] as? [[String: Any]])?.first?["command"] as? String),
            "user-permission"
        )
        assertClaudeGroup(permission[1], event: "PermissionRequest", matcher: "*", timeout: 86_400)

        let compact = try XCTUnwrap(hooks["PreCompact"] as? [[String: Any]])
        assertClaudeGroup(try XCTUnwrap(compact.first), event: "PreCompact", matcher: "manual|auto", timeout: nil)

        let stop = try XCTUnwrap(hooks["Stop"] as? [[String: Any]])
        assertClaudeGroup(try XCTUnwrap(stop.first), event: "Stop", matcher: nil, timeout: nil)
    }

    func testClaudeVerifyAndUninstallOnlyTouchOwnedGroups() throws {
        let original = #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"user-stop"}]}]}}"#
        let config = try ManagedJSONHookConfig(data: Data(original.utf8))
        let installed = try config.install(
            sourceId: "claude",
            events: ["SessionStart", "Stop"],
            helperCommand: "helper"
        )
        let installedConfig = try ManagedJSONHookConfig(data: installed)
        XCTAssertTrue(installedConfig.verify(
            sourceId: "claude",
            events: ["SessionStart", "Stop"],
            helperCommand: "helper"
        ))

        let removed = try installedConfig.uninstall(sourceId: "claude", helperCommand: "helper")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: removed) as? [String: Any])
        let hooks = try XCTUnwrap(object["hooks"] as? [String: Any])
        XCTAssertNil(hooks["SessionStart"])
        XCTAssertEqual((hooks["Stop"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((((hooks["Stop"] as? [[String: Any]])?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String), "user-stop")
    }

    func testInstallPreservesUnknownKeysAndUserEntries() throws {
        let original = #"{"custom":true,"hooks":{"ForeignEvent":[{"command":"user-hook"}]}}"#
        let config = try ManagedJSONHookConfig(data: Data(original.utf8))

        let updated = try config.install(sourceId: "codex", events: ["SessionStart"], helperCommand: "helper")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: updated) as? [String: Any])
        let hooks = try XCTUnwrap(object["hooks"] as? [String: Any])

        XCTAssertEqual(object["custom"] as? Bool, true)
        XCTAssertEqual((hooks["ForeignEvent"] as? [[String: Any]])?.first?["command"] as? String, "user-hook")
        XCTAssertNotNil(hooks["SessionStart"])
    }

    func testForeignEntryOnCanonicalEventFailsClosed() throws {
        let config = try ManagedJSONHookConfig(data: Data(#"{"hooks":{"SessionStart":[{"command":"user-hook"}]}}"#.utf8))

        XCTAssertThrowsError(try config.install(sourceId: "codex", events: ["SessionStart"], helperCommand: "helper")) { error in
            XCTAssertEqual(error as? ManagedHookConfigError, .unmanagedConflict)
        }
    }

    func testMalformedAndUnmanagedConflictsFailClosedWhileStaleManagedEntriesRemainRepairable() throws {
        XCTAssertThrowsError(try ManagedJSONHookConfig(data: Data(#"{"hooks":"bad"}"#.utf8)))

        let stale = try ManagedJSONHookConfig(data: Data(#"{"hooks":{"SessionStart":[{"command":"other","managedBy":"my-vibe-island","source":"codex","version":99}]}}"#.utf8))
        XCTAssertNoThrow(try stale.install(sourceId: "codex", events: ["SessionStart"], helperCommand: "helper"))
        XCTAssertNoThrow(try stale.uninstall(sourceId: "codex", helperCommand: "helper"))

        let conflict = try ManagedJSONHookConfig(data: Data(#"{"hooks":{"SessionStart":[{"command":"other","managedBy":"my-vibe-island","source":"other","version":1}]}}"#.utf8))
        XCTAssertThrowsError(try conflict.install(sourceId: "codex", events: ["SessionStart"], helperCommand: "helper"))
        XCTAssertThrowsError(try conflict.uninstall(sourceId: "codex", helperCommand: "helper"))
    }

    func testOnlyManagedEntriesAreRemovedAndVerificationChecksCommandEventsAndVersion() throws {
        let config = try ManagedJSONHookConfig(data: Data(#"{"hooks":{"SessionStart":[{"type":"command","command":"helper --source codex --event SessionStart","managedBy":"my-vibe-island","source":"codex","version":1}],"ForeignEvent":[{"command":"user"}]}}"#.utf8))
        XCTAssertTrue(config.verify(sourceId: "codex", events: ["SessionStart"], helperCommand: "helper", version: 1))
        let removed = try config.uninstall(sourceId: "codex", helperCommand: "helper")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: removed) as? [String: Any])
        let hooks = try XCTUnwrap(object["hooks"] as? [String: Any])
        let entries = try XCTUnwrap(hooks["ForeignEvent"] as? [[String: Any]])
        XCTAssertNil(hooks["SessionStart"])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?["command"] as? String, "user")
    }

    private func assertClaudeGroup(
        _ group: [String: Any],
        event: String,
        matcher: String?,
        timeout: Int?
    ) {
        XCTAssertEqual(group["managedBy"] as? String, ManagedJSONHookConfig.marker)
        XCTAssertEqual(group["source"] as? String, "claude")
        XCTAssertEqual(group["matcher"] as? String, matcher)
        let command = ((group["hooks"] as? [[String: Any]])?.first)
        XCTAssertEqual(command?["type"] as? String, "command")
        XCTAssertEqual(command?["command"] as? String, "helper --source claude")
        XCTAssertEqual(command?["timeout"] as? Int, timeout)
    }
}
