import Foundation
import MyVibeIslandCore

public struct HookCLI {
    private let codec: BridgeCodec
    private let environmentCapture: () -> HookEnvironment
    private let standardInput: () -> String
    private let bridgeSend: (BridgeEnvelope, String, BridgeCodec) throws -> BridgeResponse
    private let bridgeSendFireAndForget: (BridgeEnvelope, String, BridgeCodec) throws -> Void

    public init(
        codec: BridgeCodec = BridgeCodec(),
        environmentCapture: @escaping () -> HookEnvironment = { HookEnvironment.capture() },
        standardInput: @escaping () -> String = { String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? "" },
        bridgeSend: @escaping (BridgeEnvelope, String, BridgeCodec) throws -> BridgeResponse = { envelope, socketPath, codec in
            try BridgeClient(socketPath: socketPath, codec: codec).send(envelope)
        },
        bridgeSendFireAndForget: @escaping (BridgeEnvelope, String, BridgeCodec) throws -> Void = { envelope, socketPath, codec in
            try BridgeClient(socketPath: socketPath, codec: codec).sendFireAndForget(envelope)
        }
    ) {
        self.codec = codec
        self.environmentCapture = environmentCapture
        self.standardInput = standardInput
        self.bridgeSend = bridgeSend
        self.bridgeSendFireAndForget = bridgeSendFireAndForget
    }

    public func run(arguments: [String]) throws -> String {
        if arguments.contains("--help") || arguments.isEmpty {
            return """
            my-vibe-island-hooks
            Commands:
              hook-event    Send one hook event to the local bridge.
              --source      Send original-style provider hook JSON.
            """
        }

        if value(after: "--source", in: arguments) != nil {
            return try runSourceHook(arguments: arguments)
        }

        if arguments.first == "hook-event" {
            return try runHookEvent(arguments: Array(arguments.dropFirst()))
        }

        return "unsupported hook command: \(arguments.joined(separator: " "))"
    }

    private func runSourceHook(arguments: [String]) throws -> String {
        guard let source = value(after: "--source", in: arguments) else {
            return try codec.encodeResponseLine(.failure(message: "missing --source"))
        }

        let input = value(after: "--input", in: arguments) ?? standardInput()
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return try codec.encodeResponseLine(.failure(message: "missing --input"))
        }

        let socketPath = value(after: "--socket", in: arguments) ?? BridgeSocketPath.defaultPath()
        let eventName = value(after: "--event", in: arguments)
        let waitForAck = arguments.contains("--wait-for-ack")

        let payload: [String: BridgeJSONValue]
        do {
            payload = try normalizedPayload(source: source, eventName: eventName, input: input)
        } catch {
            return try codec.encodeResponseLine(.failure(message: "invalid --input"))
        }
        let sessionId = Self.firstString(in: payload, keys: ["sessionId", "session_id"])
        let effectiveEventName = eventName ?? Self.firstString(in: payload, keys: ["hook_event_name"])
        if Self.isCompletionEvent(effectiveEventName) {
            SessionCompletionTraceLog.append(
                stage: "hook.received",
                sessionId: sessionId,
                metadata: [
                    "source": source,
                    "event": effectiveEventName ?? "-",
                    "socket": socketPath,
                ]
            )
        }

