import Foundation
import XCTest
@testable import MyVibeIslandCore

final class AppRuntimeOpenCodeSyncTests: XCTestCase {
    func testStopLocalSessionWatchersLeavesBridgeRunning() throws {
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        try runtime.startBridge()
        runtime.startLocalSessionWatchers(homeDirectory: FileManager.default.temporaryDirectory)

        runtime.stopLocalSessionWatchers()

        XCTAssertTrue(runtime.status().isBridgeRunning)
        runtime.stop()
        XCTAssertFalse(runtime.status().isBridgeRunning)
    }

    func testConcurrentWatcherStartsPublishOpenCodeBootstrapOnce() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = home.appendingPathComponent(".local/share/opencode/storage/session")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "{\"session\":{\"directory\":\"/tmp/concurrent-start\"},\"messages\":[]}".write(
            to: root.appendingPathComponent("session.json"), atomically: true, encoding: .utf8
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }
        let recorder = RuntimeSnapshotRecorder()
        let published = DispatchSemaphore(value: 0)
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        runtime.setIslandRuntimeDidChange {
            recorder.append($0)
            published.signal()
        }
        let group = DispatchGroup()
        for _ in 0..<4 {
            group.enter()
            DispatchQueue.global().async {
                runtime.startLocalSessionWatchers(homeDirectory: home)
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(published.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(recorder.snapshots.filter { $0.sessions.map(\.id) == ["/tmp/concurrent-start"] }.count, 1)
        runtime.stopLocalSessionWatchers()
    }

    func testReentrantPublishQueuesWithoutDeadlockOrDuplicateRevision() {
        let coordinator = SessionCoordinator()
        coordinator.apply(.sessionStarted(source: "codex", sessionId: "one", cwd: "/tmp/one"))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionCoordinator: coordinator)
        let callback = DispatchSemaphore(value: 0)
        let recorder = RuntimeSnapshotRecorder()
        runtime.setIslandRuntimeDidChange { snapshot in
            recorder.append(snapshot)
            runtime.publishSessionPreviews()
            callback.signal()
        }

        DispatchQueue.global().async { runtime.publishSessionPreviews() }

        XCTAssertEqual(callback.wait(timeout: .now() + 1), .success)
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertEqual(recorder.snapshots.count, 1)
    }

    func testLegacyOpenCodeSyncPublishesUpdatedRuntimeSnapshot() throws {
        let root = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/opencode-published", to: root.appendingPathComponent("session.json"))
        let recorder = RuntimeSnapshotRecorder()
        let published = DispatchSemaphore(value: 0)
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        runtime.setIslandRuntimeDidChange {
            recorder.append($0)
            published.signal()
        }

        runtime.syncOpenCodeDiskSessions(rootURL: root)

        XCTAssertEqual(published.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(recorder.snapshots.count, 1)
        XCTAssertEqual(recorder.snapshots.first?.sessions.map(\.id), ["/tmp/opencode-published"])
    }

    func testStartOwnsLocalWatchersWithoutImportingClaudeProjectHistory() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let opencode = home.appendingPathComponent(".local/share/opencode/storage/session")
        let claude = home.appendingPathComponent(".claude/projects/project")
        try FileManager.default.createDirectory(at: opencode, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
        try "{\"session\":{\"directory\":\"/tmp/opencode-live\"},\"messages\":[]}".write(
            to: opencode.appendingPathComponent("session.json"), atomically: true, encoding: .utf8
        )
        try "{\"sessionId\":\"claude-live\",\"cwd\":\"/tmp/claude-live\"}\n".write(
            to: claude.appendingPathComponent("session.jsonl"), atomically: true, encoding: .utf8
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }

        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        runtime.startLocalSessionWatchers(homeDirectory: home)

        let deadline = Date().addingTimeInterval(1)
        while runtime.sessionSnapshot(sessionId: "/tmp/opencode-live") == nil, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "/tmp/opencode-live")?.source, "opencode")
        XCTAssertNil(runtime.sessionSnapshot(sessionId: "claude-live"))

        runtime.stopLocalSessionWatchers()
    }

    func testAppRuntimeOpenCodeSyncMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppRuntimeOpenCodeSyncMatrixFixture.self,
            from: try FixtureLoader.data("runtime/app-runtime-opencode-sync-matrix")
        )

        let preSyncRuntime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())

        let mixedRoot = try temporaryRoot()
        try "{ broken".write(to: mixedRoot.appendingPathComponent("broken.json"), atomically: true, encoding: .utf8)
        try writeSnapshot(directory: "/tmp/opencode-valid", to: mixedRoot.appendingPathComponent("valid.json"))
        let mixedRuntime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        let mixedResults = mixedRuntime.syncOpenCodeDiskSessions(rootURL: mixedRoot)

        let persistedRoot = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/opencode-persisted", to: persistedRoot.appendingPathComponent("session.json"))
        let store = InMemorySessionStore()
        let persistedRuntime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionStore: store)
        let persistedResults = persistedRuntime.syncOpenCodeDiskSessions(rootURL: persistedRoot)

        let missingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-opencode-runtime-sync-tests")
            .appendingPathComponent(UUID().uuidString)
        let missingStore = InMemorySessionStore()
        let missingRuntime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionStore: missingStore)
        let missingResults = missingRuntime.syncOpenCodeDiskSessions(rootURL: missingRoot)

        let actual = AppRuntimeOpenCodeSyncMatrixFixture(rows: [
            AppRuntimeOpenCodeSyncMatrixRow(
                id: "pre-sync-diagnostics-empty",
                resultFileNames: [],
                failedResultCount: 0,
                runtimeSessionIds: [],
                storeSessionIds: [],
                rootDirectoryExistsAfterSync: nil,
                diagnostics: diagnosticRow(preSyncRuntime.status().openCodeSyncDiagnostics, root: nil)
            ),
            row(
                id: "mixed-valid-and-broken-files",
                root: mixedRoot,
                results: mixedResults,
                runtime: mixedRuntime
            ),
            row(
                id: "persists-valid-session-to-injected-store",
                root: persistedRoot,
                results: persistedResults,
                runtime: persistedRuntime,
                store: store
            ),
            row(
                id: "missing-root-no-mutation",
                root: missingRoot,
                results: missingResults,
                runtime: missingRuntime,
                store: missingStore
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testOpenCodeSyncDiagnosticsAreNilBeforeFirstSync() {
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())

        XCTAssertNil(runtime.status().openCodeSyncDiagnostics)
    }

    func testSyncOpenCodeDiskSessionsCreatesRuntimeSession() throws {
        let root = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/opencode-runtime", to: root.appendingPathComponent("session.json"))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())

        let results = runtime.syncOpenCodeDiskSessions(rootURL: root)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.snapshot?.session.directory, "/tmp/opencode-runtime")
        XCTAssertNil(results.first?.errorDescription)
        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "/tmp/opencode-runtime")?.source, "opencode")
        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "/tmp/opencode-runtime")?.cwd, "/tmp/opencode-runtime")
        XCTAssertEqual(runtime.status().openCodeSyncDiagnostics, OpenCodeSyncDiagnostics(
            rootPath: root.path,
            attemptedFileCount: 1,
            successfulSnapshotCount: 1,
            failedSnapshotCount: 0,
            emittedEventCount: 1,
            rootMissing: false
        ))
    }

    func testSyncOpenCodeDiskSessionsPersistsToInjectedStore() throws {
        let root = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/opencode-persisted", to: root.appendingPathComponent("session.json"))
        let store = InMemorySessionStore()
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionStore: store)

        runtime.syncOpenCodeDiskSessions(rootURL: root)

        XCTAssertEqual(store.loadSnapshot().sessions.map(\.id), ["/tmp/opencode-persisted"])
        XCTAssertEqual(store.loadSnapshot().sessions.first?.source, "opencode")
        XCTAssertEqual(store.loadSnapshot().sessions.first?.cwd, "/tmp/opencode-persisted")
    }

    func testSyncOpenCodeDiskSessionsReturnsFailuresAndAppliesValidSnapshots() throws {
        let root = try temporaryRoot()
        try "{ broken".write(to: root.appendingPathComponent("broken.json"), atomically: true, encoding: .utf8)
        try writeSnapshot(directory: "/tmp/opencode-valid", to: root.appendingPathComponent("valid.json"))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())

        let results = runtime.syncOpenCodeDiskSessions(rootURL: root)

        XCTAssertEqual(results.map(\.fileURL.lastPathComponent), ["broken.json", "valid.json"])
        XCTAssertNil(results[0].snapshot)
        XCTAssertNotNil(results[0].errorDescription)
        XCTAssertEqual(results[1].snapshot?.session.directory, "/tmp/opencode-valid")
        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "/tmp/opencode-valid")?.source, "opencode")
        XCTAssertEqual(runtime.status().openCodeSyncDiagnostics, OpenCodeSyncDiagnostics(
            rootPath: root.path,
            attemptedFileCount: 2,
            successfulSnapshotCount: 1,
            failedSnapshotCount: 1,
            emittedEventCount: 1,
            rootMissing: false
        ))
    }

    func testSyncOpenCodeDiskSessionsMissingRootDoesNotMutateRuntimeOrStore() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-opencode-runtime-sync-tests")
            .appendingPathComponent(UUID().uuidString)
        let store = InMemorySessionStore()
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionStore: store)

        let results = runtime.syncOpenCodeDiskSessions(rootURL: root)

        XCTAssertEqual(results, [])
        XCTAssertEqual(runtime.status().sessionCount, 0)
        XCTAssertEqual(store.loadSnapshot().sessions, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        XCTAssertEqual(runtime.status().openCodeSyncDiagnostics, OpenCodeSyncDiagnostics(
            rootPath: root.path,
            attemptedFileCount: 0,
            successfulSnapshotCount: 0,
            failedSnapshotCount: 0,
            emittedEventCount: 0,
            rootMissing: true
        ))
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-opencode-runtime-sync-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private func writeSnapshot(directory: String, to url: URL) throws {
        try """
        {
          "session": {
            "directory": "\(directory)"
          },
          "messages": []
        }
        """.write(to: url, atomically: true, encoding: .utf8)
    }

    private func row(
        id: String,
        root: URL,
        results: [OpenCodeDiskSessionScanResult],
        runtime: AppRuntime,
        store: SessionStore? = nil
    ) -> AppRuntimeOpenCodeSyncMatrixRow {
        AppRuntimeOpenCodeSyncMatrixRow(
            id: id,
            resultFileNames: results.map(\.fileURL.lastPathComponent),
            failedResultCount: results.filter { $0.errorDescription != nil }.count,
            runtimeSessionIds: runtime.runtimeSessionSnapshots().map(\.snapshot.sessionId),
            storeSessionIds: store?.loadSnapshot().sessions.map(\.id) ?? [],
            rootDirectoryExistsAfterSync: FileManager.default.fileExists(atPath: root.path),
            diagnostics: diagnosticRow(runtime.status().openCodeSyncDiagnostics, root: root)
        )
    }

    private func diagnosticRow(
        _ diagnostics: OpenCodeSyncDiagnostics?,
        root: URL?
    ) -> AppRuntimeOpenCodeSyncDiagnosticsRow? {
        guard let diagnostics else {
            return nil
        }

        let rootPath = root.map { diagnostics.rootPath.replacingOccurrences(of: $0.path, with: "$ROOT") }
            ?? diagnostics.rootPath
        return AppRuntimeOpenCodeSyncDiagnosticsRow(
            rootPath: rootPath,
            attemptedFileCount: diagnostics.attemptedFileCount,
            successfulSnapshotCount: diagnostics.successfulSnapshotCount,
            failedSnapshotCount: diagnostics.failedSnapshotCount,
            emittedEventCount: diagnostics.emittedEventCount,
            rootMissing: diagnostics.rootMissing
        )
    }

    private struct AppRuntimeOpenCodeSyncMatrixFixture: Codable, Equatable {
        let rows: [AppRuntimeOpenCodeSyncMatrixRow]
    }

    private struct AppRuntimeOpenCodeSyncMatrixRow: Codable, Equatable {
        let id: String
        let resultFileNames: [String]
        let failedResultCount: Int
        let runtimeSessionIds: [String]
        let storeSessionIds: [String]
        let rootDirectoryExistsAfterSync: Bool?
        let diagnostics: AppRuntimeOpenCodeSyncDiagnosticsRow?
    }

    private struct AppRuntimeOpenCodeSyncDiagnosticsRow: Codable, Equatable {
        let rootPath: String
        let attemptedFileCount: Int
        let successfulSnapshotCount: Int
        let failedSnapshotCount: Int
        let emittedEventCount: Int
        let rootMissing: Bool
    }
}

private final class RuntimeSnapshotRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var snapshots: [IslandRuntimeSnapshot] = []
    func append(_ snapshot: IslandRuntimeSnapshot) {
        lock.lock()
        snapshots.append(snapshot)
        lock.unlock()
    }
}
