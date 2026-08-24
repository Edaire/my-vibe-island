import XCTest
@testable import MyVibeIslandCore

final class SessionStoreIndexRuntimeTests: XCTestCase {
    func testSessionStoreIndexRuntimeMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SessionStoreIndexRuntimeMatrixFixture.self,
            from: try FixtureLoader.data("runtime/session-store-index-runtime-matrix")
        )

        let noStoreRuntime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())
        noStoreRuntime.setActiveSessionId("s1")
        noStoreRuntime.markSessionSummarized(sessionId: "s1")
        noStoreRuntime.setQuestionSelection("approve", forRequestId: "request-1")

        let activeRuntime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionStore: InMemorySessionStore()
        )
        activeRuntime.setActiveSessionId("active-session")

        let summarizedRuntime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionStore: InMemorySessionStore()
        )
        summarizedRuntime.markSessionSummarized(sessionId: "b")
        summarizedRuntime.markSessionSummarized(sessionId: "a")
        summarizedRuntime.markSessionSummarized(sessionId: "b")

        let selectionRuntime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionStore: InMemorySessionStore()
        )
        selectionRuntime.setQuestionSelection("approve", forRequestId: "request-1")
        selectionRuntime.setQuestionSelection("deny", forRequestId: "request-1")

        let home = temporaryHomeDirectory()
        let jsonRuntime = AppRuntimeSessionStore.runtime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            homeDirectory: home
        )
        jsonRuntime.setActiveSessionId("active")
        jsonRuntime.markSessionSummarized(sessionId: "summary")
        jsonRuntime.setQuestionSelection("approve", forRequestId: "request-1")
        let reloadedJSONSnapshot = AppRuntimeSessionStore.defaultStore(homeDirectory: home).loadSnapshot()

        let actual = SessionStoreIndexRuntimeMatrixFixture(rows: [
            row(id: "runtime-without-store-no-ops", runtime: noStoreRuntime, requestId: "request-1"),
            row(id: "runtime-stores-active-session-id", runtime: activeRuntime, requestId: "request-1"),
            row(id: "runtime-normalizes-summarized-session-ids", runtime: summarizedRuntime, requestId: "request-1"),
            row(id: "runtime-overwrites-question-selection", runtime: selectionRuntime, requestId: "request-1"),
            SessionStoreIndexRuntimeMatrixRow(
                id: "default-json-runtime-persists-indexes",
                activeSessionId: reloadedJSONSnapshot.activeSessionId,
                summarizedSessionIds: reloadedJSONSnapshot.summarizedSessionIds,
                questionSelections: reloadedJSONSnapshot.questionSelections,
                singleQuestionSelection: jsonRuntime.questionSelection(forRequestId: "request-1")
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRuntimeWithoutStoreReturnsEmptyIndexesAndNoOpsWrites() {
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())

        runtime.setActiveSessionId("s1")
        runtime.markSessionSummarized(sessionId: "s1")
        runtime.setQuestionSelection("approve", forRequestId: "request-1")

        XCTAssertEqual(runtime.sessionStoreIndexes(), SessionStoreIndexes())
        XCTAssertNil(runtime.questionSelection(forRequestId: "request-1"))
    }

    func testRuntimeStoresAndReadsActiveSessionId() {
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionStore: InMemorySessionStore()
        )

        runtime.setActiveSessionId("active-session")

        XCTAssertEqual(runtime.sessionStoreIndexes().activeSessionId, "active-session")
    }

    func testRuntimeMarksSummarizedSessionsWithStoreNormalization() {
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionStore: InMemorySessionStore()
        )

        runtime.markSessionSummarized(sessionId: "b")
        runtime.markSessionSummarized(sessionId: "a")
        runtime.markSessionSummarized(sessionId: "b")

        XCTAssertEqual(runtime.sessionStoreIndexes().summarizedSessionIds, ["a", "b"])
    }

    func testRuntimeStoresAndReadsQuestionSelections() {
        let runtime = AppRuntime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            sessionStore: InMemorySessionStore()
        )

        runtime.setQuestionSelection("approve", forRequestId: "request-1")
        runtime.setQuestionSelection("deny", forRequestId: "request-1")

        XCTAssertEqual(runtime.questionSelection(forRequestId: "request-1"), "deny")
        XCTAssertEqual(runtime.sessionStoreIndexes().questionSelections, ["request-1": "deny"])
    }

    func testDefaultJSONRuntimePersistsStoreIndexes() {
        let home = temporaryHomeDirectory()
        let runtime = AppRuntimeSessionStore.runtime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            homeDirectory: home
        )

        runtime.setActiveSessionId("active")
        runtime.markSessionSummarized(sessionId: "summary")
        runtime.setQuestionSelection("approve", forRequestId: "request-1")

        let reloaded = AppRuntimeSessionStore.defaultStore(homeDirectory: home).loadSnapshot()
        XCTAssertEqual(reloaded.activeSessionId, "active")
        XCTAssertEqual(reloaded.summarizedSessionIds, ["summary"])
        XCTAssertEqual(reloaded.questionSelections, ["request-1": "approve"])
    }

    private func temporaryHomeDirectory() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-store-index-runtime-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private func row(
        id: String,
        runtime: AppRuntime,
        requestId: String
    ) -> SessionStoreIndexRuntimeMatrixRow {
        let indexes = runtime.sessionStoreIndexes()
        return SessionStoreIndexRuntimeMatrixRow(
            id: id,
            activeSessionId: indexes.activeSessionId,
            summarizedSessionIds: indexes.summarizedSessionIds,
            questionSelections: indexes.questionSelections,
            singleQuestionSelection: runtime.questionSelection(forRequestId: requestId)
        )
    }

    private struct SessionStoreIndexRuntimeMatrixFixture: Codable, Equatable {
        let rows: [SessionStoreIndexRuntimeMatrixRow]
    }

    private struct SessionStoreIndexRuntimeMatrixRow: Codable, Equatable {
        let id: String
        let activeSessionId: String?
        let summarizedSessionIds: [String]
        let questionSelections: [String: String]
        let singleQuestionSelection: String?
    }
}
