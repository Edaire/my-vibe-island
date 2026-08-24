import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OpenCodeDiskSessionWatcherTests: XCTestCase {
    func testOpenCodeDiskSessionWatcherMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            OpenCodeDiskSessionWatcherMatrixFixture.self,
            from: try FixtureLoader.data("opencode/disk-session-watcher-matrix")
        )

        let sortedRoot = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/b", to: sortedRoot.appendingPathComponent("b.json"))
        try writeSnapshot(directory: "/tmp/a", to: sortedRoot.appendingPathComponent("a.json"))
        try "ignored".write(to: sortedRoot.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let mixedRoot = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/valid", to: mixedRoot.appendingPathComponent("valid.json"))
        try "{ broken".write(to: mixedRoot.appendingPathComponent("broken.json"), atomically: true, encoding: .utf8)

        let missingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-opencode-watcher-tests")
            .appendingPathComponent(UUID().uuidString)

        let childRoot = try temporaryRoot()
        try writeSnapshot(
            directory: "/tmp/open-code-child",
            to: childRoot.appendingPathComponent("child.json"),
            parentID: "parent-session"
        )
        let childCoordinator = SessionCoordinator()
        let childWatcher = OpenCodeDiskSessionWatcher(rootURL: childRoot)
        childWatcher.agentEvents().forEach(childCoordinator.apply)

        let actual = OpenCodeDiskSessionWatcherMatrixFixture(rows: [
            row(id: "sorted-json-snapshots-ignore-non-json", root: sortedRoot),
            row(id: "broken-json-keeps-valid-events", root: mixedRoot),
            row(id: "missing-root-empty-no-create", root: missingRoot),
            row(
                id: "parent-grouping-events-apply-to-coordinator",
                root: childRoot,
                coordinatorSessionId: "/tmp/open-code-child",
                coordinator: childCoordinator
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testScansValidJSONSnapshotsDeterministically() throws {
        let root = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/b", to: root.appendingPathComponent("b.json"))
        try writeSnapshot(directory: "/tmp/a", to: root.appendingPathComponent("a.json"))
        try "ignored".write(to: root.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let watcher = OpenCodeDiskSessionWatcher(rootURL: root)
        let results = watcher.scan()

        XCTAssertEqual(results.map(\.fileURL.lastPathComponent), ["a.json", "b.json"])
        XCTAssertEqual(results.compactMap(\.snapshot?.session.directory), ["/tmp/a", "/tmp/b"])
        XCTAssertEqual(watcher.agentEvents(), [
            .sessionStarted(source: "opencode", sessionId: "/tmp/a", cwd: "/tmp/a"),
            .sessionStarted(source: "opencode", sessionId: "/tmp/b", cwd: "/tmp/b"),
        ])
    }

    func testMalformedJSONDoesNotDropValidSnapshotEvents() throws {
        let root = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/valid", to: root.appendingPathComponent("valid.json"))
        try "{ broken".write(to: root.appendingPathComponent("broken.json"), atomically: true, encoding: .utf8)

        let watcher = OpenCodeDiskSessionWatcher(rootURL: root)
        let results = watcher.scan()

        XCTAssertEqual(results.map(\.fileURL.lastPathComponent), ["broken.json", "valid.json"])
        XCTAssertNil(results[0].snapshot)
        XCTAssertNotNil(results[0].errorDescription)
        XCTAssertEqual(results[1].snapshot?.session.directory, "/tmp/valid")
        XCTAssertNil(results[1].errorDescription)
        XCTAssertEqual(watcher.agentEvents(), [
            .sessionStarted(source: "opencode", sessionId: "/tmp/valid", cwd: "/tmp/valid"),
        ])
    }

    func testMissingRootReturnsEmptyScanWithoutCreatingDirectories() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-opencode-watcher-tests")
            .appendingPathComponent(UUID().uuidString)

        let watcher = OpenCodeDiskSessionWatcher(rootURL: root)

        XCTAssertEqual(watcher.scan(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testWatcherEventsApplyToSessionCoordinator() throws {
        let root = try temporaryRoot()
        try writeSnapshot(
            directory: "/tmp/open-code-child",
            to: root.appendingPathComponent("child.json"),
            parentID: "parent-session"
        )

        let coordinator = SessionCoordinator()
        let watcher = OpenCodeDiskSessionWatcher(rootURL: root)
        watcher.agentEvents().forEach(coordinator.apply)

        let snapshot = try XCTUnwrap(coordinator.snapshot(sessionId: "/tmp/open-code-child"))
        XCTAssertEqual(snapshot.source, "opencode")
        XCTAssertEqual(snapshot.cwd, "/tmp/open-code-child")
        XCTAssertEqual(snapshot.teamGrouping?.childToParent, ["/tmp/open-code-child": "parent-session"])
    }

    func testLegacyScanBoundsFileCountAndFileSize() throws {
        let root = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/a", to: root.appendingPathComponent("a.json"))
        try String(repeating: "x", count: 512).write(to: root.appendingPathComponent("b.json"), atomically: true, encoding: .utf8)
        try writeSnapshot(directory: "/tmp/c", to: root.appendingPathComponent("c.json"))
        let watcher = OpenCodeDiskSessionWatcher(rootURL: root, maximumFileCount: 2, maximumSnapshotBytes: 128)

        let results = watcher.scan()

        XCTAssertEqual(results.map(\.fileURL.lastPathComponent), ["a.json", "b.json"])
        XCTAssertNotNil(results[0].snapshot)
        XCTAssertNil(results[1].snapshot)
        XCTAssertNotNil(results[1].errorDescription)
    }

    func testLegacyScanStopsAtDeterministicVisitedEntryLimit() throws {
        let root = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/first", to: root.appendingPathComponent("000-first.json"))
        for index in 0..<100 {
            try "ignored".write(
                to: root.appendingPathComponent(String(format: "%03d-note.txt", index + 1)),
                atomically: true,
                encoding: .utf8
            )
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(String(format: "%03d-directory", index + 101)),
                withIntermediateDirectories: false
            )
        }
        try writeSnapshot(directory: "/tmp/late", to: root.appendingPathComponent("999-late.json"))
        let watcher = OpenCodeDiskSessionWatcher(
            rootURL: root,
            maximumFileCount: 10,
            maximumVisitedEntries: 8
        )

        XCTAssertEqual(watcher.scan().map(\.fileURL.lastPathComponent), ["000-first.json"])
        XCTAssertEqual(watcher.scan().map(\.fileURL.lastPathComponent), ["000-first.json"])
    }

    func testBoundedScannerReportsFileAndVisitedTruncationMetadata() throws {
        let root = try temporaryRoot()
        try writeSnapshot(directory: "/tmp/first", to: root.appendingPathComponent("000-first.json"))

        let fileLimited = OpenCodeBoundedJSONFileScanner(
            fileManager: .default,
            maximumFileCount: 1,
            maximumDepth: 0,
            maximumVisitedEntries: 10
        ).scan(rootURL: root)
        XCTAssertFalse(fileLimited.isComplete)
        XCTAssertEqual(fileLimited.truncationReason, .fileCountLimit)
        XCTAssertEqual(fileLimited.visitedEntries, 1)

        let visitedLimited = OpenCodeBoundedJSONFileScanner(
            fileManager: .default,
            maximumFileCount: 10,
            maximumDepth: 0,
            maximumVisitedEntries: 1
        ).scan(rootURL: root)
        XCTAssertFalse(visitedLimited.isComplete)
        XCTAssertEqual(visitedLimited.truncationReason, .visitedEntriesLimit)
        XCTAssertEqual(visitedLimited.visitedEntries, 1)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-opencode-watcher-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private func writeSnapshot(directory: String, to url: URL, parentID: String? = nil) throws {
        let parentLine = parentID.map { #","parentID":"\#($0)""# } ?? ""
        try """
        {
          "session": {
            "directory": "\(directory)"\(parentLine)
          },
          "messages": []
        }
        """.write(to: url, atomically: true, encoding: .utf8)
    }

    private func row(
        id: String,
        root: URL,
        coordinatorSessionId: String? = nil,
        coordinator: SessionCoordinator? = nil
    ) -> OpenCodeDiskSessionWatcherMatrixRow {
        let watcher = OpenCodeDiskSessionWatcher(rootURL: root)
        let results = watcher.scan()
        let coordinatorSnapshot = coordinatorSessionId.flatMap {
            coordinator?.snapshot(sessionId: $0)
        }
        return OpenCodeDiskSessionWatcherMatrixRow(
            id: id,
            resultFileNames: results.map(\.fileURL.lastPathComponent),
            snapshotDirectories: results.compactMap(\.snapshot?.session.directory),
            failedResultCount: results.filter { $0.errorDescription != nil }.count,
            eventSummaries: watcher.agentEvents().map(eventSummary),
            rootDirectoryExistsAfterScan: FileManager.default.fileExists(atPath: root.path),
            coordinatorSessionId: coordinatorSnapshot?.sessionId,
            coordinatorParentId: coordinatorSnapshot?.teamGrouping?.rootSessionId
        )
    }

    private func eventSummary(_ event: AgentEvent) -> String {
        switch event {
        case let .sessionStarted(source, sessionId, cwd):
            return "sessionStarted:\(source):\(sessionId):\(cwd)"
        case let .teamGroupingUpdated(source, sessionId, grouping):
            return "teamGroupingUpdated:\(source):\(sessionId):\(grouping.rootSessionId)"
        case let .messageReceived(source, sessionId, message):
            return "messageReceived:\(source):\(sessionId):\(message)"
        default:
            return "\(event)"
        }
    }

    private struct OpenCodeDiskSessionWatcherMatrixFixture: Codable, Equatable {
        let rows: [OpenCodeDiskSessionWatcherMatrixRow]
    }

    private struct OpenCodeDiskSessionWatcherMatrixRow: Codable, Equatable {
        let id: String
        let resultFileNames: [String]
        let snapshotDirectories: [String]
        let failedResultCount: Int
        let eventSummaries: [String]
        let rootDirectoryExistsAfterScan: Bool
        let coordinatorSessionId: String?
        let coordinatorParentId: String?
    }
}
