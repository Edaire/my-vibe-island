import Foundation
import MyVibeIslandShared

public struct CodexRolloutSnapshot: Equatable, Sendable {
    public var sessionId: String?
    public var cwd: String?
    public var status: SessionStatus
    public var summary: String
    public var activeTool: String?
    public var toolInput: [String: BridgeJSONValue]?
    public var toolTarget: String?
    public var lastAssistantMessage: String?
    public var currentCommandPreview: String?
    public var firstUserMessage: String?
    public var lastUserMessage: String?
    public var codexRolloutPath: String?
    public var codexOrigin: String?
    public var codexSubagentKind: String?
    public var subagentParentThreadId: String?
    public var subagentNickname: String?
    public var subagentRole: String?
    public var needsAttention: Bool
    public var startsNewTurn: Bool
    public var isCompletionFallback: Bool
    public var updatedAt: Date?

    public init(
        sessionId: String? = nil,
        cwd: String? = nil,
        status: SessionStatus = .idle,
        summary: String = "Codex is idle.",
        activeTool: String? = nil,
        toolInput: [String: BridgeJSONValue]? = nil,
        toolTarget: String? = nil,
        lastAssistantMessage: String? = nil,
        currentCommandPreview: String? = nil,
        firstUserMessage: String? = nil,
        lastUserMessage: String? = nil,
        codexRolloutPath: String? = nil,
        codexOrigin: String? = nil,
        codexSubagentKind: String? = nil,
        subagentParentThreadId: String? = nil,
        subagentNickname: String? = nil,
        subagentRole: String? = nil,
        needsAttention: Bool = false,
        startsNewTurn: Bool = false,
        isCompletionFallback: Bool = false,
        updatedAt: Date? = nil
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.status = status
        self.summary = summary
        self.activeTool = activeTool
        self.toolInput = toolInput
        self.toolTarget = toolTarget
        self.lastAssistantMessage = lastAssistantMessage
        self.currentCommandPreview = currentCommandPreview
        self.firstUserMessage = firstUserMessage
        self.lastUserMessage = lastUserMessage
        self.codexRolloutPath = codexRolloutPath
        self.codexOrigin = codexOrigin
        self.codexSubagentKind = codexSubagentKind
        self.subagentParentThreadId = subagentParentThreadId
        self.subagentNickname = subagentNickname
        self.subagentRole = subagentRole
        self.needsAttention = needsAttention
        self.startsNewTurn = startsNewTurn
        self.isCompletionFallback = isCompletionFallback
        self.updatedAt = updatedAt
    }

    public var semanticFingerprint: CodexRolloutSemanticFingerprint {
        CodexRolloutSemanticFingerprint(
            sessionId: sessionId,
            cwd: cwd,
            status: status,
            summary: summary,
            activeTool: activeTool,
            toolInput: toolInput,
            toolTarget: toolTarget,
            lastAssistantMessage: lastAssistantMessage,
            currentCommandPreview: currentCommandPreview,
            firstUserMessage: firstUserMessage,
            lastUserMessage: lastUserMessage,
            codexRolloutPath: codexRolloutPath,
            codexOrigin: codexOrigin,
            codexSubagentKind: codexSubagentKind,
            subagentParentThreadId: subagentParentThreadId,
            subagentNickname: subagentNickname,
            subagentRole: subagentRole,
            needsAttention: needsAttention,
            startsNewTurn: startsNewTurn,
            isCompletionFallback: isCompletionFallback
        )
    }
}

public struct CodexRolloutSemanticFingerprint: Equatable, Hashable, Sendable {
    public let sessionId: String?
    public let cwd: String?
    public let status: SessionStatus
    public let summary: String
    public let activeTool: String?
    public let toolInput: [String: BridgeJSONValue]?
    public let toolTarget: String?
    public let lastAssistantMessage: String?
    public let currentCommandPreview: String?
    public let firstUserMessage: String?
    public let lastUserMessage: String?
    public let codexRolloutPath: String?
    public let codexOrigin: String?
    public let codexSubagentKind: String?
    public let subagentParentThreadId: String?
    public let subagentNickname: String?
    public let subagentRole: String?
    public let needsAttention: Bool
    public let startsNewTurn: Bool
    public let isCompletionFallback: Bool
}

public enum CodexRolloutReducer {
    public static func snapshot(for lines: [String]) -> CodexRolloutSnapshot {
        var snapshot = CodexRolloutSnapshot()
        lines.forEach { apply(line: $0, to: &snapshot) }
        return snapshot
    }

    public static func apply(line: String, to snapshot: inout CodexRolloutSnapshot) {
        guard
            let data = line.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return
        }

