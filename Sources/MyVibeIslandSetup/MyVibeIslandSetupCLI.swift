public struct MyVibeIslandSetupCLI {
    private let cli: SetupCLI

    public init(cli: SetupCLI = SetupCLI()) {
        self.cli = cli
    }

    public func run(arguments: [String]) throws -> String {
        try cli.run(arguments: arguments)
    }
}
