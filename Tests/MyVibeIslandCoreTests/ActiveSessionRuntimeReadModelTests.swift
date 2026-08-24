import XCTest
@testable import MyVibeIslandCore

final class ActiveSessionRuntimeReadModelTests: XCTestCase {
    func testActiveSessionRuntimeReadModelMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ActiveSessionRuntimeReadModelMatrixFixture.self,
            from: try FixtureLoader.data("runtime/active-session-read-model-matrix")
        )
        let withoutStore = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project"),
            ])
        )
        let activeStore = InMemorySessionStore(snapshot: SessionStoreSnapshot(
            sessions: [
                AgentSession(id: "s1", source: "codex", cwd: "/tmp/one"),
                AgentSession(id: "s2", source: "claude", cwd: "/tmp/two"),
            ],
            activeSessionId: "s2"
        ))
        let activeRuntime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionStore: activeStore)
        let missingStore = InMemorySessionStore(snapshot: SessionStoreSnapshot(
            sessions: [
                AgentSession(id: "s1", source: "codex", cwd: "/tmp/one"),
            ],
            activeSessionId: "missing"
        ))
        let missingRuntime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionStore: missingStore)
        let home = temporaryHomeDirectory()
        let jsonStore = AppRuntimeSessionStore.defaultStore(homeDirectory: home)
        jsonStore.replaceSnapshot(SessionStoreSnapshot(
            sessions: [
                AgentSession(id: "restored", source: "codex", cwd: "/tmp/restored"),
            ],
            activeSessionId: "restored"
        ))
        let restoredRuntime = AppRuntimeSessionStore.runtime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            homeDirectory: home
        )

        let cases = [
            ActiveSessionRuntimeReadModelCase(
                name: "runtime-without-store-has-no-active-session",
                projection: ActiveSessionRuntimeReadModelProjection(withoutStore)
            ),
            ActiveSessionRuntimeReadModelCase(
                name: "runtime-marks-configured-active-session",
                projection: ActiveSessionRuntimeReadModelProjection(activeRuntime)
            ),
            ActiveSessionRuntimeReadModelCase(
                name: "missing-active-session-id-is-ignored",
                projection: ActiveSessionRuntimeReadModelProjection(missingRuntime)
            ),
            ActiveSessionRuntimeReadModelCase(
                name: "default-json-runtime-restores-active-session",
                projection: ActiveSessionRuntimeReadModelProjection(restoredRuntime)
            )
        ]

        XCTAssertEqual(cases, expected.cases)
    }

    func testRuntimeWithoutStoreMarksAllRuntimeSnapshotsInactive() {
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionCoordinator: SessionCoordinator(sessions: [
                SessionState(sessionId: "s1", source: "codex", cwd: "/tmp/project"),
            ])
        )

        let snapshots = runtime.runtimeSessionSnapshots()

        XCTAssertEqual(snapshots.map(\.snapshot.sessionId), ["s1"])
        XCTAssertEqual(snapshots.map(\.isActive), [false])
        XCTAssertNil(runtime.activeRuntimeSessionSnapshot())
    }

    func testRuntimeMarksConfiguredActiveSession() {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(
            sessions: [
                AgentSession(id: "s1", source: "codex", cwd: "/tmp/one"),
                AgentSession(id: "s2", source: "claude", cwd: "/tmp/two"),
            ],
            activeSessionId: "s2"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionStore: store)

        let snapshots = runtime.runtimeSessionSnapshots()

        XCTAssertEqual(snapshots.map(\.snapshot.sessionId), ["s1", "s2"])
        XCTAssertEqual(snapshots.map(\.isActive), [false, true])
        XCTAssertEqual(runtime.activeRuntimeSessionSnapshot()?.snapshot.sessionId, "s2")
    }

    func testMissingActiveSessionIdReturnsNoActiveRuntimeSnapshot() {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(
            sessions: [
                AgentSession(id: "s1", source: "codex", cwd: "/tmp/one"),
            ],
            activeSessionId: "missing"
        ))
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionStore: store)

        XCTAssertEqual(runtime.runtimeSessionSnapshots().map(\.isActive), [false])
        XCTAssertNil(runtime.activeRuntimeSessionSnapshot())
    }

    func testDefaultJSONRuntimeRestoresActiveRuntimeSessionSnapshot() {
        let home = temporaryHomeDirectory()
        let store = AppRuntimeSessionStore.defaultStore(homeDirectory: home)
        store.replaceSnapshot(SessionStoreSnapshot(
            sessions: [
                AgentSession(id: "restored", source: "codex", cwd: "/tmp/restored"),
            ],
            activeSessionId: "restored"
        ))

        let runtime = AppRuntimeSessionStore.runtime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            homeDirectory: home
        )

        XCTAssertEqual(runtime.activeRuntimeSessionSnapshot()?.snapshot.sessionId, "restored")
        XCTAssertEqual(runtime.runtimeSessionSnapshots().map(\.isActive), [true])
    }

    private func temporaryHomeDirectory() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-active-session-runtime-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private struct ActiveSessionRuntimeReadModelMatrixFixture: Codable, Equatable {
        let cases: [ActiveSessionRuntimeReadModelCase]
    }

    private struct ActiveSessionRuntimeReadModelCase: Codable, Equatable {
        let name: String
        let projection: ActiveSessionRuntimeReadModelProjection
    }

    private struct ActiveSessionRuntimeReadModelProjection: Codable, Equatable {
        let sessionIds: [String]
        let sources: [String]
        let activeFlags: [Bool]
        let activeSessionId: String?

        init(_ runtime: AppRuntime) {
            let snapshots = runtime.runtimeSessionSnapshots()
            self.sessionIds = snapshots.map(\.snapshot.sessionId)
            self.sources = snapshots.map(\.snapshot.source)
            self.activeFlags = snapshots.map(\.isActive)
            self.activeSessionId = runtime.activeRuntimeSessionSnapshot()?.snapshot.sessionId
        }
    }
}
