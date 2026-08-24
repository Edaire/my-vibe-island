import Foundation
import Darwin

public struct LocalProcessSnapshot: Equatable, Sendable {
    public let pid: Int
    public let tty: String?
    public let command: String

    public init(pid: Int, tty: String?, command: String) {
        self.pid = pid
        self.tty = tty
        self.command = command
    }
}

public protocol LocalProcessSnapshotRunning: Sendable {
    func run(executable: String, arguments: [String]) throws -> String
}

public enum LocalProcessSnapshotError: Error, Equatable, Sendable {
    case timedOut
    case outputLimitExceeded
    case nonzeroExit(Int32)
}

public extension LocalProcessSnapshotRunning {
    func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval,
        maximumOutputBytes: Int
    ) throws -> String {
        try run(executable: executable, arguments: arguments)
    }
}

public struct LocalProcessSnapshotProvider: Sendable {
    public static let executable = "/bin/ps"
    public static let arguments = ["-axo", "pid=,tty=,command="]
    public static let defaultTimeout: TimeInterval = 2
    public static let defaultMaximumOutputBytes = 1_048_576
    private let runner: LocalProcessSnapshotRunning
    private let timeout: TimeInterval
    private let maximumOutputBytes: Int

    public init(
        runner: LocalProcessSnapshotRunning? = nil,
        timeout: TimeInterval = Self.defaultTimeout,
        maximumOutputBytes: Int = Self.defaultMaximumOutputBytes
    ) {
        self.runner = runner ?? SystemLocalProcessSnapshotRunner()
        self.timeout = timeout
        self.maximumOutputBytes = maximumOutputBytes
    }

    public func snapshot() throws -> [LocalProcessSnapshot] {
        try runner.run(
            executable: Self.executable,
            arguments: Self.arguments,
            timeout: timeout,
            maximumOutputBytes: maximumOutputBytes
        )
            .split(whereSeparator: \.isNewline)
            .compactMap(parse)
    }

    private func parse(_ line: Substring) -> LocalProcessSnapshot? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let fields = trimmed.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" })
        guard fields.count == 3, let pid = Int(fields[0]), !fields[2].isEmpty else { return nil }
        return LocalProcessSnapshot(pid: pid, tty: fields[1] == "??" ? "??" : String(fields[1]), command: String(fields[2]))
    }
}

/// Shares the expensive process-table read between runtime publications. Hook
/// data remains live; this only bounds process discovery work.
public final class CachedLocalProcessSnapshotProvider: @unchecked Sendable {
    private let provider: LocalProcessSnapshotProvider
    private let minimumRefreshInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let lock = NSLock()
    private var cachedSnapshot: [LocalProcessSnapshot]?
    private var cachedAt: Date?

    public init(
        provider: LocalProcessSnapshotProvider = LocalProcessSnapshotProvider(),
        minimumRefreshInterval: TimeInterval = 5,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.provider = provider
        self.minimumRefreshInterval = max(0, minimumRefreshInterval)
        self.now = now
    }

    public func snapshot() throws -> [LocalProcessSnapshot] {
        let currentTime = now()
        lock.lock()
        if let cachedSnapshot,
           let cachedAt,
           currentTime.timeIntervalSince(cachedAt) < minimumRefreshInterval {
            lock.unlock()
            return cachedSnapshot
        }
        lock.unlock()

        let freshSnapshot = try provider.snapshot()
        lock.lock()
        cachedSnapshot = freshSnapshot
        cachedAt = currentTime
        lock.unlock()
        return freshSnapshot
    }
}

public struct SystemLocalProcessSnapshotRunner: LocalProcessSnapshotRunning, Sendable {
    public init() {}

    public func run(executable: String, arguments: [String]) throws -> String {
        try run(
            executable: executable,
            arguments: arguments,
            timeout: LocalProcessSnapshotProvider.defaultTimeout,
            maximumOutputBytes: LocalProcessSnapshotProvider.defaultMaximumOutputBytes
        )
    }

    public func run(
        executable: String,
        arguments: [String],
        timeout: TimeInterval,
        maximumOutputBytes: Int
    ) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        let state = ProcessReadState(maximumOutputBytes: maximumOutputBytes)
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            state.read(stdout.fileHandleForReading, into: .stdout, process: process)
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            state.read(stderr.fileHandleForReading, into: .stderr, process: process)
            group.leave()
        }

        do {
            try process.run()
        } catch {
            close(pipe: stdout)
            close(pipe: stderr)
            group.wait()
            throw error
        }
        let timeoutWork = DispatchWorkItem {
            if process.isRunning {
                state.markTimedOut()
                process.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
        process.waitUntilExit()
        timeoutWork.cancel()
        close(pipe: stdout)
        close(pipe: stderr)
        group.wait()
        if state.timedOut { throw LocalProcessSnapshotError.timedOut }
        if state.outputLimitExceeded { throw LocalProcessSnapshotError.outputLimitExceeded }
        guard process.terminationStatus == 0 else {
            throw LocalProcessSnapshotError.nonzeroExit(process.terminationStatus)
        }
        return String(decoding: state.stdoutData, as: UTF8.self)
    }

    private func close(pipe: Pipe) {
        try? pipe.fileHandleForWriting.close()
        try? pipe.fileHandleForReading.close()
    }
}

private final class ProcessReadState: @unchecked Sendable {
    enum Stream { case stdout, stderr }
    private let lock = NSLock()
    private let maximumOutputBytes: Int
    private var outputBytes = 0
    private(set) var stdoutData = Data()
    private(set) var outputLimitExceeded = false
    private(set) var timedOut = false

    init(maximumOutputBytes: Int) {
        self.maximumOutputBytes = max(1, maximumOutputBytes)
    }

    func read(_ handle: FileHandle, into stream: Stream, process: Process) {
        while true {
            guard let chunk = try? handle.read(upToCount: 4096), !chunk.isEmpty else { return }
            lock.lock()
            let nextCount = outputBytes + chunk.count
            if nextCount > maximumOutputBytes {
                outputLimitExceeded = true
                lock.unlock()
                if process.isRunning { process.terminate() }
                return
            }
            outputBytes = nextCount
            if stream == .stdout { stdoutData.append(chunk) }
            lock.unlock()
        }
    }

    func markTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }
}
