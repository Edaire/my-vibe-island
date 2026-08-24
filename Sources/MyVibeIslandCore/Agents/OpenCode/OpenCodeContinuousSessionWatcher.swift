import Foundation

public enum OpenCodeContinuousSessionTransition: Equatable, Sendable {
    case changed(path: String)
    case archived(path: String)
    case deleted(path: String)
}

public final class OpenCodeContinuousSessionWatcher: @unchecked Sendable {
    public static let defaultRelativeRoot = ".local/share/opencode/storage/session"
    public static let defaultMaximumVisitedEntries = 4_096
    public static let maximumSnapshotBytes = 1_048_576
    public let rootURL: URL
    public var lastTransitions: [OpenCodeContinuousSessionTransition] {
        onSyncQueue { storedLastTransitions }
    }

    private let fileManager: FileManager
    private let dataReader: OpenCodeSessionDataReading
    private let scheduler: CodexSessionWatchScheduling
    private let eventHandler: @Sendable (AgentEvent) -> Void
    private let lifecycleLock = NSLock()
    private let syncQueue = DispatchQueue(label: "my-vibe-island.opencode-continuous-session-watcher.sync")
    private let syncQueueKey = DispatchSpecificKey<UInt8>()
    private let maximumFileCount: Int
    private let maximumDepth: Int
    private let maximumVisitedEntries: Int
    private let maximumSnapshotBytes: Int
    private var fingerprints: [String: String] = [:]
    private var sessionIDsByPath: [String: String] = [:]
    private var endedPaths: Set<String> = []
    private var storedLastTransitions: [OpenCodeContinuousSessionTransition] = []
    private var timer: CodexSessionWatchCancellation?
    private var isRunning = false
    private var generation: UInt64 = 0

    public init(
        rootURL: URL? = nil,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default,
        dataReader: OpenCodeSessionDataReading = FoundationOpenCodeSessionDataReader(),
        scheduler: CodexSessionWatchScheduling = DispatchCodexSessionWatchScheduler(),
        maximumFileCount: Int = 256,
        maximumDepth: Int = 4,
        maximumVisitedEntries: Int = 4_096,
        maximumSnapshotBytes: Int = 1_048_576,
        eventHandler: @escaping @Sendable (AgentEvent) -> Void
    ) {
        self.rootURL = rootURL ?? homeDirectory.appendingPathComponent(Self.defaultRelativeRoot, isDirectory: true)
        self.fileManager = fileManager
        self.dataReader = dataReader
        self.scheduler = scheduler
        self.maximumFileCount = max(0, maximumFileCount)
        self.maximumDepth = max(0, maximumDepth)
        self.maximumVisitedEntries = max(0, maximumVisitedEntries)
        self.maximumSnapshotBytes = max(1, maximumSnapshotBytes)
        self.eventHandler = eventHandler
        syncQueue.setSpecific(key: syncQueueKey, value: 1)
    }

    deinit { stop() }

    public func start() {
        lifecycleLock.lock()
        guard !isRunning else { lifecycleLock.unlock(); return }
        isRunning = true
        generation &+= 1
        let startGeneration = generation
        timer = scheduler.schedule(every: 2) { [weak self] in
            self?.syncNow(expectedGeneration: startGeneration)
        }
        lifecycleLock.unlock()
        syncNow(expectedGeneration: startGeneration)
    }

    public func stop() {
        lifecycleLock.lock()
        let timer = self.timer
        self.timer = nil
        isRunning = false
        generation &+= 1
        lifecycleLock.unlock()
        timer?.cancel()
        onSyncQueue {
            fingerprints.removeAll()
            sessionIDsByPath.removeAll()
            endedPaths.removeAll()
            storedLastTransitions.removeAll()
        }
    }

    @discardableResult
    public func syncNow() -> [OpenCodeDiskSessionScanResult] {
        onSyncQueue { performSync(expectedGeneration: nil) }
    }

