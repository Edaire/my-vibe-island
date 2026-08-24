import XCTest
@testable import MyVibeIslandCore

final class CodexBridgePayloadNormalizerTests: XCTestCase {
    func testNormalizesIdaBackedCodexHookFields() throws {
        let payload = try CodexBridgePayloadNormalizer.normalizedPayload(
            eventName: "PermissionRequest",
            input: [
                "session_id": .string("019f-session"),
                "cwd": .string("/tmp/project"),
                "transcript_path": .string("/tmp/codex/transcript.jsonl"),
                "model": .string("gpt-5"),
                "permission_mode": .string("plan"),
                "turn_id": .string("turn-1"),
                "prompt": .string(String(repeating: "x", count: 450)),
                "last_assistant_message": .string("Running bash"),
            ]
        )

        XCTAssertEqual(payload["_source"], .string("codex"))
        XCTAssertEqual(payload["hook_event_name"], .string("PermissionRequest"))
        XCTAssertEqual(payload["session_id"], .string("codex-019f-session"))
        XCTAssertEqual(payload["codex_thread_id"], .string("codex-019f-session"))
        XCTAssertEqual(payload["codex_turn_id"], .string("turn-1"))
        XCTAssertEqual(payload["codex_transcript_path"], .string("/tmp/codex/transcript.jsonl"))
        XCTAssertEqual(payload["codex_model"], .string("gpt-5"))
        XCTAssertEqual(payload["codex_permission_mode"], .string("plan"))
        XCTAssertEqual(payload["codex_last_assistant_message"], .string("Running bash"))

        guard case let .string(prompt)? = payload["prompt"] else {
            return XCTFail("missing prompt")
        }
        XCTAssertEqual(prompt.count, 400)
    }

    func testKeepsAlreadyPrefixedCodexSessionId() throws {
        let payload = try CodexBridgePayloadNormalizer.normalizedPayload(
            eventName: "SessionStart",
            input: [
                "session_id": .string("codex-existing"),
                "cwd": .string("/tmp/project"),
            ]
        )

        XCTAssertEqual(payload["session_id"], .string("codex-existing"))
        XCTAssertEqual(payload["codex_thread_id"], .string("codex-existing"))
    }

}
