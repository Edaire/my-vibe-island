import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OpenCodeContinuousSessionWatcherTests: XCTestCase {
    func testDefaultRootUsesOpenCodeSessionStorage() {
        let home = URL(fileURLWithPath: "/tmp/home")
        let watcher = OpenCodeContinuousSessionWatcher(homeDirectory: home, scheduler: TestWatcherScheduler()) { _ in }

        XCTAssertEqual(
            watcher.rootURL.path,
            "/tmp/home/.local/share/opencode/storage/session"
        )
    }

    func testFingerprintDedupesUnchangedSnapshotAndEmitsOnChange() throws {
        let root = try temporaryRoot()
        let file = root.appendingPathComponent("session.json")
        try snapshot(directory: "/tmp/opencode", messageID: "one").write(to: file, atomically: true, encoding: .utf8)
        let recorder = EventRecorder()
        let watcher = OpenCodeContinuousSessionWatcher(rootURL: root, scheduler: TestWatcherScheduler()) { recorder.append($0) }

        watcher.syncNow()
        watcher.syncNow()
        XCTAssertEqual(recorder.count, 2)

        try snapshot(directory: "/tmp/opencode", messageID: "two").write(to: file, atomically: true, encoding: .utf8)
        watcher.syncNow()
        XCTAssertEqual(recorder.count, 4)
    }

    func testStartStopCancelsTimerAndRestartRestoresExistingSnapshot() throws {
        let root = try temporaryRoot()
        try snapshot(directory: "/tmp/restored", messageID: "one")
            .write(to: root.appendingPathComponent("session.json"), atomically: true, encoding: .utf8)
        let scheduler = TestWatcherScheduler()
        let recorder = EventRecorder()
        let watcher = OpenCodeContinuousSessionWatcher(rootURL: root, scheduler: scheduler) { recorder.append($0) }

        watcher.start()
        XCTAssertEqual(recorder.count, 2)
        watcher.stop()
        XCTAssertEqual(scheduler.cancelledCount, 1)
        watcher.start()
        XCTAssertEqual(recorder.count, 4)
    }

    func testArchiveAndDeleteTransitionsAreObservableWithoutCreatingNewSessions() throws {
        let root = try temporaryRoot()
        let file = root.appendingPathComponent("session.json")
        try "{\"session\":{\"directory\":\"/tmp/archived\",\"archivedAt\":\"2026-07-16T00:00:00Z\"},\"messages\":[]}".write(to: file, atomically: true, encoding: .utf8)
        let recorder = EventRecorder()
        let watcher = OpenCodeContinuousSessionWatcher(rootURL: root, scheduler: TestWatcherScheduler()) { recorder.append($0) }

        watcher.syncNow()
        XCTAssertEqual(watcher.lastTransitions, [.changed(path: file.path), .archived(path: file.path)])
        XCTAssertTrue(recorder.events.contains(.sessionEnded(source: "opencode", sessionId: "/tmp/archived")))
        let eventCountAfterArchive = recorder.count
        try FileManager.default.removeItem(at: file)
        watcher.syncNow()
        XCTAssertEqual(watcher.lastTransitions, [.deleted(path: file.path)])
        XCTAssertEqual(recorder.count, eventCountAfterArchive)
    }

    func testArchiveEndsSessionButKeepsItForStoreOwnedCleanup() throws {
        let root = try temporaryRoot()
        let file = root.appendingPathComponent("session.json")
        try "{\"session\":{\"directory\":\"/tmp/stored\"},\"messages\":[]}".write(to: file, atomically: true, encoding: .utf8)
        let coordinator = SessionCoordinator()
        let store = InMemorySessionStore(snapshot: SessionStoreSnapshot(activeSessionId: "/tmp/stored"))
        let watcher = OpenCodeContinuousSessionWatcher(rootURL: root, scheduler: TestWatcherScheduler()) { event in
            coordinator.apply(event)
            coordinator.save(to: store)
        }

        watcher.syncNow()
        XCTAssertNotNil(store.loadSnapshot().sessions.first)
        try "{\"session\":{\"directory\":\"/tmp/stored\",\"archivedAt\":\"2026-07-16T00:00:00Z\"},\"messages\":[]}".write(to: file, atomically: true, encoding: .utf8)
        watcher.syncNow()

        XCTAssertEqual(store.loadSnapshot().sessions.map(\.id), ["/tmp/stored"])
        XCTAssertEqual(store.loadSnapshot().activeSessionId, "/tmp/stored")
        XCTAssertEqual(coordinator.snapshot(sessionId: "/tmp/stored")?.sessionId, "/tmp/stored")
    }

    func testParseFailurePreservesPreviousFingerprintAndDoesNotEmitDelete() throws {
        let root = try temporaryRoot()
        let file = root.appendingPathComponent("session.json")
        try snapshot(directory: "/tmp/previous", messageID: "one").write(to: file, atomically: true, encoding: .utf8)
        let watcher = OpenCodeContinuousSessionWatcher(rootURL: root, scheduler: TestWatcherScheduler()) { _ in }

        watcher.syncNow()
        try "{ broken".write(to: file, atomically: true, encoding: .utf8)
        watcher.syncNow()

        XCTAssertFalse(watcher.lastTransitions.contains { transition in
            if case .deleted = transition { return true }
            return false
        })
    }

    func testStopWaitsForInflightTimerCallback() throws {
        let root = try temporaryRoot()
        let scheduler = TestWatcherScheduler()
        let handlerEntered = DispatchSemaphore(value: 0)
        let releaseHandler = DispatchSemaphore(value: 0)
        let watcher = OpenCodeContinuousSessionWatcher(rootURL: root, scheduler: scheduler) { _ in
            handlerEntered.signal()
            releaseHandler.wait()
        }
        watcher.start()
        try "{\"session\":{\"directory\":\"/tmp/inflight\"},\"messages\":[]}"
            .write(to: root.appendingPathComponent("session.json"), atomically: true, encoding: .utf8)
        scheduler.fire()
        XCTAssertEqual(handlerEntered.wait(timeout: .now() + 1), .success)

        let stopped = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            watcher.stop()
            stopped.signal()
        }
        XCTAssertEqual(stopped.wait(timeout: .now() + 0.05), .timedOut)
        releaseHandler.signal()
        XCTAssertEqual(stopped.wait(timeout: .now() + 1), .success)
    }

    func testConcurrentPublicSyncsEmitSnapshotOnce() throws {
        let root = try temporaryRoot()
        try snapshot(directory: "/tmp/serial", messageID: "one")
            .write(to: root.appendingPathComponent("session.json"), atomically: true, encoding: .utf8)
        let recorder = EventRecorder()
        let watcher = OpenCodeContinuousSessionWatcher(rootURL: root, scheduler: TestWatcherScheduler()) { recorder.append($0) }
        let group = DispatchGroup()
        for _ in 0..<8 {
            group.enter()
            DispatchQueue.global().async {
                watcher.syncNow()
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(recorder.count, 2)
    }

    func testRecursiveScanBoundsDepthAndFileCount() throws {
        let root = try temporaryRoot()
        let shallow = root.appendingPathComponent("shallow")
        let deep = root.appendingPathComponent("deep/one/two")
        try FileManager.default.createDirectory(at: shallow, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        try snapshot(directory: "/tmp/a", messageID: "a").write(to: shallow.appendingPathComponent("a.json"), atomically: true, encoding: .utf8)
        try snapshot(directory: "/tmp/b", messageID: "b").write(to: shallow.appendingPathComponent("b.json"), atomically: true, encoding: .utf8)
        try snapshot(directory: "/tmp/deep", messageID: "deep").write(to: deep.appendingPathComponent("deep.json"), atomically: true, encoding: .utf8)
        let watcher = OpenCodeContinuousSessionWatcher(
            rootURL: root,
            scheduler: TestWatcherScheduler(),
            maximumFileCount: 1,
            maximumDepth: 1
        ) { _ in }

        XCTAssertEqual(watcher.syncNow().map(\.fileURL.lastPathComponent), ["a.json"])
    }

    func testBoundedScanIsStableAcrossLargeDirectoryAndRepeatedSyncs() throws {
        let root = try temporaryRoot()
        try snapshot(directory: "/tmp/first", messageID: "first")
            .write(to: root.appendingPathComponent("000-first.json"), atomically: true, encoding: .utf8)
        try snapshot(directory: "/tmp/second", messageID: "second")
            .write(to: root.appendingPathComponent("001-second.json"), atomically: true, encoding: .utf8)
        for index in 0..<100 {
            try "ignored".write(
                to: root.appendingPathComponent(String(format: "%03d-note.txt", index + 2)),
                atomically: true,
                encoding: .utf8
            )
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(String(format: "%03d-directory", index + 102)),
                withIntermediateDirectories: false
            )
        }
        let recorder = EventRecorder()
        let watcher = OpenCodeContinuousSessionWatcher(
            rootURL: root,
            scheduler: TestWatcherScheduler(),
            maximumFileCount: 10,
            maximumDepth: 1,
            maximumVisitedEntries: 12
        ) { recorder.append($0) }

        let first = watcher.syncNow()
        let firstEventCount = recorder.count
        let second = watcher.syncNow()

        XCTAssertEqual(first.map(\.fileURL.lastPathComponent), ["000-first.json", "001-second.json"])
        XCTAssertEqual(second.map(\.fileURL.lastPathComponent), first.map(\.fileURL.lastPathComponent))
        XCTAssertEqual(recorder.count, firstEventCount)
        XCTAssertEqual(watcher.lastTransitions, [])
    }

    func testFileCountTruncationPreservesUnvisitedSessionUntilCompleteDeletionScan() throws {
        let root = try temporaryRoot()
        let oldFile = root.appendingPathComponent("100-old.json")
        let newFile = root.appendingPathComponent("000-new.json")
        try snapshot(directory: "/tmp/old", messageID: "old").write(to: oldFile, atomically: true, encoding: .utf8)
        let recorder = EventRecorder()
        let watcher = OpenCodeContinuousSessionWatcher(
            rootURL: root,
            scheduler: TestWatcherScheduler(),
            maximumFileCount: 2
        ) { recorder.append($0) }

        watcher.syncNow()
        try snapshot(directory: "/tmp/new", messageID: "new").write(to: newFile, atomically: true, encoding: .utf8)
        watcher.syncNow()
        XCTAssertFalse(watcher.lastTransitions.contains { if case .deleted = $0 { return true }; return false })
        XCTAssertFalse(recorder.events.contains(.sessionEnded(source: "opencode", sessionId: "/tmp/old")))

        try snapshot(directory: "/tmp/new", messageID: "newer").write(to: newFile, atomically: true, encoding: .utf8)
        watcher.syncNow()
        XCTAssertEqual(watcher.lastTransitions, [.changed(path: newFile.path)])

        try FileManager.default.removeItem(at: newFile)
        watcher.syncNow()
        try FileManager.default.removeItem(at: oldFile)
        watcher.syncNow()

        XCTAssertEqual(watcher.lastTransitions, [.deleted(path: oldFile.path)])
        XCTAssertTrue(recorder.events.contains(.sessionEnded(source: "opencode", sessionId: "/tmp/old")))
    }

    func testVisitedEntryTruncationPreservesUnvisitedSessionUntilCompleteDeletionScan() throws {
        let root = try temporaryRoot()
        let oldFile = root.appendingPathComponent("100-old.json")
        let newFile = root.appendingPathComponent("000-new.json")
        try snapshot(directory: "/tmp/old", messageID: "old").write(to: oldFile, atomically: true, encoding: .utf8)
        let recorder = EventRecorder()
        let watcher = OpenCodeContinuousSessionWatcher(
            rootURL: root,
            scheduler: TestWatcherScheduler(),
            maximumVisitedEntries: 2
        ) { recorder.append($0) }

        watcher.syncNow()
        try snapshot(directory: "/tmp/new", messageID: "new").write(to: newFile, atomically: true, encoding: .utf8)
        try "ignored".write(to: root.appendingPathComponent("001-note.txt"), atomically: true, encoding: .utf8)
        watcher.syncNow()
        XCTAssertFalse(watcher.lastTransitions.contains { if case .deleted = $0 { return true }; return false })
        XCTAssertFalse(recorder.events.contains(.sessionEnded(source: "opencode", sessionId: "/tmp/old")))

        try FileManager.default.removeItem(at: newFile)
        try FileManager.default.removeItem(at: root.appendingPathComponent("001-note.txt"))
        watcher.syncNow()
        try FileManager.default.removeItem(at: oldFile)
        watcher.syncNow()

        XCTAssertEqual(watcher.lastTransitions, [.deleted(path: oldFile.path)])
        XCTAssertTrue(recorder.events.contains(.sessionEnded(source: "opencode", sessionId: "/tmp/old")))
    }

    func testEachFileIsReadOnceForParseAndFingerprint() throws {
        let root = try temporaryRoot()
        let file = root.appendingPathComponent("session.json")
        let data = Data(snapshot(directory: "/tmp/once", messageID: "one").utf8)
        try data.write(to: file)
        let reader = CountingOpenCodeReader(data: data)
        let watcher = OpenCodeContinuousSessionWatcher(
            rootURL: root,
            dataReader: reader,
            scheduler: TestWatcherScheduler()
        ) { _ in }

        watcher.syncNow()

        XCTAssertEqual(reader.readCount, 1)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func snapshot(directory: String, messageID: String) -> String {
        """
        {"session":{"directory":"\(directory)"},"messages":[{"id":"\(messageID)","sessionID":"\(directory)","role":"assistant"}]}
        """
    }
}

private final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedEvents: [AgentEvent] = []
    var count: Int { lock.lock(); defer { lock.unlock() }; return recordedEvents.count }
    var events: [AgentEvent] { lock.lock(); defer { lock.unlock() }; return recordedEvents }
    func append(_ event: AgentEvent) { lock.lock(); recordedEvents.append(event); lock.unlock() }
}

private final class TestWatcherScheduler: CodexSessionWatchScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var cancelledCount = 0
    private var action: (@Sendable () -> Void)?
    func schedule(every interval: TimeInterval, action: @escaping @Sendable () -> Void) -> CodexSessionWatchCancellation {
        lock.lock()
        self.action = action
        lock.unlock()
        return TestWatcherCancellation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.cancelledCount += 1
            self.action = nil
            self.lock.unlock()
        }
    }
    func fire() {
        lock.lock()
        let action = self.action
        lock.unlock()
        DispatchQueue.global().async { action?() }
    }
}

private final class TestWatcherCancellation: CodexSessionWatchCancellation, @unchecked Sendable {
    private let onCancel: () -> Void
    init(_ onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() { onCancel() }
}

private final class CountingOpenCodeReader: OpenCodeSessionDataReading, @unchecked Sendable {
    private let lock = NSLock()
    private let data: Data
    private var count = 0
    var readCount: Int { lock.lock(); defer { lock.unlock() }; return count }
    init(data: Data) { self.data = data }
    func read(_ url: URL, maximumBytes: Int) throws -> Data {
        lock.lock(); count += 1; lock.unlock()
        return data
    }
}
