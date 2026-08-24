struct JumpTargetUpdatePayload: Sendable {
    private static let allowedTopLevelKeys: Set<String> = [
        "sessionId", "jumpInput", "confidence", "source",
    ]
    private static let allowedJumpInputKeys: Set<String> = [
        "bundleId", "cwd", "cliSessionId", "pid", "tty",
        "isIDEHost", "isSSHRemote", "isInTmux", "tmuxPane",
        "zellijSessionName", "zellijPaneId", "itermSessionId",
        "cmuxWorkspaceId", "cmuxSurfaceId", "warpPaneUUID",
        "kittyWindowId", "weztermPane", "ottyPaneId", "ideWindowId",
        "termSessionId", "supacodeWorktreeId", "supacodeTabId",
        "supacodeSurfaceId", "sshTTY", "remoteHostId", "remoteCwd",
    ]

    let sessionId: String
    let jumpInput: JumpInput

    init(payload: [String: BridgeJSONValue], requestSource: String) throws {
        guard Set(payload.keys).isSubset(of: Self.allowedTopLevelKeys),
              case let .string(sessionId) = payload["sessionId"], !sessionId.isEmpty,
              case let .object(rawJumpInput) = payload["jumpInput"],
              Set(rawJumpInput.keys).isSubset(of: Self.allowedJumpInputKeys) else {
            throw AgentAdapterError.invalidHookPayload
        }

        self.sessionId = sessionId
        jumpInput = JumpInput(
            sessionId: sessionId,
            source: requestSource,
            bundleId: try Self.string("bundleId", in: rawJumpInput),
            cwd: try Self.string("cwd", in: rawJumpInput),
            cliSessionId: try Self.string("cliSessionId", in: rawJumpInput),
            pid: try Self.integer("pid", in: rawJumpInput),
            tty: try Self.string("tty", in: rawJumpInput),
            isIDEHost: try Self.bool("isIDEHost", in: rawJumpInput),
            isSSHRemote: try Self.bool("isSSHRemote", in: rawJumpInput),
            isInTmux: try Self.bool("isInTmux", in: rawJumpInput),
            tmuxPane: try Self.string("tmuxPane", in: rawJumpInput),
            zellijSessionName: try Self.string("zellijSessionName", in: rawJumpInput),
            zellijPaneId: try Self.string("zellijPaneId", in: rawJumpInput),
            itermSessionId: try Self.string("itermSessionId", in: rawJumpInput),
            cmuxWorkspaceId: try Self.string("cmuxWorkspaceId", in: rawJumpInput),
            cmuxSurfaceId: try Self.string("cmuxSurfaceId", in: rawJumpInput),
            warpPaneUUID: try Self.string("warpPaneUUID", in: rawJumpInput),
            kittyWindowId: try Self.string("kittyWindowId", in: rawJumpInput),
            weztermPane: try Self.string("weztermPane", in: rawJumpInput),
            ottyPaneId: try Self.string("ottyPaneId", in: rawJumpInput),
            ideWindowId: try Self.string("ideWindowId", in: rawJumpInput),
            termSessionId: try Self.string("termSessionId", in: rawJumpInput),
            supacodeWorktreeId: try Self.string("supacodeWorktreeId", in: rawJumpInput),
            supacodeTabId: try Self.string("supacodeTabId", in: rawJumpInput),
            supacodeSurfaceId: try Self.string("supacodeSurfaceId", in: rawJumpInput),
            sshTTY: try Self.string("sshTTY", in: rawJumpInput),
            remoteHostId: try Self.string("remoteHostId", in: rawJumpInput),
            remoteCwd: try Self.string("remoteCwd", in: rawJumpInput)
        )
    }

    private static func string(_ key: String, in values: [String: BridgeJSONValue]) throws -> String? {
        guard let value = values[key] else { return nil }
        guard case let .string(string) = value else { throw AgentAdapterError.invalidHookPayload }
        return string
    }

    private static func integer(_ key: String, in values: [String: BridgeJSONValue]) throws -> Int? {
        guard let value = values[key] else { return nil }
        guard case let .integer(integer) = value else { throw AgentAdapterError.invalidHookPayload }
        return integer
    }

    private static func bool(_ key: String, in values: [String: BridgeJSONValue]) throws -> Bool? {
        guard let value = values[key] else { return nil }
        guard case let .bool(bool) = value else { throw AgentAdapterError.invalidHookPayload }
        return bool
    }
}
