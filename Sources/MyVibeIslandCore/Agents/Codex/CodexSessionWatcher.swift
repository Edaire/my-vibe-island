import Dispatch
import Foundation
import MyVibeIslandShared

public protocol CodexSessionWatchCancellation: Sendable {
    func cancel()
}

public protocol CodexSessionWatchScheduling: Sendable {
    func schedule(
        every interval: TimeInterval,
        action: @escaping @Sendable () -> Void
    ) -> CodexSessionWatchCancellation
}

public struct CodexSessionWatcherTiming: Equatable, Sendable {
    public let attentionFallbackInterval: TimeInterval
    public let idleFallbackInterval: TimeInterval

    public static let evidenceDefault = Self(
        attentionFallbackInterval: 1,
        idleFallbackInterval: 8
    )

    public init(attentionFallbackInterval: TimeInterval, idleFallbackInterval: TimeInterval) {
        self.attentionFallbackInterval = attentionFallbackInterval
        self.idleFallbackInterval = idleFallbackInterval
    }
}

public enum CodexWatcherTraceStage: String, Equatable, Sendable {
    case resolutionRequested = "writer.resolution_requested"
    case resolutionResolved = "writer.resolution_resolved"
    case admitted = "writer.admitted"
    case published = "writer.published"
    case rejected = "writer.rejected"
}

public struct CodexWatcherTraceEvent: Equatable, Sendable {
    public let stage: CodexWatcherTraceStage
    public let rolloutPath: String
    public let inode: UInt64?
    public let sessionId: String?
    public let writerInfo: CodexWriterInfo?
    public let publishedEventCount: Int?

    public init(
        stage: CodexWatcherTraceStage,
        rolloutPath: String,
        inode: UInt64?,
        sessionId: String? = nil,
        writerInfo: CodexWriterInfo? = nil,
        publishedEventCount: Int? = nil
    ) {
        self.stage = stage
        self.rolloutPath = rolloutPath
        self.inode = inode
        self.sessionId = sessionId
        self.writerInfo = writerInfo
        self.publishedEventCount = publishedEventCount
    }
}

public final class CodexSessionWatcher: @unchecked Sendable {
    public static let fastPollInterval: TimeInterval = 2
    public static let activeFileTimeout: TimeInterval = 300
    public static let tombstoneTTL: TimeInterval = 600
    public static let maximumBytesPerPoll: UInt64 = 262_144
    public static let maximumBootstrapBytes: UInt64 = 8 * 1_024 * 1_024
    private static let maximumInitialPromptBootstrapBytes: UInt64 = 4 * 1_024 * 1_024
    private static let maximumSubagentMetadataProbeBytes: UInt64 = 64 * 1_024
    public static let maximumFallbackRecords = 256
    private static let largeRolloutBootstrapThreshold = maximumBytesPerPoll
    private static let digestChunkSize = 65_536
    private static let digestOffsetBasis: UInt64 = 14_695_981_039_346_656_037
    private static let digestPrime: UInt64 = 1_099_511_628_211

    private let lock = NSCondition()
    private let pipelineQueue = DispatchQueue(label: "my-vibe-island.codex-session-watcher.pipeline")
    private let pipelineQueueKey = DispatchSpecificKey<UInt8>()
    private let discovery: CodexSessionDiscovery
    private let liveDiscovery: (@Sendable () -> [CodexDiscoveredRolloutFile])?
    private let scheduler: CodexSessionWatchScheduling
    private let discoveryObserver: CodexSessionDiscoveryObserving
    private let now: @Sendable () -> Date
    private let timing: CodexSessionWatcherTiming
    private let discoveryPollInterval: TimeInterval
    private let scheduleInitialPoll: @Sendable (@escaping @Sendable () -> Void) -> Void
    private let admissionLedgerURL: URL
    private let requiresLiveWriterForNewSession: Bool
    private let writerInfoResolver: @Sendable (
        CodexDiscoveredRolloutFile,
        @escaping @Sendable (CodexWriterInfo) -> Void
    ) -> Void
    private let writerTrace: @Sendable (CodexWatcherTraceEvent) -> Void
    private let eventHandler: @Sendable (AgentEvent) -> Void

