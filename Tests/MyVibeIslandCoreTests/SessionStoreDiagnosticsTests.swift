import XCTest
@testable import MyVibeIslandCore

final class SessionStoreDiagnosticsTests: XCTestCase {
    func testSessionStoreDiagnosticsMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SessionStoreDiagnosticsMatrixFixture.self,
            from: try FixtureLoader.data("runtime/session-store-diagnostics-matrix")
        )

        let noStoreRuntime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())

        let defaultHome = temporaryHomeDirectory()
        let defaultRuntime = AppRuntimeSessionStore.runtime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            homeDirectory: defaultHome
        )

        let persistedHome = temporaryHomeDirectory()
        let persistedStore = AppRuntimeSessionStore.defaultStore(homeDirectory: persistedHome)
        persistedStore.replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(id: "a", source: "codex", cwd: "/tmp/a"),
            AgentSession(id: "b", source: "codex", cwd: "/tmp/b"),
        ]))

        let malformedHome = temporaryHomeDirectory()
        let malformedURL = AppRuntimeSessionStore.defaultFileURL(homeDirectory: malformedHome)
        try FileManager.default.createDirectory(
            at: malformedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{ "schemaVersion": "#.utf8).write(to: malformedURL)
        let malformedStore = AppRuntimeSessionStore.defaultStore(homeDirectory: malformedHome)

        let actual = SessionStoreDiagnosticsMatrixFixture(rows: [
            row(id: "runtime-without-store", diagnostics: noStoreRuntime.status().sessionStoreDiagnostics),
            row(id: "default-runtime-json-store", diagnostics: defaultRuntime.status().sessionStoreDiagnostics),
            row(id: "persisted-json-store-count", diagnostics: persistedStore.diagnostics()),
            row(id: "malformed-json-store-error", diagnostics: malformedStore.diagnostics()),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testRuntimeWithoutStoreReportsNoSessionStoreDiagnostics() {
        let runtime = AppRuntime(socketPath: BridgeSocketPath.temporaryForTests())

        XCTAssertNil(runtime.status().sessionStoreDiagnostics)
    }

    func testDefaultRuntimeReportsJSONStorePathDiagnostics() {
        let home = temporaryHomeDirectory()
        let runtime = AppRuntimeSessionStore.runtime(
            socketPath: BridgeSocketPath.temporaryForTests(),
            homeDirectory: home
        )

        XCTAssertEqual(runtime.status().sessionStoreDiagnostics, SessionStoreDiagnostics(
            kind: "json",
            filePath: AppRuntimeSessionStore.defaultFileURL(homeDirectory: home).path,
            lastErrorDescription: nil,
            sessionCount: 0
        ))
    }

    func testJSONDiagnosticsReportPersistedSessionCount() {
        let home = temporaryHomeDirectory()
        let store = AppRuntimeSessionStore.defaultStore(homeDirectory: home)
        store.replaceSnapshot(SessionStoreSnapshot(sessions: [
            AgentSession(id: "a", source: "codex", cwd: "/tmp/a"),
            AgentSession(id: "b", source: "codex", cwd: "/tmp/b"),
        ]))

        XCTAssertEqual(store.diagnostics().sessionCount, 2)
        XCTAssertNil(store.diagnostics().lastErrorDescription)
    }

    func testMalformedJSONDiagnosticsReportLastErrorDescription() throws {
        let home = temporaryHomeDirectory()
        let url = AppRuntimeSessionStore.defaultFileURL(homeDirectory: home)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{ "schemaVersion": "#.utf8).write(to: url)

        let store = AppRuntimeSessionStore.defaultStore(homeDirectory: home)

        XCTAssertEqual(store.diagnostics().kind, "json")
        XCTAssertEqual(store.diagnostics().filePath, url.path)
        XCTAssertEqual(store.diagnostics().sessionCount, 0)
        XCTAssertFalse(store.diagnostics().lastErrorDescription?.isEmpty ?? true)
    }

    private func temporaryHomeDirectory() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-store-diagnostics-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private func row(
        id: String,
        diagnostics: SessionStoreDiagnostics?
    ) -> SessionStoreDiagnosticsMatrixRow {
        SessionStoreDiagnosticsMatrixRow(
            id: id,
            hasDiagnostics: diagnostics != nil,
            kind: diagnostics?.kind,
            filePathSuffix: diagnostics?.filePath.map(stableFilePathSuffix),
            hasLastErrorDescription: !(diagnostics?.lastErrorDescription?.isEmpty ?? true),
            sessionCount: diagnostics?.sessionCount
        )
    }

    private func stableFilePathSuffix(_ path: String) -> String {
        guard let range = path.range(of: "/Library/Application Support/MyVibeIsland/sessions.json") else {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return String(path[range.lowerBound...])
    }

    private struct SessionStoreDiagnosticsMatrixFixture: Codable, Equatable {
        let rows: [SessionStoreDiagnosticsMatrixRow]
    }

    private struct SessionStoreDiagnosticsMatrixRow: Codable, Equatable {
        let id: String
        let hasDiagnostics: Bool
        let kind: String?
        let filePathSuffix: String?
        let hasLastErrorDescription: Bool
        let sessionCount: Int?
    }
}
