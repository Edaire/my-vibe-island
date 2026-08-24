import XCTest
@testable import MyVibeIslandCore

final class AppRuntimeSessionStoreTests: XCTestCase {
    private final class RecordingJumpRunner: TerminalJumpActionRunning, @unchecked Sendable {
        private(set) var actions: [TerminalJumpActionDescription] = []
        private let result: TerminalJumpRunnerResult

        init(result: TerminalJumpRunnerResult) {
            self.result = result
        }

        func run(_ action: TerminalJumpActionDescription) -> TerminalJumpRunnerResult {
            actions.append(action)
            return result
        }
    }

    func testAppRuntimeSessionStoreMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppRuntimeSessionStoreMatrixFixture.self,
            from: try FixtureLoader.data("runtime/app-runtime-session-store-matrix")
        )
        let home = temporaryHomeDirectory()
        let defaultURL = AppRuntimeSessionStore.defaultFileURL(homeDirectory: home)
        let defaultDirectoryExists = FileManager.default.fileExists(
            atPath: home.appendingPathComponent("Library/Application Support/MyVibeIsland").path
        )

        let jumpInput = JumpInput(sessionId: "restored", source: "codex", cwd: "/tmp/restored")
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "restored",
                source: "codex",
                cwd: "/tmp/restored",
                jumpInput: jumpInput,
                resolvedJumpTarget: TerminalResolver().resolve(jumpInput)
            ),
        ]))
        let runner = RecordingJumpRunner(result: .succeeded("runner executed"))
        let runtime = AppRuntimeSessionStore.runtime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            homeDirectory: home,
            jumpRunner: runner
        )
        let result = runtime.executeJumpToSession(sessionId: "restored", mode: .execute)

        let actual = AppRuntimeSessionStoreMatrixFixture(
            defaultPathSuffix: defaultURL.path.replacingOccurrences(of: home.path, with: "$HOME"),
            defaultDirectoryExistsAfterPathCalculation: defaultDirectoryExists,
            restoredSessionIds: runtime.runtimeSessionSnapshots().map(\.snapshot.sessionId),
            restoredCwd: runtime.sessionSnapshot(sessionId: "restored")?.cwd,
            jumpStatus: result.status.rawValue,
            jumpDiagnosticSummary: result.diagnosticSummary,
            runnerActionKinds: runner.actions.map(\.kind.rawValue)
        )

        XCTAssertEqual(actual, expected)
    }

    func testDefaultFileURLUsesApplicationSupportPathUnderSuppliedHomeDirectory() {
        let home = temporaryHomeDirectory()

        let url = AppRuntimeSessionStore.defaultFileURL(homeDirectory: home)

        XCTAssertEqual(
            url.path,
            home
                .appendingPathComponent("Library/Application Support/MyVibeIsland")
                .appendingPathComponent("sessions.json")
                .path
        )
    }

    func testTerminalSessionMapFileURLsPreferMyStoreThenOriginalCompatibilityStore() {
        let home = temporaryHomeDirectory()

        let urls = AppRuntimeSessionStore.terminalSessionMapFileURLs(homeDirectory: home)

        XCTAssertEqual(urls.map(\.path), [
            home
                .appendingPathComponent("Library/Application Support/MyVibeIsland")
                .appendingPathComponent("session-terminals.json")
                .path,
            home
                .appendingPathComponent("Library/Application Support/vibe-island")
                .appendingPathComponent("session-terminals.json")
                .path,
        ])
    }

    func testDefaultPathCalculationDoesNotCreateDirectories() {
        let home = temporaryHomeDirectory()

        _ = AppRuntimeSessionStore.defaultFileURL(homeDirectory: home)

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: home.appendingPathComponent("Library/Application Support/MyVibeIsland").path
        ))
    }

    func testDefaultStoreLoadsExistingSnapshotFromSuppliedHomeDirectory() {
        let home = temporaryHomeDirectory()
        let store = JSONSessionStore(fileURL: AppRuntimeSessionStore.defaultFileURL(homeDirectory: home))
        store.replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(id: "stored", source: "codex", cwd: "/tmp/stored"),
        ]))

        let reloaded = AppRuntimeSessionStore.defaultStore(homeDirectory: home)

        XCTAssertEqual(reloaded.loadSnapshot().sessions.map(\.id), ["stored"])
    }

    func testRuntimeFactoryRestoresFromDefaultStore() {
        let home = temporaryHomeDirectory()
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(id: "restored", source: "codex", cwd: "/tmp/restored"),
        ]))

        let runtime = AppRuntimeSessionStore.runtime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            homeDirectory: home
        )

        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "restored")?.cwd, "/tmp/restored")
    }

    func testRuntimeFactoryPassesJumpRunnerThrough() {
        let home = temporaryHomeDirectory()
        let jumpInput = JumpInput(sessionId: "restored", source: "codex", cwd: "/tmp/restored")
        AppRuntimeSessionStore.defaultStore(homeDirectory: home).replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "restored",
                source: "codex",
                cwd: "/tmp/restored",
                jumpInput: jumpInput,
                resolvedJumpTarget: TerminalResolver().resolve(jumpInput)
            ),
        ]))
        let runner = RecordingJumpRunner(result: .succeeded("runner executed"))
        let runtime = AppRuntimeSessionStore.runtime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            homeDirectory: home,
            jumpRunner: runner
        )

        let result = runtime.executeJumpToSession(sessionId: "restored", mode: .execute)

        XCTAssertEqual(result.status, .executed)
        XCTAssertEqual(result.diagnosticSummary, "runner executed")
        XCTAssertEqual(runner.actions.map(\.kind), [.openWorkspace])
    }

    func testRuntimeFactorySavesAcceptedHookEventToDefaultStoreFile() throws {
        let home = temporaryHomeDirectory()
        let socketPath = BridgeSocketPath.temporaryForTests()
        let runtime = AppRuntimeSessionStore.runtime(socketPath: socketPath, homeDirectory: home)
        try runtime.startBridge()
        defer {
            runtime.stop()
        }

        let response = try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "hook",
                source: "codex",
                requestId: nil,
                command: .hookEvent,
                payload: [
                    "rawEventName": .string("SessionStart"),
                    "sessionId": .string("s1"),
                    "cwd": .string("/tmp/project"),
                ]
            )
        )

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(
            JSONSessionStore(fileURL: AppRuntimeSessionStore.defaultFileURL(homeDirectory: home))
                .loadSnapshot()
                .sessions
                .map(\.id),
            ["s1"]
        )
    }

    private func temporaryHomeDirectory() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-runtime-store-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private struct AppRuntimeSessionStoreMatrixFixture: Codable, Equatable {
        let defaultPathSuffix: String
        let defaultDirectoryExistsAfterPathCalculation: Bool
        let restoredSessionIds: [String]
        let restoredCwd: String?
        let jumpStatus: String
        let jumpDiagnosticSummary: String
        let runnerActionKinds: [String]
    }
}