    private var isWatching = false
    private var isFastPollRunning = false
    private var isSlowPollRunning = false
    private var generation: UInt64 = 0
    private var pollInterval = CodexSessionWatcher.fastPollInterval
    private var lastWriteTime = Date.distantPast
    private var fastCancellation: CodexSessionWatchCancellation?
    private var slowCancellation: CodexSessionWatchCancellation?
    private var discoveryCancellation: CodexSessionWatchCancellation?
    private var fileStates: [String: CodexRolloutFileState] = [:]
    private var snapshots: [String: CodexRolloutSnapshot] = [:]
    private var publishedSnapshots: [String: CodexRolloutSnapshot] = [:]
    private var activeSessionFiles: Set<String> = []
    private var fileLastActivityAt: [String: Date] = [:]
    private var scanRejectionTombstones: [String: ScanRejectionTombstone] = [:]
    private var writerInfoCache: [String: WriterInfoCacheEntry] = [:]
    private var pendingWriterInfoInodes: [String: UInt64?] = [:]
    private var attentionTimers: [String: CodexSessionWatchCancellation] = [:]
    private var idleTimers: [String: CodexSessionWatchCancellation] = [:]
    private var idleFallbackContexts: [String: Date] = [:]
    private var idleFallbackRecoveries: [String: Date] = [:]
    private var attentionFallbackContexts: [String: Date] = [:]
    private var attentionFallbackRecoveries: [String: Date] = [:]

    public init(
        discovery: CodexSessionDiscovery = CodexSessionDiscovery(),
        liveDiscovery: (@Sendable () -> [CodexDiscoveredRolloutFile])? = nil,
        scheduler: CodexSessionWatchScheduling = DispatchCodexSessionWatchScheduler(),
        discoveryObserver: CodexSessionDiscoveryObserving = FSEventsCodexSessionDiscoveryObserver(),
        now: @escaping @Sendable () -> Date = Date.init,
        timing: CodexSessionWatcherTiming = .evidenceDefault,
        discoveryPollInterval: TimeInterval = 15 * 60,
        scheduleInitialPoll: @escaping @Sendable (@escaping @Sendable () -> Void) -> Void = {
            DispatchQueue.global(qos: .utility).async(execute: $0)
        },
        admissionLedgerURL: URL = SessionAdmissionLedger.defaultURL(),
        requiresLiveWriterForNewSession: Bool = false,
        writerInfoResolver: @escaping @Sendable (
            CodexDiscoveredRolloutFile,
            @escaping @Sendable (CodexWriterInfo) -> Void
        ) -> Void = { _, completion in
            completion(CodexWriterInfo(outcome: .unknown))
        },
        writerTrace: @escaping @Sendable (CodexWatcherTraceEvent) -> Void = { _ in },
        eventHandler: @escaping @Sendable (AgentEvent) -> Void
    ) {
        self.discovery = discovery
        self.liveDiscovery = liveDiscovery
        self.scheduler = scheduler
        self.discoveryObserver = discoveryObserver
        self.now = now
        self.timing = timing
        self.discoveryPollInterval = discoveryPollInterval
        self.scheduleInitialPoll = scheduleInitialPoll
        self.admissionLedgerURL = admissionLedgerURL
        self.requiresLiveWriterForNewSession = requiresLiveWriterForNewSession
        self.writerInfoResolver = writerInfoResolver
        self.writerTrace = writerTrace
        self.eventHandler = eventHandler
        pipelineQueue.setSpecific(key: pipelineQueueKey, value: 1)
    }

    deinit {
        stop()
    }

    public func start() {
        lock.lock()
        guard !isWatching else {
            lock.unlock()
            return
        }
        isWatching = true
        generation &+= 1
        pollInterval = Self.fastPollInterval
        lastWriteTime = now()
        fastCancellation = scheduler.schedule(every: pollInterval) { [weak self] in
            self?.pollFast()
        }
        slowCancellation = scheduler.schedule(every: discoveryPollInterval) { [weak self] in
            self?.pollSlow()
        }
        discoveryCancellation = discoveryObserver.observe(roots: discovery.roots) { [weak self] in
            self?.pollSlow()
        }
        lock.unlock()

        scheduleInitialPoll { [weak self] in
            self?.pollSlow()
        }
    }

    public func stop() {
        var cancellations: [CodexSessionWatchCancellation] = []
        lock.lock()
        guard isWatching else {
            lock.unlock()
            return
        }
        isWatching = false
        generation &+= 1
        let fastCancellation = self.fastCancellation
        let slowCancellation = self.slowCancellation
        let discoveryCancellation = self.discoveryCancellation
        self.fastCancellation = nil
        self.slowCancellation = nil
        self.discoveryCancellation = nil
        if let fastCancellation { cancellations.append(fastCancellation) }
        if let slowCancellation { cancellations.append(slowCancellation) }
        if let discoveryCancellation { cancellations.append(discoveryCancellation) }
        fileStates.removeAll()
        snapshots.removeAll()
        publishedSnapshots.removeAll()
        activeSessionFiles.removeAll()
        fileLastActivityAt.removeAll()
        scanRejectionTombstones.removeAll()
        writerInfoCache.removeAll()
        pendingWriterInfoInodes.removeAll()
        cancellations.append(contentsOf: attentionTimers.values)
        cancellations.append(contentsOf: idleTimers.values)
        attentionTimers.removeAll()
        idleTimers.removeAll()
        idleFallbackContexts.removeAll()
        idleFallbackRecoveries.removeAll()
        attentionFallbackContexts.removeAll()
        attentionFallbackRecoveries.removeAll()
        trimFallbackRecords()
        isFastPollRunning = false
        isSlowPollRunning = false
        lock.unlock()

        cancellations.forEach { $0.cancel() }
        if DispatchQueue.getSpecific(key: pipelineQueueKey) == nil {
            pipelineQueue.sync {}
        }
    }

