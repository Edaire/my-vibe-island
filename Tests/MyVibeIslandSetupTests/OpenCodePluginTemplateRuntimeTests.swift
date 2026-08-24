import Foundation
import XCTest
@testable import MyVibeIslandSetup

final class OpenCodePluginTemplateRuntimeTests: XCTestCase {
    func testPermissionAskedSendsBridgeEnvelopeAndReturnsDirective() throws {
        let result = try runPluginFixture(
            eventName: "permission.asked",
            inputJSON: #"{"id":"perm-1","sessionID":"session-1","permission":"bash","cwd":"/tmp/project","metadata":{"k":"v"},"patterns":["*"],"always":true}"#,
            hookOutputJSON: #"{"type":"allow"}"#
        )

        XCTAssertEqual(result.directive["type"] as? String, "allow")
        XCTAssertEqual(result.socketPath, "/tmp/my-vibe-island-runtime-fixture.sock")

        let envelope = result.envelope
        XCTAssertEqual(envelope["schemaVersion"] as? Int, 1)
        XCTAssertEqual(envelope["clientRole"] as? String, "hook")
        XCTAssertEqual(envelope["source"] as? String, "opencode")
        XCTAssertEqual(envelope["requestId"] as? String, "perm-1")
        XCTAssertEqual(envelope["command"] as? String, "hookEvent")

        let payload = try XCTUnwrap(envelope["payload"] as? [String: Any])
        XCTAssertEqual(payload["event"] as? String, "permission")
        XCTAssertEqual(payload["id"] as? String, "perm-1")
        XCTAssertEqual(payload["sessionID"] as? String, "session-1")
        XCTAssertEqual(payload["permission"] as? String, "bash")
        XCTAssertEqual(payload["cwd"] as? String, "/tmp/project")
        XCTAssertEqual((payload["metadata"] as? [String: Any])?["k"] as? String, "v")
        XCTAssertEqual(payload["patterns"] as? [String], ["*"])
        XCTAssertEqual(payload["always"] as? Bool, true)
    }

    func testQuestionAskedSendsBridgeEnvelopeAndReturnsAnswerDirective() throws {
        let result = try runPluginFixture(
            eventName: "question.asked",
            inputJSON: #"{"id":"question-1","sessionID":"session-1","cwd":"/tmp/project"}"#,
            hookOutputJSON: #"{"type":"answer","text":"Use option A"}"#
        )

        XCTAssertEqual(result.directive["type"] as? String, "answer")
        XCTAssertEqual(result.directive["text"] as? String, "Use option A")

        let envelope = result.envelope
        XCTAssertEqual(envelope["source"] as? String, "opencode")
        XCTAssertEqual(envelope["requestId"] as? String, "question-1")
        XCTAssertEqual(envelope["command"] as? String, "hookEvent")

        let payload = try XCTUnwrap(envelope["payload"] as? [String: Any])
        XCTAssertEqual(payload["event"] as? String, "question")
        XCTAssertEqual(payload["id"] as? String, "question-1")
        XCTAssertEqual(payload["sessionID"] as? String, "session-1")
        XCTAssertEqual(payload["cwd"] as? String, "/tmp/project")
    }

    private struct FixtureResult {
        let directive: [String: Any]
        let envelope: [String: Any]
        let socketPath: String
    }

    private func runPluginFixture(eventName: String, inputJSON: String, hookOutputJSON: String) throws -> FixtureResult {
        let bunPath = try requireExecutable("bun")
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-opencode-plugin-runtime-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }

        let pluginURL = root.appendingPathComponent("open-island.js")
        let fakeHookURL = root.appendingPathComponent("fake-hook.sh")
        let captureURL = root.appendingPathComponent("capture.json")
        let runnerURL = root.appendingPathComponent("runner.js")

        try OpenCodePluginTemplate.contents.write(to: pluginURL, atomically: true, encoding: .utf8)
        try """
        #!/bin/sh
        CAPTURE_PATH="$MY_VIBE_ISLAND_CAPTURE_PATH"
        SOCKET=""
        INPUT=""
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --socket)
              shift
              SOCKET="$1"
              ;;
            --input)
              shift
              INPUT="$1"
              ;;
          esac
          shift
        done
        printf '{"socket":%s,"input":%s}\\n' "$(printf '%s' "$SOCKET" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" "$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" > "$CAPTURE_PATH"
        printf '%s\\n' "$MY_VIBE_ISLAND_FAKE_HOOK_OUTPUT"
        """.write(to: fakeHookURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeHookURL.path)
        try """
        import { MyVibeIslandOpenCodePlugin } from "./open-island.js"

        const plugin = await MyVibeIslandOpenCodePlugin()
        const input = JSON.parse(process.env.MY_VIBE_ISLAND_FIXTURE_INPUT)
        const result = await plugin[process.env.MY_VIBE_ISLAND_FIXTURE_EVENT](input)
        console.log(JSON.stringify(result ?? null))
        """.write(to: runnerURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bunPath)
        process.arguments = [runnerURL.path]
        process.currentDirectoryURL = root
        var environment = ProcessInfo.processInfo.environment
        environment["MY_VIBE_ISLAND_HOOKS_COMMAND"] = fakeHookURL.path
        environment["MY_VIBE_ISLAND_SOCKET_PATH"] = "/tmp/my-vibe-island-runtime-fixture.sock"
        environment["MY_VIBE_ISLAND_CAPTURE_PATH"] = captureURL.path
        environment["MY_VIBE_ISLAND_FAKE_HOOK_OUTPUT"] = hookOutputJSON
        environment["MY_VIBE_ISLAND_FIXTURE_INPUT"] = inputJSON
        environment["MY_VIBE_ISLAND_FIXTURE_EVENT"] = eventName
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        let stdoutText = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(process.terminationStatus, 0, stderrText)

        let directive = try decodeObject(stdoutText)
        let capture = try decodeObject(try String(contentsOf: captureURL, encoding: .utf8))
        let socketPath = try XCTUnwrap(capture["socket"] as? String)
        let input = try XCTUnwrap(capture["input"] as? String)
        let envelope = try decodeObject(input)
        return FixtureResult(directive: directive, envelope: envelope, socketPath: socketPath)
    }

    private func requireExecutable(_ name: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", name]
        let stdout = Pipe()
        process.standardOutput = stdout
        try process.run()
        process.waitUntilExit()
        let path = (String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !path.isEmpty else {
            throw XCTSkip("\(name) is not installed")
        }
        return path
    }

    private func decodeObject(_ json: String) throws -> [String: Any] {
        let data = Data(json.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
