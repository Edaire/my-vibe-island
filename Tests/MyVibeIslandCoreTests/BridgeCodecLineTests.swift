import XCTest
@testable import MyVibeIslandCore

final class BridgeCodecLineTests: XCTestCase {
    func testDecodesOriginalVibeIslandBridgeCodexHookLine() throws {
        let line = #"{"session_id":"codex-compat-probe","hook_event_name":"SessionStart","_source":"codex","cwd":"/tmp/compat-probe","codex_thread_id":"compat-probe","codex_event_type":"hook-session-start"}"#

        let envelope = try BridgeCodec().decodeRequestLine(line)

        XCTAssertEqual(envelope.schemaVersion, 1)
        XCTAssertEqual(envelope.clientRole, "original-bridge")
        XCTAssertEqual(envelope.source, "codex")
        XCTAssertEqual(envelope.command, .hookEvent)
        XCTAssertEqual(envelope.payload["session_id"], .string("codex-compat-probe"))
        XCTAssertEqual(envelope.payload["hook_event_name"], .string("SessionStart"))
        XCTAssertEqual(envelope.payload["codex_thread_id"], .string("compat-probe"))
    }

    func testOriginalBridgePermissionUsesStableSessionRequestID() throws {
        let line = #"{"session_id":"codex-compat-permission","hook_event_name":"PermissionRequest","_source":"codex","cwd":"/tmp/compat-probe","tool_name":"Bash"}"#

        let envelope = try BridgeCodec().decodeRequestLine(line)

        XCTAssertEqual(envelope.requestId, "original-bridge:codex-compat-permission")
    }

    func testOriginalBridgeResponseWritesSourceDirectiveWithoutEnvelope() throws {
        let response = BridgeResponse.ok(
            message: "action resolved locally",
            sourceDirective: .object([
                "continue": .bool(true),
                "hookSpecificOutput": .object([
                    "hookEventName": .string("PermissionRequest"),
                    "decision": .object(["behavior": .string("allow")]),
                ]),
            ])
        )

        XCTAssertEqual(
            try BridgeCodec().encodeOriginalBridgeResponseLine(response),
            #"{"continue":true,"hookSpecificOutput":{"decision":{"behavior":"allow"},"hookEventName":"PermissionRequest"}}"# + "\n"
        )
    }

