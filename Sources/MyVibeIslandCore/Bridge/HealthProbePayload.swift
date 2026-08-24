struct HealthProbePayload: Equatable, Sendable {
    let source: String

    init(payload: [String: BridgeJSONValue]) throws {
        guard Set(payload.keys) == ["source"],
              case let .string(source) = payload["source"], !source.isEmpty else {
            throw AgentAdapterError.invalidHookPayload
        }
        self.source = source
    }

    func response() -> BridgeJSONValue {
        .object([
            "reachable": .bool(true),
            "hookInstalled": .null,
            "hashStatus": .string("notChecked"),
            "lastEventAt": .null,
            "originStatus": .string("recognized"),
        ])
    }
}
