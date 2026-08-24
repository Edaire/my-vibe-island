import Foundation

public enum AgentAdapterError: Error, Equatable, Sendable {
    case invalidHookPayload
}

public protocol AgentAdapter: Sendable {
    var sourceIds: Set<String> { get }

    func hookEvent(from envelope: BridgeEnvelope) throws -> HookEvent
    func directive(for request: ActionableRequest, resolution: ActionResolution) -> SourceDirective
    func blockingTimeout(for request: ActionableRequest) -> TimeInterval?
}

public struct GenericHookAdapter: AgentAdapter {
    public let sourceIds: Set<String> = []

    public init() {}

    public func hookEvent(from envelope: BridgeEnvelope) throws -> HookEvent {
        guard
            let rawEventName = requiredStringValue("rawEventName", in: envelope.payload),
            let sessionId = requiredStringValue("sessionId", in: envelope.payload),
            let cwd = requiredStringValue("cwd", in: envelope.payload)
        else {
            throw AgentAdapterError.invalidHookPayload
        }

        return HookEvent(
            rawEventName: rawEventName,
            source: envelope.source,
            sessionId: sessionId,
            requestId: nonEmpty(envelope.requestId) ?? stringValue("requestId", in: envelope.payload),
            cwd: cwd,
            model: stringValue("model", in: envelope.payload),
            permissionMode: stringValue("permissionMode", in: envelope.payload),
            toolName: stringValue("toolName", in: envelope.payload),
            message: stringValue("message", in: envelope.payload),
            actionRequestDetails: ActionRequestDetails.safeDetails(from: envelope.payload),
            environment: envelope.environment,
            tasks: NormalizedSessionContentPayload.tasks(from: envelope.payload),
            todos: NormalizedSessionContentPayload.todos(from: envelope.payload)
        )
    }

    public func directive(for request: ActionableRequest, resolution: ActionResolution) -> SourceDirective {
        .none
    }

    public func blockingTimeout(for request: ActionableRequest) -> TimeInterval? {
        nil
    }
}

extension AgentAdapter {
    public func directive(for request: ActionableRequest, resolution: ActionResolution) -> SourceDirective {
        .none
    }

    public func blockingTimeout(for request: ActionableRequest) -> TimeInterval? {
        nil
    }

    func stringValue(_ key: String, in payload: [String: BridgeJSONValue]) -> String? {
        guard case let .string(value) = payload[key], !value.isEmpty else {
            return nil
        }

        return value
    }

    func requiredStringValue(_ key: String, in payload: [String: BridgeJSONValue]) -> String? {
        stringValue(key, in: payload)
    }

    func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }

        return value
    }
}
