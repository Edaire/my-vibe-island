import Foundation
import XCTest
import MyVibeIslandShared
@testable import MyVibeIslandCore

final class CodexSessionWatcherTests: XCTestCase {
    func testLiveWriterAdmissionDoesNotCreateSessionFromHistoricalRollout() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-history.jsonl")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: rollout)
        let recorder = EventRecorder()
        let watcher = CodexSessionWatcher(
            discovery: CodexSessionDiscovery(roots: [root]),
            scheduler: ManualCodexScheduler(),
            discoveryObserver: NoopCodexSessionDiscoveryObserver(),
            scheduleInitialPoll: { $0() },
            requiresLiveWriterForNewSession: true,
            writerInfoResolver: { _, completion in
                completion(CodexWriterInfo(outcome: .notFound))
            },
            eventHandler: recorder.record
        )

        watcher.start()

        XCTAssertTrue(recorder.events.isEmpty)
    }

    func testLiveProcessBackedRolloutIsScannedEvenWhenFileHasNotBeenModifiedRecently() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-live-but-old.jsonl")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: rollout)
        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000))
        try FileManager.default.setAttributes(
            [.modificationDate: clock.now.addingTimeInterval(-CodexSessionWatcher.activeFileTimeout - 1)],
            ofItemAtPath: rollout.path
        )
        let liveFile = try XCTUnwrap(CodexSessionDiscovery(roots: [root]).file(at: rollout))
        let recorder = EventRecorder()
        let watcher = CodexSessionWatcher(
            discovery: CodexSessionDiscovery(roots: [root]),
            liveDiscovery: { [liveFile] },
            scheduler: ManualCodexScheduler(),
            discoveryObserver: NoopCodexSessionDiscoveryObserver(),
            now: { clock.now },
            scheduleInitialPoll: { $0() },
            requiresLiveWriterForNewSession: true,
            writerInfoResolver: { _, completion in
                completion(CodexWriterInfo(tty: "/dev/ttys008", pid: 414, outcome: .matched))
            },
            eventHandler: recorder.record
        )

        watcher.start()

        XCTAssertTrue(recorder.events.contains(where: isSessionStarted))
    }

    func testDelayedWriterResolutionPublishesAlreadyReadLiveRollout() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-delayed-writer.jsonl")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: rollout)
        let liveFile = try XCTUnwrap(CodexSessionDiscovery(roots: [root]).file(at: rollout))
        let recorder = EventRecorder()
        let scheduler = ManualCodexScheduler()
        let published = DispatchSemaphore(value: 0)
        let callbackBox = WriterCompletionBox()
        let watcher = CodexSessionWatcher(
            discovery: CodexSessionDiscovery(roots: [root]),
            liveDiscovery: { [liveFile] },
            scheduler: scheduler,
            discoveryObserver: NoopCodexSessionDiscoveryObserver(),
            scheduleInitialPoll: { $0() },
            requiresLiveWriterForNewSession: true,
            writerInfoResolver: { _, completion in
                callbackBox.store(completion)
            },
            writerTrace: { trace in
                if trace.stage == .published { published.signal() }
            },
            eventHandler: { event in recorder.record(event) }
        )

        watcher.start()
        callbackBox.call(with: CodexWriterInfo(tty: "/dev/ttys008", pid: 414, outcome: .matched))
        scheduler.fire(interval: 900)

        XCTAssertEqual(published.wait(timeout: .now() + 1), .success)
        XCTAssertTrue(recorder.events.contains(where: isSessionStarted))
    }

    func testWriterTraceRecordsResolutionAdmissionAndPublicationForAcceptedRollout() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-traced.jsonl")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: rollout)
        let recorder = EventRecorder()
        let traceRecorder = CodexWatcherTraceRecorder()
        let watcher = CodexSessionWatcher(
            discovery: CodexSessionDiscovery(roots: [root]),
            scheduler: ManualCodexScheduler(),
            discoveryObserver: NoopCodexSessionDiscoveryObserver(),
            scheduleInitialPoll: { $0() },
            writerInfoResolver: { _, completion in
                completion(CodexWriterInfo(
                    tty: "/dev/ttys008",
                    pid: 414,
                    terminalBundleId: "com.apple.Terminal",
                    outcome: .matched
                ))
            },
            writerTrace: traceRecorder.record,
            eventHandler: recorder.record
        )

        watcher.start()

        XCTAssertEqual(
            traceRecorder.events.map(\.stage),
            [.resolutionRequested, .resolutionResolved, .admitted, .published]
        )
        XCTAssertEqual(traceRecorder.events.last?.sessionId, "codex-rollout-1")
        XCTAssertEqual(traceRecorder.events.last?.writerInfo?.tty, "/dev/ttys008")
        XCTAssertEqual(traceRecorder.events.last?.publishedEventCount, recorder.events.count)
    }

    func testWriterTraceDoesNotClaimAdmissionForAWriteThatPublishesNoSessionEvent() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-trace-noop.jsonl")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: rollout)
        let scheduler = ManualCodexScheduler()
        let traceRecorder = CodexWatcherTraceRecorder()
        let watcher = CodexSessionWatcher(
            discovery: CodexSessionDiscovery(roots: [root]),
            scheduler: scheduler,
            discoveryObserver: NoopCodexSessionDiscoveryObserver(),
            scheduleInitialPoll: { $0() },
            writerInfoResolver: { _, completion in
                completion(CodexWriterInfo(outcome: .matched))
            },
            writerTrace: traceRecorder.record,
            eventHandler: { _ in }
        )

        watcher.start()
        let publishedTraceCount = traceRecorder.events.count
        try append("{}\n", to: rollout)
        scheduler.fire(interval: 2)

        XCTAssertEqual(traceRecorder.events.count, publishedTraceCount)
    }

    func testAdmissionDeniedWriterSuppressesRolloutEvents() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-denied.jsonl")
        let admissionLedgerURL = root.appendingPathComponent("admission-ledger.json")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: rollout)
        let scheduler = ManualCodexScheduler()
        let recorder = EventRecorder()
        let resolverCalls = LockedCounter()

        let watcher = CodexSessionWatcher(
            discovery: CodexSessionDiscovery(roots: [root]),
            scheduler: scheduler,
            discoveryObserver: NoopCodexSessionDiscoveryObserver(),
            scheduleInitialPoll: { $0() },
            admissionLedgerURL: admissionLedgerURL,
            writerInfoResolver: { _, completion in
                _ = resolverCalls.increment()
                completion(CodexWriterInfo(
                    admissionDeniedAncestorBundleId: "com.example.denied",
                    outcome: .admissionDenied
                ))
            },
            eventHandler: recorder.record
        )

        watcher.start()

        XCTAssertTrue(recorder.events.isEmpty)
        XCTAssertEqual(watcher.trackedFileCount, 0)
        XCTAssertEqual(resolverCalls.value, 1)
        let rejection = SessionAdmissionLedger.load(from: admissionLedgerURL)["codex-rollout-1"]
        XCTAssertEqual(rejection?.evidence.cwd, "/tmp/private-project")
        XCTAssertEqual(rejection?.evidence.bundleIdentifiers, ["com.example.denied"])
        XCTAssertEqual(rejection?.reason, "ancestor bundle denied: com.example.denied")
    }

    func testEvidenceDefaultUsesOriginalEightSecondCompletionFallback() {
        XCTAssertEqual(CodexSessionWatcherTiming.evidenceDefault.attentionFallbackInterval, 1)
        XCTAssertEqual(CodexSessionWatcherTiming.evidenceDefault.idleFallbackInterval, 8)
    }

    func testDiscoveryPrioritizesMostRecentlyModifiedRollout() throws {
        let root = try temporaryRoot()
        let older = root.appendingPathComponent("rollout-a.jsonl")
        let newer = root.appendingPathComponent("rollout-z.jsonl")
        try Data("{}\n".utf8).write(to: older)
        try Data("{}\n".utf8).write(to: newer)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 100)],
            ofItemAtPath: older.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 200)],
            ofItemAtPath: newer.path
        )

        let discovered = CodexSessionDiscovery(roots: [root]).discover()

        XCTAssertEqual(discovered.map(\.url.lastPathComponent), ["rollout-z.jsonl", "rollout-a.jsonl"])
    }

    func testDiscoveryCanLimitToOneMostRecentlyModifiedRollout() throws {
        let root = try temporaryRoot()
        let older = root.appendingPathComponent("rollout-a.jsonl")
        let newer = root.appendingPathComponent("rollout-z.jsonl")
        try Data("{}\n".utf8).write(to: older)
        try Data("{}\n".utf8).write(to: newer)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 100)],
            ofItemAtPath: older.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 200)],
            ofItemAtPath: newer.path
        )

        let discovered = CodexSessionDiscovery(roots: [root], maximumFiles: 1).discover()

        XCTAssertEqual(discovered.map(\.url.lastPathComponent), ["rollout-z.jsonl"])
    }

    func testStartupUsesFSEventsAndIDARecoverySweepToDiscoverRollouts() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-startup.jsonl")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: rollout)
        let scheduler = ManualCodexScheduler()
        let recorder = EventRecorder()
        let discoveryObserver = ManualCodexSessionDiscoveryObserver()
        let watcher = makeWatcher(
            root: root,
            scheduler: scheduler,
            recorder: recorder,
            discoveryObserver: discoveryObserver
        )

        watcher.start()

        XCTAssertEqual(scheduler.activeIntervals, [2, 900])
        XCTAssertEqual(discoveryObserver.observedRoots, [[root]])
        XCTAssertEqual(recorder.events.count, 2)
        XCTAssertEqual(watcher.fileState(for: rollout)?.remainder, Data())
        XCTAssertEqual(watcher.fileState(for: rollout)?.size, try fileSize(rollout))
        XCTAssertNotNil(watcher.fileState(for: rollout)?.inode)

        let addedAfterStartup = root.appendingPathComponent("rollout-fsevent.jsonl")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: addedAfterStartup)
        discoveryObserver.trigger()

        XCTAssertNotNil(watcher.fileState(for: addedAfterStartup))
    }

    func testStartupPublishesRolloutPathForTerminalSessionMap() throws {
        let (_, rollout, _, recorder, _) = try startedWatcher()

        let activity = try XCTUnwrap(recorder.events.compactMap(\.activity).first)

        XCTAssertEqual(activity.codexRolloutPath, rollout.path)
    }

    func testChildRolloutPreservesFirstChildMetadataAcrossInheritedParentSessionMetadata() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-child-history.jsonl")
        let inherited = [
            #"{"timestamp":"2026-08-17T12:53:02.000Z","type":"session_meta","payload":{"session_id":"parent-thread","id":"child-thread","forked_from_id":"parent-thread","parent_thread_id":"parent-thread","cwd":"/tmp/project","thread_source":"subagent","agent_nickname":"Bacon","agent_path":"/root/independent_diff_review","source":{"subagent":{"thread_spawn":{"parent_thread_id":"parent-thread","depth":1,"agent_path":"/root/independent_diff_review","agent_nickname":"Bacon","agent_role":null}}}}}"#,
            #"{"timestamp":"2026-08-17T12:53:02.100Z","type":"session_meta","payload":{"id":"parent-thread","cwd":"/tmp/project","thread_source":"user","source":"cli"}}"#,
            #"{"timestamp":"2026-08-19T09:00:01.000Z","type":"event_msg","payload":{"type":"task_started"}}"#,
            #"{"timestamp":"2026-08-19T09:00:02.000Z","type":"response_item","payload":{"type":"function_call","name":"exec","arguments":"{\"cmd\":\"historical command\"}"}}"#,
        ].joined(separator: "\n") + "\n"
        try inherited.write(to: rollout, atomically: true, encoding: .utf8)
        let scheduler = ManualCodexScheduler()
        let recorder = EventRecorder()
        let watcher = makeWatcher(root: root, scheduler: scheduler, recorder: recorder)

        watcher.start()

        XCTAssertTrue(recorder.events.isEmpty)
        XCTAssertEqual(watcher.fileState(for: rollout)?.offset, try fileSize(rollout))

        try append(
            #"{"timestamp":"2026-08-19T09:00:03.000Z","type":"response_item","payload":{"type":"function_call","name":"exec","arguments":"{\"cmd\":\"live command\"}"}}"# + "\n",
            to: rollout
        )
        scheduler.fire(interval: 2)

        guard case let .subagentLifecycleUpdated(_, _, lifecycle) = try XCTUnwrap(recorder.events.first) else {
            return XCTFail("expected a post-bootstrap child lifecycle event")
        }
        XCTAssertEqual(recorder.events.count, 1)
        XCTAssertEqual(lifecycle.parentThreadId, "parent-thread")
        XCTAssertEqual(lifecycle.nickname, "Bacon")
        XCTAssertEqual(lifecycle.currentActivity, "live command")

        let coordinator = SessionCoordinator(sessions: [
            SessionState(sessionId: "codex-parent-thread", source: "codex", cwd: "/tmp/project"),
        ])
        recorder.events.forEach(coordinator.apply)
        XCTAssertEqual(coordinator.snapshots().map(\.sessionId), ["codex-parent-thread"])
        XCTAssertEqual(coordinator.snapshot(sessionId: "codex-parent-thread")?.subagents.map(\.id), ["codex-child-thread"])
    }

    func testStartReturnsWhileInitialBootstrapIsStillPublishing() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-startup.jsonl")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: rollout)
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let returned = DispatchSemaphore(value: 0)
        let watcher = CodexSessionWatcher(
            discovery: CodexSessionDiscovery(roots: [root]),
            scheduler: ManualCodexScheduler(),
            eventHandler: { _ in
                entered.signal()
                release.wait()
            }
        )

        DispatchQueue.global().async {
            watcher.start()
            returned.signal()
        }

        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(returned.wait(timeout: .now() + 0.1), .success)
        release.signal()
        watcher.stop()
    }

    func testSlowBootstrapRejectsUntrackedRolloutOlderThanActiveTimeout() throws {
        let root = try temporaryRoot()
        let active = root.appendingPathComponent("rollout-active.jsonl")
        let stale = root.appendingPathComponent("rollout-stale.jsonl")
        let fixture = try FixtureLoader.data("codex/rollout-startup", extension: "jsonl")
        try fixture.write(to: active)
        try fixture.write(to: stale)

        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000))
        try FileManager.default.setAttributes(
            [.modificationDate: clock.now.addingTimeInterval(-CodexSessionWatcher.activeFileTimeout - 1)],
            ofItemAtPath: stale.path
        )
        let scheduler = ManualCodexScheduler()
        let watcher = makeWatcher(root: root, scheduler: scheduler, recorder: EventRecorder(), clock: clock)

        watcher.start()

        XCTAssertEqual(watcher.trackedFileCount, 1)
        XCTAssertNotNil(watcher.fileState(for: active))
        XCTAssertNil(watcher.fileState(for: stale))
    }

    func testIDAActiveTimeoutIsAppliedBySlowPollNotFastPoll() throws {
        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000))
        let (_, rollout, scheduler, _, watcher) = try startedWatcher(clock: clock)
        XCTAssertEqual(watcher.trackedFileCount, 1)

        clock.advance(by: CodexSessionWatcher.activeFileTimeout + 1)
        scheduler.fire(interval: 2)

        XCTAssertEqual(watcher.trackedFileCount, 1)
        XCTAssertNotNil(watcher.fileState(for: rollout))

        scheduler.fire(interval: 900)

        XCTAssertEqual(watcher.trackedFileCount, 0)
        XCTAssertNil(watcher.fileState(for: rollout))
    }

    func testInactiveRolloutTombstonePreventsRepeatedSlowBootstrapUntilFileChanges() throws {
        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000))
        let (_, rollout, scheduler, _, watcher) = try startedWatcher(clock: clock)

        clock.advance(by: CodexSessionWatcher.activeFileTimeout + 1)
        scheduler.fire(interval: 900)
        XCTAssertEqual(watcher.trackedFileCount, 0)

        scheduler.fire(interval: 900)
        XCTAssertEqual(watcher.trackedFileCount, 0)

        try append("\n", to: rollout)
        scheduler.fire(interval: 900)
        XCTAssertEqual(watcher.trackedFileCount, 1)
    }

    func testAppendAndPartialLinePublishOnlyAfterNewline() throws {
        let (root, rollout, scheduler, recorder, watcher) = try startedWatcher()
        let baseline = recorder.events.count
        let partial = #"{"timestamp":"2026-07-16T08:01:00.000Z","type":"event_msg","payload":{"type":"request_user_input"}}"#

        try append(partial, to: rollout)
        scheduler.fire(interval: 2)
        XCTAssertEqual(recorder.events.count, baseline)
        XCTAssertFalse(watcher.fileState(for: rollout)?.remainder.isEmpty ?? true)

        try append("\n", to: rollout)
        scheduler.fire(interval: 2)
        XCTAssertEqual(recorder.events.last?.activity?.status, .waiting)
        XCTAssertEqual(watcher.fileState(for: rollout)?.remainder, Data())
        _ = root
    }

    func testRemainderIsCappedAtIDA262144Bytes() throws {
        let (_, rollout, scheduler, recorder, watcher) = try startedWatcher()
        let baseline = recorder.events.count

        try append(String(repeating: "x", count: CodexRolloutFileState.maximumRemainderSize + 1), to: rollout)
        scheduler.fire(interval: 2)

        XCTAssertLessThanOrEqual(
            watcher.fileState(for: rollout)?.remainder.count ?? .max,
            CodexRolloutFileState.maximumRemainderSize
        )
        XCTAssertEqual(recorder.events.count, baseline)
    }

    func testOversizedLineIsDroppedEvenWhenItEndsInsideACombinedChunk() throws {
        let (_, rollout, scheduler, recorder, watcher) = try startedWatcher()
        let baseline = recorder.events.count
        try append(String(repeating: "x", count: CodexRolloutFileState.maximumRemainderSize - 1), to: rollout)
        scheduler.fire(interval: 2)

        let valid = #"{"type":"event_msg","payload":{"type":"user_message","message":"resumed after oversized"}}"# + "\n"
        try append(String(repeating: "x", count: 100) + "\n" + valid, to: rollout)
        scheduler.fire(interval: 2)

        XCTAssertTrue(recorder.events.dropFirst(baseline).contains { event in
            guard case let .sessionActivityUpdated(_, sessionId, activity) = event else { return false }
            return sessionId == "codex-rollout-1"
                && activity.lastUserMessage == "resumed after oversized"
        }, "events: \(recorder.events)")
        XCTAssertLessThanOrEqual(watcher.fileState(for: rollout)?.remainder.count ?? .max,
                                 CodexRolloutFileState.maximumRemainderSize)
    }

    func testTruncationAndInodeRotationResetFileStateWithoutDuplicateEvents() throws {
        let (_, rollout, scheduler, recorder, watcher) = try startedWatcher()
        let originalInode = try XCTUnwrap(watcher.fileState(for: rollout)?.inode)
        let startup = try FixtureLoader.data("codex/rollout-startup", extension: "jsonl")

        try startup.write(to: rollout, options: .atomic)
        scheduler.fire(interval: 2)
        let rotatedInode = try XCTUnwrap(watcher.fileState(for: rollout)?.inode)
        XCTAssertNotEqual(rotatedInode, originalInode)

        let beforeDuplicatePoll = recorder.events.count
        scheduler.fire(interval: 2)
        XCTAssertEqual(recorder.events.count, beforeDuplicatePoll)

        try Data(startup.prefix(120)).write(to: rollout)
        scheduler.fire(interval: 2)
        XCTAssertEqual(watcher.fileState(for: rollout)?.size, 120)
    }

    func testCompletionFallbackPublishesOnceAfterIdleDeadline() throws {
        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000))
        let (_, rollout, scheduler, recorder, watcher) = try startedWatcher(clock: clock)
        XCTAssertEqual(watcher.trackedFileCount, 1)
        try append(try FixtureLoader.string("codex/rollout-idle", extension: "jsonl"), to: rollout)
        scheduler.fire(interval: 2)
        XCTAssertEqual(recorder.events.last?.activity?.status, .idle)

        clock.advance(by: CodexSessionWatcherTiming.evidenceDefault.idleFallbackInterval)
        scheduler.fire(interval: CodexSessionWatcherTiming.evidenceDefault.idleFallbackInterval)
        XCTAssertEqual(recorder.events.last?.activity?.status, .completed)
        XCTAssertEqual(recorder.events.last?.activity?.isCompletionFallback, true)

        let count = recorder.events.count
        scheduler.fire(interval: 2)
        XCTAssertEqual(recorder.events.count, count)
    }

    func testCompletionFallbackDoesNotCompleteAnIdleSnapshotWhileItsWriterIsStillLive() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-live-idle.jsonl")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: rollout)
        try append(try FixtureLoader.string("codex/rollout-idle", extension: "jsonl"), to: rollout)
        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000))
        let scheduler = ManualCodexScheduler()
        let recorder = EventRecorder()
        let watcher = CodexSessionWatcher(
            discovery: CodexSessionDiscovery(roots: [root]),
            scheduler: scheduler,
            discoveryObserver: NoopCodexSessionDiscoveryObserver(),
            now: { clock.now },
            scheduleInitialPoll: { $0() },
            writerInfoResolver: { _, completion in
                completion(CodexWriterInfo(tty: "/dev/ttys008", pid: 414, outcome: .matched))
            },
            eventHandler: recorder.record
        )

        watcher.start()
        scheduler.fire(interval: 2)
        XCTAssertEqual(recorder.events.last?.activity?.status, .idle)

        clock.advance(by: CodexSessionWatcherTiming.evidenceDefault.idleFallbackInterval)
        scheduler.fire(interval: CodexSessionWatcherTiming.evidenceDefault.idleFallbackInterval)

        XCTAssertNotEqual(recorder.events.last?.activity?.status, .completed)
    }

    func testAssistantMessageDoesNotCompleteBeforeTheOriginalEightSecondFallbackBoundary() throws {
        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000))
        let (_, rollout, scheduler, recorder, watcher) = try startedWatcher(clock: clock)
        XCTAssertEqual(watcher.trackedFileCount, 1)
        try append(try FixtureLoader.string("codex/rollout-idle", extension: "jsonl"), to: rollout)
        scheduler.fire(interval: 2)
        XCTAssertEqual(recorder.events.last?.activity?.status, .idle)

        let count = recorder.events.count
        clock.advance(by: 7)
        scheduler.fire(interval: 7)

        XCTAssertEqual(recorder.events.count, count)
        XCTAssertEqual(recorder.events.last?.activity?.status, .idle)
    }

    func testFastAndSlowPollGuardsAndStopTeardown() throws {
        let (root, _, scheduler, recorder, watcher) = try startedWatcher()
        let baseline = recorder.events.count

        watcher.withFastPollGuardForTesting {
            scheduler.fire(interval: 2)
        }
        watcher.withSlowPollGuardForTesting {
            scheduler.fire(interval: 900)
        }
        XCTAssertEqual(recorder.events.count, baseline)

        watcher.stop()
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl")
            .write(to: root.appendingPathComponent("rollout-late.jsonl"))
        scheduler.fireAll()

        XCTAssertTrue(scheduler.allCancelled)
        XCTAssertEqual(watcher.trackedFileCount, 0)
        XCTAssertEqual(recorder.events.count, baseline)
    }

    func testAdaptivePollUsesLastWriteAgeAndReschedulesFastTimer() throws {
        let clock = ManualClock(Date(timeIntervalSince1970: 100))
        let (_, _, scheduler, _, watcher) = try startedWatcher(clock: clock)

        XCTAssertEqual(watcher.currentPollInterval, 2)
        clock.advance(by: 4)
        scheduler.fire(interval: 2)
        XCTAssertEqual(watcher.currentPollInterval, 2)
        XCTAssertEqual(scheduler.activeIntervals.sorted(), [2, 900])

        clock.advance(by: 1)
        scheduler.fire(interval: 2)
        XCTAssertEqual(watcher.currentPollInterval, 5)
        XCTAssertEqual(scheduler.activeIntervals.sorted(), [5, 900])

        clock.advance(by: 24)
        scheduler.fire(interval: 5)
        XCTAssertEqual(watcher.currentPollInterval, 5)

        clock.advance(by: 1)
        scheduler.fire(interval: 5)
        XCTAssertEqual(watcher.currentPollInterval, 15)
        XCTAssertEqual(scheduler.activeIntervals.sorted(), [15, 900])
    }

    func testAttentionFallbackIsInjectedAndLeavingAttentionRecordsRecovery() throws {
        let timing = CodexSessionWatcherTiming(attentionFallbackInterval: 3, idleFallbackInterval: 4)
        let clock = ManualClock(Date(timeIntervalSince1970: 100))
        let (_, rollout, scheduler, recorder, watcher) = try startedWatcher(clock: clock, timing: timing)

        try append(try FixtureLoader.string("codex/rollout-attention", extension: "jsonl"), to: rollout)
        scheduler.fire(interval: 2)
        XCTAssertEqual(watcher.attentionTimerCount, 1)

        try append(try FixtureLoader.string("codex/rollout-idle", extension: "jsonl"), to: rollout)
        scheduler.fire(interval: 2)
        XCTAssertEqual(watcher.attentionTimerCount, 0)
        XCTAssertEqual(watcher.attentionRecoveryCount, 1)

        clock.advance(by: 3)
        scheduler.fire(interval: 3)
        XCTAssertEqual(recorder.events.last?.activity?.status, .idle)
    }

    func testAttentionFallbackPublishesACompletionFallbackEvent() throws {
        let timing = CodexSessionWatcherTiming(attentionFallbackInterval: 3, idleFallbackInterval: 4)
        let clock = ManualClock(Date(timeIntervalSince1970: 100))
        let (_, rollout, scheduler, recorder, watcher) = try startedWatcher(clock: clock, timing: timing)

        try append(try FixtureLoader.string("codex/rollout-attention", extension: "jsonl"), to: rollout)
        scheduler.fire(interval: 2)
        clock.advance(by: 3)
        scheduler.fire(interval: 3)

        XCTAssertEqual(watcher.attentionTimerCount, 0)
        XCTAssertEqual(recorder.events.last?.activity?.status, .completed)
        XCTAssertEqual(recorder.events.last?.activity?.isCompletionFallback, true)
    }

    func testStopWaitsForInFlightGenerationAndPreventsOldPublishAfterReturn() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-startup.jsonl")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: rollout)
        let scheduler = ManualCodexScheduler()
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let stopped = DispatchSemaphore(value: 0)
        let counter = LockedCounter()
        let watcher = CodexSessionWatcher(
            discovery: CodexSessionDiscovery(roots: [root]),
            scheduler: scheduler,
            scheduleInitialPoll: { $0() },
            eventHandler: { _ in
                if counter.increment() == 1 {
                    entered.signal()
                    release.wait()
                }
            }
        )

        DispatchQueue.global().async { watcher.start() }
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        DispatchQueue.global().async {
            watcher.stop()
            stopped.signal()
        }
        XCTAssertEqual(stopped.wait(timeout: .now() + 0.05), .timedOut)
        release.signal()
        XCTAssertEqual(stopped.wait(timeout: .now() + 1), .success)

        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl")
            .write(to: root.appendingPathComponent("rollout-late.jsonl"))
        scheduler.fireAll()
        XCTAssertEqual(counter.value, 1)
    }

    func testEventHandlerCanStopReentrantlyAndNoCallbackRunsAfterStop() throws {
        let root = try temporaryRoot()
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl")
            .write(to: root.appendingPathComponent("rollout-startup.jsonl"))
        let scheduler = ManualCodexScheduler()
        let callbacks = LockedCounter()
        let finished = DispatchSemaphore(value: 0)
        let watcherBox = WatcherBox()
        let watcher = CodexSessionWatcher(
            discovery: CodexSessionDiscovery(roots: [root]),
            scheduler: scheduler,
            scheduleInitialPoll: { $0() },
            eventHandler: { _ in
                _ = callbacks.increment()
                watcherBox.value?.stop()
            }
        )
        watcherBox.value = watcher

        DispatchQueue.global().async {
            watcher.start()
            finished.signal()
        }

        XCTAssertEqual(finished.wait(timeout: .now() + 1), .success)
        let callbackCount = callbacks.value
        scheduler.fireAll()
        XCTAssertEqual(callbacks.value, callbackCount)
    }

    func testPollReadsBoundedChunksAndOffsetAdvancesOnlyByActualBytes() throws {
        let (_, rollout, scheduler, _, watcher) = try startedWatcher()
        let initialSize = try fileSize(rollout)
        try append(String(repeating: "x", count: 1_000_000), to: rollout)

        scheduler.fire(interval: 2)

        let state = try XCTUnwrap(watcher.fileState(for: rollout))
        let actualSize = try fileSize(rollout)
        XCTAssertEqual(state.offset, state.size)
        XCTAssertLessThan(state.offset, actualSize)
        XCTAssertLessThanOrEqual(
            state.offset - initialSize,
            CodexSessionWatcher.maximumBytesPerPoll
        )
        XCTAssertLessThanOrEqual(
            state.remainder.count,
            CodexRolloutFileState.maximumRemainderSize
        )
    }

    func testLargeExistingRolloutBootstrapsCurrentTailInsteadOfOldFileHead() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-large.jsonl")
        let header = #"{"timestamp":"2026-07-17T04:00:00.000Z","type":"session_meta","payload":{"id":"large-session","cwd":"/tmp/project"}}"# + "\n"
        let filler = String(repeating: "x", count: Int(CodexSessionWatcher.maximumBytesPerPoll) + 100)
        let currentTurn = #"{"timestamp":"2026-07-17T04:01:00.000Z","type":"event_msg","payload":{"type":"turn_started"}}"# + "\n"
        try (header + filler + "\n" + currentTurn).write(to: rollout, atomically: true, encoding: .utf8)

        let scheduler = ManualCodexScheduler()
        let recorder = EventRecorder()
        let watcher = makeWatcher(root: root, scheduler: scheduler, recorder: recorder)

        watcher.start()

        XCTAssertEqual(recorder.events.last?.activity?.status, .active)
        XCTAssertEqual(watcher.fileState(for: rollout)?.offset, try fileSize(rollout))
    }

    func testLargeBootstrapFindsRecentUserMessageBeforeOversizedToolRecord() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-large-user-message.jsonl")
        let header = #"{"type":"session_meta","payload":{"id":"large-session","cwd":"/tmp/project"}}"# + "\n"
        let user = #"{"type":"event_msg","payload":{"type":"user_message","message":"Render the real session"}}"# + "\n"
        let oversizedInput = String(repeating: "x", count: Int(CodexSessionWatcher.maximumBytesPerPoll) * 2)
        let tool = #"{"type":"response_item","payload":{"type":"custom_tool_call","name":"exec","input":""#
            + oversizedInput
            + #""}}"#
            + "\n"
        let current = #"{"type":"event_msg","payload":{"type":"turn_started"}}"# + "\n"
        try (header + user + tool + current).write(to: rollout, atomically: true, encoding: .utf8)

        let recorder = EventRecorder()
        let watcher = makeWatcher(
            root: root,
            scheduler: ManualCodexScheduler(),
            recorder: recorder
        )

        watcher.start()

        XCTAssertEqual(recorder.events.last?.activity?.lastUserMessage, "Render the real session")
    }

    func testLargeBootstrapPreservesInitialPromptFromHeadAndLatestPromptFromTail() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-large-prompts.jsonl")
        let header = #"{"type":"session_meta","payload":{"id":"large-session","cwd":"/tmp/project"}}"# + "\n"
        let injected = #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>internal</environment_context>"}]}}"# + "\n"
        let initial = #"{"type":"event_msg","payload":{"type":"user_message","message":"Build the original island behavior"}}"# + "\n"
        let filler = String(repeating: "x", count: Int(CodexSessionWatcher.maximumBootstrapBytes) + 1_024) + "\n"
        let latest = #"{"type":"event_msg","payload":{"type":"user_message","message":"Fix the first session card"}}"# + "\n"
        try (header + injected + initial + filler + latest)
            .write(to: rollout, atomically: true, encoding: .utf8)

        let recorder = EventRecorder()
        let watcher = makeWatcher(
            root: root,
            scheduler: ManualCodexScheduler(),
            recorder: recorder
        )

        watcher.start()

        XCTAssertEqual(recorder.events.last?.activity?.firstUserMessage, "Build the original island behavior")
        XCTAssertEqual(recorder.events.last?.activity?.lastUserMessage, "Fix the first session card")
    }

    func testSameInodeRewriteWithSizeAtLeastOldSizeRebuildsFromStart() throws {
        let (_, rollout, scheduler, recorder, watcher) = try startedWatcher()
        let oldInode = try XCTUnwrap(watcher.fileState(for: rollout)?.inode)
        let oldSize = try fileSize(rollout)
        let rewritten = """
        {"timestamp":"2026-07-16T09:00:00.000Z","type":"session_meta","payload":{"id":"codex-rewritten","cwd":"/tmp/rebuilt"}}
        {"timestamp":"2026-07-16T09:00:01.000Z","type":"event_msg","payload":{"type":"task_started"}}
        """ + String(repeating: " ", count: max(0, Int(oldSize) - 1))
        let handle = try FileHandle(forWritingTo: rollout)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(rewritten.utf8))
        try handle.close()

        XCTAssertGreaterThanOrEqual(try fileSize(rollout), oldSize)
        XCTAssertEqual(try XCTUnwrap(watcher.fileState(for: rollout)?.inode), oldInode)
        scheduler.fire(interval: 2)

        XCTAssertTrue(recorder.events.contains { event in
            guard case let .sessionStarted(_, sessionId, _) = event else { return false }
            return sessionId == "codex-rewritten"
        })
    }

    func testSameInodeRewriteWithIdenticalFirst4096BytesRebuildsFromStart() throws {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-same-prefix.jsonl")
        let commonPrefix = String(repeating: " ", count: 4_096) + "\n"
        let original = commonPrefix + """
        {"type":"session_meta","payload":{"id":"before-rewrite","cwd":"/tmp/before"}}
        {"type":"event_msg","payload":{"type":"task_started"}}
        """
        try original.write(to: rollout, atomically: false, encoding: .utf8)
        let scheduler = ManualCodexScheduler()
        let recorder = EventRecorder()
        let watcher = makeWatcher(root: root, scheduler: scheduler, recorder: recorder)
        watcher.start()
        let oldInode = try XCTUnwrap(watcher.fileState(for: rollout)?.inode)

        let replacement = commonPrefix + """
        {"type":"session_meta","payload":{"id":"after-rewrite","cwd":"/tmp/after"}}
        {"type":"event_msg","payload":{"type":"request_user_input"}}
        """ + String(repeating: " ", count: original.utf8.count)
        let handle = try FileHandle(forWritingTo: rollout)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(replacement.utf8))
        try handle.close()

        XCTAssertEqual(try XCTUnwrap(watcher.fileState(for: rollout)?.inode), oldInode)
        scheduler.fire(interval: 2)

        XCTAssertTrue(recorder.events.contains { event in
            guard case let .sessionStarted(_, sessionId, _) = event else { return false }
            return sessionId == "codex-after-rewrite"
        }, "events: \(recorder.events)")
    }

    func testConcurrentFastAndSlowPollsPublishEverySemanticEventInPipelineOrder() throws {
        let (_, rollout, scheduler, recorder, watcher) = try startedWatcher()
        try append(try FixtureLoader.string("codex/rollout-attention", extension: "jsonl"), to: rollout)
        scheduler.fire(interval: 2)
        XCTAssertEqual(watcher.attentionTimerCount, 1)

        let blocked = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let cancellationCount = LockedCounter()
        scheduler.cancellationProbe = {
            if cancellationCount.increment() == 1 {
                blocked.signal()
                release.wait()
            }
        }
        try append(try FixtureLoader.string("codex/rollout-idle", extension: "jsonl"), to: rollout)
        let fastFinished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            scheduler.fire(interval: 2)
            fastFinished.signal()
        }
        XCTAssertEqual(blocked.wait(timeout: .now() + 1), .success)

        try append(#"{"type":"event_msg","payload":{"type":"turn_complete"}}"# + "\n", to: rollout)
        let slowFinished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            scheduler.fire(interval: 900)
            slowFinished.signal()
        }
        let slowResultBeforeRelease = slowFinished.wait(timeout: .now() + 0.05)

        release.signal()
        XCTAssertEqual(fastFinished.wait(timeout: .now() + 1), .success)
        if slowResultBeforeRelease == .timedOut {
            XCTAssertEqual(slowFinished.wait(timeout: .now() + 1), .success)
        }
        XCTAssertEqual(slowResultBeforeRelease, .timedOut)

        let sessionStarts = recorder.events.compactMap { event -> String? in
            guard case let .sessionStarted(_, sessionId, _) = event else { return nil }
            return sessionId
        }
        XCTAssertEqual(sessionStarts.count, 1)
        XCTAssertEqual(recorder.events.first.map(isSessionStarted), true)
        XCTAssertEqual(recorder.events.compactMap(\.activity?.status), [.active, .waiting, .idle, .completed])
    }

    func testIdleFallbackRecordsShareTheGlobalBoundAndRejectDeterministically() throws {
        let root = try temporaryRoot()
        let count = CodexSessionWatcher.maximumFallbackRecords + 20
        for index in 0..<count {
            let url = root.appendingPathComponent(String(format: "rollout-%04d.jsonl", index))
            try """
            {"type":"session_meta","payload":{"id":"idle-\(index)","cwd":"/tmp"}}
            {"type":"event_msg","payload":{"type":"agent_message"}}
            """.write(to: url, atomically: true, encoding: .utf8)
        }
        let timing = CodexSessionWatcherTiming(attentionFallbackInterval: 3, idleFallbackInterval: 4)
        let scheduler = ManualCodexScheduler()
        let recorder = EventRecorder()
        let watcher = makeWatcher(root: root, scheduler: scheduler, recorder: recorder, timing: timing)
        watcher.start()

        XCTAssertEqual(watcher.idleContextCount, CodexSessionWatcher.maximumFallbackRecords)
        XCTAssertEqual(scheduler.activeIntervals.filter { $0 == 4 }.count,
                       CodexSessionWatcher.maximumFallbackRecords)

        scheduler.fire(interval: 4)
        let completedIds = recorder.events.compactMap { event -> String? in
            guard case let .sessionActivityUpdated(_, sessionId, activity) = event,
                  activity.status == .completed else { return nil }
            return sessionId
        }
        XCTAssertTrue(completedIds.contains("codex-idle-\(count - 1)"), "completed IDs: \(completedIds)")
        XCTAssertFalse(completedIds.contains("codex-idle-0"))
    }

    func testRemovedFileClearsFallbackContextsRecoveriesAndBoundedBookkeeping() throws {
        let root = try temporaryRoot()
        for index in 0..<(CodexSessionWatcher.maximumFallbackRecords + 10) {
            let url = root.appendingPathComponent("rollout-\(index).jsonl")
            try """
            {"type":"session_meta","payload":{"id":"s-\(index)","cwd":"/tmp"}}
            {"type":"event_msg","payload":{"type":"request_user_input"}}
            """.write(to: url, atomically: true, encoding: .utf8)
        }
        let scheduler = ManualCodexScheduler()
        let watcher = makeWatcher(root: root, scheduler: scheduler, recorder: EventRecorder())
        watcher.start()

        XCTAssertLessThanOrEqual(watcher.attentionTimerCount, CodexSessionWatcher.maximumFallbackRecords)
        let removed = root.appendingPathComponent("rollout-0.jsonl")
        try FileManager.default.removeItem(at: removed)
        scheduler.fire(interval: 900)
        XCTAssertNil(watcher.fileState(for: removed))
        XCTAssertEqual(watcher.attentionContextCount(for: removed), 0)
        XCTAssertEqual(watcher.recoveryCount(for: removed), 0)
    }

    func testTimerCancellationCanReenterWatcherWithoutLockInversion() throws {
        let (_, rollout, scheduler, _, watcher) = try startedWatcher()
        try append(try FixtureLoader.string("codex/rollout-attention", extension: "jsonl"), to: rollout)
        scheduler.fire(interval: 2)
        let finished = DispatchSemaphore(value: 0)
        scheduler.cancellationProbe = {
            _ = watcher.trackedFileCount
            finished.signal()
        }

        DispatchQueue.global().async {
            watcher.stop()
        }
        XCTAssertEqual(finished.wait(timeout: .now() + 1), .success)
    }

    private func startedWatcher(
        clock: ManualClock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000)),
        timing: CodexSessionWatcherTiming = .evidenceDefault
    ) throws -> (URL, URL, ManualCodexScheduler, EventRecorder, CodexSessionWatcher) {
        let root = try temporaryRoot()
        let rollout = root.appendingPathComponent("rollout-startup.jsonl")
        try FixtureLoader.data("codex/rollout-startup", extension: "jsonl").write(to: rollout)
        let scheduler = ManualCodexScheduler()
        let recorder = EventRecorder()
        let watcher = makeWatcher(root: root, scheduler: scheduler, recorder: recorder, clock: clock, timing: timing)
        watcher.start()
        return (root, rollout, scheduler, recorder, watcher)
    }

    private func makeWatcher(
        root: URL,
        scheduler: ManualCodexScheduler,
        recorder: EventRecorder,
        clock: ManualClock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000)),
        timing: CodexSessionWatcherTiming = .evidenceDefault,
        discoveryObserver: CodexSessionDiscoveryObserving = NoopCodexSessionDiscoveryObserver()
    ) -> CodexSessionWatcher {
        CodexSessionWatcher(
            discovery: CodexSessionDiscovery(roots: [root]),
            scheduler: scheduler,
            discoveryObserver: discoveryObserver,
            now: { clock.now },
            timing: timing,
            scheduleInitialPoll: { $0() },
            eventHandler: recorder.record
        )
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-codex-watcher-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func append(_ string: String, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(string.utf8))
    }

    private func fileSize(_ url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    }

    private func isSessionStarted(_ event: AgentEvent) -> Bool {
        guard case .sessionStarted = event else { return false }
        return true
    }
}

