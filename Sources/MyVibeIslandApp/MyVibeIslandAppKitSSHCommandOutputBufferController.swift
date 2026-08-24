import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSSHCommandOutputBufferController {
    public private(set) var lastBuffer: SSHCommandOutputBuffer?

    private let maxBytes: Int
    private let publishBuffer: @MainActor (SSHCommandOutputBuffer) -> Void

    public init(
        maxBytes: Int,
        publishBuffer: @escaping @MainActor (SSHCommandOutputBuffer) -> Void = { _ in }
    ) {
        self.maxBytes = maxBytes
        self.publishBuffer = publishBuffer
    }

    @discardableResult
    public func capture(
        stdout: String,
        stderr: String,
        exitCode: Int? = nil,
        durationMs: Int? = nil,
        redactionApplied: Bool = false
    ) -> SSHCommandOutputBuffer {
        let buffer = SSHCommandOutputBuffer(
            stdout: stdout,
            stderr: stderr,
            maxBytes: maxBytes,
            exitCode: exitCode,
            durationMs: durationMs,
            redactionApplied: redactionApplied
        )
        lastBuffer = buffer
        publishBuffer(buffer)
        return buffer
    }
}
