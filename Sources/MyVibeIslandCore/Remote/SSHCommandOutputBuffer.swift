public struct SSHCommandOutputBuffer: Codable, Equatable, Sendable {
    public let stdoutTail: String
    public let stderrTail: String
    public let maxBytes: Int
    public let truncated: Bool
    public let exitCode: Int?
    public let durationMs: Int?
    public let redactionApplied: Bool

    public init(
        stdout: String,
        stderr: String,
        maxBytes: Int,
        exitCode: Int? = nil,
        durationMs: Int? = nil,
        redactionApplied: Bool = false
    ) {
        let boundedMaxBytes = max(0, maxBytes)
        self.stdoutTail = String(stdout.suffix(boundedMaxBytes))
        self.stderrTail = String(stderr.suffix(boundedMaxBytes))
        self.maxBytes = boundedMaxBytes
        self.truncated = stdout.count > boundedMaxBytes || stderr.count > boundedMaxBytes
        self.exitCode = exitCode
        self.durationMs = durationMs
        self.redactionApplied = redactionApplied
    }
}
