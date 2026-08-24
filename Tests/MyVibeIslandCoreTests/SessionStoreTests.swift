import XCTest
@testable import MyVibeIslandCore

final class SessionStoreTests: XCTestCase {
    func testInMemorySessionStoreMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            InMemorySessionStoreMatrixFixture.self,
            from: try FixtureLoader.data("runtime/in-memory-session-store-matrix")
        )

        let emptyStore = InMemorySessionStore()

        let upsertStore = InMemorySessionStore()
        upsertStore.upsert(session("b", safeTitle: "First"))
        upsertStore.upsert(session("b", safeTitle: "Updated"))

        let sortedStore = InMemorySessionStore()
        sortedStore.upsert(session("c"))
        sortedStore.upsert(session("a"))
        sortedStore.upsert(session("b"))

        let removeStore = InMemorySessionStore()
        removeStore.upsert(session("a"))
        removeStore.upsert(session("b"))
        removeStore.setActiveSessionId("a")
        removeStore.markSummarized(sessionId: "a")
        removeStore.markSummarized(sessionId: "b")
        removeStore.setQuestionSelection("approve", forRequestId: "request-1")
        removeStore.remove(sessionId: "a")

        let replaceStore = InMemorySessionStore()
        replaceStore.upsert(session("old"))
        replaceStore.replaceSnapshot(SessionStoreSnapshot(
            schemaVersion: 3,
            sessions: [session("b"), session("a")],
            activeSessionId: "b",
            summarizedSessionIds: ["b", "a", "b"],
            questionSelections: ["request-1": "approve"]
        ))

        let selectionStore = InMemorySessionStore()
        selectionStore.setQuestionSelection("approve", forRequestId: "request-1")
        selectionStore.setQuestionSelection("deny", forRequestId: "request-1")

        let actual = InMemorySessionStoreMatrixFixture(rows: [
            row(id: "empty-store", store: emptyStore),
            row(id: "upsert-replaces-by-id", store: upsertStore),
            row(id: "snapshot-sessions-sorted-by-id", store: sortedStore),
            row(id: "remove-clears-active-and-summarized-indexes", store: removeStore),
            row(id: "replace-snapshot-normalizes-state", store: replaceStore),
            row(id: "question-selection-overwrites-by-request-id", store: selectionStore),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testEmptyStoreReturnsVersionOneEmptySnapshot() {
        let store = InMemorySessionStore()

        XCTAssertEqual(store.loadSnapshot(), SessionStoreSnapshot(
            schemaVersion: 1,
            sessions: [],
            activeSessionId: nil,
            summarizedSessionIds: [],
            questionSelections: [:]
        ))
    }

    func testUpsertInsertsAndReplacesSessionById() {
        let store = InMemorySessionStore()
        store.upsert(session("b", safeTitle: "First"))
        store.upsert(session("b", safeTitle: "Updated"))

        XCTAssertEqual(store.loadSnapshot().sessions, [
            session("b", safeTitle: "Updated"),
        ])
    }

    func testSnapshotSessionsAreSortedById() {
        let store = InMemorySessionStore()
        store.upsert(session("c"))
        store.upsert(session("a"))
        store.upsert(session("b"))

        XCTAssertEqual(store.loadSnapshot().sessions.map(\.id), ["a", "b", "c"])
    }

    func testRemoveDeletesSessionAndClearsIndexes() {
        let store = InMemorySessionStore()
        store.upsert(session("a"))
        store.upsert(session("b"))
        store.setActiveSessionId("a")
        store.markSummarized(sessionId: "a")
        store.markSummarized(sessionId: "b")

        store.remove(sessionId: "a")

        let snapshot = store.loadSnapshot()
        XCTAssertEqual(snapshot.sessions.map(\.id), ["b"])
        XCTAssertNil(snapshot.activeSessionId)
        XCTAssertEqual(snapshot.summarizedSessionIds, ["b"])
    }

    func testReplaceSnapshotReplacesAllStateAndNormalizesSummarizedIds() {
        let store = InMemorySessionStore()
        store.upsert(session("old"))

        store.replaceSnapshot(SessionStoreSnapshot(
            schemaVersion: 3,
            sessions: [session("b"), session("a")],
            activeSessionId: "b",
            summarizedSessionIds: ["b", "a", "b"],
            questionSelections: ["request-1": "approve"]
        ))

        let snapshot = store.loadSnapshot()
        XCTAssertEqual(snapshot.schemaVersion, 3)
        XCTAssertEqual(snapshot.sessions.map(\.id), ["a", "b"])
        XCTAssertEqual(snapshot.activeSessionId, "b")
        XCTAssertEqual(snapshot.summarizedSessionIds, ["a", "b"])
        XCTAssertEqual(snapshot.questionSelections, ["request-1": "approve"])
    }

    func testCodexBareAndPrefixedThreadIdsAreStoredAsOnePrefixedSession() {
        let store = InMemorySessionStore()

        store.replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(
                id: "019f36a7-b73f-7750-85db-081ea9257dbb",
                source: "codex",
                cwd: "/tmp/codex",
                safeTitle: "bare"
            ),
            AgentSession(
                id: "codex-019f36a7-b73f-7750-85db-081ea9257dbb",
                source: "codex",
                cwd: "/tmp/codex",
                safeTitle: "prefixed",
                codexRolloutPath: "/tmp/rollout.jsonl",
                jumpInput: JumpInput(
                    sessionId: "codex-019f36a7-b73f-7750-85db-081ea9257dbb",
                    source: "codex",
                    codexThreadId: "019f36a7-b73f-7750-85db-081ea9257dbb"
                )
            ),
        ]))

        let snapshot = store.loadSnapshot()
        XCTAssertEqual(snapshot.sessions.map(\.id), ["codex-019f36a7-b73f-7750-85db-081ea9257dbb"])
        XCTAssertEqual(snapshot.sessions.first?.safeTitle, "prefixed")
        XCTAssertEqual(snapshot.sessions.first?.codexRolloutPath, "/tmp/rollout.jsonl")
        XCTAssertEqual(snapshot.sessions.first?.jumpInput?.codexThreadId, "019f36a7-b73f-7750-85db-081ea9257dbb")
    }

    func testSetActiveSessionIdStoresActiveId() {
        let store = InMemorySessionStore()

        store.setActiveSessionId("active-session")

        XCTAssertEqual(store.loadSnapshot().activeSessionId, "active-session")
    }

    func testMarkSummarizedKeepsIdsUnique() {
        let store = InMemorySessionStore()

        store.markSummarized(sessionId: "b")
        store.markSummarized(sessionId: "a")
        store.markSummarized(sessionId: "b")

        XCTAssertEqual(store.loadSnapshot().summarizedSessionIds, ["a", "b"])
    }

    func testQuestionSelectionsStoreAndReplaceByRequestId() {
        let store = InMemorySessionStore()

        store.setQuestionSelection("approve", forRequestId: "request-1")
        store.setQuestionSelection("deny", forRequestId: "request-1")

        XCTAssertEqual(store.loadSnapshot().questionSelections, ["request-1": "deny"])
    }

    func testConcurrentUpsertsKeepUniqueSessions() {
        let store = InMemorySessionStore()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "session-store-tests", attributes: .concurrent)
        let sessions = (0..<100).map { index in
            session("session-\(index % 10)", safeTitle: "title-\(index)")
        }

        for session in sessions {
            group.enter()
            queue.async {
                store.upsert(session)
                group.leave()
            }
        }

        group.wait()

        let ids = store.loadSnapshot().sessions.map(\.id)
        XCTAssertEqual(ids, (0..<10).map { "session-\($0)" })
    }

    private func session(_ id: String, safeTitle: String? = nil) -> AgentSession {
        AgentSession(
            id: id,
            source: "codex",
            cwd: "/tmp/\(id)",
            safeTitle: safeTitle
        )
    }

    private func row(id: String, store: InMemorySessionStore) -> InMemorySessionStoreMatrixRow {
        let snapshot = store.loadSnapshot()
        return InMemorySessionStoreMatrixRow(
            id: id,
            schemaVersion: snapshot.schemaVersion,
            sessionIds: snapshot.sessions.map(\.id),
            safeTitles: snapshot.sessions.map(\.safeTitle),
            activeSessionId: snapshot.activeSessionId,
            summarizedSessionIds: snapshot.summarizedSessionIds,
            questionSelections: snapshot.questionSelections
        )
    }

    private struct InMemorySessionStoreMatrixFixture: Codable, Equatable {
        let rows: [InMemorySessionStoreMatrixRow]
    }

    private struct InMemorySessionStoreMatrixRow: Codable, Equatable {
        let id: String
        let schemaVersion: Int
        let sessionIds: [String]
        let safeTitles: [String?]
        let activeSessionId: String?
        let summarizedSessionIds: [String]
        let questionSelections: [String: String]
    }
}
