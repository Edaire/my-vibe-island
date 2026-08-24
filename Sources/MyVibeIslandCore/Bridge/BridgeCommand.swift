public enum BridgeCommand: String, Codable, Equatable, Sendable {
    case hello
    case hookEvent
    case watchEvent
    case resolveAction
    case updateJumpTarget
    case healthProbe
}
