import Foundation

public struct BridgeCodec: Sendable {
    public init() {}

    public func decodeRequestLine(_ line: String) throws -> BridgeEnvelope {
        do {
            return try decodeEnvelopeLine(line)
        } catch {
            return try decodeOriginalBridgeHookLine(line)
        }
    }

    public func decodeEnvelopeLine(_ line: String) throws -> BridgeEnvelope {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let decoder = JSONDecoder()
        return try decoder.decode(BridgeEnvelope.self, from: Data(trimmed.utf8))
    }

    public func encodeEnvelopeLine(_ envelope: BridgeEnvelope) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(envelope)
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    public func encodeResponseLine(_ response: BridgeResponse) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    public func encodeOriginalBridgeResponseLine(_ response: BridgeResponse) throws -> String {
        let value = response.sourceDirective ?? .object(["continue": .bool(true)])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    public func decodeResponseLine(_ line: String) throws -> BridgeResponse {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let decoder = JSONDecoder()
        return try decoder.decode(BridgeResponse.self, from: Data(trimmed.utf8))
    }

    private func decodeOriginalBridgeHookLine(_ line: String) throws -> BridgeEnvelope {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = try JSONDecoder().decode(
            [String: BridgeJSONValue].self,
            from: Data(trimmed.utf8)
        )
        guard case let .string(source) = payload["_source"], !source.isEmpty,
              case let .string(eventName) = payload["hook_event_name"], !eventName.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Unsupported bridge request")
            )
        }

        let requestId = Self.firstString(
            in: payload,
            keys: ["request_id", "tool_use_id", "question_id"]
        ) ?? Self.originalBridgeRequestId(payload: payload, eventName: eventName)

        return BridgeEnvelope(
            schemaVersion: 1,
            clientRole: "original-bridge",
            source: source,
            requestId: requestId,
            command: .hookEvent,
            payload: payload,
            environment: Self.originalBridgeEnvironment(from: payload)
        )
    }

    private static func originalBridgeRequestId(
        payload: [String: BridgeJSONValue],
        eventName: String
    ) -> String? {
        guard eventName == "PermissionRequest" || eventName == "QuestionRequest",
              let sessionId = firstString(in: payload, keys: ["session_id"]) else {
            return nil
        }
        return "original-bridge:\(sessionId)"
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

    private static func originalBridgeEnvironment(
        from payload: [String: BridgeJSONValue]
    ) -> HookEnvironment? {
        guard case let .object(environment) = payload["_env"] else {
            return nil
        }

        func string(_ key: String) -> String? {
            guard case let .string(value) = environment[key], !value.isEmpty else {
                return nil
            }
            return value
        }

        return HookEnvironment(
            cwd: firstString(in: payload, keys: ["cwd"]),
            shell: string("SHELL"),
            terminal: string("TERM_PROGRAM"),
            tty: string("TTY"),
            termProgram: string("TERM_PROGRAM"),
            itermSessionId: string("ITERM_SESSION_ID"),
            termSessionId: string("TERM_SESSION_ID"),
            warpSessionId: string("WARP_SESSION_ID"),
            warpTerminalSessionUUID: string("WARP_TERMINAL_SESSION_UUID"),
            warpFocusURL: string("WARP_FOCUS_URL"),
            tmux: string("TMUX"),
            tmuxPane: string("TMUX_PANE"),
            kittyWindowId: string("KITTY_WINDOW_ID"),
            kittyListenOn: string("KITTY_LISTEN_ON"),
            zellijSessionName: string("ZELLIJ_SESSION_NAME"),
            zellijPaneId: string("ZELLIJ_PANE_ID"),
            cfBundleIdentifier: string("__CFBundleIdentifier"),
            cursorTraceId: string("CURSOR_TRACE_ID"),
            conductorWorkspaceName: string("CONDUCTOR_WORKSPACE_NAME"),
            conductorPort: string("CONDUCTOR_PORT"),
            cmuxWorkspaceId: string("CMUX_WORKSPACE_ID"),
            cmuxSurfaceId: string("CMUX_SURFACE_ID"),
            cmuxSocketPath: string("CMUX_SOCKET_PATH"),
            supacodeWorktreeId: string("SUPACODE_WORKTREE_ID"),
            supacodeTabId: string("SUPACODE_TAB_ID"),
            supacodeSurfaceId: string("SUPACODE_SURFACE_ID"),
            supacodeSocketPath: string("SUPACODE_SOCKET_PATH"),
            weztermSocket: string("WEZTERM_UNIX_SOCKET"),
            weztermPane: string("WEZTERM_PANE"),
            ottySocket: string("OTTY_SOCKET"),
            ottyPaneId: string("OTTY_PANE_ID"),
            sshConnection: string("SSH_CONNECTION"),
            sshTTY: string("SSH_TTY")
        )
    }
}
