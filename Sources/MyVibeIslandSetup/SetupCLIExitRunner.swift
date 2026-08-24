public struct SetupCLIExitResult: Equatable, Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public struct SetupCLIExitRunner {
    private let operation: ([String]) throws -> String

    public init(cli: SetupCLI = SetupCLI()) {
        operation = cli.run(arguments:)
    }

    init(operation: @escaping ([String]) throws -> String) {
        self.operation = operation
    }

    public func run(arguments: [String]) -> SetupCLIExitResult {
        do {
            return SetupCLIExitResult(stdout: try operation(arguments), stderr: "", exitCode: 0)
        } catch {
            return SetupCLIExitResult(stdout: "", stderr: error.localizedDescription, exitCode: 1)
        }
    }
}
