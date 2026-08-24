import Foundation

public struct CodexAdapter: AgentAdapter {
    public let sourceIds: Set<String> = ["codex"]
    private let genericAdapter: GenericHookAdapter

    public init(genericAdapter: GenericHookAdapter = GenericHookAdapter()) {
        self.genericAdapter = genericAdapter
    }

    public func hookEvent(from envelope: BridgeEnvelope) throws -> HookEvent {
        guard envelope.payload["hook_event_name"] != nil else {
            return try genericAdapter.hookEvent(from: envelope)
        }

        let payload = try CodexHookPayload(payload: envelope.payload)
        let requestId = nonEmpty(envelope.requestId) ?? payload.toolUseId ?? payload.genericRequestId
        let assistantMessage = payload.lastAssistantMessage
            ?? Self.lastAssistantMessageFromTranscript(path: payload.transcriptPath)
        let firstUserMessage = Self.firstUserMessageFromTranscript(path: payload.transcriptPath)

        if payload.hookEventName == "PermissionRequest", requestId == nil {
            throw AgentAdapterError.invalidHookPayload
        }

        return HookEvent(
            rawEventName: payload.hookEventName,
            source: envelope.source,
            sessionId: CodexSessionIdentity.prefixed(payload.sessionId),
            requestId: requestId,
            cwd: payload.cwd,
            model: payload.model,
            permissionMode: payload.permissionMode,
            toolName: payload.toolName,
            message: Self.message(
                eventName: payload.hookEventName,
                prompt: payload.prompt,
                assistantMessage: assistantMessage
            ),
            firstUserMessage: firstUserMessage,
            codexRolloutPath: payload.transcriptPath,
            actionRequestDetails: ActionRequestDetails.safeDetails(
                from: envelope.payload,
                fallbackPrompt: payload.prompt
            ),
            environment: envelope.environment,
            tasks: NormalizedSessionContentPayload.tasks(from: envelope.payload),
            todos: NormalizedSessionContentPayload.todos(from: envelope.payload),
            subagentParentThreadId: payload.subagentParentThreadId,
            subagentKind: payload.subagentKind,
            subagentNickname: payload.subagentNickname,
            subagentRole: payload.subagentRole,
            childModel: payload.childModel,
            childReasoningEffort: payload.childReasoningEffort,
            agentId: payload.agentId,
            agentType: payload.agentType,
            childParentId: payload.childParentId,
            childRuntimeSessionId: payload.childRuntimeSessionId,
            childProcessIncarnation: payload.childProcessIncarnation
        )
    }

    public func directive(for request: ActionableRequest, resolution: ActionResolution) -> SourceDirective {
        guard request.kind == .permission else {
            return .none
        }

        switch resolution.kind {
        case .approve:
            return permissionDirective(decision: [
                "behavior": .string("allow"),
            ])
        case .deny:
            return permissionDirective(decision: [
                "behavior": .string("deny"),
                "message": .string("Permission denied in My Vibe Island."),
            ])
        case .approveAlways, .answer, .dismiss:
            return .none
        }
    }

    public func blockingTimeout(for request: ActionableRequest) -> TimeInterval? {
        request.kind == .permission ? 7_200 : nil
    }

    private func permissionDirective(decision: [String: BridgeJSONValue]) -> SourceDirective {
        .json(.object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object(decision),
            ]),
        ]))
    }

    private static func message(
        eventName: String,
        prompt: String?,
        assistantMessage: String?
    ) -> String? {
        if eventName == "UserPromptSubmit" {
            return prompt ?? assistantMessage
        }
        if eventName == "Stop" || eventName == "StopFailure" || eventName == "SubagentStop" {
            return assistantMessage
        }
        return assistantMessage ?? prompt
    }

    private static func lastAssistantMessageFromTranscript(path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        let readSize = min(fileSize, 256 * 1024)
        guard readSize > 0 else { return nil }
        try? handle.seek(toOffset: fileSize - readSize)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return nil }

        var text = String(decoding: data, as: UTF8.self)
        if readSize < fileSize, let newline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: newline)...])
        }
        let lines = text.split(separator: "\n").map(String.init)
        return CodexRolloutReducer.snapshot(for: lines).lastAssistantMessage
    }

    public static func firstUserMessageFromTranscript(path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let readSize = 256 * 1024
        guard let data = try? handle.read(upToCount: readSize), !data.isEmpty else { return nil }
        let lines = data
            .split(separator: UInt8(ascii: "\n"))
            .map { String(decoding: $0, as: UTF8.self) }
        return CodexRolloutReducer.snapshot(for: lines).firstUserMessage
    }
}
