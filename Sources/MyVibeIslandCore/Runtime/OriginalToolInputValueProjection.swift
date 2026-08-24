public enum OriginalToolInputValueProjection {
    public static func resolve(_ value: BridgeJSONValue) -> String {
        switch value {
        case let .string(value):
            value
        case let .integer(value):
            value.description
        case let .number(value):
            value.description
        case let .bool(value):
            value.description
        case let .array(values):
            values.map(resolve).joined(separator: ", ")
        case let .object(values):
            values.map { key, value in
                "\(key): \(resolve(value))"
            }.joined(separator: ", ")
        case .null:
            ""
        }
    }
}