private final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var events: [AgentEvent] = []

    func record(_ event: AgentEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }
}

private final class WriterCompletionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: ((CodexWriterInfo) -> Void)?

    func store(_ completion: @escaping (CodexWriterInfo) -> Void) {
        lock.lock()
        self.completion = completion
        lock.unlock()
    }

    func call(with info: CodexWriterInfo) {
        lock.lock()
        let completion = self.completion
        lock.unlock()
        completion?(info)
    }
}

private final class CodexWatcherTraceRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var events: [CodexWatcherTraceEvent] = []

    func record(_ event: CodexWatcherTraceEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var value = 0

    func increment() -> Int {
        lock.lock()
        value += 1
        let result = value
        lock.unlock()
        return result
    }
}

private final class WatcherBox: @unchecked Sendable {
    var value: CodexSessionWatcher?
}

private final class ManualClock: @unchecked Sendable {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

private final class ManualCodexSessionDiscoveryObserver: CodexSessionDiscoveryObserving, @unchecked Sendable {
    private(set) var observedRoots: [[URL]] = []
    private var handler: (@Sendable () -> Void)?

    func observe(
        roots: [URL],
        handler: @escaping @Sendable () -> Void
    ) -> CodexSessionWatchCancellation {
        observedRoots.append(roots)
        self.handler = handler
        return ManualCancellation()
    }

