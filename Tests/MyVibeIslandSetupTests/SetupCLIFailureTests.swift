import Foundation
import XCTest
@testable import MyVibeIslandSetup

final class SetupCLIFailureTests: XCTestCase {
    func testVerifyFailureIsThrownForNonZeroExecutableExit() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }
        XCTAssertThrowsError(try SetupCLI().run(arguments: ["verify", "codex", "--home", home.path])) { error in
            XCTAssertEqual(error as? SetupCLIError, .verificationFailed("codex"))
        }
    }

    func testVerifyFailureReturnsNonZeroExitCodeWithoutBuiltExecutable() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }

        let result = SetupCLIExitRunner().run(arguments: ["verify", "codex", "--home", home.path])

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertTrue(result.stderr.contains("verification failed for codex"))
        XCTAssertTrue(result.stdout.isEmpty)
    }

    func testTypedMutationFailureReturnsNonZeroExitCodeWithoutBuiltExecutable() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let path = home.appendingPathComponent(".kimi/config.toml")
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("hooks = [\n  { command = \"foreign\" }\n]\n".utf8).write(to: path)
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }

        let result = SetupCLIExitRunner().run(arguments: ["install", "kimi", "--home", home.path])

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertFalse(result.stderr.isEmpty)
        XCTAssertTrue(result.stdout.isEmpty)
    }

    func testSuccessfulCommandReturnsZeroExitCodeAndStdout() {
        let result = SetupCLIExitRunner().run(arguments: [])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("My Vibe Island setup"))
        XCTAssertTrue(result.stderr.isEmpty)
    }
}
