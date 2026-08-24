public struct SSHLocalProcessRow: Codable, Equatable, Sendable {
    public let pid: Int
    public let tty: String?
    public let command: String
    public let arguments: [String]

    public init(
        pid: Int,
        tty: String? = nil,
        command: String,
        arguments: [String] = []
    ) {
        self.pid = pid
        self.tty = tty
        self.command = command
        self.arguments = arguments
    }
}
