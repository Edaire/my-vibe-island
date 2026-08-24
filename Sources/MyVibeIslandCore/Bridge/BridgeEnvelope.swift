public struct BridgeEnvelope: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let clientRole: String
    public let source: String
    public let requestId: String?
    public let command: BridgeCommand
    public let payload: [String: BridgeJSONValue]
    public let sentAt: String?
    public let environment: HookEnvironment?

    public init(
        schemaVersion: Int,
        clientRole: String,
        source: String,
        requestId: String?,
        command: BridgeCommand,
        payload: [String: BridgeJSONValue],
        sentAt: String? = nil,
        environment: HookEnvironment? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.clientRole = clientRole
        self.source = source
        self.requestId = requestId
        self.command = command
        self.payload = payload
        self.sentAt = sentAt
        self.environment = environment
    }
}
