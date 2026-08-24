import XCTest
@testable import MyVibeIslandCore

final class FixtureLoaderTests: XCTestCase {
    func testLoadsBridgeJSONPayloadFixture() throws {
        let payload = try FixtureLoader.bridgePayload("codex/hook-session-start")

        XCTAssertEqual(payload["hook_event_name"], .string("SessionStart"))
        XCTAssertEqual(payload["session_id"], .string("codex-session"))
        XCTAssertEqual(payload["cwd"], .string("/tmp/codex"))
        XCTAssertEqual(payload["model"], .string("gpt-5"))
    }
}
