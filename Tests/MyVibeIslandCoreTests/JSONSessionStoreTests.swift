import XCTest
@testable import MyVibeIslandCore

final class JSONSessionStoreTests: XCTestCase {
    func testJSONSessionStoreMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            JSONSessionStoreMatrixFixture.self,
            from: try FixtureLoader.data("runtime/json-session-store-matrix")
        )

        let missingURL = temporaryStoreURL()
        let missingStore = JSONSessionStore(fileURL: missingURL)

        let validURL = temporaryStoreURL()
        try write(SessionStoreSnapshot(
            schemaVersion: 2,
            sessions: [session("stored")],
            activeSessionId: "stored",
            summarizedSessionIds: ["stored"],
            questionSelections: ["request-1": "approve"]
        ), to: validURL)
        let validStore = JSONSessionStore(fileURL: validURL)

        let replaceURL = temporaryStoreURL()
        let replaceStore = JSONSessionStore(fileURL: replaceURL)
        replaceStore.replaceSnapshot(SessionStoreSnapshot(
            sessions: [session("b"), session("a")],
            activeSessionId: "a",
            summarizedSessionIds: ["b", "a", "b"],
            questionSelections: ["request-1": "deny"]
        ))

        let upsertURL = temporaryStoreURL()
            .deletingLastPathComponent()
            .appendingPathComponent("nested")
            .appendingPathComponent("sessions.json")
        let upsertStore = JSONSessionStore(fileURL: upsertURL)
        upsertStore.upsert(session("b"))
        upsertStore.upsert(session("a"))

        let removeURL = temporaryStoreURL()
        let removeStore = JSONSessionStore(fileURL: removeURL)
        removeStore.replaceSnapshot(SessionStoreSnapshot(
            sessions: [session("a"), session("b")],
            activeSessionId: "a",
            summarizedSessionIds: ["a", "b"]
        ))
        removeStore.remove(sessionId: "a")

        let malformedURL = temporaryStoreURL()
        try FileManager.default.createDirectory(
            at: malformedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{ "schemaVersion": "#.utf8).write(to: malformedURL)
        let malformedStore = JSONSessionStore(fileURL: malformedURL)

        let actual = JSONSessionStoreMatrixFixture(rows: [
            row(id: "missing-file-loads-empty-without-creating-file", store: missingStore, url: missingURL),
            row(id: "valid-json-loads-snapshot", store: validStore, url: validURL),
            row(id: "replace-snapshot-persists-normalized-json", store: JSONSessionStore(fileURL: replaceURL), url: replaceURL),
            row(id: "upsert-creates-parent-directory-and-sorts", store: JSONSessionStore(fileURL: upsertURL), url: upsertURL),
            row(id: "remove-persists-session-and-index-cleanup", store: JSONSessionStore(fileURL: removeURL), url: removeURL),
            row(id: "malformed-json-loads-empty-and-records-error", store: malformedStore, url: malformedURL),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testMissingFileLoadsEmptySnapshotWithoutCreatingFile() {
        let url = temporaryStoreURL()
        let store = JSONSessionStore(fileURL: url)

        XCTAssertEqual(store.loadSnapshot(), SessionStoreSnapshot())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNil(store.lastError)
    }

    func testValidJSONFileLoadsSnapshot() throws {
        let url = temporaryStoreURL()
        let snapshot = SessionStoreSnapshot(
            schemaVersion: 2,
            sessions: [session("stored")],
            activeSessionId: "stored",
            summarizedSessionIds: ["stored"],
            questionSelections: ["request-1": "approve"]
        )
        try write(snapshot, to: url)

        let store = JSONSessionStore(fileURL: url)

        XCTAssertEqual(store.loadSnapshot(), snapshot)
        XCTAssertNil(store.lastError)
    }

    func testReplaceSnapshotWritesJSONLoadedByNewStoreInstance() {
        let url = temporaryStoreURL()
        let store = JSONSessionStore(fileURL: url)
        let snapshot = SessionStoreSnapshot(
            sessions: [session("b"), session("a")],
            activeSessionId: "a",
            summarizedSessionIds: ["b", "a", "b"],
            questionSelections: ["request-1": "deny"]
        )

        store.replaceSnapshot(snapshot)

        let reloaded = JSONSessionStore(fileURL: url)
        XCTAssertEqual(reloaded.loadSnapshot().sessions.map(\.id), ["a", "b"])
        XCTAssertEqual(reloaded.loadSnapshot().activeSessionId, "a")
        XCTAssertEqual(reloaded.loadSnapshot().summarizedSessionIds, ["a", "b"])
        XCTAssertEqual(reloaded.loadSnapshot().questionSelections, ["request-1": "deny"])
        XCTAssertNil(store.lastError)
    }

    func testUpsertPersistsSortedSessionsAndCreatesParentDirectories() {
        let url = temporaryStoreURL()
            .deletingLastPathComponent()
            .appendingPathComponent("nested")
            .appendingPathComponent("sessions.json")
        let store = JSONSessionStore(fileURL: url)

        store.upsert(session("b"))
        store.upsert(session("a"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(JSONSessionStore(fileURL: url).loadSnapshot().sessions.map(\.id), ["a", "b"])
    }

    func testRemovePersistsSessionRemovalAndIndexCleanup() {
        let url = temporaryStoreURL()
        let store = JSONSessionStore(fileURL: url)
        store.replaceSnapshot(SessionStoreSnapshot(
            sessions: [session("a"), session("b")],
            activeSessionId: "a",
            summarizedSessionIds: ["a", "b"]
        ))

        store.remove(sessionId: "a")

        let snapshot = JSONSessionStore(fileURL: url).loadSnapshot()
        XCTAssertEqual(snapshot.sessions.map(\.id), ["b"])
        XCTAssertNil(snapshot.activeSessionId)
        XCTAssertEqual(snapshot.summarizedSessionIds, ["b"])
    }

    func testMalformedJSONLoadsEmptySnapshotAndRecordsError() throws {
        let url = temporaryStoreURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{ "schemaVersion": "#.utf8).write(to: url)

        let store = JSONSessionStore(fileURL: url)

        XCTAssertEqual(store.loadSnapshot(), SessionStoreSnapshot())
        XCTAssertNotNil(store.lastError)
    }

    func testLoadsAndPersistsSessionWithoutSyntheticConversationText() throws {
        let url = temporaryStoreURL()
        let synthetic = AgentSession(
            id: "synthetic",
            source: "codex",
            cwd: "/tmp/project",
            firstUserMessage: "<subagent_notification>\ninternal\n</subagent_notification>",
            lastUserMessage: "<codex_internal_context source=\"goal\">\ninternal\n</codex_internal_context>"
        )
        try write(SessionStoreSnapshot(sessions: [synthetic]), to: url)

        let store = JSONSessionStore(fileURL: url)
        let loaded = try XCTUnwrap(store.loadSnapshot().sessions.first)

        XCTAssertNil(loaded.firstUserMessage)
        XCTAssertNil(loaded.lastUserMessage)
        let reloaded = JSONSessionStore(fileURL: url).loadSnapshot().sessions.first
        XCTAssertNil(reloaded?.firstUserMessage)
        XCTAssertNil(reloaded?.lastUserMessage)
    }

    private func temporaryStoreURL() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-json-store-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root.appendingPathComponent("sessions.json")
    }

    private func session(_ id: String) -> AgentSession {
        AgentSession(id: id, source: "codex", cwd: "/tmp/\(id)")
    }

    private func write(_ snapshot: SessionStoreSnapshot, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: url)
    }

    private func row(
        id: String,
        store: JSONSessionStore,
        url: URL
    ) -> JSONSessionStoreMatrixRow {
        let snapshot = store.loadSnapshot()
        return JSONSessionStoreMatrixRow(
            id: id,
            fileExists: FileManager.default.fileExists(atPath: url.path),
            hasLastError: store.lastError != nil,
            diagnosticKind: store.diagnostics().kind,
            diagnosticSessionCount: store.diagnostics().sessionCount,
            diagnosticHasLastErrorDescription: !(store.diagnostics().lastErrorDescription?.isEmpty ?? true),
            schemaVersion: snapshot.schemaVersion,
            sessionIds: snapshot.sessions.map(\.id),
            activeSessionId: snapshot.activeSessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds,
            questionSelections: snapshot.questionSelections
        )
    }

    private struct JSONSessionStoreMatrixFixture: Codable, Equatable {
        let rows: [JSONSessionStoreMatrixRow]
    }

    private struct JSONSessionStoreMatrixRow: Codable, Equatable {
        let id: String
        let fileExists: Bool
        let hasLastError: Bool
        let diagnosticKind: String
        let diagnosticSessionCount: Int
        let diagnosticHasLastErrorDescription: Bool
        let schemaVersion: Int
        let sessionIds: [String]
        let activeSessionId: String?
        let summarizedSessionIds: [String]
        let questionSelections: [String: String]
    }
}
