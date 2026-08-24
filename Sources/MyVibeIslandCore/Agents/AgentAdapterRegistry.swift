import Foundation

public struct AgentAdapterRegistry: Sendable {
    public static let `default` = AgentAdapterRegistry(adapters: [
        CodexAdapter(),
        ClaudeCompatibleAdapter(),
        CursorAdapter(),
        GeminiAdapter(),
        OpenCodeAdapter(),
    ])

    private let adaptersBySource: [String: any AgentAdapter]
    private let fallback: GenericHookAdapter

    public init(adapters: [any AgentAdapter], fallback: GenericHookAdapter = GenericHookAdapter()) {
        var adaptersBySource: [String: any AgentAdapter] = [:]
        for adapter in adapters {
            for sourceId in adapter.sourceIds {
                adaptersBySource[sourceId] = adapter
            }
        }

        self.adaptersBySource = adaptersBySource
        self.fallback = fallback
    }

    public func hookEvent(from envelope: BridgeEnvelope) throws -> HookEvent {
        let adapter = adaptersBySource[envelope.source] ?? fallback
        return try adapter.hookEvent(from: envelope)
    }

    public func directive(for request: ActionableRequest, resolution: ActionResolution) -> SourceDirective {
        let adapter = adaptersBySource[request.source] ?? fallback
        return adapter.directive(for: request, resolution: resolution)
    }

    public func blockingTimeout(for request: ActionableRequest) -> TimeInterval? {
        let adapter = adaptersBySource[request.source] ?? fallback
        return adapter.blockingTimeout(for: request)
    }
}
