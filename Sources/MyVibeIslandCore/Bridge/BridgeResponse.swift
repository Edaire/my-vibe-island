public enum BridgeResponseTransportDisposition: Equatable, Sendable {
    case reply
    case closeWithoutReply
}

public struct BridgeResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let message: String?
    public let sourceDirective: BridgeJSONValue?
    public let transportDisposition: BridgeResponseTransportDisposition

    public init(
        ok: Bool,
        message: String? = nil,
        sourceDirective: BridgeJSONValue? = nil,
        transportDisposition: BridgeResponseTransportDisposition = .reply
    ) {
        self.ok = ok
        self.message = message
        self.sourceDirective = sourceDirective
        self.transportDisposition = transportDisposition
    }

    public static func ok(message: String? = nil, sourceDirective: BridgeJSONValue? = nil) -> BridgeResponse {
        BridgeResponse(ok: true, message: message, sourceDirective: sourceDirective)
    }

    public static func failure(message: String? = nil, sourceDirective: BridgeJSONValue? = nil) -> BridgeResponse {
        BridgeResponse(ok: false, message: message, sourceDirective: sourceDirective)
    }

    public static func nativeApprovalHandoff() -> BridgeResponse {
        BridgeResponse(ok: true, transportDisposition: .closeWithoutReply)
    }

    private enum CodingKeys: String, CodingKey {
        case ok
        case message
        case sourceDirective
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decode(Bool.self, forKey: .ok)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        sourceDirective = try container.decodeIfPresent(BridgeJSONValue.self, forKey: .sourceDirective)
        transportDisposition = .reply
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ok, forKey: .ok)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(sourceDirective, forKey: .sourceDirective)
    }
}