        let envelope = BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "hook",
            source: source,
            requestId: Self.firstString(in: payload, keys: ["request_id", "tool_use_id", "question_id"]),
            command: .hookEvent,
            payload: payload,
            environment: environmentCapture()
        )

        do {
            guard waitForAck || Self.requiresResponse(for: effectiveEventName) else {
                try bridgeSendFireAndForget(envelope, socketPath, codec)
                if Self.isCompletionEvent(effectiveEventName) {
                    SessionCompletionTraceLog.append(
                        stage: "hook.sent",
                        sessionId: sessionId,
                        metadata: [
                            "source": source,
                            "event": effectiveEventName ?? "-",
                            "mode": "fire-and-forget",
                        ]
                    )
                }
                return try sourceHookOutput(for: nil, eventName: effectiveEventName)
            }

            let response = try bridgeSend(envelope, socketPath, codec)
            if Self.isCompletionEvent(effectiveEventName) {
                SessionCompletionTraceLog.append(
                    stage: "hook.sent",
                    sessionId: sessionId,
                    metadata: [
                        "source": source,
                        "event": effectiveEventName ?? "-",
                        "ok": String(response.ok),
                    ]
                )
            }
            return try sourceHookOutput(for: response, eventName: effectiveEventName)
        } catch {
            if Self.isCompletionEvent(effectiveEventName) {
                SessionCompletionTraceLog.append(
                    stage: "hook.send_failed",
                    sessionId: sessionId,
                    metadata: [
                        "source": source,
                        "event": effectiveEventName ?? "-",
                        "error": String(describing: error),
                    ]
                )
            }
            return try sourceHookOutput(for: nil, eventName: effectiveEventName)
        }
    }

    private func runHookEvent(arguments: [String]) throws -> String {
        guard let input = value(after: "--input", in: arguments) else {
            return try codec.encodeResponseLine(.failure(message: "missing --input"))
        }

        guard let socketPath = value(after: "--socket", in: arguments) else {
            return try codec.encodeResponseLine(.failure(message: "missing --socket"))
        }

        let envelope: BridgeEnvelope
        do {
            envelope = try codec.decodeEnvelopeLine(input)
        } catch {
            return try codec.encodeResponseLine(.failure(message: "invalid --input"))
        }

        let outboundEnvelope = envelope.environment == nil
            ? BridgeEnvelope(
                schemaVersion: envelope.schemaVersion,
                clientRole: envelope.clientRole,
                source: envelope.source,
                requestId: envelope.requestId,
                command: envelope.command,
                payload: envelope.payload,
                sentAt: envelope.sentAt,
                environment: environmentCapture()
            )
            : envelope

        do {
            let response = try bridgeSend(outboundEnvelope, socketPath, codec)
            return try output(for: response)
        } catch {
            return try codec.encodeResponseLine(.ok(message: "bridge offline; event ignored fail-open"))
        }
    }

    private func normalizedPayload(
        source: String,
        eventName: String?,
        input: String
    ) throws -> [String: BridgeJSONValue] {
        var payload = try JSONDecoder().decode(
            [String: BridgeJSONValue].self,
            from: Data(input.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        )
        if source == "codex" {
            return try CodexBridgePayloadNormalizer.normalizedPayload(eventName: eventName, input: payload)
        }
        payload["_source"] = .string(source)
        if let eventName, !eventName.isEmpty {
            payload["hook_event_name"] = .string(eventName)
        }
        return payload
    }

    private static func firstString(
        in payload: [String: BridgeJSONValue],
        keys: [String]
    ) -> String? {
        for key in keys {
            if case let .string(value) = payload[key], !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func isCompletionEvent(_ eventName: String?) -> Bool {
        eventName == "Stop" || eventName == "StopFailure" || eventName == "SubagentStop" || eventName == "SessionEnd"
    }

    private static func requiresResponse(for eventName: String?) -> Bool {
        switch eventName {
        case "PermissionRequest", "QuestionRequest":
            return true
        default:
            return false
        }
    }

    private func output(for response: BridgeResponse) throws -> String {
        guard let sourceDirective = response.sourceDirective else {
            return try codec.encodeResponseLine(response)
        }

        let data = try JSONEncoder().encode(sourceDirective)
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    private func sourceHookOutput(for response: BridgeResponse?, eventName: String?) throws -> String {
        guard let response, response.sourceDirective != nil else {
            if eventName == "Stop" || eventName == "SubagentStop" {
                return "{\"continue\":true}\n"
            }
            return ""
        }
        return try output(for: response)
    }

    private func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else {
            return nil
        }

        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        let value = arguments[valueIndex]
        guard !value.hasPrefix("--") else {
            return nil
        }

        return value
    }
}