        snapshot.updatedAt = parseDate(object["timestamp"] as? String) ?? snapshot.updatedAt
        snapshot.startsNewTurn = false
        let payload = object["payload"] as? [String: Any] ?? [:]

        switch object["type"] as? String {
        case "session_meta":
            // A rollout can embed inherited parent/subagent metadata. The
            // first valid record owns the file; later records are content,
            // not a new session identity.
            guard snapshot.sessionId == nil,
                  let sessionId = nonEmpty(payload["id"] as? String) else {
                break
            }
            snapshot.sessionId = sessionId
            snapshot.cwd = nonEmpty(payload["cwd"] as? String)
            if let source = payload["source"] as? String {
                snapshot.codexOrigin = nonEmpty(source) ?? snapshot.codexOrigin
            }
            snapshot.codexSubagentKind = nonEmpty(payload["subagent_kind"] as? String)
                ?? nonEmpty(payload["subagentKind"] as? String)
                ?? snapshot.codexSubagentKind
            let spawn = (((payload["source"] as? [String: Any])?["subagent"] as? [String: Any])?["thread_spawn"] as? [String: Any])
            snapshot.codexSubagentKind = nonEmpty(spawn?["kind"] as? String)
                ?? nonEmpty(spawn?["subagent_kind"] as? String)
                ?? nonEmpty(spawn?["subagentKind"] as? String)
                ?? snapshot.codexSubagentKind
            snapshot.subagentParentThreadId = nonEmpty(spawn?["parent_thread_id"] as? String)
                ?? snapshot.subagentParentThreadId
            snapshot.subagentNickname = nonEmpty(payload["agent_nickname"] as? String)
                ?? nonEmpty(spawn?["agent_nickname"] as? String)
                ?? snapshot.subagentNickname
            snapshot.subagentRole = nonEmpty(payload["agent_role"] as? String)
                ?? nonEmpty(spawn?["agent_role"] as? String)
                ?? snapshot.subagentRole
        case "event_msg":
            applyEventMessage(payload, to: &snapshot)
        case "response_item":
            applyResponseItem(payload, to: &snapshot)
        default:
            break
        }
    }

    public static func completionFallback(from snapshot: CodexRolloutSnapshot) -> CodexRolloutSnapshot {
        guard snapshot.status == .idle || snapshot.status == .waiting else { return snapshot }
        var completed = snapshot
        completed.status = .completed
        completed.summary = "Codex completed the turn."
        completed.activeTool = nil
        completed.needsAttention = false
        completed.isCompletionFallback = true
        return completed
    }

    public static func agentEvents(
        from oldSnapshot: CodexRolloutSnapshot?,
        to newSnapshot: CodexRolloutSnapshot
    ) -> [AgentEvent] {
        guard
            let sessionId = newSnapshot.sessionId,
            let cwd = newSnapshot.cwd
        else {
            return []
        }

        let oldSnapshot = oldSnapshot?.sessionId == sessionId ? oldSnapshot : nil
        let eventSessionId = CodexSessionIdentity.prefixed(sessionId)
        guard oldSnapshot?.semanticFingerprint != newSnapshot.semanticFingerprint else { return [] }

        if let parentThreadId = newSnapshot.subagentParentThreadId {
            return [.subagentLifecycleUpdated(
                source: "codex",
                childSessionId: eventSessionId,
                lifecycle: SubagentLifecycleUpdate(
                    parentThreadId: parentThreadId,
                    nickname: newSnapshot.subagentNickname,
                    role: newSnapshot.subagentRole,
                    status: newSnapshot.status == .completed ? .completed : .running,
                    observedAt: newSnapshot.updatedAt,
                    currentActivity: nonEmpty(newSnapshot.currentCommandPreview)
                        ?? nonEmpty(newSnapshot.lastAssistantMessage),
                    needsAttention: newSnapshot.needsAttention
                )
            )]
        }

        var events: [AgentEvent] = []
        if oldSnapshot == nil {
            events.append(.sessionStarted(source: "codex", sessionId: eventSessionId, cwd: cwd))
        }
        events.append(.sessionActivityUpdated(
            source: "codex",
            sessionId: eventSessionId,
            activity: SessionActivityUpdate(
                status: newSnapshot.status,
                summary: newSnapshot.summary,
                activeTool: newSnapshot.activeTool,
                toolInput: newSnapshot.toolInput,
                toolTarget: newSnapshot.toolTarget,
                lastAssistantMessage: newSnapshot.lastAssistantMessage,
                currentCommandPreview: newSnapshot.currentCommandPreview,
                updatedAt: newSnapshot.updatedAt,
                firstUserMessage: newSnapshot.firstUserMessage,
                lastUserMessage: newSnapshot.lastUserMessage,
                codexRolloutPath: newSnapshot.codexRolloutPath,
                codexOrigin: newSnapshot.codexOrigin,
                codexSubagentKind: newSnapshot.codexSubagentKind,
                needsAttention: newSnapshot.needsAttention,
                hasUnreadCompletion: newSnapshot.status == .completed
                    && nonEmpty(newSnapshot.lastAssistantMessage) != nil,
                startsNewTurn: newSnapshot.startsNewTurn,
                isCompletionFallback: newSnapshot.isCompletionFallback
            )
        ))
        return events
    }

    private static func applyEventMessage(
        _ payload: [String: Any],
        to snapshot: inout CodexRolloutSnapshot
    ) {
        switch payload["type"] as? String {
        case "user_message":
            snapshot.startsNewTurn = true
            recordUserMessage(
                nonEmpty(payload["message"] as? String) ?? nonEmpty(payload["content"] as? String),
                snapshot: &snapshot
            )
            setActive(summary: "Codex is working.", tool: nil, snapshot: &snapshot)
        case "task_started", "turn_started", "agent_reasoning", "agent_reasoning_raw_content":
            setActive(summary: "Codex is working.", tool: nil, snapshot: &snapshot)
        case "exec_command_begin":
            setActive(summary: "Codex is running a tool.", tool: "exec_command", snapshot: &snapshot)
        case "patch_apply_begin", "patch_apply_updated":
            setActive(summary: "Codex is running a tool.", tool: "apply_patch", snapshot: &snapshot)
        case "mcp_tool_call_begin", "dynamic_tool_call_request":
            setActive(
                summary: "Codex is running a tool.",
                tool: nonEmpty(payload["tool"] as? String) ?? "mcp_tool",
                snapshot: &snapshot
            )
        case "request_user_input", "elicitation_request", "exec_approval_request", "apply_patch_approval_request", "request_permissions":
            snapshot.status = .waiting
            snapshot.summary = "Codex needs attention."
            snapshot.activeTool = nil
            snapshot.needsAttention = true
            snapshot.isCompletionFallback = false
        case "agent_message":
            recordAssistantMessage(
                nonEmpty(payload["message"] as? String),
                snapshot: &snapshot
            )
            snapshot.status = .idle
            snapshot.summary = "Codex is idle."
            snapshot.activeTool = nil
            snapshot.needsAttention = false
            snapshot.isCompletionFallback = false
        case "task_complete", "turn_complete":
            snapshot.status = .completed
            snapshot.summary = "Codex completed the turn."
            snapshot.activeTool = nil
            snapshot.needsAttention = false
            snapshot.isCompletionFallback = false
        case "turn_aborted":
            snapshot.status = .failed
            snapshot.summary = "Codex turn was interrupted."
            snapshot.activeTool = nil
            snapshot.needsAttention = false
            snapshot.isCompletionFallback = false
        case "token_count" where rateLimitReached(payload):
            snapshot.status = .completed
            snapshot.summary = "Codex reached a usage limit."
            snapshot.activeTool = nil
            snapshot.needsAttention = false
            snapshot.isCompletionFallback = true
        default:
            break
        }
    }

    private static func applyResponseItem(
        _ payload: [String: Any],
        to snapshot: inout CodexRolloutSnapshot
    ) {
        switch payload["type"] as? String {
        case "message" where payload["role"] as? String == "assistant":
            recordAssistantMessage(messageText(from: payload["content"]), snapshot: &snapshot)
            snapshot.status = .idle
            snapshot.summary = "Codex is idle."
            snapshot.activeTool = nil
            snapshot.needsAttention = false
            snapshot.isCompletionFallback = false
        case "message" where payload["role"] as? String == "user":
            recordUserMessage(messageText(from: payload["content"]), snapshot: &snapshot)
            setActive(summary: "Codex is working.", tool: nil, snapshot: &snapshot)
        case "function_call", "custom_tool_call":
            setActive(
                summary: "Codex is running a tool.",
                tool: nonEmpty(payload["name"] as? String) ?? "tool",
                input: payload["type"] as? String == "custom_tool_call"
                    ? inputDictionary(payload["input"])
                    : nil,
                commandPreview: commandPreview(from: payload),
                snapshot: &snapshot
            )
        case "local_shell_call":
            setActive(summary: "Codex is running a tool.", tool: "exec_command", snapshot: &snapshot)
        case "web_search_call":
            setActive(summary: "Codex is running a tool.", tool: "web_search", snapshot: &snapshot)
        case "image_generation_call":
            setActive(summary: "Codex is running a tool.", tool: "image_generation", snapshot: &snapshot)
        case "reasoning", "function_call_output", "custom_tool_call_output":
            // The original card shows the last concrete activity while tool
            // output and reasoning continue. Keep that activity available for
            // the renderer instead of replacing it with a generic fallback.
            setActive(
                summary: "Codex is working.",
                tool: nil,
                preserveCommandPreview: true,
                snapshot: &snapshot
            )
        default:
            break
        }
    }

    private static func setActive(
        summary: String,
        tool: String?,
        input: [String: BridgeJSONValue]? = nil,
        target: String? = nil,
        commandPreview: String? = nil,
        preserveCommandPreview: Bool = false,
        snapshot: inout CodexRolloutSnapshot
    ) {
        snapshot.status = .active
        snapshot.summary = summary
        snapshot.activeTool = tool
        snapshot.toolInput = input
        snapshot.toolTarget = target
        if let commandPreview {
            snapshot.currentCommandPreview = commandPreview
        } else if !preserveCommandPreview {
            snapshot.currentCommandPreview = nil
        }
        snapshot.needsAttention = false
        snapshot.isCompletionFallback = false
    }

    private static func recordUserMessage(
        _ message: String?,
        snapshot: inout CodexRolloutSnapshot
    ) {
        guard let message = nonEmpty(message), !SyntheticUserText.isSynthetic(message) else { return }
        if snapshot.firstUserMessage == nil {
            snapshot.firstUserMessage = message
        }
        snapshot.lastUserMessage = message
    }

    private static func recordAssistantMessage(
        _ message: String?,
        snapshot: inout CodexRolloutSnapshot
    ) {
        guard let message = nonEmpty(message) else { return }
        snapshot.lastAssistantMessage = message
    }

    private static func messageText(from value: Any?) -> String? {
        if let string = value as? String {
            return nonEmpty(string)
        }
        guard let parts = value as? [[String: Any]] else { return nil }
        let text = parts.compactMap { part -> String? in
            guard let type = part["type"] as? String,
                  type == "input_text" || type == "text" else { return nil }
            return nonEmpty(part["text"] as? String)
        }.joined(separator: "\n")
        return nonEmpty(text)
    }

    private static func inputDictionary(_ value: Any?) -> [String: BridgeJSONValue]? {
        if let object = value as? [String: Any] {
            return object.reduce(into: [String: BridgeJSONValue]()) { result, entry in
                result[entry.key] = bridgeValue(entry.value)
            }
        }
        if let string = value as? String, let data = string.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return inputDictionary(object)
        }
        guard let value else { return nil }
        return ["input": bridgeValue(value)]
    }

    private static func commandPreview(from payload: [String: Any]) -> String? {
        if let input = payload["input"] as? String, !input.isEmpty {
            return safeCommandPreview(input)
        }
        if let arguments = payload["arguments"] as? String,
           let data = arguments.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["cmd", "command", "query", "path", "file_path"] {
                if let value = nonEmpty(object[key] as? String) {
                    return safeCommandPreview(value)
                }
            }
        }
        return nil
    }

    private static func safeCommandPreview(_ command: String) -> String {
        command
            .split(whereSeparator: \Character.isWhitespace)
            .map { token in
                let unquoted = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                return unquoted.hasPrefix("/") ? "<path>" : String(token)
            }
            .joined(separator: " ")
    }

    private static func bridgeValue(_ value: Any) -> BridgeJSONValue {
        switch value {
        case let value as String: .string(value)
        case let value as Bool: .bool(value)
        case let value as Int: .integer(value)
        case let value as Double: .number(value)
        case let value as [Any]: .array(value.map(bridgeValue))
        case let value as [String: Any]:
            .object(value.reduce(into: [String: BridgeJSONValue]()) { result, entry in
                result[entry.key] = bridgeValue(entry.value)
            })
        default: .null
        }
    }

    private static func rateLimitReached(_ payload: [String: Any]) -> Bool {
        let info = payload["info"] as? [String: Any]
        let limits = info?["rate_limits"] as? [String: Any]
            ?? payload["rate_limits"] as? [String: Any]
        if nonEmpty(limits?["rate_limit_reached_type"] as? String) != nil {
            return true
        }
        guard
            let primary = limits?["primary"] as? [String: Any],
            let number = primary["used_percent"] as? NSNumber
        else {
            return false
        }
        return number.doubleValue >= 100
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}
