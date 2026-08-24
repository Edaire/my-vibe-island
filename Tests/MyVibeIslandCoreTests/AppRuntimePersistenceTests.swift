import XCTest
@testable import MyVibeIslandCore

final class AppRuntimePersistenceTests: XCTestCase {
    func testAppRuntimePersistenceMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            AppRuntimePersistenceMatrixFixture.self,
            from: try FixtureLoader.data("runtime/app-runtime-persistence-matrix")
        )

        let restoredStore = InMemorySessionStore(snapshot: SessionStoreSnapshot(
            sessions: [
                AgentSession(id: "restored", source: "codex", cwd: "/tmp/restored"),
            ],
            activeSessionId: "restored",
            summarizedSessionIds: ["previous"],
            questionSelections: ["request-1": "approve"]
        ))
        let restoredRuntime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionStore: restoredStore
        )

        let noStoreRuntime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        noStoreRuntime.setActiveSessionId("ignored")
        noStoreRuntime.markSessionSummarized(sessionId: "ignored")
        noStoreRuntime.setQuestionSelection("ignored", forRequestId: "request-1")

        let actual = AppRuntimePersistenceMatrixFixture(rows: [
            row(id: "restores-sessions-from-injected-store", runtime: restoredRuntime),
            row(id: "runtime-without-store-keeps-empty-state", runtime: noStoreRuntime),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRuntimeRestoresSessionsFromInjectedStoreAtInitialization() {
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(id: "restored", source: "codex", cwd: "/tmp/restored"),
        ]))

        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests(), sessionStore: store)

        XCTAssertEqual(runtime.sessionSnapshot(sessionId: "restored")?.cwd, "/tmp/restored")
        XCTAssertEqual(runtime.status().sessionCount, 1)
    }

    func testRuntimeWithoutStoreKeepsCurrentEmptyInitialState() {
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())

        XCTAssertEqual(runtime.status().sessionCount, 0)
    }

    func testAcceptedHookEventSavesSessionSnapshotToStore() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let store = InMemorySessionStore()
        let runtime = AppRuntime(socketPath: socketPath, sessionStore: store)
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
        XCTAssertEqual(store.loadSnapshot().sessions.map(\.id), ["s1"])
        XCTAssertEqual(store.loadSnapshot().sessions.first?.cwd, "/tmp/project")
    }

    func testInvalidHookEventDoesNotReplaceExistingStoreSnapshot() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(sessions: [
            AgentSession(id: "existing", source: "codex", cwd: "/tmp/existing"),
        ]))
        let runtime = AppRuntime(socketPath: socketPath, sessionStore: store)
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
                    "sessionId": .string("bad"),
                ]
            )
        )

        XCTAssertEqual(response, .failure(message: "invalid hook payload"))
        XCTAssertEqual(store.loadSnapshot().sessions.map(\.id), ["existing"])
    }

    func testAcceptedWatchEventSavesNormalizedContentToStore() throws {
        let socketPath = BridgeSocketPath.temporaryForTests()
        let store = InMemorySessionStore()
        let runtime = AppRuntime(socketPath: socketPath, sessionStore: store)
        try runtime.startBridge()
        defer {
            runtime.stop()
        }

        let response = try BridgeClient(socketPath: socketPath).send(
            BridgeEnvelope(
                schemaVersion: 1,
                clientRole: "watcher",
                source: "codex",
                requestId: nil,
                command: .watchEvent,
                payload: [
                    "eventKind": .string("content"),
                    "sessionId": .string("s1"),
                    "tasks": .array([
                        .object([
                            "id": .string("task-1"),
                            "subject": .string("Plan"),
                            "status": .string("active"),
                        ]),
                    ]),
                ]
            )
        )

        XCTAssertEqual(response, .ok(message: "event accepted"))
        XCTAssertEqual(store.loadSnapshot().sessions.map(\.id), ["s1"])
        XCTAssertEqual(store.loadSnapshot().sessions.first?.tasks, [
            TaskItem(id: "task-1", subject: "Plan", status: .active),
        ])
    }

    private func row(id: String, runtime: AppRuntime) -> AppRuntimePersistenceMatrixRow {
        let indexes = runtime.sessionStoreIndexes()
        let snapshots = runtime.runtimeSessionSnapshots()
        return AppRuntimePersistenceMatrixRow(
            id: id,
            statusSessionCount: runtime.status().sessionCount,
            sessionIds: snapshots.map(\.snapshot.sessionId),
            restoredSessionIds: snapshots.filter(\.snapshot.isRestored).map(\.snapshot.sessionId),
            activeSessionId: indexes.activeSessionId,
            activeRuntimeSessionId: runtime.activeRuntimeSessionSnapshot()?.snapshot.sessionId,
            summarizedSessionIds: indexes.summarizedSessionIds,
            questionSelections: indexes.questionSelections,
            selectedQuestionAnswer: runtime.questionSelection(forRequestId: "request-1")
        )
    }

    private struct AppRuntimePersistenceMatrixFixture: Codable, Equatable {
        let rows: [AppRuntimePersistenceMatrixRow]
    }

    private struct AppRuntimePersistenceMatrixRow: Codable, Equatable {
        let id: String
        let statusSessionCount: Int
        let sessionIds: [String]
        let restoredSessionIds: [String]
        let activeSessionId: String?
        let activeRuntimeSessionId: String?
        let summarizedSessionIds: [String]
        let questionSelections: [String: String]
        let selectedQuestionAnswer: String?
    }
}