    func testBridgeCodecLineMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            BridgeCodecLineMatrixFixture.self,
            from: try FixtureLoader.data("runtime/bridge-codec-line-matrix")
        )
        let codec = BridgeCodec()

        let decodedEnvelope = try codec.decodeEnvelopeLine(
            " \t\n" + #"{"schemaVersion":1,"clientRole":"hook","source":"codex","requestId":"req-1","command":"hookEvent","payload":{"rawEventName":"SessionStart"}}"# + "\n"
        )
        let encodedEnvelopeLine = try codec.encodeEnvelopeLine(BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: "request-1",
            command: .hello,
            payload: ["clientVersion": .string("test")],
            sentAt: "2026-07-09T03:00:00Z"
        ))
        let encodedOKLine = try codec.encodeResponseLine(.ok(message: "reachable"))
        let encodedFailureLine = try codec.encodeResponseLine(.failure(
            message: "blocked",
            sourceDirective: .object(["type": .string("deny")])
        ))
        let decodedResponse = try codec.decodeResponseLine(" \t\n" + #"{"ok":false,"message":"blocked"}"# + "\n\t ")

        let actual = BridgeCodecLineMatrixFixture(rows: [
            BridgeCodecLineRowFixture(
                id: "decode-envelope-trims-line",
                decodedCommand: decodedEnvelope.command.rawValue,
                decodedSource: decodedEnvelope.source,
                decodedResponseOK: nil,
                decodedResponseMessage: nil,
                encodedTrailingNewlineCount: nil,
                encodedDecodesBack: nil,
                encodedContainsSourceDirective: nil
            ),
            try encodedEnvelopeRow(id: "encode-envelope-single-newline", line: encodedEnvelopeLine),
            try encodedResponseRow(id: "encode-ok-response-single-newline", response: .ok(message: "reachable"), line: encodedOKLine),
            try encodedResponseRow(
                id: "encode-failure-response-source-directive",
                response: .failure(message: "blocked", sourceDirective: .object(["type": .string("deny")])),
                line: encodedFailureLine
            ),
            BridgeCodecLineRowFixture(
                id: "decode-response-trims-line",
                decodedCommand: nil,
                decodedSource: nil,
                decodedResponseOK: decodedResponse.ok,
                decodedResponseMessage: decodedResponse.message,
                encodedTrailingNewlineCount: nil,
                encodedDecodesBack: nil,
                encodedContainsSourceDirective: nil
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    private func XCTAssertExactlyOneTrailingNewline(
        _ line: String,
        file: StaticString = #filePath,
        line testLine: UInt = #line
    ) {
        let trailingNewlineCount = line.reversed().prefix(while: { $0 == "\n" }).count
        XCTAssertEqual(trailingNewlineCount, 1, file: file, line: testLine)
    }

    func testDecodeEnvelopeFromJSONLine() throws {
        let line = #"{"schemaVersion":1,"clientRole":"hook","source":"codex","requestId":null,"command":"hello","payload":{"clientVersion":"test"}}"# + "\n"

        let envelope = try BridgeCodec().decodeEnvelopeLine(line)

        XCTAssertEqual(envelope.command, .hello)
        XCTAssertEqual(envelope.payload["clientVersion"], .string("test"))
    }

    func testEncodeResponseAddsTrailingNewline() throws {
        let line = try BridgeCodec().encodeResponseLine(.ok(message: "reachable"))

        XCTAssertTrue(line.hasSuffix("\n"))
        XCTAssertTrue(line.contains(#""ok":true"#))
    }

    func testEncodeEnvelopeLineAddsExactlyOneTrailingNewlineAndDecodesBackToEnvelope() throws {
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: "request-1",
            command: .hello,
            payload: ["clientVersion": .string("test")],
            sentAt: "2026-07-07T00:00:00Z"
        )

        let line = try BridgeCodec().encodeEnvelopeLine(envelope)

        XCTAssertExactlyOneTrailingNewline(line)
        XCTAssertEqual(try BridgeCodec().decodeEnvelopeLine(line), envelope)
    }

    func testDecodeResponseLineTrimsSurroundingWhitespaceAndNewlines() throws {
        let line = " \t\n" + #"{"ok":true,"message":"reachable"}"# + "\n\t "

        let response = try BridgeCodec().decodeResponseLine(line)

        XCTAssertEqual(response, .ok(message: "reachable"))
    }

    func testEncodeResponseLineAddsExactlyOneTrailingNewlineAndDecodesBackToResponse() throws {
        let response = BridgeResponse.ok(message: "reachable")

        let line = try BridgeCodec().encodeResponseLine(response)

        XCTAssertExactlyOneTrailingNewline(line)
        XCTAssertEqual(try BridgeCodec().decodeResponseLine(line), response)
    }

    private func encodedEnvelopeRow(id: String, line: String) throws -> BridgeCodecLineRowFixture {
        BridgeCodecLineRowFixture(
            id: id,
            decodedCommand: nil,
            decodedSource: nil,
            decodedResponseOK: nil,
            decodedResponseMessage: nil,
            encodedTrailingNewlineCount: trailingNewlineCount(line),
            encodedDecodesBack: try BridgeCodec().decodeEnvelopeLine(line).command == .hello,
            encodedContainsSourceDirective: nil
        )
    }

    private func encodedResponseRow(id: String, response: BridgeResponse, line: String) throws -> BridgeCodecLineRowFixture {
        BridgeCodecLineRowFixture(
            id: id,
            decodedCommand: nil,
            decodedSource: nil,
            decodedResponseOK: nil,
            decodedResponseMessage: nil,
            encodedTrailingNewlineCount: trailingNewlineCount(line),
            encodedDecodesBack: try BridgeCodec().decodeResponseLine(line) == response,
            encodedContainsSourceDirective: line.contains(#""sourceDirective""#)
        )
    }

    private func trailingNewlineCount(_ line: String) -> Int {
        line.reversed().prefix(while: { $0 == "\n" }).count
    }

    private struct BridgeCodecLineMatrixFixture: Codable, Equatable {
        let rows: [BridgeCodecLineRowFixture]
    }

    private struct BridgeCodecLineRowFixture: Codable, Equatable {
        let id: String
        let decodedCommand: String?
        let decodedSource: String?
        let decodedResponseOK: Bool?
        let decodedResponseMessage: String?
        let encodedTrailingNewlineCount: Int?
        let encodedDecodesBack: Bool?
        let encodedContainsSourceDirective: Bool?
    }
}
