public enum AppExecutableMode: String, Codable, Equatable, Sendable {
    case cli
    case appShell
    case help
    case invalid
}

public struct AppExecutableModeResolution: Codable, Equatable, Sendable {
    public let mode: AppExecutableMode
    public let remainingArguments: [String]
    public let diagnostic: String?

    public init(
        mode: AppExecutableMode,
        remainingArguments: [String] = [],
        diagnostic: String? = nil
    ) {
        self.mode = mode
        self.remainingArguments = remainingArguments
        self.diagnostic = diagnostic
    }
}

public struct AppExecutableModeResolver: Sendable {
    public let defaultMode: AppExecutableMode

    public init(defaultMode: AppExecutableMode = .appShell) {
        self.defaultMode = defaultMode
    }

    public func resolve(arguments: [String]) -> AppExecutableModeResolution {
        guard let first = arguments.first else {
            return AppExecutableModeResolution(mode: defaultMode)
        }

        if first == "--" {
            return AppExecutableModeResolution(mode: .cli, remainingArguments: Array(arguments.dropFirst()))
        }

        if Self.helpFlags.contains(first) {
            return AppExecutableModeResolution(mode: .help, remainingArguments: Array(arguments.dropFirst()))
        }

        if Self.appShellAliases.contains(first) {
            return AppExecutableModeResolution(mode: .appShell, remainingArguments: Array(arguments.dropFirst()))
        }

        if Self.cliSubcommands.contains(first) || !first.hasPrefix("-") {
            return AppExecutableModeResolution(mode: .cli, remainingArguments: arguments)
        }

        return AppExecutableModeResolution(
            mode: .invalid,
            remainingArguments: arguments,
            diagnostic: "unknown top-level option: \(first)"
        )
    }

    private static let helpFlags: Set<String> = ["--help", "-h"]

    private static let appShellAliases: Set<String> = [
        "--app",
        "app",
        "launch-app"
    ]

    private static let cliSubcommands: Set<String> = [
        "status",
        "jump",
        "runtime",
        "sync-opencode",
        "bridge-smoke"
    ]
}