    @discardableResult
    private func syncNow(expectedGeneration: UInt64?) -> [OpenCodeDiskSessionScanResult] {
        onSyncQueue { performSync(expectedGeneration: expectedGeneration) }
    }

    private func performSync(expectedGeneration: UInt64?) -> [OpenCodeDiskSessionScanResult] {
        guard isGenerationActive(expectedGeneration) else { return [] }
        let scan = scanRecursively()
        let scannedFiles = scan.files
        let results = scannedFiles.map(\.result)
        var events: [AgentEvent] = []
        var nextFingerprints = fingerprints
        var nextSessionIDsByPath = sessionIDsByPath
        var visitedPaths: Set<String> = []
        var transitions: [OpenCodeContinuousSessionTransition] = []
        for scannedFile in scannedFiles {
            let result = scannedFile.result
            let key = result.fileURL.standardizedFileURL.path
            visitedPaths.insert(key)
            guard let snapshot = result.snapshot else {
                continue
            }
            let fingerprint = scannedFile.fingerprint
            nextFingerprints[key] = fingerprint
            nextSessionIDsByPath[key] = snapshot.session.directory
            let changed = fingerprints[key] != fingerprint
            if changed {
                transitions.append(.changed(path: key))
                if snapshot.session.archivedAt != nil {
                    transitions.append(.archived(path: key))
                    events.append(.sessionEnded(source: "opencode", sessionId: snapshot.session.directory))
                    endedPaths.insert(key)
                } else {
                    endedPaths.remove(key)
                    events.append(contentsOf: snapshot.agentEvents())
                }
            }
        }
        guard isGenerationActive(expectedGeneration) else { return results }
        if scan.isComplete {
            let deleted = Set(fingerprints.keys).subtracting(visitedPaths)
            transitions.append(contentsOf: deleted.sorted().map { .deleted(path: $0) })
            events.append(contentsOf: deleted.sorted().compactMap { path in
                guard !endedPaths.contains(path) else { return nil }
                return sessionIDsByPath[path].map { .sessionEnded(source: "opencode", sessionId: $0) }
            })
            deleted.forEach {
                nextFingerprints.removeValue(forKey: $0)
                nextSessionIDsByPath.removeValue(forKey: $0)
            }
            endedPaths.subtract(deleted)
        }
        storedLastTransitions = transitions
        fingerprints = nextFingerprints
        sessionIDsByPath = nextSessionIDsByPath
        for event in events {
            guard isGenerationActive(expectedGeneration) else { break }
            eventHandler(event)
        }
        return results
    }

    private struct ScannedFile {
        let result: OpenCodeDiskSessionScanResult
        let fingerprint: String
    }

    private struct ScannedFiles {
        let files: [ScannedFile]
        let isComplete: Bool
    }

    private func scanRecursively() -> ScannedFiles {
        let scan = OpenCodeBoundedJSONFileScanner(
            fileManager: fileManager,
            maximumFileCount: maximumFileCount,
            maximumDepth: maximumDepth,
            maximumVisitedEntries: maximumVisitedEntries
        ).scan(rootURL: rootURL)
        return ScannedFiles(files: scan.files.map { url in
            do {
                let data = try dataReader.read(url, maximumBytes: maximumSnapshotBytes)
                return ScannedFile(
                    result: .success(fileURL: url, snapshot: try OpenCodeDiskSessionParser.parseSnapshot(from: data)),
                    fingerprint: fingerprint(for: data)
                )
            } catch {
                return ScannedFile(
                    result: .failure(fileURL: url, error: error),
                    fingerprint: "failure"
                )
            }
        }, isComplete: scan.isComplete)
    }

    private func fingerprint(for data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        return "\(data.count):\(hash)"
    }

    private func isGenerationActive(_ expectedGeneration: UInt64?) -> Bool {
        guard let expectedGeneration else { return true }
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return isRunning && generation == expectedGeneration
    }

    private func onSyncQueue<T>(_ body: () -> T) -> T {
        if DispatchQueue.getSpecific(key: syncQueueKey) != nil { return body() }
        return syncQueue.sync(execute: body)
    }
}
