import XCTest
@testable import MyVibeIslandCore

final class ActiveCliTTYProviderTests: XCTestCase {
    func testTerminalReadsSelectedTabTTYWithFrozenAppleScript() {
        let runner = ActiveCliTTYRecordingRunner(output: " /dev/ttys002\n")
        let provider = ActiveCliTTYProvider(
            frontmostBundleIdentifier: { "com.apple.Terminal" },
            runner: runner
        )

        XCTAssertEqual(provider.activeTTYs(), ["ttys002"])
        XCTAssertEqual(runner.executable, "/usr/bin/osascript")
        XCTAssertEqual(runner.arguments, [["-e", ActiveCliTTYProvider.terminalScript]])
    }

    func testITermReadsCurrentSessionTTYWithFrozenAppleScript() {
        let runner = ActiveCliTTYRecordingRunner(output: "/dev/ttys003")
        let provider = ActiveCliTTYProvider(
            frontmostBundleIdentifier: { "com.googlecode.iterm2" },
            runner: runner
        )

        XCTAssertEqual(provider.activeTTYs(), ["ttys003"])
        XCTAssertEqual(runner.arguments, [["-e", ActiveCliTTYProvider.iTermScript]])
    }

    func testUnknownFrontmostApplicationAndScriptFailureFailClosed() {
        let unknownRunner = ActiveCliTTYRecordingRunner(output: "/dev/ttys004")
        let unknown = ActiveCliTTYProvider(
            frontmostBundleIdentifier: { "com.apple.Safari" },
            runner: unknownRunner
        )
        let failing = ActiveCliTTYProvider(
            frontmostBundleIdentifier: { "com.apple.Terminal" },
            runner: ActiveCliTTYRecordingRunner(error: ActiveCliTTYTestError.failed)
        )

        XCTAssertEqual(unknown.activeTTYs(), [])
        XCTAssertNil(unknownRunner.executable)
        XCTAssertEqual(failing.activeTTYs(), [])
    }

    func testTmuxSessionsDoNotAddUnfocusedPaneTTYsToForegroundEvidence() {
        let runner = ActiveCliTTYRecordingRunner(outputs: [
            "/dev/ttys004",
            "/dev/ttys007 0\n/dev/ttys008 1\n",
        ])
        let tmuxSession = AgentSession(
            id: "tmux-session",
            source: "codex",
            cwd: "/work/tmux",
            jumpInput: JumpInput(
                sessionId: "tmux-session",
                source: "codex",
                cwd: "/work/tmux",
                isInTmux: true
            )
        )
        let provider = ActiveCliTTYProvider(
            frontmostBundleIdentifier: { "com.apple.Terminal" },
            runner: runner
        )

        XCTAssertEqual(provider.activeTTYs(for: [tmuxSession]), ["ttys004"])
        XCTAssertEqual(runner.arguments, [
            ["-e", ActiveCliTTYProvider.terminalScript],
        ])
    }

    func testTmuxIsNotProbedWhenNoVisibleSessionUsesTmux() {
        let runner = ActiveCliTTYRecordingRunner(outputs: ["/dev/ttys004"])
        let provider = ActiveCliTTYProvider(
            frontmostBundleIdentifier: { "com.apple.Terminal" },
            runner: runner
        )

        XCTAssertEqual(provider.activeTTYs(for: []), ["ttys004"])
        XCTAssertEqual(runner.arguments, [["-e", ActiveCliTTYProvider.terminalScript]])
    }
}

private enum ActiveCliTTYTestError: Error { case failed }

private final class ActiveCliTTYRecordingRunner: LocalProcessSnapshotRunning, @unchecked Sendable {
    private var outputs: [String]
    private let error: Error?
    var executable: String?
    var arguments: [[String]] = []

    init(output: String = "", error: Error? = nil) {
        self.outputs = [output]
        self.error = error
    }

    init(outputs: [String]) {
        self.outputs = outputs
        self.error = nil
    }

    func run(executable: String, arguments: [String]) throws -> String {
        self.executable = executable
        self.arguments.append(arguments)
        if let error { throw error }
        return outputs.isEmpty ? "" : outputs.removeFirst()
    }
}
