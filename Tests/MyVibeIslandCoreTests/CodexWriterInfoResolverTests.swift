import XCTest
@testable import MyVibeIslandCore

final class CodexWriterInfoResolverTests: XCTestCase {
    func testResolvesWriterPIDAndTTYFromV3LsofAndPSQueries() throws {
        let rollout = URL(fileURLWithPath: "/tmp/rollout-42.jsonl")
        let runner = RecordingProcessRunner(outputs: [
            ProcessInvocation(
                executable: "/usr/sbin/lsof",
                arguments: ["-F", "p", rollout.path]
            ): "p417\np811\n",
            ProcessInvocation(
                executable: "/bin/ps",
                arguments: ["-p", "417", "-o", "tty="]
            ): "ttys004\n",
        ])
        let resolver = CodexWriterInfoResolver(
            runner: runner,
            terminalBundleId: { pid in
                XCTAssertEqual(pid, 417)
                return "com.apple.Terminal"
            },
            deniedAncestorBundleId: { _ in nil }
        )

        let info = resolver.resolve(rolloutPath: rollout.path)

        XCTAssertEqual(info, CodexWriterInfo(
            tty: "/dev/ttys004",
            pid: 417,
            terminalBundleId: "com.apple.Terminal",
            outcome: .matched
        ))
        XCTAssertEqual(runner.invocations, [
            ProcessInvocation(executable: "/usr/sbin/lsof", arguments: ["-F", "p", rollout.path]),
            ProcessInvocation(executable: "/bin/ps", arguments: ["-p", "417", "-o", "tty="]),
        ])
    }
}

private struct ProcessInvocation: Hashable {
    let executable: String
    let arguments: [String]
}

private final class RecordingProcessRunner: LocalProcessSnapshotRunning, @unchecked Sendable {
    private let outputs: [ProcessInvocation: String]
    private(set) var invocations: [ProcessInvocation] = []

    init(outputs: [ProcessInvocation: String]) {
        self.outputs = outputs
    }

    func run(executable: String, arguments: [String]) throws -> String {
        let invocation = ProcessInvocation(executable: executable, arguments: arguments)
        invocations.append(invocation)
        return outputs[invocation] ?? ""
    }
}