    func trigger() {
        handler?()
    }
}

private final class ManualCodexScheduler: CodexSessionWatchScheduling, @unchecked Sendable {
    private struct Entry {
        let interval: TimeInterval
        let action: @Sendable () -> Void
        let cancellation: ManualCancellation
    }

    private var entries: [Entry] = []

    var intervals: [TimeInterval] { entries.map(\.interval) }
    var activeIntervals: [TimeInterval] {
        entries.filter { !$0.cancellation.isCancelled }.map(\.interval)
    }
    var cancellationProbe: (() -> Void)?
    var allCancelled: Bool { entries.allSatisfy(\.cancellation.isCancelled) }

    func schedule(every interval: TimeInterval, action: @escaping @Sendable () -> Void) -> CodexSessionWatchCancellation {
        let cancellation = ManualCancellation(onCancel: { [weak self] in self?.cancellationProbe?() })
        entries.append(Entry(interval: interval, action: action, cancellation: cancellation))
        return cancellation
    }

    func fire(interval: TimeInterval) {
        entries.filter { $0.interval == interval && !$0.cancellation.isCancelled }.forEach { $0.action() }
    }

    func fireAll() {
        entries.filter { !$0.cancellation.isCancelled }.forEach { $0.action() }
    }
}

private final class ManualCancellation: CodexSessionWatchCancellation, @unchecked Sendable {
    private let onCancel: (() -> Void)?
    private(set) var isCancelled = false

    init(onCancel: (() -> Void)? = nil) {
        self.onCancel = onCancel
    }

    func cancel() {
        isCancelled = true
        onCancel?()
    }
}

private extension AgentEvent {
    var activity: SessionActivityUpdate? {
        guard case let .sessionActivityUpdated(_, _, activity) = self else { return nil }
        return activity
    }
}
