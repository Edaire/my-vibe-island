import Foundation

public struct ClaudeCoworkWatcherTiming: Equatable, Sendable {
    public let pollInterval: TimeInterval
    public let maximumAuditBytes: UInt64
    public let inactivityTimeout: TimeInterval

    public init(
        pollInterval: TimeInterval = 1.0,
        maximumAuditBytes: UInt64 = 262_144,
        inactivityTimeout: TimeInterval = 30.0
    ) {
        self.pollInterval = max(0.01, pollInterval)
        self.maximumAuditBytes = maximumAuditBytes
        self.inactivityTimeout = max(0, inactivityTimeout)
    }
}

public final class ClaudeCoworkWatcher: @unchecked Sendable {
    private struct Track {
        let result: ClaudeCoworkAuditResult
        let cwd: String
    }

    private let discovery: ClaudeCoworkSessionDiscovery
    private let timing: ClaudeCoworkWatcherTiming
    private let tailReader: ClaudeCoworkAuditTailReader
    private let now: @Sendable () -> Date
    private let queue: DispatchQueue
    private let stateLock = NSLock()
    private let eventHandler: (@Sendable (AgentEvent) -> Void)?
    private var tracks: [String: Track] = [:]
    private var timer: DispatchSourceTimer?

    public init(
        discovery: ClaudeCoworkSessionDiscovery,
        timing: ClaudeCoworkWatcherTiming = ClaudeCoworkWatcherTiming(),
        tailReader: ClaudeCoworkAuditTailReader = ClaudeCoworkAuditTailReader(),
        queue: DispatchQueue = DispatchQueue(label: "my-vibe-island.claude-cowork-watcher"),
        now: @escaping @Sendable () -> Date = Date.init,
        eventHandler: (@Sendable (AgentEvent) -> Void)? = nil
    ) {
        self.discovery = discovery
        self.timing = timing
        self.tailReader = tailReader
        self.queue = queue
        self.now = now
        self.eventHandler = eventHandler
    }

    public func refresh() throws -> [AgentEvent] {
        let files = discovery.discover()
        var events: [AgentEvent] = []

        stateLock.lock()
        defer { stateLock.unlock() }

        for file in files {
            if file.metadata.isArchived {
                if tracks.removeValue(forKey: file.sessionId) != nil {
                    events.append(.sessionEnded(
                        source: "claude",
                        sessionId: coworkSessionId(for: file)
                    ))
                }
                continue
            }
            guard FileManager.default.fileExists(atPath: file.auditLogURL.path) else { continue }
            guard let text = try? tailReader.read(from: file.auditLogURL, maximumBytes: timing.maximumAuditBytes) else {
                continue
            }

            var result = ClaudeCoworkAuditResult()
            for line in text.split(whereSeparator: \ .isNewline) {
                guard let row = try? ClaudeCoworkAuditRow.decode(from: Data(line.utf8)) else { continue }
                ClaudeCoworkAuditReducer.apply(row: row, to: &result)
            }
            guard result.hasAnyTurn else { continue }

            let cwd = file.metadata.cwd ?? discovery.rootURL.path
            let oldTrack = tracks[file.sessionId]
            guard oldTrack?.result != result else { continue }
            tracks[file.sessionId] = Track(result: result, cwd: cwd)

            if oldTrack == nil {
                events.append(.sessionStarted(
                    source: "claude",
                    sessionId: coworkSessionId(for: file),
                    cwd: cwd
                ))
            }
            events.append(.sessionActivityUpdated(
                source: "claude",
                sessionId: coworkSessionId(for: file),
                activity: activity(
                    for: result,
                    title: file.metadata.title,
                    cliSessionId: file.metadata.cliSessionId,
                    cwd: cwd,
                    fileModificationDate: file.auditLogModificationDate
                )
            ))
        }

        return events
    }

    public func start() {
        stateLock.lock()
        guard timer == nil else {
            stateLock.unlock()
            return
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: timing.pollInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            guard let events = try? self.refresh() else { return }
            events.forEach { self.eventHandler?($0) }
        }
        self.timer = timer
        stateLock.unlock()
        timer.resume()
    }

    public func stop() {
        stateLock.lock()
        let timer = self.timer
        self.timer = nil
        stateLock.unlock()
        timer?.setEventHandler {}
        timer?.cancel()
    }

    public var isRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return timer != nil
    }

    private func coworkSessionId(for file: ClaudeCoworkSessionFile) -> String {
        "cowork-\(file.sessionId)"
    }

    private func activity(
        for result: ClaudeCoworkAuditResult,
        title: String,
        cliSessionId: String?,
        cwd: String,
        fileModificationDate: Date?
    ) -> SessionActivityUpdate {
        let effectiveTimestamp = result.latestTimestamp ?? fileModificationDate
        let isStale = effectiveTimestamp.map {
            now().timeIntervalSince($0) > timing.inactivityTimeout
        } ?? true
        let status: SessionStatus
        let originalStatus: OriginalPixelStatusCompact
        if result.pendingQuestionInput != nil {
            status = .waiting
            originalStatus = .question
        } else if result.lastTurnType == "result" || isStale {
            status = .idle
            originalStatus = .waitingForInput
        } else {
            status = .active
            originalStatus = .processing
        }

        let summary = result.lastAssistantMessage ?? result.lastUserMessage
        let questionToolInput: [String: BridgeJSONValue]?
        if case let .object(input) = result.pendingQuestionInput {
            questionToolInput = input
        } else {
            questionToolInput = nil
        }
        return SessionActivityUpdate(
            status: status,
            summary: summary,
            originalStatus: originalStatus,
            safeTitle: title,
            cliSessionId: cliSessionId,
            activeTool: questionToolInput == nil ? nil : "AskUserQuestion",
            toolInput: questionToolInput,
            lastAssistantMessage: result.lastAssistantMessage,
            updatedAt: effectiveTimestamp,
            lastUserMessage: result.lastUserMessage,
            needsAttention: result.pendingQuestionInput != nil,
            hasUnreadCompletion: false,
            cwd: cwd
        )
    }
}