    func fileState(for url: URL) -> CodexRolloutFileState? {
        lock.lock()
        defer { lock.unlock() }
        return fileStates[pathKey(url)]
    }

    var trackedFileCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return fileStates.count
    }

    var currentPollInterval: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return pollInterval
    }

    var attentionTimerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return attentionTimers.count
    }

    var attentionRecoveryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return attentionFallbackRecoveries.count
    }

    var idleContextCount: Int {
        lock.lock(); defer { lock.unlock() }
        return idleFallbackContexts.count
    }

    func attentionContextCount(for url: URL) -> Int {
        lock.lock(); defer { lock.unlock() }
        return attentionFallbackContexts[pathKey(url)] == nil ? 0 : 1
    }

    func recoveryCount(for url: URL) -> Int {
        lock.lock(); defer { lock.unlock() }
        let path = pathKey(url)
        return (attentionFallbackRecoveries[path] == nil ? 0 : 1)
            + (idleFallbackRecoveries[path] == nil ? 0 : 1)
    }

    func withFastPollGuardForTesting(_ body: () -> Void) {
        lock.lock()
        isFastPollRunning = true
        lock.unlock()
        body()
        lock.lock()
        isFastPollRunning = false
        lock.unlock()
    }

    func withSlowPollGuardForTesting(_ body: () -> Void) {
        lock.lock()
        isSlowPollRunning = true
        lock.unlock()
        body()
        lock.lock()
        isSlowPollRunning = false
        lock.unlock()
    }

    private func pollFast() {
        runOnPipeline { [weak self] in
            self?.performFastPoll()
        }
    }

    private func performFastPoll() {
        lock.lock()
        guard isWatching, !isFastPollRunning else {
            lock.unlock()
            return
        }
        isFastPollRunning = true
        let pollGeneration = generation
        let paths = Array(activeSessionFiles)
        let files = paths.compactMap { discovery.file(at: URL(fileURLWithPath: $0)) }
        var cancellations: [CodexSessionWatchCancellation] = []
        let events = refresh(files: files, cancellations: &cancellations)
        rescheduleFastTimerIfNeeded(cancellations: &cancellations)
        isFastPollRunning = false
        lock.unlock()
        cancellations.forEach { $0.cancel() }
        publishInPipeline(events, generation: pollGeneration)
    }

    private func pollSlow() {
        runOnPipeline { [weak self] in
            self?.performSlowPoll()
        }
    }

    private func performSlowPoll() {
        lock.lock()
        guard isWatching, !isSlowPollRunning else {
            lock.unlock()
            return
        }
        isSlowPollRunning = true
        let pollGeneration = generation
        var cancellations: [CodexSessionWatchCancellation] = []
        let pollDate = now()
        let discoveredFiles = liveDiscovery?() ?? discovery.discover()
        let discoveredPaths = Set(discoveredFiles.map { pathKey($0.url) })
        for path in Array(activeSessionFiles) where !discoveredPaths.contains(path) {
            removeTrackedFile(path, cancellations: &cancellations)
        }
        expireScanRejectionTombstones(now: pollDate)
        let files = discoveredFiles.filter {
            shouldScan(
                $0,
                now: pollDate,
                isLiveProcessBacked: liveDiscovery != nil
            )
        }
        let events = refresh(files: files, cancellations: &cancellations)
        pruneInactiveFiles(now: pollDate, cancellations: &cancellations)
        isSlowPollRunning = false
        lock.unlock()
        cancellations.forEach { $0.cancel() }
        publishInPipeline(events, generation: pollGeneration)
    }

    private func refresh(
        files: [CodexDiscoveredRolloutFile],
        cancellations: inout [CodexSessionWatchCancellation]
    ) -> [AgentEvent] {
        var events: [AgentEvent] = []
        for file in files {
            events.append(contentsOf: refresh(file: file, cancellations: &cancellations))
        }
        return events
    }

    private func refresh(file: CodexDiscoveredRolloutFile, cancellations: inout [CodexSessionWatchCancellation]) -> [AgentEvent] {
        let path = pathKey(file.url)
        // Writer/process resolution is supplemental evidence. A restored
        // rollout must still publish while lsof/ps is pending or unavailable;
        // only an explicitly resolved denied ancestor is an admission veto.
        let writerInfo = writerInfo(for: file)
        if let writerInfo, writerInfo.isAdmissionDenied {
            traceWriter(.rejected, file: file, writerInfo: writerInfo)
            recordWriterAdmissionRejection(writerInfo, for: file)
            scanRejectionTombstones[path] = ScanRejectionTombstone(
                inode: file.inode,
                size: file.size,
                rejectedAt: now()
            )
            removeTrackedFile(path, cancellations: &cancellations)
            return []
        }
        activeSessionFiles.insert(path)
        if fileLastActivityAt[path] == nil {
            fileLastActivityAt[path] = now()
        }
        var state = fileStates[path] ?? CodexRolloutFileState(inode: file.inode)
        var snapshot = snapshots[path] ?? CodexRolloutSnapshot()
        snapshot.codexRolloutPath = file.url.path

        if state.inode != file.inode || file.size < state.offset || consumedDigestChanged(file: file, state: state) {
            state = CodexRolloutFileState(inode: file.inode)
            snapshot = CodexRolloutSnapshot()
            snapshot.codexRolloutPath = file.url.path
            cancelFallbacks(for: path, cancellations: &cancellations)
        }

        if state.offset == 0,
           let initial = read(
               file.url,
               from: 0,
               count: min(file.size, Self.maximumSubagentMetadataProbeBytes)
           ),
           CodexSubagentBootstrapGate.resolve(initialData: initial.data) == .skipInheritedHistory {
            consumeFirstSessionMetadata(from: initial.data, snapshot: &snapshot)

            state.offset = initial.size
            state.size = initial.size
            state.inode = initial.inode ?? file.inode
            state.modificationDate = initial.modificationDate
            state.remainder = Data()
            // The inherited prefix is deliberately unparsed. Do not compare a
            // digest for it on later appends, or the watcher will replay it.
            state.isTailBootstrapped = true
            fileStates[path] = state
            snapshots[path] = snapshot
            fileLastActivityAt[path] = now()
            return []
        }

        if state.offset == 0,
           file.size > Self.largeRolloutBootstrapThreshold,
           let head = read(
               file.url,
               from: 0,
               count: min(file.size, Self.maximumInitialPromptBootstrapBytes)
           ),
           let tail = read(
               file.url,
               from: file.size - min(file.size, Self.maximumBootstrapBytes),
               count: min(file.size, Self.maximumBootstrapBytes)
           ) {
            var headBuffer = head.data
            consumeLines(from: &headBuffer, snapshot: &snapshot)
            var tailBuffer = tail.data
            consumeLines(from: &tailBuffer, snapshot: &snapshot)

            state.offset = file.size
            state.size = file.size
            state.inode = file.inode
            state.modificationDate = tail.modificationDate
            state.remainder = tailBuffer
            state.isTailBootstrapped = true
            fileStates[path] = state
            snapshots[path] = snapshot
            fileLastActivityAt[path] = now()
            lastWriteTime = now()
            updateFallbackScheduling(
                for: path,
                snapshot: snapshot,
                generation: generation,
                cancellations: &cancellations
            )

            let oldSnapshot = publishedSnapshots[path]
            guard mayPublish(snapshot: snapshot, previous: oldSnapshot, writerInfo: writerInfo) else {
                return []
            }
            let events = CodexRolloutReducer.agentEvents(from: oldSnapshot, to: snapshot)
            if !events.isEmpty {
                publishedSnapshots[path] = snapshot
                traceWriter(.admitted, file: file, sessionId: snapshot.sessionId, writerInfo: writerInfo)
                traceWriter(
                    .published,
                    file: file,
                    sessionId: snapshot.sessionId,
                    writerInfo: writerInfo,
                    publishedEventCount: events.count
                )
            }
            return events
        }

        guard file.size > state.offset else {
            fileStates[path] = state
            snapshots[path] = snapshot
            let oldSnapshot = publishedSnapshots[path]
            if mayPublish(snapshot: snapshot, previous: oldSnapshot, writerInfo: writerInfo) {
                let events = CodexRolloutReducer.agentEvents(from: oldSnapshot, to: snapshot)
                if !events.isEmpty {
                    publishedSnapshots[path] = snapshot
                    traceWriter(.admitted, file: file, sessionId: snapshot.sessionId, writerInfo: writerInfo)
                    traceWriter(
                        .published,
                        file: file,
                        sessionId: snapshot.sessionId,
                        writerInfo: writerInfo,
                        publishedEventCount: events.count
                    )
                    return events
                }
            }
            return []
        }

        let count = min(file.size - state.offset, Self.maximumBytesPerPoll)
        guard let result = read(file.url, from: state.offset, count: count),
              result.inode == file.inode,
              result.size >= state.offset else {
            return []
        }

        let bytesRead = UInt64(result.data.count)
        guard bytesRead > 0 else { return [] }
        state.offset += bytesRead
        state.size = state.offset
        state.inode = file.inode
        state.consumedDigest = updateDigest(state.consumedDigest, with: result.data)
        state.modificationDate = result.modificationDate
        fileLastActivityAt[path] = now()
        var buffer = state.remainder
        buffer.append(result.data)

        if state.discardingOversizedLine {
            guard let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) else {
                state.remainder = Data()
                fileStates[path] = state
                snapshots[path] = snapshot
                return []
            }
            buffer.removeSubrange(...newline)
            state.discardingOversizedLine = false
        }

        consumeLines(from: &buffer, snapshot: &snapshot)

        if buffer.count > CodexRolloutFileState.maximumRemainderSize {
            state.remainder = Data()
            state.discardingOversizedLine = true
        } else {
            state.remainder = buffer
        }

        fileStates[path] = state
        snapshots[path] = snapshot
        lastWriteTime = now()
        updateFallbackScheduling(for: path, snapshot: snapshot, generation: generation, cancellations: &cancellations)

        let oldSnapshot = publishedSnapshots[path]
        guard mayPublish(snapshot: snapshot, previous: oldSnapshot, writerInfo: writerInfo) else {
            return []
        }
        let events = CodexRolloutReducer.agentEvents(from: oldSnapshot, to: snapshot)
        if !events.isEmpty {
            publishedSnapshots[path] = snapshot
            traceWriter(.admitted, file: file, sessionId: snapshot.sessionId, writerInfo: writerInfo)
            traceWriter(
                .published,
                file: file,
                sessionId: snapshot.sessionId,
                writerInfo: writerInfo,
                publishedEventCount: events.count
            )
        }
        return events
    }

    /// A rollout is content evidence, not session liveness evidence. In the
    /// production configuration, only a process currently writing that file
    /// may create the first top-level card. Existing hook-admitted sessions
    /// continue to receive watcher enrichment after the writer exits.
    private func mayPublish(
        snapshot: CodexRolloutSnapshot,
        previous: CodexRolloutSnapshot?,
        writerInfo: CodexWriterInfo?
    ) -> Bool {
        guard snapshot.sessionId != nil else { return false }
        guard requiresLiveWriterForNewSession, previous == nil else { return true }
        return writerInfo?.outcome == .matched
            && writerInfo?.pid != nil
            && writerInfo?.tty != nil
    }

    private func shouldScan(
        _ file: CodexDiscoveredRolloutFile,
        now: Date,
        isLiveProcessBacked: Bool = false
    ) -> Bool {
        let path = pathKey(file.url)
        if !activeSessionFiles.contains(path),
           !isLiveProcessBacked,
           let modificationDate = file.modificationDate,
           now.timeIntervalSince(modificationDate) >= Self.activeFileTimeout {
            return false
        }
        guard !activeSessionFiles.contains(path), let tombstone = scanRejectionTombstones[path] else {
            return true
        }
        if now.timeIntervalSince(tombstone.rejectedAt) >= Self.tombstoneTTL
            || tombstone.inode != file.inode
            || tombstone.size != file.size {
            scanRejectionTombstones.removeValue(forKey: path)
            return true
        }
        return false
    }

    private func expireScanRejectionTombstones(now: Date) {
        for path in Array(scanRejectionTombstones.keys) {
            guard let tombstone = scanRejectionTombstones[path] else { continue }
            if now.timeIntervalSince(tombstone.rejectedAt) >= Self.tombstoneTTL {
                scanRejectionTombstones.removeValue(forKey: path)
            }
        }
    }

    private func pruneInactiveFiles(
        now: Date,
        cancellations: inout [CodexSessionWatchCancellation]
    ) {
        for path in Array(activeSessionFiles) {
            guard let lastActivity = fileLastActivityAt[path] else { continue }
            if now.timeIntervalSince(lastActivity) >= Self.activeFileTimeout {
                if let file = discovery.file(at: URL(fileURLWithPath: path)) {
                    scanRejectionTombstones[path] = ScanRejectionTombstone(
                        inode: file.inode,
                        size: file.size,
                        rejectedAt: now
                    )
                }
                removeTrackedFile(path, cancellations: &cancellations)
            }
        }
    }

    private func removeTrackedFile(
        _ path: String,
        cancellations: inout [CodexSessionWatchCancellation]
    ) {
        activeSessionFiles.remove(path)
        fileLastActivityAt.removeValue(forKey: path)
        fileStates.removeValue(forKey: path)
        snapshots.removeValue(forKey: path)
        publishedSnapshots.removeValue(forKey: path)
        writerInfoCache.removeValue(forKey: path)
        pendingWriterInfoInodes.removeValue(forKey: path)
        removeFallbacks(for: path, cancellations: &cancellations)
    }

    private func writerInfo(for file: CodexDiscoveredRolloutFile) -> CodexWriterInfo? {
        let path = pathKey(file.url)
        if let cached = writerInfoCache[path],
           cached.inode == file.inode,
           now().timeIntervalSince(cached.cachedAt) < cached.timeToLive {
            return cached.info
        }
        if pendingWriterInfoInodes[path] == file.inode {
            return nil
        }

        pendingWriterInfoInodes[path] = file.inode
        traceWriter(.resolutionRequested, file: file)
        let resolution = WriterInfoResolutionBox()
        writerInfoResolver(file) { [weak self] info in
            self?.traceWriter(.resolutionResolved, file: file, writerInfo: info)
            resolution.offer(info)
            guard let watcher = self else { return }
            // Writer resolution runs on a utility worker and may complete while
            // the pipeline is inside a slow ps/lsof poll. Never synchronously
            // re-enter that pipeline here: one callback per rollout would
            // otherwise consume a dispatch thread until the slow poll exits.
            watcher.pipelineQueue.async { [weak watcher] in
                watcher?.cacheWriterInfo(info, for: file)
            }
        }
        if let info = resolution.take() {
            pendingWriterInfoInodes.removeValue(forKey: path)
            writerInfoCache[path] = WriterInfoCacheEntry(info: info, inode: file.inode, cachedAt: now())
            return info
        }
        return nil
    }

    private func recordWriterAdmissionRejection(
        _ writerInfo: CodexWriterInfo,
        for file: CodexDiscoveredRolloutFile
    ) {
        guard let deniedBundleId = writerInfo.admissionDeniedAncestorBundleId,
              let handle = try? FileHandle(forReadingFrom: file.url) else {
            return
        }
        defer { try? handle.close() }
        guard let data = try? handle.read(
            upToCount: Int(min(file.size, Self.maximumInitialPromptBootstrapBytes))
        ) else {
            return
        }
        let snapshot = CodexRolloutReducer.snapshot(
            for: String(decoding: data, as: UTF8.self)
                .split(whereSeparator: \.isNewline)
                .map(String.init)
        )
        guard let sessionId = snapshot.sessionId else { return }
        try? SessionAdmissionLedger.record(
            sessionId: CodexSessionIdentity.prefixed(sessionId),
            evidence: SessionAdmissionEvidence(
                cwd: snapshot.cwd,
                bundleIdentifiers: [deniedBundleId]
            ),
            rejection: .ancestorBundle(deniedBundleId),
            to: admissionLedgerURL,
            now: now()
        )
    }

    private func cacheWriterInfo(_ info: CodexWriterInfo, for file: CodexDiscoveredRolloutFile) {
        lock.lock()
        let path = pathKey(file.url)
        guard isWatching, pendingWriterInfoInodes[path] == file.inode else {
            lock.unlock()
            return
        }
        pendingWriterInfoInodes.removeValue(forKey: path)
        writerInfoCache[path] = WriterInfoCacheEntry(info: info, inode: file.inode, cachedAt: now())
        lock.unlock()
        pollSlow()
    }

    private func traceWriter(
        _ stage: CodexWatcherTraceStage,
        file: CodexDiscoveredRolloutFile,
        sessionId: String? = nil,
        writerInfo: CodexWriterInfo? = nil,
        publishedEventCount: Int? = nil
    ) {
        writerTrace(CodexWatcherTraceEvent(
            stage: stage,
            rolloutPath: file.url.path,
            inode: file.inode,
            sessionId: sessionId,
            writerInfo: writerInfo,
            publishedEventCount: publishedEventCount
        ))
    }

    private func updateFallbackScheduling(
        for path: String,
        snapshot: CodexRolloutSnapshot,
        generation: UInt64,
        cancellations: inout [CodexSessionWatchCancellation]
    ) {
        if snapshot.status == .waiting || snapshot.needsAttention {
            cancelIdleFallback(for: path, cancellations: &cancellations)
            if attentionTimers[path] == nil,
               activeFallbackCount < Self.maximumFallbackRecords {
                let startedAt = now()
                attentionFallbackContexts[path] = startedAt
                attentionTimers[path] = scheduler.schedule(every: timing.attentionFallbackInterval) { [weak self] in
                    self?.fireAttentionFallback(path: path, generation: generation)
                }
            }
            return
        }

        cancelAttentionFallback(for: path, cancellations: &cancellations)
        if snapshot.status == .idle, snapshot.sessionId != nil {
            if idleTimers[path] == nil,
               activeFallbackCount < Self.maximumFallbackRecords {
                idleFallbackContexts[path] = now()
                idleTimers[path] = scheduler.schedule(every: timing.idleFallbackInterval) { [weak self] in
                    self?.fireIdleFallback(path: path, generation: generation)
                }
            }
        } else {
            cancelIdleFallback(for: path, cancellations: &cancellations)
        }
    }

    private func fireIdleFallback(path: String, generation: UInt64) {
        fireFallback(path: path, generation: generation, require: .idle)
    }

    private func fireAttentionFallback(path: String, generation: UInt64) {
        fireFallback(path: path, generation: generation, require: .waiting)
    }

    private func fireFallback(
        path: String,
        generation: UInt64,
        require status: SessionStatus
    ) {
        runOnPipeline { [weak self] in
            self?.performFallback(path: path, generation: generation, require: status)
        }
    }

    private func performFallback(
        path: String,
        generation: UInt64,
        require status: SessionStatus
    ) {
        lock.lock()
        guard isWatching, self.generation == generation, let snapshot = snapshots[path], snapshot.status == status else {
            lock.unlock()
            return
        }

        // An idle snapshot is not terminal while Codex still owns the rollout.
        // A turn can publish intermediate assistant/tool output and briefly
        // return to idle before its real task_complete event. Do not promote
        // that state through the fallback while writer evidence is live or
        // still being resolved.
        let writerIsPending = pendingWriterInfoInodes[path] != nil
        let writerIsLive = writerInfoCache[path].map { entry in
            entry.inode == fileStates[path]?.inode
                && entry.info.outcome == .matched
                && now().timeIntervalSince(entry.cachedAt) < entry.timeToLive
        } ?? false
        guard !writerIsPending, !writerIsLive else {
            lock.unlock()
            return
        }

        let completed = CodexRolloutReducer.completionFallback(from: snapshot)
        snapshots[path] = completed
        var cancellations: [CodexSessionWatchCancellation] = []
        cancelFallbacks(for: path, cancellations: &cancellations)
        let events = CodexRolloutReducer.agentEvents(from: publishedSnapshots[path], to: completed)
        if !events.isEmpty {
            publishedSnapshots[path] = completed
        }
        lock.unlock()
        cancellations.forEach { $0.cancel() }
        publishInPipeline(events, generation: generation)
    }

    private func cancelFallbacks(for path: String, cancellations: inout [CodexSessionWatchCancellation]) {
        cancelAttentionFallback(for: path, cancellations: &cancellations)
        cancelIdleFallback(for: path, cancellations: &cancellations)
    }

    private func removeFallbacks(for path: String, cancellations: inout [CodexSessionWatchCancellation]) {
        if let attention = attentionTimers.removeValue(forKey: path) { cancellations.append(attention) }
        if let idle = idleTimers.removeValue(forKey: path) { cancellations.append(idle) }
        attentionFallbackContexts.removeValue(forKey: path)
        idleFallbackContexts.removeValue(forKey: path)
        attentionFallbackRecoveries.removeValue(forKey: path)
        idleFallbackRecoveries.removeValue(forKey: path)
    }

    private func cancelAttentionFallback(for path: String, cancellations: inout [CodexSessionWatchCancellation]) {
        if let cancellation = attentionTimers.removeValue(forKey: path) {
            cancellations.append(cancellation)
        }
        if attentionFallbackContexts.removeValue(forKey: path) != nil {
            attentionFallbackRecoveries[path] = now()
        }
        trimFallbackRecords()
    }

    private func cancelIdleFallback(for path: String, cancellations: inout [CodexSessionWatchCancellation]) {
        if let cancellation = idleTimers.removeValue(forKey: path) {
            cancellations.append(cancellation)
        }
        if idleFallbackContexts.removeValue(forKey: path) != nil {
            idleFallbackRecoveries[path] = now()
        }
        trimFallbackRecords()
    }

    private func rescheduleFastTimerIfNeeded(cancellations: inout [CodexSessionWatchCancellation]) {
        let age = max(0, now().timeIntervalSince(lastWriteTime))
        let next: TimeInterval
        if age < 5 {
            next = 2
        } else if age < 30 {
            next = 5
        } else {
            next = 15
        }
        guard next != pollInterval else { return }
        pollInterval = next
        if let old = fastCancellation {
            cancellations.append(old)
        }
        fastCancellation = nil
        guard isWatching else { return }
        fastCancellation = scheduler.schedule(every: next) { [weak self] in
            self?.pollFast()
        }
    }

    private func runOnPipeline(_ work: @escaping @Sendable () -> Void) {
        if DispatchQueue.getSpecific(key: pipelineQueueKey) != nil {
            pipelineQueue.async(execute: work)
        } else {
            pipelineQueue.sync(execute: work)
        }
    }

    private func publishInPipeline(_ events: [AgentEvent], generation: UInt64) {
        for event in events {
            lock.lock()
            let allowed = isWatching && self.generation == generation
            lock.unlock()
            guard allowed else { return }
            eventHandler(event)
        }
    }

    private struct ReadResult {
        let data: Data
        let size: UInt64
        let inode: UInt64?
        let modificationDate: Date?
    }

    private struct WriterInfoCacheEntry {
        let info: CodexWriterInfo
        let inode: UInt64?
        let cachedAt: Date

        // V3 retains its positive writer lookup outcome for 30 seconds and
        // retries all other outcomes after 2 seconds; it also rejects cache
        // reuse when the rollout inode changes.
        var timeToLive: TimeInterval {
            info.outcome == .matched ? 30 : 2
        }
    }

    private final class WriterInfoResolutionBox: @unchecked Sendable {
        private let lock = NSLock()
        private var resolvedInfo: CodexWriterInfo?

        func offer(_ info: CodexWriterInfo) {
            lock.lock()
            resolvedInfo = info
            lock.unlock()
        }

        func take() -> CodexWriterInfo? {
            lock.lock()
            defer { lock.unlock() }
            return resolvedInfo
        }
    }

    private func read(_ url: URL, from offset: UInt64, count: UInt64) -> ReadResult? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: offset)
            guard count <= UInt64(Int.max) else { return nil }
            let data = try handle.read(upToCount: Int(count)) ?? Data()
            let metadata = discovery.file(at: url)
            return ReadResult(
                data: data,
                size: metadata?.size ?? 0,
                inode: metadata?.inode,
                modificationDate: metadata?.modificationDate
            )
        } catch {
            return nil
        }
    }

    private var activeFallbackCount: Int {
        attentionTimers.count + idleTimers.count
    }

    private func consumedDigestChanged(file: CodexDiscoveredRolloutFile, state: CodexRolloutFileState) -> Bool {
        guard state.offset > 0 else { return false }
        guard !state.isTailBootstrapped else { return false }
        guard file.size != state.size || file.modificationDate != state.modificationDate else { return false }
        guard let current = digest(file.url, count: state.offset, expectedInode: file.inode) else { return true }
        return current != state.consumedDigest
    }

    private func digest(_ url: URL, count: UInt64, expectedInode: UInt64?) -> UInt64? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            var remaining = count
            var result = Self.digestOffsetBasis
            while remaining > 0 {
                let chunkCount = min(remaining, UInt64(Self.digestChunkSize))
                guard chunkCount <= UInt64(Int.max) else { return nil }
                let data = try handle.read(upToCount: Int(chunkCount)) ?? Data()
                guard !data.isEmpty else { return nil }
                result = updateDigest(result, with: data)
                remaining -= UInt64(data.count)
            }
            guard let metadata = discovery.file(at: url),
                  metadata.inode == expectedInode,
                  metadata.size >= count else { return nil }
            return result
        } catch {
            return nil
        }
    }

    private func updateDigest(_ digest: UInt64, with data: Data) -> UInt64 {
        data.reduce(into: digest) { result, byte in
            result ^= UInt64(byte)
            result &*= Self.digestPrime
        }
    }

    private func consumeLines(from buffer: inout Data, snapshot: inout CodexRolloutSnapshot) {
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer.prefix(upTo: newline)
            buffer.removeSubrange(...newline)
            if !line.isEmpty && line.count <= CodexRolloutFileState.maximumRemainderSize {
                CodexRolloutReducer.apply(line: String(decoding: line, as: UTF8.self), to: &snapshot)
            }
        }
    }

    private func consumeFirstSessionMetadata(from data: Data, snapshot: inout CodexRolloutSnapshot) {
        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard
                !line.isEmpty,
                line.count <= CodexRolloutFileState.maximumRemainderSize,
                let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                object["type"] as? String == "session_meta"
            else {
                continue
            }
            CodexRolloutReducer.apply(line: String(decoding: line, as: UTF8.self), to: &snapshot)
            return
        }
    }

    private func trimFallbackRecords() {
        while attentionFallbackRecoveries.count + idleFallbackRecoveries.count > Self.maximumFallbackRecords {
            if let key = attentionFallbackRecoveries.keys.first {
                attentionFallbackRecoveries.removeValue(forKey: key)
            } else if let key = idleFallbackRecoveries.keys.first {
                idleFallbackRecoveries.removeValue(forKey: key)
            } else {
                break
            }
        }
    }

    private func pathKey(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private struct ScanRejectionTombstone {
        let inode: UInt64?
        let size: UInt64
        let rejectedAt: Date
    }
}

public final class DispatchCodexSessionWatchScheduler: CodexSessionWatchScheduling, @unchecked Sendable {
    private let queue: DispatchQueue

    public init(queue: DispatchQueue = DispatchQueue(label: "my-vibe-island.codex-session-watcher")) {
        self.queue = queue
    }

    public func schedule(
        every interval: TimeInterval,
        action: @escaping @Sendable () -> Void
    ) -> CodexSessionWatchCancellation {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler(handler: action)
        timer.resume()
        return DispatchCodexSessionWatchCancellation(timer: timer)
    }
}

private final class DispatchCodexSessionWatchCancellation: CodexSessionWatchCancellation, @unchecked Sendable {
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?

    init(timer: DispatchSourceTimer) {
        self.timer = timer
    }

    func cancel() {
        lock.lock()
        let timer = self.timer
        self.timer = nil
        lock.unlock()
        timer?.cancel()
    }
}
