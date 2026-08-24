public enum SetupCommandOperation: String, Sendable {
    case status
    case install
    case uninstall
    case repair
    case verify
    case printManifest
}

public struct SetupCommand: Sendable {
    public let operation: SetupCommandOperation
    public let sourceId: String?

    public init?(arguments: [String]) {
        guard let rawOperation = arguments.first else {
            return nil
        }

        switch rawOperation {
        case "status":
            operation = .status
        case "install":
            operation = .install
        case "uninstall":
            operation = .uninstall
        case "repair":
            operation = .repair
        case "verify":
            operation = .verify
        case "print-manifest", "printManifest":
            operation = .printManifest
        default:
            return nil
        }

        sourceId = arguments.dropFirst().first { !$0.hasPrefix("--") }
    }
}
