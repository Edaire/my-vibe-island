import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitSSHCommandOutputBufferControllerTests: XCTestCase {
    @MainActor
    func testSSHCommandOutputBufferControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SSHCommandOutputBufferControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/ssh-command-output-buffer-controller-matrix")
        )

        let actual = SSHCommandOutputBufferControllerMatrixFixture(rows: [
            row(
                id: "bounded-redacted-failure-output",
                maxBytes: 4,
                captures: [
                    capture(
                        stdout: "0123456789",
                        stderr: "abcdefghij",
                        exitCode: 2,
                        durationMs: 99,
                        redactionApplied: true
                    )
                ]
            ),
            row(
                id: "negative-limit-normalizes-to-empty-tail",
                maxBytes: -1,
                captures: [
                    capture(stdout: "output", stderr: "error")
                ]
            ),
            row(
                id: "latest-capture-replaces-last-buffer",
                maxBytes: 6,
                captures: [
                    capture(stdout: "first-output", stderr: "first-error", exitCode: 1),
                    capture(stdout: "ok", stderr: "", exitCode: 0, durationMs: 12)
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testCaptureBuildsBoundedOutputBufferAndPublishesIt() {
        var published: [SSHCommandOutputBuffer] = []
        let controller = MyVibeIslandAppKitSSHCommandOutputBufferController(
            maxBytes: 4,
            publishBuffer: { buffer in
                published.append(buffer)
            }
        )

        let buffer = controller.capture(
            stdout: "0123456789",
            stderr: "abcdefghij",
            exitCode: 2,
            durationMs: 99,
            redactionApplied: true
        )

        XCTAssertEqual(buffer.stdoutTail, "6789")
        XCTAssertEqual(buffer.stderrTail, "ghij")
        XCTAssertTrue(buffer.truncated)
        XCTAssertEqual(controller.lastBuffer, buffer)
        XCTAssertEqual(published, [buffer])
    }

    @MainActor
    func testCaptureUsesNonNegativeMaxBytes() {
        let controller = MyVibeIslandAppKitSSHCommandOutputBufferController(maxBytes: -1)

        let buffer = controller.capture(stdout: "output", stderr: "error")

        XCTAssertEqual(buffer.maxBytes, 0)
        XCTAssertEqual(buffer.stdoutTail, "")
        XCTAssertEqual(buffer.stderrTail, "")
        XCTAssertTrue(buffer.truncated)
    }

    private func capture(
        stdout: String,
        stderr: String,
        exitCode: Int? = nil,
        durationMs: Int? = nil,
        redactionApplied: Bool = false
    ) -> SSHCommandOutputBufferControllerCapture {
        SSHCommandOutputBufferControllerCapture(
            stdout: stdout,
            stderr: stderr,
            exitCode: exitCode,
            durationMs: durationMs,
            redactionApplied: redactionApplied
        )
    }

    @MainActor
    private func row(
        id: String,
        maxBytes: Int,
        captures: [SSHCommandOutputBufferControllerCapture]
    ) -> SSHCommandOutputBufferControllerMatrixRow {
        var events: [SSHCommandOutputBufferSummary] = []
        let controller = MyVibeIslandAppKitSSHCommandOutputBufferController(
            maxBytes: maxBytes,
            publishBuffer: { buffer in
                events.append(SSHCommandOutputBufferSummary(buffer))
            }
        )

        let buffers = captures.map { capture in
            SSHCommandOutputBufferSummary(controller.capture(
                stdout: capture.stdout,
                stderr: capture.stderr,
                exitCode: capture.exitCode,
                durationMs: capture.durationMs,
                redactionApplied: capture.redactionApplied
            ))
        }

        return SSHCommandOutputBufferControllerMatrixRow(
            id: id,
            captures: captures.map(\.summary),
            buffers: buffers,
            lastBuffer: controller.lastBuffer.map(SSHCommandOutputBufferSummary.init),
            events: events
        )
    }
}

private struct SSHCommandOutputBufferControllerMatrixFixture: Codable, Equatable {
    let rows: [SSHCommandOutputBufferControllerMatrixRow]
}

private struct SSHCommandOutputBufferControllerMatrixRow: Codable, Equatable {
    let id: String
    let captures: [String]
    let buffers: [SSHCommandOutputBufferSummary]
    let lastBuffer: SSHCommandOutputBufferSummary?
    let events: [SSHCommandOutputBufferSummary]
}

private struct SSHCommandOutputBufferControllerCapture {
    let stdout: String
    let stderr: String
    let exitCode: Int?
    let durationMs: Int?
    let redactionApplied: Bool

    var summary: String {
        [
            "capture",
            "stdout=\(stdout.count)",
            "stderr=\(stderr.count)",
            "exit=\(exitCode.map(String.init) ?? "nil")",
            "duration=\(durationMs.map(String.init) ?? "nil")",
            "redacted=\(redactionApplied)"
        ].joined(separator: ":")
    }
}

private struct SSHCommandOutputBufferSummary: Codable, Equatable {
    let stdoutTail: String
    let stderrTail: String
    let maxBytes: Int
    let truncated: Bool
    let exitCode: Int?
    let durationMs: Int?
    let redactionApplied: Bool

    init(_ buffer: SSHCommandOutputBuffer) {
        self.stdoutTail = buffer.stdoutTail
        self.stderrTail = buffer.stderrTail
        self.maxBytes = buffer.maxBytes
        self.truncated = buffer.truncated
        self.exitCode = buffer.exitCode
        self.durationMs = buffer.durationMs
        self.redactionApplied = buffer.redactionApplied
    }
}
