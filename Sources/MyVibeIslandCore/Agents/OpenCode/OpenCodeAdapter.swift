import Foundation

public struct OpenCodeAdapter: AgentAdapter {
    public let sourceIds: Set<String> = ["opencode"]
    private let genericAdapter: GenericHookAdapter

    public init(genericAdapter: GenericHookAdapter = GenericHookAdapter()) {
        self.genericAdapter = genericAdapter
    }

    public func hookEvent(from envelope: BridgeEnvelope) throws -> HookEvent {
        guard envelope.payload["event"] != nil else {
            return try genericAdapter.hookEvent(from: envelope)
        }

        guard
            let event = stringValue("event", in: envelope.payload),
            let requestId = stringValue("id", in: envelope.payload),
            let sessionId = stringValue("sessionID", in: envelope.payload)
        else {
            throw AgentAdapterError.invalidHookPayload
        }

        switch event {
        case "permission":
            return HookEvent(
                rawEventName: "PermissionRequest",
                source: envelope.source,
                sessionId: sessionId,
                requestId: requestId,
                cwd: stringValue("cwd", in: envelope.payload) ?? "",
                toolName: stringValue("permission", in: envelope.payload),
                actionRequestDetails: ActionRequestDetails.safeDetails(from: envelope.payload),
                environment: envelope.environment
            )
        case "question":
            return HookEvent(
                rawEventName: "QuestionRequest",
                source: envelope.source,
                sessionId: sessionId,
                requestId: requestId,
                cwd: stringValue("cwd", in: envelope.payload) ?? "",
                toolName: stringValue("toolName", in: envelope.payload) ?? "Question",
                actionRequestDetails: ActionRequestDetails.safeDetails(from: envelope.payload),
                environment: envelope.environment
            )
        default:
            throw AgentAdapterError.invalidHookPayload
        }
    }

    public func directive(for request: ActionableRequest, resolution: ActionResolution) -> SourceDirective {
        switch (request.kind, resolution.kind) {
        case (.permission, .approve):
            return permissionDirective(behavior: "allow")
        case (.permission, .approveAlways):
            return permissionDirective(behavior: "always")
        case (.permission, .deny):
            return permissionDirective(
                behavior: "deny",
                reason: "Permission denied in My Vibe Island."
            )
        case (.question, .answer):
            let answers = normalizedAnswers(for: request, resolution: resolution)
            guard !answers.isEmpty else {
                return .none
            }
            return .json(.object([
                "continue": .bool(true),
                "hookSpecificOutput": .object([
                    "hookEventName": .string("PermissionRequest"),
                    "decision": .object([
                        "behavior": .string("allow"),
                        "updatedInput": .object([
                            "answers": .object(answers.mapValues(BridgeJSONValue.string)),
                        ]),
                    ]),
                ]),
            ]))
        default:
            return .none
        }
    }

    public func blockingTimeout(for request: ActionableRequest) -> TimeInterval? {
        switch request.kind {
        case .permission, .question:
            return 3_600
        }
    }

    private func permissionDirective(
        behavior: String,
        reason: String? = nil
    ) -> SourceDirective {
        var decision: [String: BridgeJSONValue] = [
            "behavior": .string(behavior),
        ]
        if let reason {
            decision["reason"] = .string(reason)
        }
        return .json(.object([
            "continue": .bool(true),
            "hookSpecificOutput": .object([
                "hookEventName": .string("PermissionRequest"),
                "decision": .object(decision),
            ]),
        ]))
    }

    private func normalizedAnswers(
        for request: ActionableRequest,
        resolution: ActionResolution
    ) -> [String: String] {
        if let answers = resolution.answers {
            return answers.filter { !$0.key.isEmpty && !$0.value.isEmpty }
        }
        guard let selection = resolution.selection, !selection.isEmpty else {
            return [:]
        }
        let header = request.details?.questions.first?.header ?? "Question"
        return [header: selection]
    }
}
