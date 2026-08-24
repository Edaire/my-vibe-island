import XCTest
@testable import MyVibeIslandCore

final class BridgeCodecTests: XCTestCase {
    func testBridgeCodecStructuredMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            BridgeCodecStructuredMatrixFixture.self,
            from: try FixtureLoader.data("runtime/bridge-codec-structured-matrix")
        )

        let hookEvent = try JSONDecoder().decode(BridgeEnvelope.self, from: Data("""
        {"schemaVersion":1,"clientRole":"hook","source":"codex","requestId":"req-1","command":"hookEvent","payload":{"rawEventName":"SessionStart"}}
        """.utf8))
        let hello = try JSONDecoder().decode(BridgeEnvelope.self, from: Data("""
        {"schemaVersion":1,"clientRole":"agent","source":"codex","requestId":"req-2","command":"hello","payload":{"supportedCommands":["hookEvent","resolveAction"],"metadata":{"agentSpecific":{"mode":"interactive","supportsStreaming":true}}}}
        """.utf8))
        let environmentEnvelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: "req-3",
            command: .hookEvent,
            payload: ["rawEventName": .string("SessionStart")],
            environment: HookEnvironment(
                cwd: "/tmp/project",
                shell: "zsh",
                terminal: "iTerm.app",
                pid: 42,
                user: "fixture-user",
                termProgram: "iTerm.app",
                tmuxPane: "%2",
                weztermPane: "pane-1",
                sshTTY: "/dev/ttys001"
            )
        )

        let actual = BridgeCodecStructuredMatrixFixture(
            envelopes: [
                envelopeRow(id: "hook-event-command", envelope: hookEvent),
                envelopeRow(id: "hello-structured-payload", envelope: hello),
                envelopeRow(id: "hook-environment-fields", envelope: environmentEnvelope),
            ],
            responses: [
                responseRow(id: "ok-message", response: .ok(message: "reachable")),
                responseRow(
                    id: "failure-source-directive",
                    response: .failure(
                        message: "blocked",
                        sourceDirective: .object(["type": .string("deny")])
                    )
                ),
            ]
        )

        XCTAssertEqual(actual, expected)
    }

    func testEnvelopeDecodesKnownHookEventCommand() throws {
        let json = """
        {"schemaVersion":1,"clientRole":"hook","source":"codex","requestId":"req-1","command":"hookEvent","payload":{"rawEventName":"SessionStart"}}
        """
        let envelope = try JSONDecoder().decode(BridgeEnvelope.self, from: Data(json.utf8))
        XCTAssertEqual(envelope.schemaVersion, 1)
        XCTAssertEqual(envelope.command, .hookEvent)
        XCTAssertEqual(envelope.payload["rawEventName"], .string("SessionStart"))
    }

    func testEnvelopeDecodesHelloPayloadWithStructuredValues() throws {
        let json = """
        {"schemaVersion":1,"clientRole":"agent","source":"codex","requestId":"req-2","command":"hello","payload":{"supportedCommands":["hookEvent","resolveAction"],"metadata":{"agentSpecific":{"mode":"interactive","supportsStreaming":true}}}}
        """
        let envelope = try JSONDecoder().decode(BridgeEnvelope.self, from: Data(json.utf8))
        XCTAssertEqual(envelope.command, .hello)
        XCTAssertEqual(envelope.payload["supportedCommands"], .array([.string("hookEvent"), .string("resolveAction")]))
        XCTAssertEqual(
            envelope.payload["metadata"],
            .object([
                "agentSpecific": .object([
                    "mode": .string("interactive"),
                    "supportsStreaming": .bool(true)
                ])
            ])
        )
    }

    func testEnvelopeDecodesHookEnvironment() throws {
        let json = """
        {"schemaVersion":1,"clientRole":"hook","source":"codex","requestId":"req-1","command":"hookEvent","payload":{"rawEventName":"SessionStart"},"environment":{"cwd":"/tmp/project","shell":"zsh","terminal":"iTerm.app","pid":42,"user":"fixture-user","termProgram":"iTerm.app","tmuxPane":"%2","weztermPane":"pane-1","sshTTY":"/dev/ttys001"}}
        """
        let envelope = try JSONDecoder().decode(BridgeEnvelope.self, from: Data(json.utf8))

        XCTAssertEqual(
            envelope.environment,
            HookEnvironment(
                cwd: "/tmp/project",
                shell: "zsh",
                terminal: "iTerm.app",
                pid: 42,
                user: "fixture-user",
                termProgram: "iTerm.app",
                tmuxPane: "%2",
                weztermPane: "pane-1",
                sshTTY: "/dev/ttys001"
            )
        )
        XCTAssertEqual(envelope.environment?.termProgram, "iTerm.app")
        XCTAssertEqual(envelope.environment?.tmuxPane, "%2")
        XCTAssertEqual(envelope.environment?.weztermPane, "pane-1")
        XCTAssertEqual(envelope.environment?.sshTTY, "/dev/ttys001")
    }

    func testEnvelopeEncodesHookEnvironment() throws {
        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: "codex",
            requestId: "req-1",
            command: .hookEvent,
            payload: ["rawEventName": .string("SessionStart")],
            environment: HookEnvironment(
                cwd: "/tmp/project",
                shell: "zsh",
                terminal: "iTerm.app",
                pid: 42,
                user: "fixture-user",
                termProgram: "iTerm.app",
                tmuxPane: "%2",
                weztermPane: "pane-1",
                sshTTY: "/dev/ttys001"
            )
        )

        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)

        XCTAssertEqual(decoded.environment?.terminal, "iTerm.app")
        XCTAssertEqual(decoded.environment?.pid, 42)
        XCTAssertEqual(decoded.environment?.tmuxPane, "%2")
        XCTAssertEqual(decoded.environment?.weztermPane, "pane-1")
        XCTAssertEqual(decoded.environment?.sshTTY, "/dev/ttys001")
    }

    func testResponseEncodesOkAndMessage() throws {
        let response = BridgeResponse.ok(message: "reachable")
        let data = try JSONEncoder().encode(response)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains(#""ok":true"#))
        XCTAssertTrue(text.contains(#""message":"reachable""#))
    }

    func testResponseEncodesAndDecodesSourceDirective() throws {
        let response = BridgeResponse.ok(
            message: "resolved",
            sourceDirective: .object([
                "type": .string("allow"),
            ])
        )

        let line = try BridgeCodec().encodeResponseLine(response)
        let decoded = try BridgeCodec().decodeResponseLine(line)

        XCTAssertTrue(line.contains(#""sourceDirective""#))
        XCTAssertEqual(decoded, response)
    }

    private func envelopeRow(id: String, envelope: BridgeEnvelope) -> BridgeEnvelopeFixture {
        BridgeEnvelopeFixture(
            id: id,
            schemaVersion: envelope.schemaVersion,
            clientRole: envelope.clientRole,
            source: envelope.source,
            requestId: envelope.requestId,
            command: envelope.command.rawValue,
            payloadKeys: envelope.payload.keys.sorted(),
            supportedCommandCount: arrayCount(for: "supportedCommands", in: envelope.payload),
            metadataKeys: objectKeys(for: "metadata", in: envelope.payload),
            environment: envelope.environment.map(BridgeEnvironmentFixture.init(environment:))
        )
    }

    private func responseRow(id: String, response: BridgeResponse) -> BridgeResponseFixture {
        BridgeResponseFixture(
            id: id,
            ok: response.ok,
            message: response.message,
            hasSourceDirective: response.sourceDirective != nil,
            sourceDirectiveKeys: objectKeys(response.sourceDirective)
        )
    }

    private func arrayCount(for key: String, in payload: [String: BridgeJSONValue]) -> Int {
        guard case let .array(values) = payload[key] else {
            return 0
        }

        return values.count
    }

    private func objectKeys(for key: String, in payload: [String: BridgeJSONValue]) -> [String] {
        objectKeys(payload[key])
    }

    private func objectKeys(_ value: BridgeJSONValue?) -> [String] {
        guard case let .object(object) = value else {
            return []
        }

        return object.keys.sorted()
    }

    private struct BridgeCodecStructuredMatrixFixture: Codable, Equatable {
        let envelopes: [BridgeEnvelopeFixture]
        let responses: [BridgeResponseFixture]
    }

    private struct BridgeEnvelopeFixture: Codable, Equatable {
        let id: String
        let schemaVersion: Int
        let clientRole: String
        let source: String
        let requestId: String?
        let command: String
        let payloadKeys: [String]
        let supportedCommandCount: Int
        let metadataKeys: [String]
        let environment: BridgeEnvironmentFixture?
    }

    private struct BridgeEnvironmentFixture: Codable, Equatable {
        let cwd: String?
        let shell: String?
        let terminal: String?
        let pid: Int?
        let user: String?
        let termProgram: String?
        let tmuxPane: String?
        let weztermPane: String?
        let sshTTY: String?

        init(environment: HookEnvironment) {
            cwd = environment.cwd
            shell = environment.shell
            terminal = environment.terminal
            pid = environment.pid
            user = environment.user
            termProgram = environment.termProgram
            tmuxPane = environment.tmuxPane
            weztermPane = environment.weztermPane
            sshTTY = environment.sshTTY
        }
    }

    private struct BridgeResponseFixture: Codable, Equatable {
        let id: String
        let ok: Bool
        let message: String?
        let hasSourceDirective: Bool
        let sourceDirectiveKeys: [String]
    }
}
